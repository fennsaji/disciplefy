import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/cache/user_scoped_cache.dart';

void main() {
  late String? userId;
  late UserScopedCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    userId = 'user-a';
    cache = UserScopedCache(currentUserId: () => userId);
  });

  test('stores and reads a value for the current user (per variant)', () async {
    await cache.write(cache.ticket('x'), 'x', {'v': 1}, variant: 'en');
    expect(await cache.read('x', variant: 'en'), {'v': 1});
    expect(await cache.read('x', variant: 'hi'), isNull);
  });

  test('persists across instances (relaunch)', () async {
    await cache.write(cache.ticket('x'), 'x', [1, 2]);
    final relaunched = UserScopedCache(currentUserId: () => userId);
    expect(await relaunched.read('x'), [1, 2]);
  });

  test('never returns another user\'s value', () async {
    await cache.write(cache.ticket('x'), 'x', 'a-data');
    userId = 'user-b';
    expect(await cache.read('x'), isNull);
    userId = null;
    expect(await cache.read('x'), isNull);
  });

  test('drops a response that arrives after a user switch', () async {
    final ticket = cache.ticket('x');
    userId = 'user-b';
    await cache.write(ticket, 'x', 'a-data');
    expect(await cache.read('x'), isNull);
    userId = 'user-a';
    expect(await cache.read('x'), isNull);
  });

  test('invalidate removes the entry and discards in-flight responses',
      () async {
    await cache.write(cache.ticket('x'), 'x', 1, variant: 'en');
    final inFlight = cache.ticket('x');
    await cache.invalidate('x');
    expect(await cache.read('x', variant: 'en'), isNull);
    await cache.write(inFlight, 'x', 2, variant: 'en');
    expect(await cache.read('x', variant: 'en'), isNull);
    // A request started after the invalidation is stored.
    await cache.write(cache.ticket('x'), 'x', 3, variant: 'en');
    expect(await cache.read('x', variant: 'en'), 3);
  });

  test('invalidating one name keeps the others', () async {
    await cache.write(cache.ticket('x'), 'x', 1);
    await cache.write(cache.ticket('y'), 'y', 2);
    await cache.invalidate('x');
    expect(await cache.read('y'), 2);
  });

  test('clearAll (logout) removes every user\'s entries from disk', () async {
    await cache.write(cache.ticket('x'), 'x', 1);
    final inFlight = cache.ticket('y');
    await cache.clearAll();
    final relaunched = UserScopedCache(currentUserId: () => userId);
    expect(await relaunched.read('x'), isNull);
    await cache.write(inFlight, 'y', 2);
    expect(await cache.read('y'), isNull);
  });
}
