import 'dart:convert';

import 'package:stomp_dart_client/sock_js/sock_js_parser.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:test/test.dart';

void main() {
  group('SockJSParser', () {
    test('can parse basic message', () {
      final stompMsg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final sockJsMsg = 'm${json.encode(stompMsg)}';

      final callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination'], 'foo');
          expect(frame.headers['message-id'], '456');
          expect(frame.body, isEmpty);
        },
        count: 1,
      );

      final onDoneCallback = expectAsync1((_) {}, count: 0);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });

    test('can parse array with 1 message', () {
      final stompMsg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final sockJsMsg = 'a[${json.encode(stompMsg)}]';

      final callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination'], 'foo');
          expect(frame.headers['message-id'], '456');
          expect(frame.body, isEmpty);
        },
        count: 1,
      );

      final onDoneCallback = expectAsync1((_) {}, count: 0);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });

    test('can parse array with 2 messages', () {
      final stompMsg1 = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final stompMsg2 = 'MESSAGE\ndestination:foo\nmessage-id:457\n\n\x00';
      final sockJsMsg =
          'a[${json.encode(stompMsg1)},${json.encode(stompMsg2)}]';
      var count = 0;

      final callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination'], 'foo');
          expect(frame.headers['message-id'], count == 0 ? '456' : '457');
          expect(frame.body, isEmpty);
          ++count;
        },
        count: 2,
      );

      var onDoneCallback = expectAsync1((_) {}, count: 0);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });

    test('don\'t parse open frame', () {
      final sockJsMsg = 'o';

      final callback = expectAsync1((frame) {}, count: 0);
      final onDoneCallback = expectAsync1((_) {}, count: 0);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });

    test('don\'t parse Heartbeat frame', () {
      final sockJsMsg = 'h';

      final callback = expectAsync1((frame) {}, count: 0);
      final onDoneCallback = expectAsync1((_) {}, count: 0);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });

    test('don\'t parse empty message', () {
      final sockJsMsg = 'm';

      final callback = expectAsync1((frame) {}, count: 0);
      final onDoneCallback = expectAsync1((_) {}, count: 0);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });

    test('don\'t parse no json message', () {
      final stompMsg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final sockJsMsg = 'm$stompMsg';

      final callback = expectAsync1((frame) {}, count: 0);
      final onDoneCallback = expectAsync1((_) {}, count: 0);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });

    test('close frame message', () {
      final sockJsMsg = 'c[1007,"null"]';

      final callback = expectAsync1((frame) {}, count: 0);
      final onDoneCallback = expectAsync0(() {}, count: 1);

      SockJSParser(
        onStompFrame: callback,
        onDone: onDoneCallback,
      ).parseData(sockJsMsg);
    });
  });
}
