// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'logger.dart';

/// The `EventSourceBridge` object defined in `web/index.html`.
///
/// Declared as an extension type so calls go through the object itself —
/// its `connect`/`close` implementations use `this.connections`, which would
/// break if the functions were detached from the object.
extension type _EventSourceBridgeJs._(JSObject _) implements JSObject {
  external JSAny? connect(
    String url,
    JSAny? headers,
    JSFunction onMessage,
    JSFunction onError,
    JSFunction onOpen,
  );
  external void close(int connectionId);
}

@JS('EventSourceBridge')
external _EventSourceBridgeJs? get _bridge;

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
  final jsHeaders = headers?.jsify();

  // Define callback functions
  final onMessage = ((String data) {
    if (!controller.isClosed) {
      controller.add(data);
    }
  }).toJS;

  final onError = ((String error) {
    if (!controller.isClosed) {
      controller.addError(Exception('EventSource error: $error'));
    }
  }).toJS;

  final onOpen = (() {
    // Connection opened
  })
      .toJS;

  try {
    // Call the JavaScript bridge
    final jsConnectionId = _bridge?.connect(
      url,
      jsHeaders,
      onMessage,
      onError,
      onOpen,
    );

    if (jsConnectionId != null) {
      _connectionIds[dartId] = (jsConnectionId as JSNumber).toDartInt;
    } else {
      throw Exception('Failed to create JavaScript connection');
    }
  } catch (e) {
    Logger.error('[EventSourceBridge] ❌ Failed to create connection: $e');
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
      _bridge?.close(jsConnectionId);
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
    return globalContext.has('EventSourceBridge') &&
        globalContext.has('fetchEventSource');
  } catch (e) {
    return false;
  }
}
