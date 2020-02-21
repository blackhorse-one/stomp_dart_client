import 'dart:async';
import 'dart:io';

import 'package:stomp_dart_client/stomp_config.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connect(StompConfig config) async {
  Future<WebSocket> websocket =
      WebSocket.connect(config.url, headers: config.webSocketConnectHeaders);
  if (config.connectionTimeout != null) {
    websocket = websocket.timeout(config.connectionTimeout);
  }
  WebSocket webSocket = await websocket;
  return IOWebSocketChannel(webSocket);
}
