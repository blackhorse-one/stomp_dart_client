import 'dart:async';

import 'package:meta/meta.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class StompConfig {
  final String url;

  /// Time between reconnect attempts
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

  /// Asynchronous function to be executed before we connect the socket.
  ///
  /// Allows overwriting the config before a connection attempt is made.
  /// Return null to not overwrite the config
  final Future<StompConfig> Function() beforeConnect;

  /// Callback for when STOMP has successulfy connected
  final Function(StompClient, StompFrame) onConnect;

  /// Callback for when STOMP has disconnected
  final Function(StompFrame) onDisconnect;

  /// Callback for any errors encountered with STOMP
  final Function(StompFrame) onStompError;

  /// Error callback for unhandled STOMP frames
  final Function(StompFrame) onUnhandledFrame;

  /// Error callback for unhandled messages inside a frame
  final Function(StompFrame) onUnhandledMessage;

  /// Error callback for unhandled message receipts
  final Function(StompFrame) onUnhandledReceipt;

  /// Error callback for any errors with the underyling WebSocket
  final Function(dynamic) onWebSocketError;

  /// Callback when the underyling WebSocket connection is done/closed
  final Function() onWebSocketDone;

  /// Callback for debug messages
  final Function(String) onDebugMessage;

  const StompConfig({
    @required this.url,
    this.reconnectDelay = 5000,
    this.heartbeatIncoming = 5000,
    this.heartbeatOutgoing = 5000,
    this.connectionTimeout,
    this.stompConnectHeaders,
    this.webSocketConnectHeaders,
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
  });

  StompConfig copyWith(
          {String url,
          int reconnectDelay,
          int heartbeatIncoming,
          int heartbeatOutgoing,
          Duration connectionTimeout,
          Map<String, String> stompConnectHeaders,
          Map<String, dynamic> webSocketConnectHeaders,
          Future<StompConfig> Function() beforeConnect,
          Function(StompClient, StompFrame) onConnect,
          Function(StompFrame) onStompError,
          Function(StompFrame) onDisconnect,
          Function(StompFrame) onUnhandledFrame,
          Function(StompFrame) onUnhandledMessage,
          Function(StompFrame) onUnhandledReceipt,
          Function(dynamic) onWebSocketError,
          Function() onWebSocketDone}) =>
      StompConfig(
          url: url ?? this.url,
          reconnectDelay: reconnectDelay ?? this.reconnectDelay,
          heartbeatIncoming: heartbeatIncoming ?? this.heartbeatIncoming,
          heartbeatOutgoing: heartbeatOutgoing ?? this.heartbeatOutgoing,
          connectionTimeout: connectionTimeout ?? this.connectionTimeout,
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
          onWebSocketDone: onWebSocketDone ?? this.onWebSocketDone);

  static void _noOp([_, __]) => null;
  static Future<StompConfig> _noOpFuture() => null;
}
