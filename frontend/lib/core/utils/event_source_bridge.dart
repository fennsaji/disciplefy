import 'dart:async';

// Conditional imports for web-specific functionality
import 'event_source_bridge_stub.dart'
    if (dart.library.js) 'event_source_bridge_web.dart' as impl;

/// EventSource implementation with support for custom headers
/// This bridges Dart and JavaScript to enable EventSource with custom headers on web
class EventSourceBridge {
  /// Creates an EventSource connection with support for custom headers
  ///
  /// [url] - The URL to connect to
  /// [headers] - Map of headers to include (e.g., Authorization, apikey)
  ///
  /// Returns a Stream of server-sent events
  static Stream<String> connect({
    required String url,
    Map<String, String>? headers,
  }) {
    return impl.connect(url: url, headers: headers);
  }

  /// Closes all active connections
  static void closeAll() {
    impl.closeAll();
  }

  /// Checks if the EventSource bridge is available
  static bool get isAvailable {
    return impl.isAvailable;
  }
}
