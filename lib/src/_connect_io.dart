import 'dart:async';
import 'dart:io';

import 'package:stomp_dart_client/stomp_config.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connect(StompConfig config) async {
  try {
    var webSocket = WebSocket.connect(
      config.url,
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
