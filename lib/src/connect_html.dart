import 'dart:async';

import 'package:web/web.dart' as web;

import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'stomp_config.dart';

Future<WebSocketChannel> connect(StompConfig config) {
  final completer = Completer<HtmlWebSocketChannel>();
  final webSocket = web.WebSocket(config.connectUrl)
    ..binaryType = BinaryType.list.value;
  webSocket.onOpen.first.then((value) {
    completer.complete(HtmlWebSocketChannel(webSocket));
  });
  webSocket.onError.first.then((err) {
    completer.completeError(WebSocketChannelException.from(err));
  });

  if (config.connectionTimeout.inMilliseconds > 0) {
    return completer.future.timeout(config.connectionTimeout);
  }

  return completer.future;
}
