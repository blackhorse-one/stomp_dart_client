import 'dart:convert';
import 'dart:typed_data';

import 'package:stomp_dart_client/parser.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:stomp_dart_client/stomp_parser.dart';

class SockJSParser implements Parser {
  SockJSParser({
    required Function(StompFrame) onStompFrame,
    required this.onDone,
    StompPingFrameCallback? onPingFrame,
  }) {
    _stompParser = StompParser(onStompFrame, onPingFrame);
  }

  late StompParser _stompParser;

  final void Function() onDone;

  @override
  void parseData(dynamic data) {
    Uint8List byteList;
    if (data is String) {
      byteList = Uint8List.fromList(utf8.encode(data));
    } else if (data is List<int>) {
      byteList = Uint8List.fromList(data);
    } else {
      throw UnsupportedError('Input data type unsupported');
    }

    _collectData(byteList);
  }

  void _collectData(Uint8List byteList) {
    if (byteList.isEmpty) {
      return;
    }

    var msg = utf8.decode(byteList);
    var type = msg.substring(0, 1);
    var content = msg.substring(1);

    // first check for messages that don't need a payload
    switch (type) {
      case 'o': // Open frame
      case 'h': // Heartbeat frame
        return;
      default:
        break;
    }

    if (content.isEmpty) {
      return;
    }

    dynamic payload;
    try {
      payload = json.decode(content);
    } catch (exception) {
      return;
    }

    switch (type) {
      case 'a': //Array of messages
        if (payload is List) {
          for (var item in payload) {
            _stompParser.parseData(item);
          }
        }
        break;
      case 'm': //message
        _stompParser.parseData(payload);
        break;
      case 'c': //Close frame
        onDone();
        break;
    }
  }

  @override
  bool escapeHeaders = false;

  @override
  dynamic serializeFrame(StompFrame frame) {
    dynamic serializedFrame = _stompParser.serializeFrame(frame);

    serializedFrame = _encapsulateFrame(serializedFrame);

    return serializedFrame;
  }

  String _encapsulateFrame(String frame) {
    var result = json.encode(frame);
    return '[$result]';
  }
}
