import 'dart:async';
import 'dart:typed_data';

import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_handler.dart';

class StompClient {
  StompClient({required this.config});

  final StompConfig config;

  bool get connected => _handler?.connected ?? false;

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
    if (_handler != null) {
      return _handler!.subscribe(
        destination: destination,
        callback: callback,
        headers: headers,
      );
    }

    return ({Map<String, String>? unsubscribeHeaders}) {};
  }

  void send({
    required String destination,
    Map<String, String>? headers,
    String? body,
    Uint8List? binaryBody,
  }) {
    if (_handler != null) {
      _handler!.send(
        destination: destination,
        headers: headers,
        body: body,
        binaryBody: binaryBody,
      );
    }
  }

  void ack({required String id, Map<String, String>? headers}) {
    if (_handler != null) {
      _handler!.ack(id: id, headers: headers);
    }
  }

  void nack({required String id, Map<String, String>? headers}) {
    if (_handler != null) {
      _handler!.nack(id: id, headers: headers);
    }
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
