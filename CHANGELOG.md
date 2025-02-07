## 2.1.3
  - Added `pingInterval` to `copyWith` for `StompConfig`. Thanks @AndruhovSasha

## 2.1.2
  - Fixed oversight in move to `package:web` which made the package not work with wasm.

## 2.1.1
  - Added `pingInterval` to `StompConfig` to control the ping interval of IO WebSockets. Thanks @AndruhovSasha

## 2.1.0
  - Updated version of `web_socket_channel` dependency to 3.0.1
  - Moved from `dart:html` to `package:web` for [web interop](https://dart.dev/interop/js-interop/package-web#migrating-from-dart-html)

## 2.0.0
  - **Breaking**: Changed exports to be all reexported in a single file to import. This is to satisfy the dart/flutter [conventions](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#structure). Thanks @Peetee06

## 1.0.3
  - Make connectUrl lazy and initialized only once per session [#95](https://github.com/blackhorse-one/stomp_dart_client/issues/95) (Thanks @MacDeveloper1)

## 1.0.2
  - Relaxed dependency of `web_socket_channel` again

## 1.0.1
  - Fixed dependency of `web_socket_channel` until this [issue](https://github.com/dart-lang/web_socket_channel/issues/307) is resolved/clarified

## 1.0.0
  - Stable release
  - Removed `StompConfig.SockJS` constructor in favor of `StompConfig.sockJS`
  - Regenerate Session and Server ID for SockJS on every connection (#93)
  - Fixed lingering WebSocket connection on rapid disconnect after connect

## 0.4.5
  - Added `StompConfig.sockJS` and deprecated `SockJS`

## 0.4.4
  - Added `binaryBody` to `StompFrame` when `content-type` header is missing or equals `application/octet-stream` (Thanks @dlfk99)

## 0.4.3
 - Fixed `StompUnsubscribe` throwing `StompBadStateException` in some cases

## 0.4.2
 - Fixed `onWebSocketError` callback for Web
 - Reworked HTML connect API.

## 0.4.1
 - Fixed heartbeat formatting

## 0.4.0
 - Null-safety migration
 - **Breaking**: `onConnect` callback no longer returns the client as first parameter
 - **Breaking**: `send`, `subscribe`, `ack`, `nack` and `unsubscribe` will now
   throw a `StompBadStateException` when either the client is not correctly set
   up or the cient is not connected.
 - `onWebSocketError` callback will now be called on every error when trying to connect

## 0.3.8
 - Fix for SockJS in web environment

## 0.3.7
 - Fixed heartbeat for SockJS

## 0.3.6
 - Add SockJS support 
 - Reconnect websocket when `WebSocketException` occurs and reconnectDelay != 0
 - Fixed bug with binary messages

## 0.3.5
 - Prevent `StompConfig` from losing `onDebugMessage` callback on `copyWith` #22

## 0.3.4
 - Catch `WebSocketChannelException` to be platform agnostic (Note: this does not work for HTML yet)
 - Fixed minor typo in README

## 0.3.3
 - Properly catch `WebSocketException` on connect
 - Fixed minor typo in README

## 0.3.2
 - Added Ack/Nack methods (Thanks @justacid). Note: This does not yet work for 1.0 & 1.1
 - (Minor: Reformatted code according to dartanalyze)

## 0.3.1
 - Changed folder structure to please pana.

## 0.3.0
 - Replaced `IOWebSocketChannel` with `WebSocketChannel` to be platform agnostic. This means it now also should work for flutter_web.
 - Made tests hybrid tests so that they cover all types of platforms

## 0.2.3
 - Fixed `onConnect` being called on inactive StompClient

## 0.2.2
 - Reverted type change on `stompConnectHeaders` because it caused issues on connect

## 0.2.1
 - Fixed a scenario where quick connect/disconnects could cause an exception

## 0.2.0
 - Breaking Change: Renamed `connectHeaders` to `stompConnectHeaders`
 - Added `webSocketConnectHeaders` to `StompConfig` to be passed to the underyling WebSocket on connection

## 0.1.6
 - Fixed a bug where it would not try to reconnect when the WebSocket connection could not be established
 - Added a `connectionTimeout` property to the config, to allow control over when a connection attempt is aborted

## 0.1.5
 - More formatting

## 0.1.4
 - Renamed package
 - Added example
 - Incorperated format suggestions

## 0.1.3
 - Removed dependency on non-hosted package to be able to publish the package