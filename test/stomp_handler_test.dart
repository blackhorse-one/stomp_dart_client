import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  group('StompHandler', () {
    late StompConfig config;
    StompHandler? handler;
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
                      "MESSAGE\nsubscription:${frame.headers['id']}\nmessage-id:123\ndestination:/foo\ncontent-type:text/plain\n\nThis is the message body\x00");
                } else if (frame.headers['destination'] == '/bar') {
                  webSocketChannel.sink.add(utf8.encode(
                      "MESSAGE\nsubscription:${frame.headers['id']}\nmessage-id:123\ndestination:/bar\ncontent-type:text/plain\n\nThis is the message body\x00"));
                }
              } else if (frame.command == 'UNSUBSCRIBE' ||
                  frame.command == 'SEND') {
                if (frame.headers.containsKey('receipt')) {
                  webSocketChannel.sink.add(
                      "RECEIPT\nreceipt-id:${frame.headers['receipt']}\n\n\x00");

                  if (frame.command == 'UNSUBSCRIBE') {
                    Timer(Duration(milliseconds: 500), () {
                      webSocketChannel.sink.add(
                          "MESSAGE\nsubscription:${frame.headers['id']}\nmessage-id:123\ndestination:/foo\ncontent-type:text/plain\n\nThis is the message body\x00");
                    });
                  }
                }
              } else if (frame.command == 'ACK' || frame.command == 'NACK') {
                  webSocketChannel.sink.add(
                      "RECEIPT\nreceipt-id:${frame.headers['receipt']}\n\n\x00");
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

      dynamic port = await streamChannel.stream.first;
      if (port is double) {
        port = port.toInt();
      }
      config = StompConfig(
        url: 'ws://localhost:$port',
      );
    });

    tearDown(() {
      handler?.dispose();
    });

    tearDownAll(() async {
      await streamChannel.sink.close();
    });

    test('connects correctly', () async {
      final onConnect = expectAsync1((StompFrame frame) {
        expect(frame.command, 'CONNECTED');
        expect(frame.headers.length, 2);
        expect(frame.headers['version'], '1.2');
        expect(frame.headers['heart-beat'], '5000,5000');
        expect(frame.body, isNull);
        expect(frame.binaryBody, isEmpty);
        handler!.dispose();
      });

      handler = StompHandler(config: config.copyWith(onConnect: onConnect))
        ..start();
    });

    test('disconnects correctly', () async {
      final onWebSocketDone = expectAsync0(() {}, count: 1);

      final onDisconnect = expectAsync1(
        (StompFrame frame) {
          expect(handler!.connected, isFalse);
          expect(frame.command, 'RECEIPT');
          expect(frame.headers.length, 1);
          expect(frame.headers['receipt-id'], 'disconnect-0');
        },
        count: 1,
      );

      final onConnect = expectAsync1(
        (StompFrame frame) {
          Timer(Duration(milliseconds: 500), () {
            handler!.dispose();
          });
        },
        count: 1,
      );

      final onError = expectAsync1((dynamic _) {}, count: 0);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: onConnect,
          onDisconnect: onDisconnect,
          onWebSocketDone: onWebSocketDone,
          onStompError: onError,
          onWebSocketError: onError,
        ),
      )..start();
    });

    test('aborts connection if disconnected while connecting', () async {
      final onWebSocketDone = expectAsync0(() {}, count: 0);

      final onDisconnect = expectAsync1(
        (StompFrame frame) {},
        count: 0,
      );

      final onConnect = expectAsync1(
        (StompFrame frame) {},
        count: 0,
      );

      final onError = expectAsync1((dynamic _) {}, count: 0);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: onConnect,
          onDisconnect: onDisconnect,
          onWebSocketDone: onWebSocketDone,
          onStompError: onError,
          onWebSocketError: onError,
        ),
      )..start();

      Future.microtask(() => handler?.dispose());

      await Future.delayed(Duration(milliseconds: 200));
    });

    test('subscribes correctly', () {
      final onSubscriptionFrame = expectAsync1((StompFrame frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 4);
        expect(frame.headers['subscription'], 'sub-0');
        expect(frame.headers['destination'], '/foo');
        expect(frame.body, 'This is the message body');
      });

      // We need this async waiter to make sure we actually wait until the
      // connection is closed to not affect other tests
      final onDisconnect = expectAsync1((StompFrame frame) {}, count: 1);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: (frame) {
            handler!.subscribe(
              destination: '/foo',
              callback: onSubscriptionFrame,
              headers: {'id': 'sub-0'},
            );
            Timer(Duration(milliseconds: 500), () {
              handler!.dispose();
            });
          },
          onDisconnect: onDisconnect,
        ),
      )..start();
    });

    test('unsubscribes correctly', () {
      final onSubscriptionFrame = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 4);
          expect(frame.headers['subscription'], 'sub-0');
          expect(frame.headers['destination'], '/foo');
          expect(frame.body, 'This is the message body');
        },
        count: 1,
      );

      final onReceiptFrame = expectAsync1((StompFrame frame) {
        expect(frame.command, 'RECEIPT');
        expect(frame.headers['receipt-id'], 'unsub-0');
      });

      // We need this async waiter to make sure we actually wait until the
      // connection is closed
      final onDisconnect = expectAsync1((StompFrame frame) {}, count: 1);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: (StompFrame frame) {
            final unsubscribe = handler!.subscribe(
              destination: '/foo',
              callback: onSubscriptionFrame,
              headers: {'id': 'sub-0'},
            );

            Timer(
              Duration(milliseconds: 500),
              () {
                unsubscribe(unsubscribeHeaders: {'receipt': 'unsub-0'});
                // We wait an additional second because the server will send
                // another frame for this subscription and we can make sure that
                // the subscription on the client side was actually canceled
                // immediately
                Timer(Duration(milliseconds: 1000), () {
                  handler!.dispose();
                });
              },
            );
          },
          onDisconnect: onDisconnect,
        ),
      )
        ..watchForReceipt('unsub-0', onReceiptFrame)
        ..start();
    });

    test('sends message correctly', () {
      final onReceiptFrame = expectAsync1((StompFrame frame) {
        expect(frame.command, 'RECEIPT');
        expect(frame.headers['receipt-id'], 'send-0');
        expect(frame.body, isNull);
        handler!.dispose();
      });

      // We need this async waiter to make sure we actually wait until the
      // connection is closed
      final onDisconnect = expectAsync1((StompFrame frame) {}, count: 1);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: (StompFrame frame) {
            handler!.send(
              destination: '/foo/bar',
              body: 'This is a body',
              headers: {'receipt': 'send-0', 'content-type': 'text'},
            );
          },
          onDisconnect: onDisconnect,
        ),
      )
        ..watchForReceipt('send-0', onReceiptFrame)
        ..start();
    });

    test('acks message correctly', () {
      final onReceiptFrame = expectAsync1((StompFrame frame) {
        expect(frame.command, 'RECEIPT');
        expect(frame.headers['receipt-id'], 'send-0');
        expect(frame.body, isNull);
        handler!.dispose();
      });

      // We need this async waiter to make sure we actually wait until the
      // connection is closed
      final onDisconnect = expectAsync1((StompFrame frame) {}, count: 1);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: (StompFrame frame) {
            handler!.ack(id: 'message-0', headers: {'receipt': 'send-0'});
          },
          onDisconnect: onDisconnect,
        ),
      )
        ..watchForReceipt('send-0', onReceiptFrame)
        ..start();
    });

    test('nacks message correctly', () {
      final onReceiptFrame = expectAsync1((StompFrame frame) {
        expect(frame.command, 'RECEIPT');
        expect(frame.headers['receipt-id'], 'send-0');
        expect(frame.body, isNull);
        handler!.dispose();
      });

      // We need this async waiter to make sure we actually wait until the
      // connection is closed
      final onDisconnect = expectAsync1((StompFrame frame) {}, count: 1);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: (StompFrame frame) {
            handler!.nack(id: 'message-0', headers: {'receipt': 'send-0'});
          },
          onDisconnect: onDisconnect,
        ),
      )
        ..watchForReceipt('send-0', onReceiptFrame)
        ..start();
    });

    test('correctly logs data not subtype of String', () {
      final onSubscriptionFrame = expectAsync1((StompFrame frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 4);
        expect(frame.headers['subscription'], 'sub-0');
        expect(frame.headers['destination'], '/bar');
        expect(frame.body, 'This is the message body');
      });

      final onDebugMessage = expectAsync1((String _) {}, count: 1, max: -1);
      // We need this async waiter to make sure we actually wait until the
      // connection is closed to not affect other tests
      final onDisconnect = expectAsync1((StompFrame frame) {}, count: 1);

      handler = StompHandler(
        config: config.copyWith(
          onConnect: (StompFrame frame) {
            handler!.subscribe(
              destination: '/bar',
              callback: onSubscriptionFrame,
              headers: {'id': 'sub-0'},
            );
            Timer(Duration(milliseconds: 500), () {
              handler!.dispose();
            });
          },
          onDebugMessage: onDebugMessage,
          onDisconnect: onDisconnect,
        ),
      )..start();
    });

    test('throws when trying to transmit data before start was called', () {
      final handler = StompHandler(config: StompConfig(url: ''));
      expect(
        () => handler.subscribe(destination: '', callback: (_) {}),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
      expect(
        () => handler.send(destination: ''),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
      expect(
        () => handler.ack(id: ''),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
      expect(
        () => handler.nack(id: ''),
        throwsA(TypeMatcher<StompBadStateException>()),
      );
    });
  });
}
