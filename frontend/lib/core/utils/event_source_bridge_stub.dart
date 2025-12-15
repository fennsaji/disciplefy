import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mobile SSE implementation using HTTP streaming
///
/// This implementation uses the http package to create a streaming connection
/// that works on Android, iOS, and other non-web platforms.

final Map<int, _MobileEventSource> _connections = {};
int _nextId = 1;

/// Connects to an EventSource stream (mobile implementation).
///
/// Uses HTTP streaming to receive Server-Sent Events on mobile platforms.
///
/// [url] - The EventSource endpoint URL to connect to
/// [headers] - Optional HTTP headers for the connection
///
/// Returns a [Stream] of server-sent event data as strings.
Stream<String> connect({
  required String url,
  Map<String, String>? headers,
}) {
  final id = _nextId++;
  final eventSource = _MobileEventSource(url: url, headers: headers);
  _connections[id] = eventSource;

  return eventSource.stream.doOnCancel(() {
    _connections.remove(id);
    eventSource.close();
  });
}

/// Closes all active connections
void closeAll() {
  for (final connection in _connections.values) {
    connection.close();
  }
  _connections.clear();
}

/// Returns true - mobile SSE is now available
bool get isAvailable => true;

/// Extension to add doOnCancel to Stream
extension _StreamExtension<T> on Stream<T> {
  Stream<T> doOnCancel(void Function() onCancel) {
    final controller = StreamController<T>();
    StreamSubscription<T>? subscription;

    controller.onListen = () {
      subscription = listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    };

    controller.onCancel = () {
      onCancel();
      subscription?.cancel();
    };

    return controller.stream;
  }
}

/// Mobile EventSource implementation
class _MobileEventSource {
  final String url;
  final Map<String, String>? headers;
  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  http.Client? _client;
  bool _isClosed = false;

  _MobileEventSource({
    required this.url,
    this.headers,
  }) {
    _connect();
  }

  Stream<String> get stream => _controller.stream;

  Future<void> _connect() async {
    _client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse(url));

      // Add headers
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      if (headers != null) {
        request.headers.addAll(headers!);
      }

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        _controller.addError(
            Exception('HTTP ${response.statusCode}: Failed to connect to SSE'));
        await close();
        return;
      }

      // Process the stream
      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (_isClosed) break;

        buffer += chunk;

        // Process complete SSE messages
        while (buffer.contains('\n\n')) {
          final messageEnd = buffer.indexOf('\n\n');
          final message = buffer.substring(0, messageEnd);
          buffer = buffer.substring(messageEnd + 2);

          // Parse SSE message
          final data = _parseSSEMessage(message);
          if (data != null && data.isNotEmpty && !_controller.isClosed) {
            _controller.add(data);
          }
        }
      }

      // Process any remaining data
      if (buffer.isNotEmpty && !_isClosed) {
        final data = _parseSSEMessage(buffer);
        if (data != null && data.isNotEmpty && !_controller.isClosed) {
          _controller.add(data);
        }
      }

      if (!_controller.isClosed) {
        _controller.close();
      }
    } catch (e) {
      if (!_controller.isClosed) {
        _controller.addError(e);
        _controller.close();
      }
    }
  }

  /// Parse SSE message format and extract data
  String? _parseSSEMessage(String message) {
    final lines = message.split('\n');
    final dataLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('data:')) {
        // Handle both "data: value" and "data:value" formats
        final data = line.substring(5).trimLeft();
        dataLines.add(data);
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5));
      }
    }

    if (dataLines.isEmpty) return null;
    return dataLines.join('\n');
  }

  Future<void> close() async {
    _isClosed = true;
    _client?.close();
    _client = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
