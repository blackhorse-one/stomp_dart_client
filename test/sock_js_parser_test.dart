import 'dart:convert';

import 'package:stomp_dart_client/sock_js/sock_js_parser.dart';
import 'package:test/test.dart';

void main() {
  group('SockJSParser', () {
    test('can parse basic message', () {
      final stompMsg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final sockjsMsg = 'm${json.encode(stompMsg)}';

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('destination'), isTrue);
        expect(frame.headers.containsKey('message-id'), isTrue);
        expect(frame.headers['destination'], 'foo');
        expect(frame.headers['message-id'], '456');
        expect(frame.body, isEmpty);
      }, count: 1);

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });

    test('can parse array with 1 message', () {
      final stompMsg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final sockjsMsg = 'a[${json.encode(stompMsg)}]';

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('destination'), isTrue);
        expect(frame.headers.containsKey('message-id'), isTrue);
        expect(frame.headers['destination'], 'foo');
        expect(frame.headers['message-id'], '456');
        expect(frame.body, isEmpty);
      }, count: 1);

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });

    test('can parse array with 2 messages', () {
      final stompMsg1 = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final stompMsg2 = 'MESSAGE\ndestination:foo\nmessage-id:457\n\n\x00';
      final sockjsMsg =
          'a[${json.encode(stompMsg1)},${json.encode(stompMsg2)}]';
      var count = 0;

      var callback = expectAsync1((frame) {
        expect(frame.command, 'MESSAGE');
        expect(frame.headers.length, 2);
        expect(frame.headers.containsKey('destination'), isTrue);
        expect(frame.headers.containsKey('message-id'), isTrue);
        expect(frame.headers['destination'], 'foo');
        expect(frame.headers['message-id'], count == 0 ? '456' : '457');
        expect(frame.body, isEmpty);
        ++count;
      }, count: 2);

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });

    test('don\'t parse open frame', () {
      final sockjsMsg = 'o';

      var callback = expectAsync1((frame) {}, count: 0);

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });

    test('don\'t parse Heartbeat frame', () {
      final sockjsMsg = 'h';

      var callback = expectAsync1((frame) {}, count: 0);

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });

    test('don\'t parse empty message', () {
      final sockjsMsg = 'm';

      var callback = expectAsync1((frame) {}, count: 0);

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });

    test('don\'t parse no json message', () {
      final stompMsg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final sockjsMsg = 'm$stompMsg';

      var callback = expectAsync1((frame) {}, count: 0);

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });

    test('close frame message', () {
      final sockjsMsg = 'c[1007,"null"]';

      var callback = expectAsync1((frame) {}, count: 0);

      var onDoneCallback = expectAsync0(() {}, count: 1);

      final parser =
          SockJSParser(onStompFrame: callback, onDone: onDoneCallback);

      parser.parseData(sockjsMsg);
    });
  });
}
