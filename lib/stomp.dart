import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:stomp_dart_client/stomp_handler.dart';

class BadStateException implements Exception {
  final String cause;

  BadStateException(this.cause);
}

class StompClient {
  StompConfig get config => _config;

  StompHandler _handler;
  bool _isActive = false;
  Timer _reconnectTimer;
  StompConfig _config;

  StompClient({@required StompConfig config})
      : _config = config,
        assert(config != null);

  bool get connected => (_handler != null) && _handler.connected;

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
      _config.onDebugMessage('[STOMP] Already connected. Nothing to do!');
      return;
    }

    final updatedConfig = await _config.beforeConnect();
    if (updatedConfig != null) {
      _config = updatedConfig;
    }

    if (!_isActive) {
      _config.onDebugMessage('[STOMP] Client was marked as inactive. Skip!');
      return;
    }

    _handler = StompHandler(
        config: _config.copyWith(onConnect: (_, frame) {
      if (!_isActive) {
        _config.onDebugMessage(
            '[STOMP] Client connected while being deactivated. Will disconnect');
        _handler?.dispose();
        return;
      }
      _config.onConnect(this, frame);
    }, onWebSocketDone: () {
      _config.onWebSocketDone();

      if (_isActive) {
        _scheduleReconnect();
      }
    }));
    _handler.start();
  }

  Function({Map<String, String> unsubscribeHeaders}) subscribe(
      {@required String destination,
      @required Function(StompFrame) callback,
      Map<String, String> headers}) {
    return _handler.subscribe(
        destination: destination, callback: callback, headers: headers);
  }

  void send(
      {@required String destination,
      String body,
      Uint8List binaryBody,
      Map<String, String> headers}) {
    _handler.send(
        destination: destination,
        body: body,
        binaryBody: binaryBody,
        headers: headers);
  }

  void ack({@required String id, Map<String, String> headers}) {
    _handler.ack(id: id, headers: headers);
  }

  void nack({@required String id, Map<String, String> headers}) {
    _handler.nack(id: id, headers: headers);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_config.reconnectDelay > 0) {
      _reconnectTimer =
          Timer(Duration(milliseconds: _config.reconnectDelay), () {
        _connect();
      });
    }
  }
}
