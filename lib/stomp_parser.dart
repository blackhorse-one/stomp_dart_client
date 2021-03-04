import 'dart:convert';
import 'dart:typed_data';

import 'package:stomp_dart_client/parser.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

///
/// This Parser is heavily based on the excellent recursive descent parser found here
/// https://github.com/stomp-js/stompjs/blob/master/src/parser.ts
/// Credit: https://github.com/kum-deepak
///
class StompParser implements Parser {
  String? _resultCommand;
  Map<String, String>? _resultHeaders;
  String? _resultBody;

  late List<int> _currentToken;
  String? _currentHeaderKey;
  int _bodyBytesRemaining = 0;

  final Function(StompFrame)? onStompFrame;
  final Function? onPingFrame;

  final NULL = 0;
  final LF = 10;
  final CR = 13;
  final COLON = 58;

  late Function(int) _parseByte;

  @override
  bool? escapeHeaders = false;

  StompParser(this.onStompFrame, [this.onPingFrame]) {
    _initState();
  }

  @override
  void parseData(dynamic data) {
    Uint8List byteList;
    if (data is String) {
      byteList = Uint8List.fromList(utf8.encode(data));
    } else if (data is List<int>) {
      byteList = Uint8List.fromList(data);
    } else {
      throw UnsupportedError(
          'Input data type unsupported ' + data.runtimeType.toString());
    }

    for (var i = 0; i < byteList.length; i++) {
      _parseByte(byteList[i]);
    }
  }

  void _collectFrame(int byte) {
    if (byte == NULL) {
      // Ignore
      return;
    }
    if (byte == CR) {
      // Ignore CR
      return;
    }
    if (byte == LF) {
      // Incoming Ping
      onPingFrame != null ? onPingFrame!() : null;
      return;
    }

    _parseByte = _collectCommand;
    _reinjectByte(byte);
  }

  void _collectCommand(int byte) {
    if (byte == CR) {
      // Ignore CR
      return;
    }
    if (byte == LF) {
      _resultCommand = _consumeTokenAsString();
      _parseByte = _collectHeaders;
      return;
    }

    _consumeByte(byte);
  }

  void _collectHeaders(int byte) {
    if (byte == CR) {
      // Ignore CR
      return;
    }
    if (byte == LF) {
      _setupCollectBody();
      return;
    }

    _parseByte = _collectHeaderKey;
    _reinjectByte(byte);
  }

  void _collectHeaderKey(int byte) {
    if (byte == COLON) {
      _currentHeaderKey = _consumeTokenAsString();
      _parseByte = _collectHeaderValue;
      return;
    }

    _consumeByte(byte);
  }

  void _collectHeaderValue(int byte) {
    if (byte == CR) {
      // Ignore CR
      return;
    }
    if (byte == LF) {
      _resultHeaders![_currentHeaderKey!] = _consumeTokenAsString();
      _currentHeaderKey = null;
      _parseByte = _collectHeaders;
      return;
    }

    _consumeByte(byte);
  }

  void _collectFixedSizeBody(int byte) {
    if (_bodyBytesRemaining-- == 0) {
      _consumeBody();
      return;
    }

    _consumeByte(byte);
  }

  void _collectTerminatedBody(int byte) {
    if (byte == NULL) {
      _consumeBody();
      return;
    }

    _consumeByte(byte);
  }

  void _setupCollectBody() {
    if (_resultHeaders!.containsKey('content-length')) {
      final remaining = int.tryParse(_resultHeaders!['content-length']!);
      if (remaining == null) {
        print(
            '[STOMP] Unable to parse content-length although it was present. Using fallback');
        _parseByte = _collectTerminatedBody;
      } else {
        _bodyBytesRemaining = remaining;
        _parseByte = _collectFixedSizeBody;
      }
    } else {
      _parseByte = _collectTerminatedBody;
    }
  }

  void _consumeBody() {
    _resultBody = _consumeTokenAsString();

    if (escapeHeaders!) {
      _unescapeResultHeaders();
    }

    try {
      onStompFrame!(StompFrame(
          command: _resultCommand!,
          headers: _resultHeaders!,
          body: _resultBody));
    } finally {
      _initState();
    }
  }

  String _consumeTokenAsString() {
    final result = utf8.decode(_currentToken);
    _currentToken = [];
    return result;
  }

  void _consumeByte(int byte) {
    _currentToken.add(byte);
  }

  void _reinjectByte(int byte) {
    _parseByte(byte);
  }

  /// https://stomp.github.io/stomp-specification-1.2.html#Value_Encoding
  void _unescapeResultHeaders() {
    final unescapedHeaders = <String, String>{};
    _resultHeaders!.forEach((key, value) {
      unescapedHeaders[_unescapeString(key)] = _unescapeString(value);
    });
    _resultHeaders = unescapedHeaders;
  }

  String _unescapeString(String input) {
    return input
        .replaceAll(RegExp(r'\\n'), '\n')
        .replaceAll(RegExp(r'\\r'), '\r')
        .replaceAll(RegExp(r'\\c'), ':')
        .replaceAll(RegExp(r'\\\\'), '\\');
  }

  /// Order of those replaceAll is important. The \\ replace should be first,
  /// otherwise it does also replace escaped \\n etc.
  String _escapeString(String input) {
    return input
        .replaceAll(RegExp(r'\\'), '\\\\')
        .replaceAll(RegExp(r'\n'), '\\n')
        .replaceAll(RegExp(r':'), '\\c')
        .replaceAll(RegExp(r'\r'), '\\r');
  }

  Map<String, String> _escapeHeaders(Map<String?, String> headers) {
    final escapedHeaders = <String, String>{};
    headers.forEach((key, value) {
      escapedHeaders[_escapeString(key!)] = _escapeString(value);
    });
    return escapedHeaders;
  }

  /// We don't need to worry about reversing the header since we use a map and
  /// the last value written would just be the most up to date value, which is
  /// also fine with the spec
  /// https://stomp.github.io/stomp-specification-1.2.html#Repeated_Header_Entries
  @override
  dynamic serializeFrame(StompFrame frame) {
    final serializedHeaders = _serializeCmdAndHeaders(frame) ?? '';

    if (frame.binaryBody != null) {
      final binaryList = Uint8List(
          serializedHeaders.codeUnits.length + 1 + frame.binaryBody!.length);
      binaryList.setRange(
          0, serializedHeaders.codeUnits.length, serializedHeaders.codeUnits);
      binaryList.setRange(
          serializedHeaders.codeUnits.length,
          serializedHeaders.codeUnits.length + frame.binaryBody!.length,
          frame.binaryBody!);
      binaryList[
          serializedHeaders.codeUnits.length + frame.binaryBody!.length] = NULL;
      return binaryList;
    } else {
      var serializedFrame = serializedHeaders;
      serializedFrame += frame.body ?? '';
      serializedFrame += String.fromCharCode(NULL);
      return serializedFrame;
    }
  }

  String? _serializeCmdAndHeaders(StompFrame frame) {
    var serializedFrame = frame.command;
    var headers = frame.headers;
    var bodyLength = 0;
    if (frame.binaryBody != null) {
      bodyLength = frame.binaryBody!.length;
    } else if (frame.body != null) {
      bodyLength = utf8.encode(frame.body!).length;
    }
    if (bodyLength > 0) {
      headers['content-length'] = bodyLength.toString();
    }
    if (escapeHeaders!) {
      headers = _escapeHeaders(headers);
    }
    headers.forEach((key, value) {
      serializedFrame += String.fromCharCode(LF) + key + ':' + value;
    });

    serializedFrame += String.fromCharCode(LF) + String.fromCharCode(LF);

    return serializedFrame;
  }

  void _initState() {
    _resultCommand = null;
    _resultHeaders = {};
    _resultBody = null;

    _currentToken = [];
    _currentHeaderKey = null;

    _parseByte = _collectFrame;
  }
}
