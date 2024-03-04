import 'dart:typed_data';

typedef StompPingFrameCallback = void Function();

class StompFrame {
  final String command;
  final Map<String, String> headers;
  final String? body;
  final Uint8List? binaryBody;

  StompFrame({
    required this.command,
    this.headers = const {},
    this.body,
    this.binaryBody,
  });
}
