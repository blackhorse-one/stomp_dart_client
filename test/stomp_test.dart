import 'dart:async';
import 'dart:io';

import 'package:stomp_dart/stomp.dart';
import 'package:stomp_dart/stomp_config.dart';
import 'package:stomp_dart/stomp_parser.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
/**
 * Since subscribe and send are just proxies for the handler we wont test them
 * here
 */
void main() {
  group('StompClient', () {
    HttpServer server;
    StompConfig config;

    setUp(() {
      config = StompConfig(
        url: 'ws://localhost:1234',
        reconnectDelay: 5000,
      );
    });

    tearDown(() async {
      await server?.close();
    });
    test('should not be connected on creation', () {

      StompClient client = StompClient(config: null);
      expect(client.connected, false);
    });

    test('schedules reconnect on unexpected disconnect', () async {
      // Setup a server which lets connect and then drops the connection
      server = await HttpServer.bind('localhost', 1234);
      server.transform(WebSocketTransformer()).listen((webSocket) {
          var channel = IOWebSocketChannel(webSocket);
          var parser = StompParser((frame) {
            if (frame.command == 'CONNECT') {
              channel.sink.add("CONNECTED\nversion:1.2\n\n\x00");
              channel.sink.close();
            }
          });
          channel.stream.listen((request) {
            parser.parseData(request);
          });
      });

      StompClient client;
      dynamic onWebSocketDone = expectAsync0(() {}, count: 2);
      int n = 0;
      dynamic onConnect = expectAsync2((_, frame) {
        if (n == 1) {
          client.deactivate();
        }
        n++;
      }, count: 2);

      client = StompClient(config: config.copyWith(
        onConnect: onConnect,
        onWebSocketDone: onWebSocketDone
      ));

      client.activate();
    });

    test('disconnects cleanly from stomp and websocket', () async {
      server = await HttpServer.bind('localhost', 1234);
      server.transform(WebSocketTransformer()).listen((webSocket) {
          var channel = IOWebSocketChannel(webSocket);
          int n = 0;
          channel.stream.listen((request) {
            if (n == 0) {
              expect(request, startsWith("CONNECT"));
              channel.sink.add("CONNECTED\nversion:1.2\n\n\x00");
            } else {
              expect(request, startsWith("DISCONNECT"));
              channel.sink.add("RECEIPT\nreceipt-id:disconnect-0\n\n\x00");
              channel.sink.close();
            }
            n++;
          });
      });
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

      client = StompClient(config: config.copyWith(
        onConnect: onConnect,
        onWebSocketDone: onWebSocketDone,
        onWebSocketError: onError,
        onStompError: onError,
        onDisconnect: onDisconnect
      ));

      client.activate();
    });
  });
}