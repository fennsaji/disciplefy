import 'dart:async';

/// Connects to an EventSource stream (stub for non-web platforms).
///
/// This stub implementation throws [UnsupportedError] on non-web platforms.
/// EventSource with custom headers is only supported on web platforms.
///
/// **Platform Behavior:**
/// - Web: Uses conditional import to load actual EventSource implementation
/// - Non-Web (Mobile/Desktop): Throws [UnsupportedError]
///
/// [url] - The EventSource endpoint URL to connect to
/// [headers] - Optional HTTP headers for the connection (web-only)
///
/// Returns a [Stream] of server-sent event data as strings.
///
/// Throws [UnsupportedError] when called on non-web platforms.
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
