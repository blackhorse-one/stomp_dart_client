import 'dart:convert';
import 'dart:typed_data';
import 'package:stomp_dart_client/parser.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:stomp_dart_client/stomp_parser.dart';

class SockJSParser implements Parser {

  StompParser _stompParser;

  SockJSParser(Function(StompFrame) onStompFrame, [Function onPingFrame]){
    _stompParser = StompParser(onStompFrame, onPingFrame);
  }

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
    if (byteList == null || byteList.isEmpty) {
      return;
    }

    var msg = utf8.decode(byteList);
    var type = msg.substring(0, 1);
    var content = msg.substring(1);

    // first check for messages that don't need a payload
    switch (type)
    {
      case 'o':
          return;
      case 'h':
          return;
      default:
        break;
    }

    if (content.isEmpty){
      return;
    }

    dynamic payload;
    try
    {
      payload = json.decode(content);
    }
    catch(exception){
      print('sockjs payload bad json:${exception.message}');
      return;
    }

    switch (type)
    {
      case 'a'://array message
        if (payload is List)
        {
          for (var item in payload)
          {
            print('message:' + item.toString());
            _stompParser.parseData(item);
          };
        }
        break;
      case 'm'://message
        print('message' + payload.toString());
        _stompParser.parseData(payload);
        break;
      case 'c'://close  
        // TODO close event
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

  String _encapsulateFrame(String frame){
    var result = json.encode(frame);
    return '[$result]';
  }
}
