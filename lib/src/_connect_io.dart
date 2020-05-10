import 'dart:async';
import 'dart:io';

import 'package:stomp_dart_client/stomp_config.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connect(StompConfig config) async {
  var websocket =
      WebSocket.connect(config.url, headers: config.webSocketConnectHeaders);
  if (config.connectionTimeout != null) {
    websocket = websocket.timeout(config.connectionTimeout);
  }

  try {
    final webSocket = await websocket;
    return IOWebSocketChannel(webSocket);
  } on Exception catch (e) {
    config.onWebSocketError(e);
  }

  return null;
}
