import 'dart:math';

class SockJsUtils {
  static final SockJsUtils _instance = SockJsUtils._internal();

  factory SockJsUtils() => _instance;

  SockJsUtils._internal(); // private constructor

  final Random _random = Random();

  String generateTransportUrl(String url) {
    var uri = Uri.parse(url);

    var pathSegments = <String>[];
    pathSegments.addAll(uri.pathSegments);
    pathSegments.add(_generateServerId());
    pathSegments.add(_generateSessionId());
    pathSegments.add('websocket');

    uri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      query: uri.query,
      fragment: null,
      pathSegments: pathSegments,
    );

    var transportUrl = uri.toString();
    if (transportUrl.startsWith('https')) {
      transportUrl = 'wss${transportUrl.substring(5)}';
    } else if (transportUrl.startsWith('http')) {
      transportUrl = 'ws${transportUrl.substring(4)}';
    } else {
      throw ArgumentError('The url has to start with http/https');
    }
    return transportUrl;
  }

  String _generateServerId() {
    return _random.nextInt(1000).toString().padLeft(3, '0');
  }

  String _generateSessionId() {
    var sessionId = '';
    var randomStringChars = 'abcdefghijklmnopqrstuvwxyz012345';
    var max = randomStringChars.length;
    for (var i = 0; i < 8; i++) {
      sessionId += randomStringChars[_random.nextInt(max)].toString();
    }
    return sessionId;
  }
}
