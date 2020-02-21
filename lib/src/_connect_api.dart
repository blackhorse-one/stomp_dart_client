import 'dart:async';

import 'package:stomp_dart_client/stomp_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connect(StompConfig config) {
  throw UnsupportedError('No implementation of the connect api provided');
}
