import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:stomp_dart/stomp_config.dart';
import 'package:stomp_dart/stomp_frame.dart';
import 'package:stomp_dart/stomp_parser.dart';
import 'package:web_socket_channel/io.dart';

class StompHandler {
  IOWebSocketChannel channel; 
  final StompConfig config;

  StompParser _parser;
  bool _connected = false;
  int _currentReceiptIndex = 0;
  int _currentSubscriptionIndex = 0;

  Map<String, Function> _receiptWatchers = {};
  Map<String, Function> _subscriptionWatcher = {};

  DateTime _lastServerActivity;

  Timer _heartbeatSender;
  Timer _heartbeatReceiver;
  

  StompHandler({@required this.config}) {
    _parser = StompParser(_onFrame, _onPing);

    _lastServerActivity = DateTime.now();
    _currentReceiptIndex = 0;
    _currentSubscriptionIndex = 0;
  }

  get connected => this._connected;

  void start() {
    this.channel = IOWebSocketChannel.connect(config.url, timeout: Duration(milliseconds: 2000))
                      ..stream.listen(_onData, onError: _onError, onDone: _onDone);
    this.channel.ready.then((_) {
      _connectToStomp();
    });
  }

  void dispose() {
    if (connected) {
      _disconnectFromStomp();
    } else {
      // Make sure we _cleanUp regardless
      _cleanUp();
    }
  }

  Function({Map<String, String> unsubscribeHeaders}) subscribe({@required String destination, @required Function(StompFrame) callback, Map<String, String> headers}) {
    headers = headers ?? {};

    if (!headers.containsKey('id')) {
      headers['id'] = 'sub-${_currentSubscriptionIndex++}';
    }
    headers['destination'] = destination;
    _subscriptionWatcher[headers['id']] = callback;

    _transmit(command: 'SUBSCRIBE', headers: headers);

    return ({Map<String, String> unsubscribeHeaders}) {
      unsubscribeHeaders = unsubscribeHeaders ?? {};
      
      if (!unsubscribeHeaders.containsKey('id')) {
        unsubscribeHeaders['id'] = headers['id'];
      }
      _subscriptionWatcher.remove(unsubscribeHeaders['id']);

      _transmit(command: 'UNSUBSCRIBE', headers: unsubscribeHeaders);
    };
  }

  void send({@required String destination, String body, Uint8List binaryBody, Map<String, String> headers}) {
    headers = headers ?? {};
    headers['destination'] = destination;
    _transmit(command: 'SEND', body: body, binaryBody: binaryBody, headers: headers);
  }

  void watchForReceipt(String receiptId, Function(StompFrame) callback) {
    _receiptWatchers[receiptId] = callback;
  }

  void _connectToStomp() {
    Map<String, String> connectHeaders = config.connectHeaders ?? {};
    connectHeaders['accept-version'] = ['1.0', '1.1', '1.2'].join(',');
    connectHeaders['heart-beat'] = [this.config.heartbeatOutgoing, this.config.heartbeatIncoming].join(',');

    this._transmit(command: 'CONNECT', headers: connectHeaders);
  }

  void _disconnectFromStomp() {
    Map<String, String> disconnectHeaders = {};
    disconnectHeaders['receipt'] = 'disconnect-${_currentReceiptIndex++}';

    watchForReceipt(disconnectHeaders['receipt'], (StompFrame frame) {
      _cleanUp();
      this.config.onDisconnect(frame);
    });

    this._transmit(command: 'DISCONNECT', headers: disconnectHeaders);
  }

  void _transmit({String command, Map<String, String> headers, String body, Uint8List binaryBody}) {
    final StompFrame frame = StompFrame(
      command: command,
      headers: headers,
      body: body,
      binaryBody: binaryBody
    );

    dynamic serializedFrame = _parser.serializeFrame(frame);

    this.config.onDebugMessage(">>> " + serializedFrame);

    channel.sink.add(serializedFrame);
  }

  void _onError(error) {
    this.config.onWebSocketError(error);
  }

  void _onDone() {
    this.config.onWebSocketDone();
    _cleanUp();
  }

  void _onData(dynamic data) {
    _lastServerActivity = DateTime.now();
    this.config.onDebugMessage("<<< " + data);
    _parser.parseData(data);
  }

  void _onFrame(StompFrame frame) {
    switch(frame.command) {
      case 'CONNECTED':
        _onConnectFrame(frame);
        break;
      case 'MESSAGE':
        _onMessageFrame(frame);
        break;
      case 'RECEIPT':
        _onReceiptFrame(frame);
        break;
      case 'ERROR':
        _onErrorFrame(frame);
        break;
      default:
        _onUnhandledFrame(frame);
    }
  }

  void _onPing() {
    this.config.onDebugMessage("<<< PONG");
  }

  void _onConnectFrame(StompFrame frame) {
    this._connected = true;

    if (frame.headers['version'] != '1.0') {
      _parser.escapeHeaders = true;
    } else {
      _parser.escapeHeaders = false;
    }

    if (frame.headers['version'] != '1.0' && 
        frame.headers.containsKey('heart-beat')) {
      _setupHeartbeat(frame);
    }

    this.config.onConnect(null, frame);
  }

  void _onMessageFrame(StompFrame frame) {
    String subscriptionId = frame.headers['subscription'];

    if (_subscriptionWatcher.containsKey(subscriptionId)) {
      _subscriptionWatcher[subscriptionId](frame);
    } else {
      this.config.onUnhandledMessage(frame);
    }
  }

  void _onReceiptFrame(StompFrame frame) {
    String receiptId = frame.headers['receipt-id'];
    if (_receiptWatchers.containsKey(receiptId)) {
      _receiptWatchers[receiptId](frame);
      _receiptWatchers.remove(receiptId);
    } else {
      this.config.onUnhandledReceipt(frame);
    }
  }

  void _onErrorFrame(StompFrame frame) {
    this.config.onStompError(frame);
  }

  void _onUnhandledFrame(StompFrame frame) {
    this.config.onUnhandledFrame(frame);
  }

  void _setupHeartbeat(StompFrame frame) {
    List<String> serverHeartbeats = frame.headers['heart-beat'].split(',');
    int serverOutgoing = int.parse(serverHeartbeats[0]);
    int serverIncoming = int.parse(serverHeartbeats[1]);
    if (this.config.heartbeatOutgoing > 0 && serverIncoming > 0) {
      int ttl = max(this.config.heartbeatOutgoing, serverIncoming);
      _heartbeatSender?.cancel();
      _heartbeatSender = Timer.periodic(Duration(milliseconds: ttl), (_) {
        this.config.onDebugMessage(">>> PING");
        this.channel.sink.add('\n');
      });
    }

    if (this.config.heartbeatIncoming > 0 && serverOutgoing > 0) {
      int ttl = max(this.config.heartbeatIncoming, serverOutgoing);
      _heartbeatReceiver?.cancel();
      _heartbeatReceiver = Timer.periodic(Duration(milliseconds: ttl), (_) {
        int deltaMs = DateTime.now().millisecondsSinceEpoch - _lastServerActivity.millisecondsSinceEpoch;
        // The connection might be dead. Clean up.
        if (deltaMs > (ttl * 2)) {
          _cleanUp();
        }
      });
    }
  }

  void _cleanUp() {
    _connected = false;
    _heartbeatSender?.cancel();
    _heartbeatReceiver?.cancel();
    this.channel?.sink?.close();
  }
}