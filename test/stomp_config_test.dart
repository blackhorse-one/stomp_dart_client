import 'dart:async';

import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:stomp_dart_client/src/connect_api.dart'
    if (dart.library.js_interop) 'package:stomp_dart_client/src/connect_html.dart'
    if (dart.library.io) 'package:stomp_dart_client/src/connect_io.dart'
    as platform;

void main() {
  group('StompConfig', () {
    test('Generate session URL once per connection', () async {
      final config = StompConfig.sockJS(
        url: 'http://localhost',
        reconnectDelay: Duration(milliseconds: 500),
      );

      final connectUrls = <String, String>{};

      void connect() async {
        try {
          await platform.connect(config..resetSession());
        } on WebSocketChannelException catch (_) {
          // Save subsequent calls of `connectUrl`.
          connectUrls.addAll({config.connectUrl: config.connectUrl});
          if (connectUrls.length == 1) {
            // On 1st connect we expect that the current stored values are equal
            expect(connectUrls.entries.first.key,
                equals(connectUrls.entries.first.value));
          } else if (connectUrls.length == 2) {
            // On 2nd connect we expect that the current stored values are equal
            expect(connectUrls.entries.last.key,
                equals(connectUrls.entries.last.value));
            // But they are different from the values saved on 1st connect
            expect(connectUrls.entries.first.key,
                isNot(equals(connectUrls.entries.last.key)));
            expect(connectUrls.entries.first.value,
                isNot(equals(connectUrls.entries.last.value)));
          }
          Timer(config.reconnectDelay, connect);
        }
      }

      connect();

      // Wait until exit
      await Future.delayed(Duration(seconds: 3));
    });
  });
}
