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