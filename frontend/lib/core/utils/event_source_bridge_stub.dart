import 'dart:async';

/// Stub implementation for non-web platforms
/// EventSource with headers is only available on web
Stream<String> connect({
  required String url,
  Map<String, String>? headers,
}) {
  throw UnsupportedError(
      'EventSource with headers is only supported on web platforms');
}

/// Stub for closeAll
void closeAll() {
  // No-op for non-web platforms
}

/// Stub for isAvailable
bool get isAvailable => false;
