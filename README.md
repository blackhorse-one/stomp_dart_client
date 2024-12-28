# Stomp Dart
This library provides an implementation for a STOMP client connecting to a remote server.
It should work for both pure dart and flutter.

## Usage

#### Initialize
The client gets created the specified config,
please see the Config section to see all available options
```dart
StompClient client = StompClient(
    config: StompConfig(
        url: 'wss://yourserver',
        onConnect: onConnectCallback
    )
);
```
The connect callback should be used to make sure that we are actually connected before we subscribe or send messages
```dart
void onConnectCallback(StompFrame connectFrame) {
    // client is connected and ready
}
```

#### Connect
```dart
client.activate();
```

#### Subscribe
```dart
client.subscribe(destination: '/foo/bar', headers: {}, callback: (frame) {
    // Received a frame for this subscription
    print(frame.body);
})
```

#### Ack/Nack
```dart
client.ack(id: message-id, headers: headers);

client.nack(id: message-id, headers: headers);
```

#### Unsubscribe
`client.subscribe(...)` returns a function which can be called with an optional map of headers
```dart
dynamic unsubscribeFn = client.subscribe(destination: '/foo/bar', headers: {}, callback: (frame) {
    // Received a frame for this subscription
    print(frame.body);
})
...
unsubscribeFn(unsubscribeHeaders: {});
```

#### Send
```dart
client.send(destination: '/foo/bar', body: 'Your message body', headers: {});
```

#### Disconnect
```dart
client.deactivate();
```

## StompConfig
This table shows all available options in `StompConfig`


| Option                                       | Description                                                                                                                        |
|----------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| url: String                                  | The url of the server you want connect to (required)                                                                               |
| reconnectDelay: Duration                     | Time duration between reconnect attempts. Set to 0 ms if you don't want to reconnect automatically. The default value is 5 seconds |
| heartbeatOutgoing: Duration                  | Time duration between outgoing heartbeat messages. Set to 0 ms to not send any heartbeats. The default value is 5 seconds          |
| heartbeatIncoming: Duration                  | Time duration between incoming heartbeat messages. Set to 0 ms to not receive any heartbeats. The default value is 5 seconds       |
| pingInterval: Duration                       | Time duration between ping messages being sent on the underlying WebSocket. (Not supported in Web)                                 |
| connectionTimeout: Duration                  | Time duration it waits until a connection attempt is aborted. Set to 0 ms to not set a timeout. The default value is 0 ms          |
| stompConnectHeaders: Map<String, String>     | Optional header values which will be used on the STOMP connect frame                                                               |
| webSocketConnectHeaders: Map<String, dynamic>| Optional header values which will be used when connecting to the underlying WebSocket [(not supported in Web)](#token-authentication-browser-based-clients)                       |
| beforeConnect: Future<void> Function()       | An async function which will be awaited before a connection is established                                                         |
| onConnect: Function(StompFrame)              | Function to be called when the client successfully connects to the server                                                          |
| onDisconnect: Function(StompFrame)           | Function to be called when the client disconnects expectedly                                                                       |
| onStompError: Function(StompFrame)           | Function to be called when the stomp server sends an error frame                                                                   |
| onUnhandledFrame: Function(StompFrame)       | Function to be called when the server sends a unrecognized frame                                                                   |
| onUnhandledMessage: Function(StompFrame)     | Function to be called when a subscription message does not have a handler                                                          |
| onUnhandledReceipt: Function(StompFrame)     | Function to be called when a receipt message does not have a registered watcher                                                    |
| onWebSocketError: Function(dynamic)          | Function to be called when the underyling WebSocket throws an error                                                                |
| onWebSocketDone: Function()                  | Function to be called when the underyling WebSocket is done/disconnected                                                           |
| onDebugMessage: Function(String)             | Function to be called for debug messages generated by the internal message handler                                                 |


## Use Stomp with SockJS
Use StompConfig.sockJS constructor instead of default StompConfig constructor.
Note: This library does not use SockJS as its underlying connection protocol.
It uses normal WebSockets, but supports SockJS URLs and data packets (https://sockjs.github.io/sockjs-protocol/sockjs-protocol-0.3.3.html#section-36 & https://sockjs.github.io/sockjs-protocol/sockjs-protocol-0.3.3.html#section-42)

```dart
StompClient client = StompClient(
    config: StompConfig.sockJS(
        url: 'https://yourserver',
        onConnect: onConnectCallback
    )
);
```

## Evaluation of headers

The STOMP client checks the `content-type` while parsing a received message. If the
header contains the value `application/octet-stream` the message body will be treated
as binary data. The resulting `StompFrame` will have a `binaryBody`. The `body` of the
frame will be empty in this case. The same is true if the `content-type` header is
missing.

## Token Authentication (browser-based clients)

Browser clients can only use standard authentication headers (that is, basic HTTP authentication) or cookies and [cannot provide custom headers](https://github.com/whatwg/websockets/issues/16#issuecomment-332065542) (such as "Authorization" to use a Bearer token). Thus `webSocketConnectHeaders` will do nothing in a browser environment.
Alternatives are:
- Use the STOMP client to pass authentication headers at connect time. (recommended)
    - Use `stompConnectHeaders` to pass your headers in the `CONNECT` frame. Parse those headers on the server (i.e. by using a `ChannelInterceptor` in Spring)
- Pass your authentication token/credentials as query parameter.

## Development

#### Running unit tests
```dart
dart run test -p "chrome,vm" test/
```

#### Generating coverage data
```dart
dart pub global activate coverage
dart pub global run coverage:collect_coverage --port=8111 --out=coverage.json --wait-paused --resume-isolates & dart --disable-service-auth-codes --enable-vm-service=8111 --pause-isolates-on-exit test/test_all.dart
```
And to convert to lcov
```dart
dart pub global run coverage:format_coverage --lcov --in=coverage.json --out=lcov.info --packages=.packages --report-on=lib
```
