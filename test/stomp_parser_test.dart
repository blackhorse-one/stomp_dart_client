import 'dart:convert';
import 'dart:typed_data';

import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:stomp_dart_client/stomp_parser.dart';
import 'package:test/test.dart';

void main() {
  group('StompParser', () {
    test('can parse basic message', () {
      final msg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';

      var callback = expectAsync1(
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

      StompParser(callback).parseData(msg);
    });

    test('does not unescape headers (v1.0)', () {
      final msg = 'MESSAGE\ndesti\\nnation:f\\noo\nmessage-id:456\n\n\x00';

      var callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('desti\\nnation'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['desti\\nnation'], 'f\\noo');
          expect(frame.headers['message-id'], '456');
          expect(frame.body, isEmpty);
        },
        count: 1,
      );

      StompParser(callback).parseData(msg);
    });

    test('fails on unescaped header values (v1.0)', () {
      final msg = 'MESSAGE\ndesti\\nnation:f\noo\nmessage-id:456\n\n\x00';

      var callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('desti\\nnation'), isTrue);
          expect(frame.headers.containsKey('oo\nmessage-id'), isTrue);
          expect(frame.headers['desti\\nnation'], 'f');
          expect(frame.headers['oo\nmessage-id'], '456');
          expect(frame.body, isEmpty);
        },
        count: 1,
      );

      StompParser(callback).parseData(msg);
    });

    test('does unescape header keys and values (^v1.1)', () {
      final msg = 'MESSAGE\ndesti\\nnation:f\\noo\nmessage-id:456\n\n\x00';

      var callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('desti\nnation'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['desti\nnation'], 'f\noo');
          expect(frame.headers['message-id'], '456');
          expect(frame.body, isEmpty);
        },
        count: 1,
      );

      StompParser(callback)
        ..escapeHeaders = true
        ..parseData(msg);
    });

    test('supports escaped colons in headers (^v1.1)', () {
      final msg = 'MESSAGE\ndestination\\cbar:foo\\cbar\n'
          'message-id:456\n\n\x00';

      var callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 2);
          expect(frame.headers.containsKey('destination:bar'), isTrue);
          expect(frame.headers.containsKey('message-id'), isTrue);
          expect(frame.headers['destination:bar'], 'foo:bar');
          expect(frame.headers['message-id'], '456');
          expect(frame.body, isEmpty);
        },
        count: 1,
      );

      StompParser(callback)
        ..escapeHeaders = true
        ..parseData(msg);
    });

    test('correctly serializes a stomp frame unescaped', () {
      final stringFrame =
          'SEND\ndestination:/path/to/foo\ncontent-type:text/plain'
          '\ncontent-length:14\n\nThis is a body\x00';

      final frame = StompFrame(
        command: 'SEND',
        body: 'This is a body',
        headers: {'destination': '/path/to/foo', 'content-type': 'text/plain'},
      );

      final serializedFrame = StompParser((_) {}).serializeFrame(frame);
      expect(serializedFrame, stringFrame);
    });

    test('correctly serializes a stomp frame escaped', () {
      final stringFrame =
          'SEND\ndesti\\nnation:/path/to/foo\ncontent-type:te\\nxt/plain\n'
          'content-length:14\n\nThis is a body\x00';
      final frame = StompFrame(
        command: 'SEND',
        body: 'This is a body',
        headers: {
          'desti\nnation': '/path/to/foo',
          'content-type': 'te\nxt/plain',
        },
      );

      final parser = StompParser((_) {})..escapeHeaders = true;
      final serializedFrame = parser.serializeFrame(frame);

      expect(serializedFrame, stringFrame);
    });

    test('correctly serializes binary frame', () {
      final stringFrame = 'SEND\ndesti\\nnation:/path/to/foo\n'
          'content-length:14\n\nThis is a body\x00';

      final frame = StompFrame(
        command: 'SEND',
        binaryBody: Uint8List.fromList('This is a body'.codeUnits),
        headers: {'desti\nnation': '/path/to/foo'},
      );

      final parser = StompParser((_) {})..escapeHeaders = true;
      final serializedFrame = parser.serializeFrame(frame);

      expect(serializedFrame, Uint8List.fromList(stringFrame.codeUnits));

      final emptyStringFrame = 'SEND\ndesti\\nnation:/path/to/foo\n\n\x00';
      final emptyBodyFrame = StompFrame(
        command: 'SEND',
        binaryBody: Uint8List(0),
        headers: {'desti\nnation': '/path/to/foo'},
      );

      final emptySerializedFrame = parser.serializeFrame(emptyBodyFrame);
      final codeUnits = Uint8List.fromList(emptyStringFrame.codeUnits);
      expect(emptySerializedFrame, codeUnits);
    });

    test('can parse frame with empty header', () {
      final msg = 'MESSAGE\n\nThis is a body\x00';

      var callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 0);
          expect(frame.body, 'This is a body');
        },
        count: 1,
      );

      StompParser(callback)
        ..escapeHeaders = true
        ..parseData(msg);
    });

    test('can parse frame with empty header and body', () {
      final msg = 'MESSAGE\n\n\x00';

      var callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 0);
          expect(frame.body, isEmpty);
        },
        count: 1,
      );

      StompParser(callback)
        ..escapeHeaders = true
        ..parseData(msg);
    });

    test('respects content-length when parsing', () {
      final msg = 'MESSAGE\ncontent-length:10\n\n'
          'This is a body longer than 10 bytes\x00';

      var callback = expectAsync1(
        (StompFrame frame) {
          expect(frame.command, 'MESSAGE');
          expect(frame.headers.length, 1);
          expect(frame.headers['content-length'], '10');
          expect(frame.body, 'This is a ');
        },
        count: 1,
      );

      StompParser(callback).parseData(msg);
    });

    test('fails silently on wrong content-length', () {
      final msg = 'MESSAGE\ncontent-length:10\n\nThis is\x00';
      var callback = expectAsync1((frame) {}, count: 0);

      StompParser(callback).parseData(msg);
    });

    test('can parse ping message', () {
      final onFrame = expectAsync1((StompFrame frame) {}, count: 0);
      final onPing = expectAsync0(() => null, count: 1);

      StompParser(onFrame, onPing).parseData('\n');
    });

    test('accepts ping/frames with carriage return', () {
      final onFrame = expectAsync1((StompFrame frame) {}, count: 1);
      final onPing = expectAsync0(() => null, count: 2);

      StompParser(onFrame, onPing)
        ..parseData('\r\n')
        ..parseData(
            '\r\nMESSAGE\r\ndestination:foo\r\nmessage-id:456\r\n\r\n\x00');
    });

    test('can parse multiple messages separately', () {
      final msg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final msg2 = 'MESSAGE\ndestination:bar\nmessage-id:123\n\n'
          'This is a body\x00';

      var n = 0;
      final onFrame = expectAsync1(
        (StompFrame frame) {
          if (n == 0) {
            expect(frame.command, 'MESSAGE');
            expect(frame.headers.length, 2);
            expect(frame.headers.containsKey('destination'), isTrue);
            expect(frame.headers.containsKey('message-id'), isTrue);
            expect(frame.headers['destination'], 'foo');
            expect(frame.headers['message-id'], '456');
            expect(frame.body, isEmpty);
          } else {
            expect(frame.command, 'MESSAGE');
            expect(frame.headers.length, 2);
            expect(frame.headers.containsKey('destination'), isTrue);
            expect(frame.headers.containsKey('message-id'), isTrue);
            expect(frame.headers['destination'], 'bar');
            expect(frame.headers['message-id'], '123');
            expect(frame.body, 'This is a body');
          }
          n++;
        },
        count: 2,
      );

      StompParser(onFrame)
        ..parseData(msg)
        ..parseData(msg2);
    });

    test('can parse multiple messages at once', () {
      final msg = 'MESSAGE\ndestination:foo\nmessage-id:456\n\n\x00';
      final msg2 =
          'MESSAGE\ndestination:bar\nmessage-id:123\n\nThis is a body\x00';

      var n = 0;
      final onFrame = expectAsync1(
        (StompFrame frame) {
          if (n == 0) {
            expect(frame.command, 'MESSAGE');
            expect(frame.headers.length, 2);
            expect(frame.headers.containsKey('destination'), isTrue);
            expect(frame.headers.containsKey('message-id'), isTrue);
            expect(frame.headers['destination'], 'foo');
            expect(frame.headers['message-id'], '456');
            expect(frame.body, isEmpty);
          } else {
            expect(frame.command, 'MESSAGE');
            expect(frame.headers.length, 2);
            expect(frame.headers.containsKey('destination'), isTrue);
            expect(frame.headers.containsKey('message-id'), isTrue);
            expect(frame.headers['destination'], 'bar');
            expect(frame.headers['message-id'], '123');
            expect(frame.body, 'This is a body');
          }
          n++;
        },
        count: 2,
      );

      StompParser(onFrame).parseData(msg + msg2);
    });

    test('can serialize unicode special characters', () {
      final stringFrame = 'SEND\ndesti\\nnation:/path/to/foo\n'
          'content-length:14\n\n´👌👻¡Â\x00';

      final frame = StompFrame(
        command: 'SEND',
        body: '´👌👻¡Â',
        headers: {'desti\nnation': '/path/to/foo'},
      );

      final parser = StompParser((_) {})..escapeHeaders = true;
      final serializedFrame = parser.serializeFrame(frame);

      expect(serializedFrame, stringFrame);
      expect(utf8.encode(serializedFrame), utf8.encode(stringFrame));
    });

    test('can deserialize unicode special characters', () {
      final msg = 'MESSAGE\ncontent-length:23\n\n{"a": "´👌👻¡Â"}\x00';
      final msg2 = 'MESSAGE\ncontent-length:18\n\n{"a": "Piaffe´s"}\x00';

      var n = 0;
      var callback = expectAsync1(
        (StompFrame frame) {
          if (n == 0) {
            expect(frame.command, 'MESSAGE');
            expect(frame.headers.length, 1);
            expect(frame.headers.containsKey('content-length'), isTrue);
            expect(frame.headers['content-length'], '23');
            expect(frame.body, '{"a": "´👌👻¡Â"}');
            expect(utf8.encode(frame.body!), [
              123,
              34,
              97,
              34,
              58,
              32,
              34,
              194,
              180,
              240,
              159,
              145,
              140,
              240,
              159,
              145,
              187,
              194,
              161,
              195,
              130,
              34,
              125
            ]);

            final jsonMap = json.decode(frame.body!);
            expect(jsonMap.length, 1);
            expect(jsonMap['a'], '´👌👻¡Â');
          } else {
            expect(frame.command, 'MESSAGE');
            expect(frame.headers.length, 1);
            expect(frame.headers.containsKey('content-length'), isTrue);
            expect(frame.headers['content-length'], '18');
            expect(frame.body, '{"a": "Piaffe´s"}');

            expect(utf8.encode(frame.body!), [
              123,
              34,
              97,
              34,
              58,
              32,
              34,
              80,
              105,
              97,
              102,
              102,
              101,
              194,
              180,
              115,
              34,
              125
            ]);

            final jsonMap = json.decode(frame.body!);
            expect(jsonMap.length, 1);
            expect(jsonMap['a'], 'Piaffe´s');
          }
          n++;
        },
        count: 2,
      );

      StompParser(callback)
        ..parseData(msg)
        ..parseData(msg2);
    });

    group('when content-type is application/octet-stream', () {
      const command = 'MESSAGE';
      const subscription = 'sub1';
      const messageId = 'c00ca000-0000-00a0-e0fc-ce00a0000000-0000';
      const destination = '/user/queue/binary';
      const octetStreamType = 'application/octet-stream';
      const textMessage = 'This is the message.';
      const textNull = '\\x00';

      final octetStreamData = '$command\n'
          'subscription:$subscription\n'
          'message-id:$messageId\n'
          'content-length:${textMessage.length}\n'
          'destination:$destination\n'
          'content-type:$octetStreamType\n\n'
          '$textMessage$textNull';

      final textData = '$command\n'
          'subscription:$subscription\n'
          'message-id:$messageId\n'
          'content-length:${textMessage.length}\n'
          'destination:$destination\n'
          'content-type:text\n\n'
          '$textMessage$textNull';

      StompFrame? parse(Uint8List data) {
        StompFrame? result;
        StompParser((frame) => result = frame).parseData(data);

        if (result == null) {
          fail('No StompFrame result!');
        }

        return result;
      }

      StompFrame parseMessage(String input) {
        final utfData = utf8.encode(input);
        final data = Uint8List.fromList(utfData);
        return parse(data)!;
      }

      test('should provide a binary body', () async {
        final result = parseMessage(octetStreamData);

        expect(result.command, command);
        expect(result.body, isNull);

        final resultHeaders = result.headers;
        expect(resultHeaders.length, 5);
        expect(resultHeaders['message-id'], messageId);
        expect(resultHeaders['subscription'], subscription);
        expect(resultHeaders['destination'], destination);
        expect(resultHeaders['content-type'], octetStreamType);
        expect(resultHeaders['content-length'], textMessage.length.toString());

        final binaryBody = result.binaryBody;
        expect(binaryBody, [
          84,
          104,
          105,
          115,
          32,
          105,
          115,
          32,
          116,
          104,
          101,
          32,
          109,
          101,
          115,
          115,
          97,
          103,
          101,
          46,
        ]);
        expect(utf8.decode(binaryBody!.toList()), textMessage);
      });

      group('for consecutive messages', () {
        StompFrame parseBinaryMessage() {
          return parseMessage(octetStreamData);
        }

        StompFrame parseTextMessage() {
          return parseMessage(textData);
        }

        test('should erase binaryBody after handling a binary message', () {
          final result = parseBinaryMessage();
          expect(result.body, isNull);
          expect(result.binaryBody, isNotNull);

          final result2 = parseTextMessage();
          expect(result2.body, isNotNull);
          expect(result2.binaryBody, isNull);
        });

        test('should erase body after handling a text message', () {
          final result = parseTextMessage();
          expect(result.body, isNotNull);
          expect(result.binaryBody, isNull);

          final result2 = parseBinaryMessage();
          expect(result2.body, isNull);
          expect(result2.binaryBody, isNotNull);
        });
      });
    });
  });
}
