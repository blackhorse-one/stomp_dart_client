class StompBadStateException implements Exception {
  StompBadStateException([this.message]);

  String? message;

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return 'StompBadStateException';
    return 'StompBadStateException: $message';
  }
}
