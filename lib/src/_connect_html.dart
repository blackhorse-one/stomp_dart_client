import 'dart:async';
import 'dart:html';

import 'package:stomp_dart_client/stomp_config.dart';
import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connect(StompConfig config) async {
  var websocket = WebSocket(config.url)..binaryType = BinaryType.list.value;
  Future onOpenEvent = websocket.onOpen.first;
  if (config.connectionTimeout != null) {
    onOpenEvent = onOpenEvent.timeout(config.connectionTimeout!);
  }
  await onOpenEvent;
  return HtmlWebSocketChannel(websocket);
}
