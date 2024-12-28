import 'dart:async';

import 'sock_js/sock_js_utils.dart';
import 'stomp_frame.dart';

typedef StompFrameCallback = void Function(StompFrame);
typedef StompBeforeConnectCallback = Future<void> Function();
typedef StompDebugCallback = void Function(String);
typedef StompWebSocketErrorCallback = void Function(dynamic);
typedef StompWebSocketDoneCallback = void Function();

class StompConfig {
  /// The url of the WebSocket to connect to
  final String url;

  /// Whether to use SockJS
  final bool useSockJS;

  /// Time between reconnect attempts
  /// Set to a duration with 0 milliseconds if you don't want to reconnect
  /// automatically
  final Duration reconnectDelay;

  /// Time between outgoing heartbeats
  /// Set to a duration with 0 milliseconds to not send any heartbeats
  final Duration heartbeatOutgoing;

  /// Time between incoming heartbeats
  /// Set to a duration with 0 milliseconds to not receive any heartbeats
  final Duration heartbeatIncoming;

  /// Time between sent pings on the underlying WebSocket (unsupported in HTML)
  final Duration? pingInterval;

  /// Connection timeout. If specified the connection will be dropped after
  /// the timeout and depending on the [reconnectDelay] it will try again
  final Duration connectionTimeout;

  /// Optional Headers to be passed when connecting to STOMP
  final Map<String, String>? stompConnectHeaders;

  /// Optional Headers to be passed when connecting to WebSocket
  final Map<String, dynamic>? webSocketConnectHeaders;

  /// Asynchronous function to be executed before we connect
  /// the socket
  final StompBeforeConnectCallback beforeConnect;

  /// Callback for when STOMP has successfully connected
  final StompFrameCallback onConnect;

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

  /// The transport url of the WebSocket to connect to
  String get connectUrl =>
      _connectUrl ??= useSockJS ? SockJsUtils().generateTransportUrl(url) : url;

  String? _connectUrl;

  StompConfig({
    required this.url,
    this.reconnectDelay = const Duration(seconds: 5),
    this.heartbeatIncoming = const Duration(seconds: 5),
    this.heartbeatOutgoing = const Duration(seconds: 5),
    this.connectionTimeout = Duration.zero,
    this.stompConnectHeaders,
    this.webSocketConnectHeaders,
    this.pingInterval,
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

  StompConfig.sockJS({
    required this.url,
    this.reconnectDelay = const Duration(seconds: 5),
    this.heartbeatIncoming = const Duration(seconds: 5),
    this.heartbeatOutgoing = const Duration(seconds: 5),
    this.connectionTimeout = Duration.zero,
    this.stompConnectHeaders,
    this.webSocketConnectHeaders,
    this.pingInterval,
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
  }) : useSockJS = true;

  StompConfig copyWith({
    String? url,
    Duration? reconnectDelay,
    Duration? heartbeatIncoming,
    Duration? heartbeatOutgoing,
    Duration? connectionTimeout,
    bool? useSockJS,
    Map<String, String>? stompConnectHeaders,
    Map<String, dynamic>? webSocketConnectHeaders,
    StompBeforeConnectCallback? beforeConnect,
    StompFrameCallback? onConnect,
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

  /// Resets the transport URL
  void resetSession() => _connectUrl = null;

  static void _noOp([_, __]) {}

  static Future<void> _noOpFuture() => Future.value();
}
