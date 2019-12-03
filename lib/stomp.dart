import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:stomp_dart/stomp_config.dart';
import 'package:stomp_dart/stomp_frame.dart';
import 'package:stomp_dart/stomp_handler.dart';

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

  get connected => (_handler != null) && _handler.connected;

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
    if (this.connected) {
      this.config.onDebugMessage("[STOMP] Already connected. Nothing to do!");
      return;
    }

    await config.beforeConnect();

    if (!this._isActive) {
      this.config.onDebugMessage('[STOMP] Client was marked as inactive. Skip!');
      return;
    }

    _handler = StompHandler(config: this.config.copyWith(
      onConnect: (_, frame) {
        this.config.onConnect(this, frame); // Inject the client here.
      },
      onWebSocketDone: () {
        this.config.onWebSocketDone();

        if (this._isActive) {
          _scheduleReconnect();
        }
      }
    ));
    _handler.start();
  }

  Function({Map<String, String> unsubscribeHeaders}) subscribe({@required String destination, @required Function(StompFrame) callback, Map<String, String> headers}) {
    if (!_isActive || !connected) {
      throw new BadStateException("Cannot subscribe while not connected or inactive");
    }
    return _handler.subscribe(destination: destination, callback: callback, headers: headers);
  }

  void send({@required String destination, String body, Uint8List binaryBody, Map<String, String> headers}) {
    if (!_isActive || !connected) {
      throw new BadStateException("Cannot send while not connected or inactive");
    }
    _handler.send(destination: destination, body: body, binaryBody: binaryBody, headers: headers);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (this.config.reconnectDelay > 0) {
      _reconnectTimer = Timer(Duration(milliseconds: this.config.reconnectDelay), () {
        _connect();
      });
    }
  }
}