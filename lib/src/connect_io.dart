import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'stomp_config.dart';

Future<WebSocketChannel> connect(StompConfig config) async {
  try {
    var webSocketFuture = WebSocket.connect(
      config.connectUrl,
      headers: config.webSocketConnectHeaders,
    );
    if (config.connectionTimeout.inMilliseconds > 0) {
      webSocketFuture = webSocketFuture.timeout(config.connectionTimeout);
    }

    var webSocket = await webSocketFuture;

    webSocket.pingInterval = config.pingInterval;

    return IOWebSocketChannel(webSocket);
  } on SocketException catch (err) {
    throw WebSocketChannelException.from(err);
  }
}
