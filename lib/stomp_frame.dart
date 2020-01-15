import 'dart:typed_data';

import 'package:meta/meta.dart';

class StompFrame {
  final String command;
  final Map<String, String> headers;
  final String body;
  final Uint8List binaryBody;

  StompFrame(
      {@required this.command, this.headers, this.body, this.binaryBody});
}
