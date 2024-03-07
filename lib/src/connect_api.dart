import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'stomp_config.dart';

Future<WebSocketChannel> connect(StompConfig config) {
  throw UnsupportedError('No implementation of the connect api provided');
}
