import 'dart:async';

import 'package:stomp_dart_client/sock_js/sock_js_utils.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

typedef StompFrameCallback = void Function(StompFrame);
typedef StompBeforeConnectCallback = Future<void> Function();
typedef StompConnectCallback = void Function(StompClient?, StompFrame);
typedef StompDebugCallback = void Function(String);
typedef StompWebSocketErrorCallback = void Function(dynamic);
typedef StompWebSocketDoneCallback = void Function();

class StompConfig {
  /// The url of the WebSocket to connect to
  final String url;

  /// Whether to use SockJS
  final bool useSockJS;

  /// Time between reconnect attempts
  /// Set to 0 if you don't want to reconnect automatically
  final int reconnectDelay;

  /// Time between outgoing heartbeats
  /// Set to 0 to not send any heartbeats
  final int heartbeatOutgoing;

  /// Time between incoming heartbeats
  /// Set to 0 to not receive any heartbeats
  final int heartbeatIncoming;

  /// Connection timeout. If specified the connection will will be dropped after
  /// the timeout and depending on the [reconnectDelay] it will try again
  final Duration connectionTimeout;

  /// Headers to be passed when connecting to STOMP
  final Map<String, String> stompConnectHeaders;

  /// Headers to be passed when connecting to WebSocket
  final Map<String, dynamic> webSocketConnectHeaders;

  /// Asynchronous function to be executed before we connect
  /// the socket
  final StompBeforeConnectCallback beforeConnect;

  /// Callback for when STOMP has successfully connected
  final StompConnectCallback onConnect;

  /// Callback for when STOMP has disconnected
  final StompFrameCallback onDisconnect;

  /// Callback for any errors encountered with STOMP
  final StompFrameCallback onStompError;

  /// Error callback for unhandled STOMP frames
  final StompFrameCallback onUnhandledFrame;

  /// Error callback for unhandled messages inside a frame
  final StompFrameCallback onUnhandledMessage;

  /// Error callback for unhandled message receipts
  final StompFrameCallback onUnhandledReceipt;

  /// Error callback for any errors with the underlying WebSocket
  final StompWebSocketErrorCallback onWebSocketError;

  /// Callback when the underlying WebSocket connection is done/closed
  final StompWebSocketDoneCallback onWebSocketDone;

  /// Callback for debug messages
  final StompDebugCallback onDebugMessage;

  const StompConfig({
    required this.url,
    this.reconnectDelay = 5000,
    this.heartbeatIncoming = 5000,
    this.heartbeatOutgoing = 5000,
    this.connectionTimeout = const Duration(),
    this.stompConnectHeaders = const {},
    this.webSocketConnectHeaders = const {},
    this.beforeConnect = _noOpFuture,
    this.onConnect = _noOp,
    this.onStompError = _noOp,
    this.onDisconnect = _noOp,
    this.onUnhandledFrame = _noOp,
    this.onUnhandledMessage = _noOp,
    this.onUnhandledReceipt = _noOp,
    this.onWebSocketError = _noOp,
    this.onWebSocketDone = _noOp,
    this.onDebugMessage = _noOp,
    this.useSockJS = false,
  });

  StompConfig.SockJS({
    required String url,
    this.reconnectDelay = 5000,
    this.heartbeatIncoming = 5000,
    this.heartbeatOutgoing = 5000,
    this.connectionTimeout = const Duration(),
    this.stompConnectHeaders = const {},
    this.webSocketConnectHeaders = const {},
    this.beforeConnect = _noOpFuture,
    this.onConnect = _noOp,
    this.onStompError = _noOp,
    this.onDisconnect = _noOp,
    this.onUnhandledFrame = _noOp,
    this.onUnhandledMessage = _noOp,
    this.onUnhandledReceipt = _noOp,
    this.onWebSocketError = _noOp,
    this.onWebSocketDone = _noOp,
    this.onDebugMessage = _noOp,
  })  : useSockJS = true,
        url = SockJsUtils().generateTransportUrl(url);

  StompConfig copyWith({
    String? url,
    int? reconnectDelay,
    int? heartbeatIncoming,
    int? heartbeatOutgoing,
    Duration? connectionTimeout,
    bool? useSockJS,
    Map<String, String>? stompConnectHeaders,
    Map<String, dynamic>? webSocketConnectHeaders,
    StompBeforeConnectCallback? beforeConnect,
    StompConnectCallback? onConnect,
    StompFrameCallback? onStompError,
    StompFrameCallback? onDisconnect,
    StompFrameCallback? onUnhandledFrame,
    StompFrameCallback? onUnhandledMessage,
    StompFrameCallback? onUnhandledReceipt,
    StompWebSocketErrorCallback? onWebSocketError,
    StompWebSocketDoneCallback? onWebSocketDone,
    StompDebugCallback? onDebugMessage,
  }) {
    return StompConfig(
      url: url ?? this.url,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      heartbeatIncoming: heartbeatIncoming ?? this.heartbeatIncoming,
      heartbeatOutgoing: heartbeatOutgoing ?? this.heartbeatOutgoing,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      useSockJS: useSockJS ?? this.useSockJS,
      webSocketConnectHeaders:
          webSocketConnectHeaders ?? this.webSocketConnectHeaders,
      stompConnectHeaders: stompConnectHeaders ?? this.stompConnectHeaders,
      beforeConnect: beforeConnect ?? this.beforeConnect,
      onConnect: onConnect ?? this.onConnect,
      onStompError: onStompError ?? this.onStompError,
      onDisconnect: onDisconnect ?? this.onDisconnect,
      onUnhandledFrame: onUnhandledFrame ?? this.onUnhandledFrame,
      onUnhandledMessage: onUnhandledMessage ?? this.onUnhandledMessage,
      onUnhandledReceipt: onUnhandledReceipt ?? this.onUnhandledReceipt,
      onWebSocketError: onWebSocketError ?? this.onWebSocketError,
      onWebSocketDone: onWebSocketDone ?? this.onWebSocketDone,
      onDebugMessage: onDebugMessage ?? this.onDebugMessage,
    );
  }

  static void _noOp([_, __]) => null;

  static Future<void> _noOpFuture() => Future.value();
}
