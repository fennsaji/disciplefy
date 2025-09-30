// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js' as js;

final Map<int, StreamController<String>> _controllers = {};
final Map<int, int> _connectionIds = {};
int _nextDartId = 1;

/// Creates an EventSource connection with support for custom headers (Web implementation)
Stream<String> connect({
  required String url,
  Map<String, String>? headers,
}) {
  final dartId = _nextDartId++;
  final controller = StreamController<String>.broadcast();
  _controllers[dartId] = controller;

  // Connection established

  // Convert Dart map to JavaScript object
  final jsHeaders = headers != null ? js.JsObject.jsify(headers) : null;

  // Define callback functions
  final onMessage = js.allowInterop((String data) {
    if (!controller.isClosed) {
      controller.add(data);
    }
  });

  final onError = js.allowInterop((String error) {
    if (!controller.isClosed) {
      controller.addError(Exception('EventSource error: $error'));
    }
  });

  final onOpen = js.allowInterop(() {
    // Connection opened
  });

  try {
    // Call the JavaScript bridge
    final jsConnectionId =
        js.context['EventSourceBridge'].callMethod('connect', [
      url,
      jsHeaders,
      onMessage,
      onError,
      onOpen,
    ]);

    if (jsConnectionId != null) {
      _connectionIds[dartId] = jsConnectionId as int;
    } else {
      throw Exception('Failed to create JavaScript connection');
    }
  } catch (e) {
    print('[EventSourceBridge] ❌ Failed to create connection: $e');
    controller.addError(e);
    controller.close();
    _controllers.remove(dartId);
    return controller.stream;
  }

  // Handle stream cleanup when stream is cancelled
  controller.onCancel = () {
    _closeConnection(dartId);
  };

  return controller.stream;
}

/// Closes a specific connection
void _closeConnection(int dartId) {
  final jsConnectionId = _connectionIds[dartId];
  if (jsConnectionId != null) {
    try {
      js.context['EventSourceBridge'].callMethod('close', [jsConnectionId]);
    } catch (e) {
      // Error closing connection
    }
    _connectionIds.remove(dartId);
  }

  final controller = _controllers[dartId];
  if (controller != null && !controller.isClosed) {
    controller.close();
  }
  _controllers.remove(dartId);
}

/// Closes all active connections
void closeAll() {
  final dartIds = List<int>.from(_controllers.keys);
  for (final dartId in dartIds) {
    _closeConnection(dartId);
  }
}

/// Checks if the EventSource bridge is available
bool get isAvailable {
  try {
    return js.context.hasProperty('EventSourceBridge') &&
        js.context.hasProperty('fetchEventSource');
  } catch (e) {
    return false;
  }
}
