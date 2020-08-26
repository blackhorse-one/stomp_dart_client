import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:stomp_dart_client/parser.dart';
import 'package:stomp_dart_client/sock_js/sock_js_parser.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:stomp_dart_client/stomp_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'src/_connect_api.dart'
    if (dart.library.html) 'src/_connect_html.dart'
    if (dart.library.io) 'src/_connect_io.dart' as platform;

class StompHandler {
  WebSocketChannel channel;
  final StompConfig config;

  Parser _parser;
  bool _connected = false;
  int _currentReceiptIndex = 0;
  int _currentSubscriptionIndex = 0;

  final Map<String, Function> _receiptWatchers = {};
  final Map<String, Function> _subscriptionWatcher = {};

  DateTime _lastServerActivity;

  Timer _heartbeatSender;
  Timer _heartbeatReceiver;

  StompHandler({@required this.config}) {
    if (config.useSockJS) {
      // use SockJS parser
      _parser = SockJSParser(
          onStompFrame: _onFrame, onPingFrame: _onPing, onDone: _onDone);
    } else {
      _parser = StompParser(_onFrame, _onPing);
    }
    _lastServerActivity = DateTime.now();
    _currentReceiptIndex = 0;
    _currentSubscriptionIndex = 0;
  }

  bool get connected => _connected;

  void start() async {
    try {
      channel = await platform.connect(config);
      channel.stream.listen(_onData, onError: _onError, onDone: _onDone);
      _connectToStomp();
    } on WebSocketChannelException catch (err) {
      if (config.reconnectDelay == 0) {
        _onError(err);
      } else {
        config.onDebugMessage('Connection error...reconnecting');
        _onDone();
      }
    } on TimeoutException catch (err) {
      if (config.reconnectDelay == 0) {
        _onError(err);
      } else {
        config.onDebugMessage('Connection timed out...reconnecting');
        _onDone();
      }
    } catch (err) {
      _onDone();
    }
  }

  void dispose() {
    if (connected) {
      _disconnectFromStomp();
    } else {
      // Make sure we _cleanUp regardless
      _cleanUp();
    }
  }

  Function({Map<String, String> unsubscribeHeaders}) subscribe(
      {@required String destination,
      @required Function(StompFrame) callback,
      Map<String, String> headers}) {
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

  void send(
      {@required String destination,
      String body,
      Uint8List binaryBody,
      Map<String, String> headers}) {
    headers = headers ?? {};
    headers['destination'] = destination;
    _transmit(
        command: 'SEND', body: body, binaryBody: binaryBody, headers: headers);
  }

  void ack({@required String id, Map<String, String> headers}) {
    headers = headers ?? {};
    headers['id'] = id;
    _transmit(command: 'ACK', headers: headers);
  }

  void nack({@required String id, Map<String, String> headers}) {
    headers = headers ?? {};
    headers['id'] = id;
    _transmit(command: 'NACK', headers: headers);
  }

  void watchForReceipt(String receiptId, Function(StompFrame) callback) {
    _receiptWatchers[receiptId] = callback;
  }

  void _connectToStomp() {
    var connectHeaders = config.stompConnectHeaders ?? {};
    connectHeaders['accept-version'] = ['1.0', '1.1', '1.2'].join(',');
    connectHeaders['heart-beat'] =
        [config.heartbeatOutgoing, config.heartbeatIncoming].join(',');

    _transmit(command: 'CONNECT', headers: connectHeaders);
  }

  void _disconnectFromStomp() {
    final disconnectHeaders = <String, String>{};
    disconnectHeaders['receipt'] = 'disconnect-${_currentReceiptIndex++}';

    watchForReceipt(disconnectHeaders['receipt'], (StompFrame frame) {
      _cleanUp();
      config.onDisconnect(frame);
    });

    _transmit(command: 'DISCONNECT', headers: disconnectHeaders);
  }

  void _transmit(
      {String command,
      Map<String, String> headers,
      String body,
      Uint8List binaryBody}) {
    final frame = StompFrame(
        command: command, headers: headers, body: body, binaryBody: binaryBody);

    dynamic serializedFrame = _parser.serializeFrame(frame);

    config.onDebugMessage('>>> ' + serializedFrame.toString());

    channel.sink.add(serializedFrame);
  }

  void _onError(error) {
    config.onWebSocketError(error);
  }

  void _onDone() {
    config.onWebSocketDone();
    _cleanUp();
  }

  void _onData(dynamic data) {
    _lastServerActivity = DateTime.now();
    config.onDebugMessage('<<< ' + data.toString());
    _parser.parseData(data);
  }

  void _onFrame(StompFrame frame) {
    switch (frame.command) {
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
    config.onDebugMessage('<<< PONG');
  }

  void _onConnectFrame(StompFrame frame) {
    _connected = true;

    if (frame.headers['version'] != '1.0') {
      _parser.escapeHeaders = true;
    } else {
      _parser.escapeHeaders = false;
    }

    if (frame.headers['version'] != '1.0' &&
        frame.headers.containsKey('heart-beat')) {
      _setupHeartbeat(frame);
    }

    config.onConnect(null, frame);
  }

  void _onMessageFrame(StompFrame frame) {
    final subscriptionId = frame.headers['subscription'];

    if (_subscriptionWatcher.containsKey(subscriptionId)) {
      _subscriptionWatcher[subscriptionId](frame);
    } else {
      config.onUnhandledMessage(frame);
    }
  }

  void _onReceiptFrame(StompFrame frame) {
    final receiptId = frame.headers['receipt-id'];
    if (_receiptWatchers.containsKey(receiptId)) {
      _receiptWatchers[receiptId](frame);
      _receiptWatchers.remove(receiptId);
    } else {
      config.onUnhandledReceipt(frame);
    }
  }

  void _onErrorFrame(StompFrame frame) {
    config.onStompError(frame);
  }

  void _onUnhandledFrame(StompFrame frame) {
    config.onUnhandledFrame(frame);
  }

  void _setupHeartbeat(StompFrame frame) {
    final serverHeartbeats = frame.headers['heart-beat'].split(',');
    final serverOutgoing = int.parse(serverHeartbeats[0]);
    final serverIncoming = int.parse(serverHeartbeats[1]);
    if (config.heartbeatOutgoing > 0 && serverIncoming > 0) {
      final ttl = max(config.heartbeatOutgoing, serverIncoming);
      _heartbeatSender?.cancel();
      _heartbeatSender = Timer.periodic(Duration(milliseconds: ttl), (_) {
        config.onDebugMessage('>>> PING');
        if (config.useSockJS) {
          channel.sink.add('[\\n]');
        } else {
          channel.sink.add('\n');
        }
      });
    }

    if (config.heartbeatIncoming > 0 && serverOutgoing > 0) {
      final ttl = max(config.heartbeatIncoming, serverOutgoing);
      _heartbeatReceiver?.cancel();
      _heartbeatReceiver = Timer.periodic(Duration(milliseconds: ttl), (_) {
        final deltaMs = DateTime.now().millisecondsSinceEpoch -
            _lastServerActivity.millisecondsSinceEpoch;
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
    channel?.sink?.close();
  }
}
