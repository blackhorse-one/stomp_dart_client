import 'dart:async';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:test/test.dart';

void main() {
  group('StompClient', () {
    setUp(() {});

    tearDown(() async {});
    test('should not be connected on creation', () {
      final client = StompClient(config: StompConfig(url: null));
      expect(client.connected, false);
    });

    test('schedules reconnect on unexpected disconnect', () async {
      // Setup a server which lets connect and then drops the connection
      var streamChannel = spawnHybridCode(r'''
        import 'dart:io';
        import 'dart:async';
        import 'package:web_socket_channel/io.dart';
        import 'package:stomp_dart_client/stomp_parser.dart';
        import 'package:stream_channel/stream_channel.dart';
        
        hybridMain(StreamChannel channel) async {
          HttpServer server = await HttpServer.bind("localhost", 0);
          server.transform(WebSocketTransformer()).listen((webSocket) {
            var webSocketChannel = IOWebSocketChannel(webSocket);
            var parser = StompParser((frame) {
              if (frame.command == 'CONNECT') {
                webSocketChannel.sink.add("CONNECTED\nversion:1.2\n\n\x00");
                webSocketChannel.sink.close();
              } 
            });
            webSocketChannel.stream.listen((request) {
              parser.parseData(request);
            });
          });

          channel.sink.add(server.port);
        }
      ''', stayAlive: true);

      int port = await streamChannel.stream.first;

      StompClient client;
      dynamic onWebSocketDone = expectAsync0(() {}, count: 2);
      var n = 0;
      dynamic onConnect = expectAsync2((_, frame) {
        if (n == 1) {
          client.deactivate();
        }
        n++;
      }, count: 2);

      client = StompClient(
          config: StompConfig(
              url: 'ws://localhost:$port',
              reconnectDelay: 5000,
              onConnect: onConnect,
              onWebSocketDone: onWebSocketDone));

      client.activate();
    });

    test('attempts to reconnect indefinitely when server is unavailable',
        () async {
      StompClient client;
      var n = 0;
      dynamic onWebSocketDone = expectAsync0(() {
        if (n == 3) client.deactivate();
        n++;
      }, count: 4);
      dynamic onConnect = expectAsync2((_, frame) {}, count: 0);

      client = StompClient(
          config: StompConfig(
              url: 'ws://localhost:1234',
              onConnect: onConnect,
              reconnectDelay: 1000,
              onWebSocketDone: onWebSocketDone,
              connectionTimeout: Duration(milliseconds: 2000)));

      client.activate();
    });

    test('disconnects cleanly from stomp and websocket', () async {
      var streamChannel = spawnHybridCode(r'''
        import 'dart:io';
        import 'dart:async';
        import 'package:web_socket_channel/io.dart';
        import 'package:stomp_dart_client/stomp_parser.dart';
        import 'package:stream_channel/stream_channel.dart';
        
        hybridMain(StreamChannel channel) async {
          HttpServer server = await HttpServer.bind('localhost', 0);
          server.transform(WebSocketTransformer()).listen((webSocket) {
            var channel = IOWebSocketChannel(webSocket);
            int n = 0;
            channel.stream.listen((request) {
              if (n == 0) {
                if (!request.startsWith("CONNECT")) {
                  channel.sink.close();
                }
                channel.sink.add("CONNECTED\nversion:1.2\n\n\x00");
              } else {
                if (request.startsWith("DISCONNECT")) {
                  channel.sink.add("RECEIPT\nreceipt-id:disconnect-0\n\n\x00");
                  channel.sink.close();
                }
              }
              n++;
            });
          });

          channel.sink.add(server.port);
        }
      ''', stayAlive: true);

      int port = await streamChannel.stream.first;

      StompClient client;
      dynamic onWebSocketDone = expectAsync0(() {}, count: 1);
      dynamic onDisconnect = expectAsync1((frame) {
        expect(client.connected, isFalse);
        expect(frame.command, 'RECEIPT');
        expect(frame.headers.length, 1);
        expect(frame.headers['receipt-id'], 'disconnect-0');
      }, count: 1);
      dynamic onConnect = expectAsync2((_, frame) {
        Timer(Duration(milliseconds: 500), () {
          client.deactivate();
        });
      }, count: 1);
      dynamic onError = expectAsync1((_) {}, count: 0);

      client = StompClient(
          config: StompConfig(
              url: 'ws://localhost:$port',
              reconnectDelay: 5000,
              onConnect: onConnect,
              onWebSocketDone: onWebSocketDone,
              onWebSocketError: onError,
              onStompError: onError,
              onDisconnect: onDisconnect));

      client.activate();
    });

    test('should try updating config sync before connect', () async {
      var streamChannel = spawnHybridCode(r'''
        import 'dart:io';
        import 'dart:async';
        import 'package:web_socket_channel/io.dart';
        import 'package:stomp_dart_client/stomp_parser.dart';
        import 'package:stream_channel/stream_channel.dart';

        hybridMain(StreamChannel channel) async {
          HttpServer server = await HttpServer.bind('localhost', 0);
          server.transform(WebSocketTransformer()).listen((webSocket) {
            var channel = IOWebSocketChannel(webSocket);
            int n = 0;
            channel.stream.listen((request) {
              if (n == 0) {
                if (!request.startsWith("CONNECT")) {
                  channel.sink.close();
                }
                channel.sink.add("CONNECTED\nversion:1.2\n\n\x00");
              } else {
                if (request.startsWith("DISCONNECT")) {
                  channel.sink.add("RECEIPT\nreceipt-id:disconnect-0\n\n\x00");
                  channel.sink.close();
                }
              }
              n++;
            });
          });

          channel.sink.add(server.port);
        }
      ''', stayAlive: true);

      int port = await streamChannel.stream.first;

      dynamic onConnected = expectAsync2((StompClient client, _) {
        final header = client.config.webSocketConnectHeaders['test'];
        expect(client.config.url, 'ws://localhost:$port');
        expect(header, 'after-connect-attempt');
      });

      StompConfig config;
      config = StompConfig(
        url: 'ws://localhost:$port',
        webSocketConnectHeaders: {'test': 'before-connect-attempt'},
        beforeConnect: () {
          return config.copyWith(
            onConnect: onConnected,
            webSocketConnectHeaders: {'test': 'after-connect-attempt'},
          );
        },
      );

      final client = StompClient(config: config);
      final header = client.config.webSocketConnectHeaders['test'];
      expect(header, 'before-connect-attempt');
      client.activate();
    });

    test('should try updating config async before connect', () async {
      var streamChannel = spawnHybridCode(r'''
        import 'dart:io';
        import 'dart:async';
        import 'package:web_socket_channel/io.dart';
        import 'package:stomp_dart_client/stomp_parser.dart';
        import 'package:stream_channel/stream_channel.dart';

        hybridMain(StreamChannel channel) async {
          HttpServer server = await HttpServer.bind('localhost', 0);
          server.transform(WebSocketTransformer()).listen((webSocket) {
            var channel = IOWebSocketChannel(webSocket);
            int n = 0;
            channel.stream.listen((request) {
              if (n == 0) {
                if (!request.startsWith("CONNECT")) {
                  channel.sink.close();
                }
                channel.sink.add("CONNECTED\nversion:1.2\n\n\x00");
              } else {
                if (request.startsWith("DISCONNECT")) {
                  channel.sink.add("RECEIPT\nreceipt-id:disconnect-0\n\n\x00");
                  channel.sink.close();
                }
              }
              n++;
            });
          });

          channel.sink.add(server.port);
        }
      ''', stayAlive: true);

      int port = await streamChannel.stream.first;

      dynamic onConnected = expectAsync2((StompClient client, _) {
        final header = client.config.webSocketConnectHeaders['test'];
        expect(header, 'after-connect-attempt');
      });

      StompConfig config;
      config = StompConfig(
        url: 'ws://localhost:$port',
        webSocketConnectHeaders: {'test': 'before-connect-attempt'},
        beforeConnect: () async {
          await Future.delayed(Duration(milliseconds: 200));
          return config.copyWith(
            onConnect: onConnected,
            webSocketConnectHeaders: {'test': 'after-connect-attempt'},
          );
        },
      );

      final client = StompClient(config: config);
      final header = client.config.webSocketConnectHeaders['test'];
      expect(header, 'before-connect-attempt');
      client.activate();
    });

    test('should not update config when given null before connect', () async {
      var streamChannel = spawnHybridCode(r'''
        import 'dart:io';
        import 'dart:async';
        import 'package:web_socket_channel/io.dart';
        import 'package:stomp_dart_client/stomp_parser.dart';
        import 'package:stream_channel/stream_channel.dart';

        hybridMain(StreamChannel channel) async {
          HttpServer server = await HttpServer.bind('localhost', 0);
          server.transform(WebSocketTransformer()).listen((webSocket) {
            var channel = IOWebSocketChannel(webSocket);
            int n = 0;
            channel.stream.listen((request) {
              if (n == 0) {
                if (!request.startsWith("CONNECT")) {
                  channel.sink.close();
                }
                channel.sink.add("CONNECTED\nversion:1.2\n\n\x00");
              } else {
                if (request.startsWith("DISCONNECT")) {
                  channel.sink.add("RECEIPT\nreceipt-id:disconnect-0\n\n\x00");
                  channel.sink.close();
                }
              }
              n++;
            });
          });

          channel.sink.add(server.port);
        }
      ''', stayAlive: true);

      int port = await streamChannel.stream.first;

      dynamic onConnected = expectAsync2((StompClient client, _) {
        final header = client.config.webSocketConnectHeaders['test'];
        expect(client.config.url, 'ws://localhost:$port');
        expect(header, 'before-connect-attempt');
      });

      StompConfig config;
      config = StompConfig(
        url: 'ws://localhost:$port',
        webSocketConnectHeaders: {'test': 'before-connect-attempt'},
        beforeConnect: () => null,
        onConnect: onConnected,
      );

      final client = StompClient(config: config);
      final header = client.config.webSocketConnectHeaders['test'];
      expect(header, 'before-connect-attempt');
      client.activate();
    });
  });
}
