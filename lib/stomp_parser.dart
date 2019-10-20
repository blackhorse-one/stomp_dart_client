import 'dart:typed_data';

import 'package:stomp_dart/stomp_frame.dart';

/**
 * This Parser is heavily based on the excellent recursive descent parser found here
 * https://github.com/stomp-js/stompjs/blob/master/src/parser.ts
 * Credit: https://github.com/kum-deepak
 */
class StompParser {
  String _resultCommand;
  Map<String, String> _resultHeaders;
  String _resultBody;

  List<int> _currentToken;
  String _currentHeaderKey;
  int _bodyBytesRemaining;

  final Function(StompFrame) onStompFrame;
  final Function onPingFrame;

  final NULL = 0;
  final LF = 10;
  final CR = 13;
  final COLON = 58;

  Function(int) _parseByte;

  bool escapeHeaders = false;

  StompParser(this.onStompFrame, [this.onPingFrame]) {
    this._initState();
  }

  void parseData(dynamic data) {
    Uint8List byteList;
    if (data is String) {
      byteList = Uint8List.fromList(data.codeUnits);
    } else if (data is List<int>) {
      byteList = Uint8List.fromList(data);
    } else {
      throw new UnsupportedError("Input data type unsupported");
    }

    for (var i = 0; i < byteList.length; i++) {
      _parseByte(byteList[i]);
    }
  }

  void _collectFrame(int byte) {
    if (byte == NULL) { // Ignore
      return;
    }
    if (byte == CR) { // Ignore CR
      return;
    }
    if (byte == LF) { // Incoming Ping
      this.onPingFrame != null ? this.onPingFrame() : null;
      return;
    }

    this._parseByte = this._collectCommand;
    this._reinjectByte(byte);
  }

  void _collectCommand(int byte) {
    if (byte == CR) { // Ignore CR
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
    if (byte == CR) { // Ignore CR
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
    if (byte == CR) { // Ignore CR
      return;
    }
    if (byte == LF) {
      _resultHeaders[_currentHeaderKey] = _consumeTokenAsString();
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
    if (_resultHeaders.containsKey('content-length')) {
      _bodyBytesRemaining = int.tryParse(_resultHeaders['content-length']);
      if (_bodyBytesRemaining == null) {
        print('[STOMP] Unable to parse content-length although it was present. Using fallback');
        _parseByte = _collectTerminatedBody;
      } else {
        _parseByte = _collectFixedSizeBody;
      }
    } else {
      _parseByte = _collectTerminatedBody;
    }
  }

  
  void _consumeBody() {
    _resultBody = _consumeTokenAsString();

    if (escapeHeaders) {
      _unescapeResultHeaders();
    }
    onStompFrame(StompFrame(command: _resultCommand, headers: _resultHeaders, body: _resultBody));

    _initState();
  }

  String _consumeTokenAsString() {
    String result = String.fromCharCodes(_currentToken);
    _currentToken = [];
    return result;
  }

  void _consumeByte(int byte) {
    _currentToken.add(byte);
  }

  void _reinjectByte(int byte) {
    _parseByte(byte);
  }

  /**
   * https://stomp.github.io/stomp-specification-1.2.html#Value_Encoding
   */
  void _unescapeResultHeaders() {
    Map<String, String> unescapedHeaders = {};
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

  /**
   * Order of those replaceAll is important. The \\ replace should be first,
   * otherwise it does also replace escaped \\n etc.
   */
  String _escapeString(String input) {
    return input
      .replaceAll(RegExp(r'\\'), '\\\\')
      .replaceAll(RegExp(r'\n'), '\\n')
      .replaceAll(RegExp(r':'), '\\c')
      .replaceAll(RegExp(r'\r'), '\\r');
  }

  Map<String, String> _escapeHeaders(Map<String, String> headers) {
    Map<String, String> escapedHeaders = {};
    headers?.forEach((key, value) {
      escapedHeaders[_escapeString(key)] = _escapeString(value);
    });
    return escapedHeaders;
  }

  /**
   * We don't need to worry about reversing the header since we use a map and
   * the last value written would just be the most up to date value, which is
   * also fine with the spec
   * https://stomp.github.io/stomp-specification-1.2.html#Repeated_Header_Entries
   */
  String serializeFrameToString(StompFrame frame) {
      String serializedFrame = frame.command;
      Map<String, String> headers = frame.headers ?? {};
      if (escapeHeaders) {
        headers = _escapeHeaders(headers);
      }
      headers.forEach((key, value) {
        serializedFrame += String.fromCharCode(LF) + key + ':' + value;
      });
      serializedFrame += String.fromCharCode(LF) + String.fromCharCode(LF);
      serializedFrame += frame.body ?? '';
      serializedFrame += String.fromCharCode(NULL);
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