import 'dart:math';

class SocketJsUtils
{
  static final SocketJsUtils _instance = SocketJsUtils._internal();

  factory SocketJsUtils() => _instance;

  SocketJsUtils._internal(); // private constructor
  
  final Random _random = Random();

  String generateTransportUrl(String url){
    var uri = Uri.parse(url);

    var pathSegments = <String>[];
    if(uri.pathSegments != null){
      pathSegments.addAll(uri.pathSegments);
    }
    pathSegments.add(_generateServerId());
    pathSegments.add(_generateSessionId());
    pathSegments.add('websocket');

    uri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      fragment: uri.fragment,
      pathSegments: pathSegments
    );

    var transportUrl = uri.toString();
    if (transportUrl.startsWith('https'))
    {
        transportUrl = 'wss' + transportUrl.substring(5);
    }
    else if (transportUrl.startsWith('http'))
    {
        transportUrl = 'ws' + transportUrl.substring(4);
    }
    return transportUrl;
  }

  String _generateServerId()
  {
    return _random.nextInt(1000).toString().padLeft(3, '0');
  }

  String _generateSessionId()
  {
    var sessionId = '';
    var randomStringChars = 'abcdefghijklmnopqrstuvwxyz012345';
    var max = randomStringChars.length;
    for (var i = 0; i < 8; i++)
    {
      sessionId += randomStringChars[_random.nextInt(max)].toString();
    }
    return sessionId;
  }
}