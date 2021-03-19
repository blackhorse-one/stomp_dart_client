class StompBadStateException implements Exception {
  StompBadStateException([
    String? message,
  ]) : message = message ?? '';

  String message;
}
