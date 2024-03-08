// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:typed_data';

import 'stomp_config.dart';
import 'stomp_frame.dart';
import 'parser.dart';

typedef _ParseByteFunction = void Function(int);

///
/// This Parser is heavily based on the excellent recursive descent parser found here
/// https://github.com/stomp-js/stompjs/blob/master/src/parser.ts
/// Credit: https://github.com/kum-deepak
///
class StompParser implements Parser {
  StompParser(this.onStompFrame, [this.onPingFrame]) {
    _initState();
  }

  final StompFrameCallback onStompFrame;
  final StompPingFrameCallback? onPingFrame;

  var _resultHeaders = <String, String>{};
  String? _resultCommand;
  String? _resultBody;
  Uint8List? _binaryBody;

  var _currentToken = <int>[];
  String? _currentHeaderKey;
  int _bodyBytesRemaining = 0;

  static const _OCTET_STREAM_TYPE = 'application/octet-stream';
  static const _CONTENT_TYPE_KEY = 'content-type';
  static const _NULL = 0;
  static const _LF = 10;
  static const _CR = 13;
  static const _COLON = 58;
  late _ParseByteFunction _parseByte;

  @override
  bool escapeHeaders = false;

  @override
  void parseData(dynamic data) {
    Uint8List byteList;
    if (data is String) {
      byteList = Uint8List.fromList(utf8.encode(data));
    } else if (data is List<int>) {
      byteList = Uint8List.fromList(data);
    } else {
      throw UnsupportedError('Input data type unsupported ${data.runtimeType}');
    }

    for (var i = 0; i < byteList.length; i++) {
      _parseByte(byteList[i]);
    }
  }

  void _initState() {
    _resultCommand = null;
    _resultHeaders = {};
    _resultBody = null;
    _binaryBody = null;

    _currentToken = [];
    _currentHeaderKey = null;

    _parseByte = _collectFrame;
  }

  void _collectFrame(int byte) {
    if (byte == _NULL) {
      // Ignore
      return;
    }
    if (byte == _CR) {
      // Ignore CR
      return;
    }
    if (byte == _LF) {
      // Incoming Ping
      onPingFrame?.call();
      return;
    }

    _parseByte = _collectCommand;
    _reInjectByte(byte);
  }

  void _collectCommand(int byte) {
    if (byte == _CR) {
      // Ignore CR
      return;
    }
    if (byte == _LF) {
      _resultCommand = _consumeTokenAsString();
      _parseByte = _collectHeaders;
      return;
    }

    _consumeByte(byte);
  }

  void _collectHeaders(int byte) {
    if (byte == _CR) {
      // Ignore CR
      return;
    }
    if (byte == _LF) {
      _setupCollectBody();
      return;
    }

    _parseByte = _collectHeaderKey;
    _reInjectByte(byte);
  }

  void _collectHeaderKey(int byte) {
    if (byte == _COLON) {
      _currentHeaderKey = _consumeTokenAsString();
      _parseByte = _collectHeaderValue;
      return;
    }

    _consumeByte(byte);
  }

  void _collectHeaderValue(int byte) {
    if (byte == _CR) {
      // Ignore CR
      return;
    }
    if (byte == _LF) {
      _resultHeaders[_currentHeaderKey!] = _consumeTokenAsString();
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
    if (byte == _NULL) {
      _consumeBody();
      return;
    }

    _consumeByte(byte);
  }

  void _setupCollectBody() {
    if (_resultHeaders.containsKey('content-length')) {
      final remaining = int.tryParse(_resultHeaders['content-length']!);
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
    final type = _resultHeaders[_CONTENT_TYPE_KEY];

    if (type == _OCTET_STREAM_TYPE || type == null) {
      _binaryBody = Uint8List.fromList(_currentToken);
    } else {
      _resultBody = _consumeTokenAsString();
    }

    if (escapeHeaders) {
      _unescapeResultHeaders();
    }

    try {
      onStompFrame(StompFrame(
          command: _resultCommand!,
          headers: _resultHeaders,
          body: _resultBody,
          binaryBody: _binaryBody));
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

  void _reInjectByte(int byte) {
    _parseByte(byte);
  }

  /// https://stomp.github.io/stomp-specification-1.2.html#Value_Encoding
  void _unescapeResultHeaders() {
    final unescapedHeaders = <String, String>{};
    _resultHeaders.forEach((key, value) {
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

  Map<String, String> _escapeHeaders(Map<String, String> headers) {
    final escapedHeaders = <String, String>{};
    headers.forEach((key, value) {
      escapedHeaders[_escapeString(key)] = _escapeString(value);
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
      binaryList[serializedHeaders.codeUnits.length +
          frame.binaryBody!.length] = _NULL;
      return binaryList;
    } else {
      var serializedFrame = serializedHeaders;
      serializedFrame += frame.body ?? '';
      serializedFrame += String.fromCharCode(_NULL);
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
    if (escapeHeaders) {
      headers = _escapeHeaders(headers);
    }
    headers.forEach((key, value) {
      serializedFrame += '${String.fromCharCode(_LF)}$key:$value';
    });

    serializedFrame += String.fromCharCode(_LF) + String.fromCharCode(_LF);

    return serializedFrame;
  }
}
