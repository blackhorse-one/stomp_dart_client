import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

dynamic onConnect(StompClient client, StompFrame frame) {
  client.subscribe(
      destination: '/topic/test/subscription',
      callback: (StompFrame frame) {
        List<dynamic> result = json.decode(frame.body);
        print(result);
      });

  Timer.periodic(Duration(seconds: 10), (_) {
    client.send(
        destination: '/app/test/endpoints', body: json.encode({'a': 123}));
  });
}

final stompClient = StompClient(
    config: StompConfig(
        url: 'ws://localhost:8080',
        onConnect: onConnect,
        onWebSocketError: (dynamic error) => print(error.toString()),
        stompConnectHeaders: {'Authorization': 'Bearer yourToken'},
        webSocketConnectHeaders: {'Authorization': 'Bearer yourToken'}));

void main() {
  stompClient.activate();
}
