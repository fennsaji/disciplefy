/// Stub implementation for html library on non-web platforms
class EventSource {
  static bool get supported => false;

  EventSource(String url);

  void close() {}

  Stream get onOpen => const Stream.empty();
  Stream get onMessage => const Stream.empty();
  Stream get onError => const Stream.empty();
}

class MessageEvent {
  final String data;
  MessageEvent(this.data);
}

class Event {}
