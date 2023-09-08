import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

void main() {
  runApp(const MaterialApp(
    home: HomePage(),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late StompClient stompClient;

  // WebSocket Server with SockJS
  String socketUrlSockJS = "http://localhost:8080/ws-message";

  // WebSocket Server without SockJS
  String socketUrl = "ws://localhost:8080/ws-message";

  // String to change in listener Subscription
  String message = '';

  // Subscription
  void onConnect(StompClient stompClient, StompFrame stompFrame) {
    stompClient.subscribe(
      destination: '/topic/message',
      callback: (frame) {
        if (frame.body != null) {
          // Here changes the state in screen
          setState(() {
            Map<String, dynamic> result = jsonDecode(frame.body!);
            message = result['message'];
          });
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // Configuration client with SockJS.
    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: socketUrlSockJS,
        onConnect: (stompFrame) => onConnect(stompClient, stompFrame),
      ),
    );

    // Configuration client without SockJS.
    // stompClient = StompClient(
    //   config: StompConfig(
    //     url: socketUrl,
    //     onConnect: (stompFrame) => onConnect(stompClient, stompFrame),
    //   ),
    // );

    stompClient.activate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stomp Client Demo"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Your message from server:",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(message),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    stompClient.deactivate();
    super.dispose();
  }
}
