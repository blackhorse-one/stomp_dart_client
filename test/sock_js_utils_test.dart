import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:test/test.dart';

void main() {
  group('SockJsUtils', () {
    test('generate websocket url with http url', () {
      final url = 'http://localhost:5000/test';
      final webSocketUrl = SockJsUtils().generateTransportUrl(url);

      expect(webSocketUrl, isNotNull);
      expect(webSocketUrl, isNotEmpty);
      expect(webSocketUrl.startsWith('ws://'), isTrue);
    });

    test('generate websocket url with https url', () {
      final url = 'https://localhost:5000/test';
      final webSocketUrl = SockJsUtils().generateTransportUrl(url);

      expect(webSocketUrl, isNotNull);
      expect(webSocketUrl, isNotEmpty);
      expect(webSocketUrl.startsWith('wss://'), isTrue);
    });

    test('generate websocket url with no empty fragment', () {
      final url = 'https://localhost:5000/test';
      final webSocketUrl = SockJsUtils().generateTransportUrl(url);

      expect(webSocketUrl, isNotNull);
      expect(webSocketUrl, isNotEmpty);
      expect(webSocketUrl.endsWith('#'), isFalse);
    });

    test('generate websocket url with bad url', () {
      final url = 'wss://localhost:5000/test';

      expect(
        () => SockJsUtils().generateTransportUrl(url),
        throwsArgumentError,
      );
    });
  });
}
