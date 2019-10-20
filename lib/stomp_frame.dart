import 'package:meta/meta.dart';

class StompFrame {
  final String command;
  final Map<String, String> headers;
  final String body;

  StompFrame({@required this.command, this.headers, this.body});
}