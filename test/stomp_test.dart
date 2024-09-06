import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  group('StompClient', () {
    late StompConfig config;
    late StreamChannel streamChannel;

    setUpAll(() async {
      // Basic STOMP Server
      streamChannel = spawnHybridCode(
        r'''
        import 'dart:io';
        import 'dart:async';
        import 'dart:convert';
        import 'package:web_socket_channel/io.dart';
        import 'package:stomp_dart_client/stomp_dart_client.dart';
        import 'package:stream_channel/stream_channel.dart';

        Future<void> hybridMain(StreamChannel channel) async {
          final server = await HttpServer.bind("localhost", 0);
          server.transform(WebSocketTransformer()).listen((webSocket) {
            var webSocketChannel = IOWebSocketChannel(webSocket);
            var parser = StompParser((frame) {
              if (frame.command == 'CONNECT') {
                webSocketChannel.sink.add("CONNECTED\nversion:1.2\nheart-beat:${frame.headers['heart-beat']}\n\n\x00");
              } else if (frame.command == 'DISCONNECT') {
                webSocketChannel.sink
                    .add("RECEIPT\nreceipt-id:${frame.headers['receipt']}\n\n\x00");
              } else if (frame.command == 'SUBSCRIBE') {
                if (frame.headers['destination'] == '/foo') {
                  webSocketChannel.sink.add(
                      "MESSAGE\nsubscription:${frame.headers['id']}\nmessage-id:123\ndestination:/foo\n\nThis is the message body\x00");
                } else if (frame.headers['destination'] == '/bar') {
                  webSocketChannel.sink.add(utf8.encode(
                      "MESSAGE\nsubscription:${frame.headers['id']}\nmessage-id:123\ndestination:/bar\n\nThis is the message body\x00"));
                }
              } else if (frame.command == 'UNSUBSCRIBE' ||
                  frame.command == 'SEND') {
                if (frame.headers.containsKey('receipt')) {
                  webSocketChannel.sink.add(
                      "RECEIPT\nreceipt-id:${frame.headers['receipt']}\n\n${frame.body}\x00");

                  if (frame.command == 'UNSUBSCRIBE') {
                    Timer(Duration(milliseconds: 500), () {
                      webSocketChannel.sink.add(
                          "MESSAGE\nsubscription:${frame.headers['id']}\nmessage-id:123\ndestination:/foo\n\nThis is the message body\x00");
                    });
                  }
                }
              } else if (frame.command == 'ACK' || frame.command == 'NACK') {
                  webSocketChannel.sink.add(
                      "RECEIPT\nreceipt-id:${frame.headers['receipt']}\n\n${frame.headers['id']}\x00");
              }
            });
            webSocketChannel.stream.listen((request) {
              parser.parseData(request);
            });
          });

          channel.sink.add(server.port);
        }
      ''',
        stayAlive: true,
      );

      final port = await streamChannel.stream.first;
      config = StompConfig(
        url: 'ws://localhost:$port',
      );
    });

    tearDownAll(() async {
      await streamChannel.sink.close();
    });

    test('should not be connected on creation', () {
      final client = StompClient(config: StompConfig(url: ''));
      expect(client.connected, false);
    });

    test('schedules reconnect on unexpected disconnect', () async {
      // Basic STOMP Server
      final customChannel = spawnHybridCode(
        r'''
        import 'dart:io';
        import 'dart:async';
        import 'dart:convert';
        import 'package:web_socket_channel/io.dart';
        import 'package:stomp_dart_client/stomp_dart_client.dart';
        import 'package:stream_channel/stream_channel.dart';

        Future<void> hybridMain(StreamChannel channel) async {
          final server = await HttpServer.bind("localhost", 0);
          server.transform(WebSocketTransformer()).listen((webSocket) {
            var webSocketChannel = IOWebSocketChannel(webSocket);
            var parser = StompParser((frame) {
              if (frame.command == 'CONNECT') {
                webSocketChannel.sink.add("CONNECTED\nversion:1.2\nheart-beat:${frame.headers['heart-beat']}\n\n\x00");
                if (frame.headers['disconnect'] != null) {
                  webSocketChannel.sink.close();
                }
              } else if (frame.command == 'DISCONNECT') {
                webSocketChannel.sink
                    .add("RECEIPT\nreceipt-id:${frame.headers['receipt']}\n\n\x00");
              }
            });
            webSocketChannel.stream.listen((request) {
              parser.parseData(request);
            });
          });

          channel.sink.add(server.port);
        }
      ''',
        stayAlive: true,
      );

      dynamic customPort = await customChannel.stream.first;
      late StompClient client;
      final onWebSocketDone = expectAsync0(() {}, count: 2);

      var n = 0;
      final onConnect = expectAsync1(
        (StompFrame frame) {
          if (n == 1) {
            client.deactivate();
            Timer(
                Duration(milliseconds: 500), () => customChannel.sink.close());
          }
          n++;
        },
        count: 2,
      );

      client = StompClient(
        config: StompConfig(
          url: 'ws://localhost:$customPort',
          reconnectDelay: Duration(seconds: 5),
          onConnect: onConnect,
          stompConnectHeaders: {'disconnect': 'true'},
          onWebSocketDone: onWebSocketDone,
        ),
      )..activate();
    });

    test('attempts to reconnect indefinitely when server is unavailable',
        () async {
      late StompClient client;

      var n = 0;
      final onWebSocketDone = expectAsync0(
        () {
          if (n == 3) client.deactivate();
          n++;
        },
        count: 4,
      );

      final onConnect = expectAsync1(
        (StompFrame frame) {},
        count: 0,
      );

      client = StompClient(
        config: StompConfig(
          url: 'ws://localhost:1234',
          onConnect: onConnect,
          reconnectDelay: Duration(seconds: 1),
          onWebSocketDone: onWebSocketDone,
          connectionTimeout: Duration(seconds: 2),
        ),
      )..activate();
    });

    test('disconnects cleanly from stomp and websocket', () async {
      late StompClient client;
      final onWebSocketDone = expectAsync0(() {}, count: 1);
      final onDisconnect = expectAsync1(
        (StompFrame frame) {
          expect(client.connected, isFalse);
          expect(frame.command, 'RECEIPT');
          expect(frame.headers.length, 1);
          expect(frame.headers['receipt-id'], 'disconnect-0');
        },
        count: 1,
      );

      final onError = expectAsync1((dynamic _) {}, count: 0);
      final onConnect = expectAsync1(
        (StompFrame frame) {
          Timer(Duration(milliseconds: 500), () => client.deactivate());
        },
        count: 1,
      );

      client = StompClient(
        config: config.copyWith(
          reconnectDelay: Duration(seconds: 5),
          onConnect: onConnect,
          onWebSocketDone: onWebSocketDone,
          onWebSocketError: onError,
          onStompError: onError,
          onDisconnect: onDisconnect,
        ),
      )..activate();
    });

    test('can modify headers before connecting', () async {
      late StompClient client;
      late StompConfig customConfig;

      final beforeConnect = expectAsync0<Future<void>>(
        () async {
          customConfig.webSocketConnectHeaders?['TEST'] = 'DUMMY';
          customConfig.stompConnectHeaders?['TEST'] = 'DUMMY';
        },
        count: 1,
      );

      final onConnect = expectAsync1(
        (StompFrame frame) {
          expect(customConfig.webSocketConnectHeaders?['TEST'], 'DUMMY');
          expect(customConfig.stompConnectHeaders?['TEST'], 'DUMMY');
          Timer(Duration(milliseconds: 500), () => client.deactivate());
        },
      );

      customConfig = config.copyWith(
        beforeConnect: beforeConnect,
        onConnect: onConnect,
        stompConnectHeaders: {},
        webSocketConnectHeaders: {},
        reconnectDelay: Duration(seconds: 0),
        onWebSocketDone: expectAsync0(() {}, count: 1),
        connectionTimeout: Duration(seconds: 2),
      );

      client = StompClient(
        config: customConfig,
      )..activate();
    });

    test('throws when trying to transmit data before activate was called', () {
      final client = StompClient(config: StompConfig(url: ''));
      expect(
        () => client.subscribe(destination: '', callback: (_) {}),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
      expect(
        () => client.send(destination: ''),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
      expect(
        () => client.ack(id: ''),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
      expect(
        () => client.nack(id: ''),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
    });

    // This is needed because the function returned from subscribe could
    // already be calling inactive code
    test('does not throw when unsubscribing on inactive connection', () async {
      dynamic index = 0;

      late StompClient client;
      late StompUnsubscribe stompUnsubscribe;

      final onError = expectAsync1((dynamic res) {
        print(res);
      }, count: 0);
      final onConnect = expectAsync1(
        (StompFrame frame) {
          if (index == 0) {
            stompUnsubscribe = client.subscribe(
              destination: '/foo',
              callback: (_) => {},
              headers: {'id': 'sub-0'},
            );
            Timer(Duration(milliseconds: 500), () => client.deactivate());
            Timer(Duration(milliseconds: 1000), () => client.activate());
          } else {
            expect(() => stompUnsubscribe(), returnsNormally);
            Timer(Duration(milliseconds: 500), () => client.deactivate());
          }
          index++;
        },
        count: 2,
      );

      client = StompClient(
        config: config.copyWith(
          reconnectDelay: Duration(seconds: 5),
          onConnect: onConnect,
          onWebSocketError: onError,
          onStompError: onError,
        ),
      )..activate();
    });
  });
}
