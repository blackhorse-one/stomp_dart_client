import 'dart:async';
import 'dart:typed_data';

import 'stomp_config.dart';
import 'stomp_exception.dart';
import 'stomp_handler.dart';

class StompClient {
  StompClient({required this.config});

  final StompConfig config;

  bool get connected => _handler?.connected ?? false;

  bool get isActive => _isActive;

  StompHandler? _handler;
  Timer? _reconnectTimer;
  bool _isActive = false;

  void activate() {
    _isActive = true;
    _connect();
  }

  void deactivate() {
    _isActive = false;
    _reconnectTimer?.cancel();
    _handler?.dispose();
    _handler = null;
  }

  void _connect() async {
    if (connected) {
      config.onDebugMessage('[STOMP] Already connected. Nothing to do!');
      return;
    }

    await config.beforeConnect();

    if (!_isActive) {
      config.onDebugMessage('[STOMP] Client was marked as inactive. Skip!');
      return;
    }

    _handler = StompHandler(
      config: config.copyWith(
        onConnect: (frame) {
          if (!_isActive) {
            config.onDebugMessage(
                '[STOMP] Client connected while being deactivated. Will disconnect.');
            _handler?.dispose();
            return;
          }
          config.onConnect(frame);
        },
        onWebSocketDone: () {
          config.onWebSocketDone();
          if (_isActive) {
            _scheduleReconnect();
          }
        },
      ),
    )..start();
  }

  StompUnsubscribe subscribe({
    required String destination,
    required StompFrameCallback callback,
    Map<String, String>? headers,
  }) {
    final handler = _handler;
    if (handler == null) {
      throw StompBadStateException(
        'The StompHandler was null. '
        'Did you forget calling activate() on the client?',
      );
    }

    return handler.subscribe(
      destination: destination,
      callback: callback,
      headers: headers,
    );
  }

  void send({
    required String destination,
    Map<String, String>? headers,
    String? body,
    Uint8List? binaryBody,
  }) {
    final handler = _handler;
    if (handler == null) {
      throw StompBadStateException(
        'The StompHandler was null. '
        'Did you forget calling activate() on the client?',
      );
    }

    handler.send(
      destination: destination,
      headers: headers,
      body: body,
      binaryBody: binaryBody,
    );
  }

  /// Acknowledges the receipt of a message.
  /// For STOMP [versions 1.0](https://stomp.github.io/stomp-specification-1.0.html#frame-ACK) and [version 1.1](https://stomp.github.io/stomp-specification-1.1.html#ACK), the key used in the header for message identification is `'message-id'`.
  /// For STOMP [version 1.2](https://stomp.github.io/stomp-specification-1.2.html#ACK) and newer, the key used is `'id'`.
  /// [id] The unique identifier of the message to acknowledge.
  /// [headers] Optional additional headers to include in the ACK frame. If `headerKeyForMessageId` is not specified in [headers],
  /// it defaults to `'id'` for newer versions.
  ///
  /// Example usage:
  /// ```dart
  /// ack(id: 'message-id-value', headers: {'headerKeyForMessageId': 'message-id'});
  /// ```
  void ack({required String id, Map<String, String>? headers}) {
    final handler = _handler;
    if (handler == null) {
      throw StompBadStateException(
        'The StompHandler was null. '
        'Did you forget calling activate() on the client?',
      );
    }

    handler.ack(id: id, headers: headers);
  }

  /// Not acknowledges the receipt of a message.
  /// For STOMP versions 1.0 this function is not supported
  /// For STOMP [versions 1.1](https://stomp.github.io/stomp-specification-1.1.html#NACK), the key used in the header for message identification is `'message-id'`.
  /// For STOMP [version 1.2](https://stomp.github.io/stomp-specification-1.2.html#NACK) and newer, the key used is `'id'`.
  /// [id] The unique identifier of the message to not acknowledge.
  /// [headers] Optional additional headers to include in the NACK frame. If `headerKeyForMessageId` is not specified in [headers],
  /// it defaults to `'id'` for newer versions.
  ///
  /// Example usage:
  /// ```dart
  /// nack(id: 'message-id-value', headers: {'headerKeyForMessageId': 'message-id'});
  /// ```
  void nack({required String id, Map<String, String>? headers}) {
    final handler = _handler;
    if (handler == null) {
      throw StompBadStateException(
        'The StompHandler was null. '
        'Did you forget calling activate() on the client?',
      );
    }

    handler.nack(id: id, headers: headers);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (config.reconnectDelay.inMilliseconds > 0) {
      _reconnectTimer = Timer(
        config.reconnectDelay,
        () => _connect(),
      );
    }
  }
}
