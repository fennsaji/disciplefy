import 'dart:collection';

/// A bounded memo of [compute] results, evicting the least recently used
/// entry once [capacity] is reached.
///
/// For pure, costly string transforms that run in `build` (markdown
/// preprocessing, section chunking): a lazily built list disposes and
/// rebuilds its items as they scroll, so a per-widget cache would redo the
/// work every time an item comes back on screen.
class LruMemo<K, V> {
  final int capacity;
  final V Function(K key) compute;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  LruMemo({required this.capacity, required this.compute})
      : assert(capacity > 0);

  V call(K key) {
    if (_entries.containsKey(key)) {
      // Re-insert to mark it most recently used.
      final hit = _entries.remove(key) as V;
      _entries[key] = hit;
      return hit;
    }
    final value = compute(key);
    if (_entries.length >= capacity) _entries.remove(_entries.keys.first);
    _entries[key] = value;
    return value;
  }

  int get length => _entries.length;

  void clear() => _entries.clear();
}
