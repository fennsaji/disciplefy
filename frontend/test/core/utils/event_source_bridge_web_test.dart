@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/utils/event_source_bridge_web.dart'
    as bridge;

/// Captures what the Dart side passed across the JS boundary, and lets the
/// test drive the callbacks the way the real `EventSourceBridge` would.
class _StubBridge {
  late final JSObject object;

  String? url;
  Object? headers;
  JSFunction? onMessage;
  JSFunction? onError;
  JSFunction? onOpen;
  final List<int> closed = [];
  int nextId = 7;

  _StubBridge() {
    object = JSObject();
    object.setProperty(
      'connect'.toJS,
      ((String u, JSAny? h, JSFunction m, JSFunction e, JSFunction o) {
        url = u;
        headers = h?.dartify();
        onMessage = m;
        onError = e;
        onOpen = o;
        return nextId.toJS;
      }).toJS,
    );
    object.setProperty(
      'close'.toJS,
      ((int id) {
        closed.add(id);
      }).toJS,
    );
  }

  void install() {
    globalContext.setProperty('EventSourceBridge'.toJS, object);
    // isAvailable checks for both globals.
    globalContext.setProperty('fetchEventSource'.toJS, (() {}).toJS);
  }

  void remove() {
    globalContext.delete('EventSourceBridge'.toJS);
    globalContext.delete('fetchEventSource'.toJS);
  }

  void emit(String data) => onMessage!.callAsFunction(null, data.toJS);
  void fail(String error) => onError!.callAsFunction(null, error.toJS);
  void open() => onOpen!.callAsFunction();
}

void main() {
  late _StubBridge stub;

  setUp(() {
    stub = _StubBridge()..install();
  });

  tearDown(() {
    bridge.closeAll();
    stub.remove();
  });

  test('isAvailable reflects presence of the JS globals', () {
    expect(bridge.isAvailable, isTrue);
    stub.remove();
    expect(bridge.isAvailable, isFalse);
    stub.install();
  });

  test('passes url and headers across the JS boundary', () {
    bridge.connect(
      url: 'https://example.test/stream',
      headers: {'Authorization': 'Bearer token123', 'x-session-id': 'abc'},
    );

    expect(stub.url, 'https://example.test/stream');
    expect(stub.headers, {
      'Authorization': 'Bearer token123',
      'x-session-id': 'abc',
    });
  });

  test('tolerates null headers', () {
    bridge.connect(url: 'https://example.test/stream');
    expect(stub.headers, isNull);
  });

  test('forwards messages from JS onto the Dart stream', () async {
    final stream = bridge.connect(url: 'https://example.test/stream');
    final received = <String>[];
    stream.listen(received.add);

    stub.open();
    stub.emit('first chunk');
    stub.emit('second chunk');
    await Future.delayed(Duration.zero);

    expect(received, ['first chunk', 'second chunk']);
  });

  test('surfaces JS errors as stream errors', () async {
    final stream = bridge.connect(url: 'https://example.test/stream');
    Object? error;
    stream.listen((_) {}, onError: (Object e) => error = e);

    stub.fail('TOKEN_LIMIT_EXCEEDED');
    await Future.delayed(Duration.zero);

    expect(error, isA<Exception>());
    expect(error.toString(), contains('TOKEN_LIMIT_EXCEEDED'));
  });

  test('closes the JS connection using the id JS returned', () async {
    stub.nextId = 42;
    final stream = bridge.connect(url: 'https://example.test/stream');
    final sub = stream.listen((_) {});

    await sub.cancel();

    expect(stub.closed, [42]);
  });

  test('closeAll closes every open connection', () async {
    stub.nextId = 1;
    bridge.connect(url: 'https://example.test/a').listen((_) {});
    stub.nextId = 2;
    bridge.connect(url: 'https://example.test/b').listen((_) {});

    bridge.closeAll();

    expect(stub.closed, containsAll(<int>[1, 2]));
  });
}
