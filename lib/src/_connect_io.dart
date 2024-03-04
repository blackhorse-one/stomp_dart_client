import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'stomp_config.dart';

Future<WebSocketChannel> connect(StompConfig config) async {
  try {
    var webSocket = WebSocket.connect(
      config.connectUrl,
      headers: config.webSocketConnectHeaders,
    );
    if (config.connectionTimeout.inMilliseconds > 0) {
      webSocket = webSocket.timeout(config.connectionTimeout);
    }
    return IOWebSocketChannel(await webSocket);
  } on SocketException catch (err) {
    throw WebSocketChannelException.from(err);
  }
}
