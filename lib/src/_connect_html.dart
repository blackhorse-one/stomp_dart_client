import 'dart:async';
import 'dart:html';

import 'package:stomp_dart_client/stomp_config.dart';
import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connect(StompConfig config) {
  final completer = Completer<HtmlWebSocketChannel>();
  final webSocket = WebSocket(config.url)..binaryType = BinaryType.list.value;
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
