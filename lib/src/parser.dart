import 'stomp_frame.dart';

abstract class Parser {
  late bool escapeHeaders;

  void parseData(dynamic data);

  dynamic serializeFrame(StompFrame frame);
}
