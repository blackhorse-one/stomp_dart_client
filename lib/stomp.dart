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
  final StompConfig config;

  StompHandler _handler;
  bool _isActive = false;
  Timer _reconnectTimer;

  StompClient({@required this.config});

  bool get connected => (_handler != null) && _handler.connected;

  void activate() {
    _isActive = true;

    _connect();
  }

  void deactivate() {
    _isActive = false;
    _reconnectTimer?.cancel();
    _handler?.dispose();
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
        config: config.copyWith(onConnect: (_, frame) {
      if (!_isActive) {
        config.onDebugMessage(
            '[STOMP] Client connected while being deactivated. Will disconnected');
        _handler?.dispose();
      }
      config.onConnect(this, frame);
    }, onWebSocketDone: () {
      config.onWebSocketDone();

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

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (config.reconnectDelay > 0) {
      _reconnectTimer =
          Timer(Duration(milliseconds: config.reconnectDelay), () {
        _connect();
      });
    }
  }
}
