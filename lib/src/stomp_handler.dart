import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'parser.dart';
import 'sock_js/sock_js_parser.dart';
import 'stomp_config.dart';
import 'stomp_exception.dart';
import 'stomp_frame.dart';
import 'stomp_parser.dart';

import 'connect_api.dart'
    if (dart.library.js_interop) 'connect_html.dart'
    if (dart.library.io) 'connect_io.dart' as platform;

typedef StompUnsubscribe = void Function({
  Map<String, String>? unsubscribeHeaders,
});

class StompHandler {
  StompHandler({required this.config}) {
    if (config.useSockJS) {
      // use SockJS parser
      _parser = SockJSParser(
        onStompFrame: _onFrame,
        onPingFrame: _onPing,
        onDone: _onDone,
      );
    } else {
      _parser = StompParser(_onFrame, _onPing);
    }
  }

  final StompConfig config;

  late Parser _parser;
  WebSocketChannel? _channel;
  bool _connected = false;
  bool _isActive = false;
  int _currentReceiptIndex = 0;
  int _currentSubscriptionIndex = 0;
  DateTime _lastServerActivity = DateTime.now();

  final _receiptWatchers = <String, StompFrameCallback>{};
  final _subscriptionWatcher = <String, StompFrameCallback>{};

  Timer? _heartbeatSender;
  Timer? _heartbeatReceiver;

  bool get connected => _connected;

  void start() async {
    _isActive = true;
    try {
      _channel = await platform.connect(config..resetSession());
      // It can happen that dispose was called while the future above hasn't completed yet
      // To prevent lingering connections we need to make sure that we disconnect cleanly
      if (!_isActive) {
        _cleanUp();
      } else {
        _channel!.stream.listen(_onData, onError: _onError, onDone: _onDone);
        _connectToStomp();
      }
    } catch (err) {
      _onError(err);
      if (config.reconnectDelay.inMilliseconds == 0) {
        _cleanUp();
      } else {
        if (err is TimeoutException) {
          config.onDebugMessage('Connection timed out...reconnecting');
        } else if (err is WebSocketChannelException) {
          config.onDebugMessage('Connection error...reconnecting');
        } else {
          config.onDebugMessage('Unknown connection error...reconnecting');
        }
        _onDone();
      }
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

  StompUnsubscribe subscribe({
    required String destination,
    required StompFrameCallback callback,
    Map<String, String>? headers,
  }) {
    final subscriptionHeaders = {
      ...?headers,
      'destination': destination,
    };

    if (!subscriptionHeaders.containsKey('id')) {
      subscriptionHeaders['id'] = 'sub-${_currentSubscriptionIndex++}';
    }

    _subscriptionWatcher[subscriptionHeaders['id']!] = callback;
    _transmit(command: 'SUBSCRIBE', headers: subscriptionHeaders);

    return ({Map<String, String>? unsubscribeHeaders}) {
      if (!connected) return;
      final headers = {...?unsubscribeHeaders};
      if (!headers.containsKey('id')) {
        headers['id'] = subscriptionHeaders['id']!;
      }
      _subscriptionWatcher.remove(headers['id']);

      _transmit(command: 'UNSUBSCRIBE', headers: headers);
    };
  }

  void send({
    required String destination,
    Map<String, String>? headers,
    String? body,
    Uint8List? binaryBody,
  }) {
    _transmit(
      command: 'SEND',
      body: body,
      binaryBody: binaryBody,
      headers: {
        ...?headers,
        'destination': destination,
      },
    );
  }

  void ack({required String id, Map<String, String>? headers}) {
    _transmit(command: 'ACK', headers: {...?headers, 'id': id});
  }

  void nack({required String id, Map<String, String>? headers}) {
    _transmit(command: 'NACK', headers: {...?headers, 'id': id});
  }

  void watchForReceipt(String receiptId, StompFrameCallback callback) {
    _receiptWatchers[receiptId] = callback;
  }

  void _connectToStomp() {
    final connectHeaders = {
      ...?config.stompConnectHeaders,
      'accept-version': ['1.0', '1.1', '1.2'].join(','),
      'heart-beat': [
        config.heartbeatOutgoing.inMilliseconds,
        config.heartbeatIncoming.inMilliseconds,
      ].join(','),
    };

    _transmit(command: 'CONNECT', headers: connectHeaders);
  }

  void _disconnectFromStomp() {
    final disconnectHeaders = {
      'receipt': 'disconnect-${_currentReceiptIndex++}',
    };

    watchForReceipt(disconnectHeaders['receipt']!, (frame) {
      _cleanUp();
      config.onDisconnect(frame);
    });

    _transmit(command: 'DISCONNECT', headers: disconnectHeaders);
  }

  void _transmit({
    required String command,
    required Map<String, String> headers,
    String? body,
    Uint8List? binaryBody,
  }) {
    final frame = StompFrame(
      command: command,
      headers: headers,
      body: body,
      binaryBody: binaryBody,
    );

    dynamic serializedFrame = _parser.serializeFrame(frame);
    config.onDebugMessage('>>> $serializedFrame');

    try {
      _channel!.sink.add(serializedFrame);
    } catch (_) {
      throw StompBadStateException(
        'The StompHandler has no active connection '
        'or the connection was unexpectedly closed.',
      );
    }
  }

  void _onError(dynamic error) {
    config.onWebSocketError(error);
  }

  void _onDone() {
    config.onWebSocketDone();
    _cleanUp();
  }

  void _onData(dynamic data) {
    _lastServerActivity = DateTime.now();
    config.onDebugMessage('<<< $data');
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

    config.onConnect(frame);
  }

  void _onMessageFrame(StompFrame frame) {
    final subscriptionId = frame.headers['subscription'];

    if (_subscriptionWatcher.containsKey(subscriptionId)) {
      _subscriptionWatcher[subscriptionId]!(frame);
    } else {
      config.onUnhandledMessage(frame);
    }
  }

  void _onReceiptFrame(StompFrame frame) {
    final receiptId = frame.headers['receipt-id'];
    if (_receiptWatchers.containsKey(receiptId)) {
      _receiptWatchers[receiptId]!(frame);
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
    final serverHeartbeats = frame.headers['heart-beat']!.split(',');
    final serverOutgoing = int.parse(serverHeartbeats[0]);
    final serverIncoming = int.parse(serverHeartbeats[1]);
    if (config.heartbeatOutgoing.inMilliseconds > 0 && serverIncoming > 0) {
      final ttl = max(config.heartbeatOutgoing.inMilliseconds, serverIncoming);
      _heartbeatSender?.cancel();
      _heartbeatSender = Timer.periodic(Duration(milliseconds: ttl), (_) {
        config.onDebugMessage('>>> PING');
        if (config.useSockJS) {
          _channel?.sink.add('["\\n"]');
        } else {
          _channel?.sink.add('\n');
        }
      });
    }

    if (config.heartbeatIncoming.inMilliseconds > 0 && serverOutgoing > 0) {
      final ttl = max(config.heartbeatIncoming.inMilliseconds, serverOutgoing);
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
    _isActive = false;
    _heartbeatSender?.cancel();
    _heartbeatReceiver?.cancel();
    _channel?.sink.close();
  }
}
