import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_cache.dart';

http.Response _profile(String id, {String name = 'A'}) => http.Response(
      json.encode({
        'data': {'id': id, 'first_name': name}
      }),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

String _name(http.Response r) =>
    (json.decode(r.body)['data'] as Map)['first_name'] as String;

void main() {
  late String? userId;
  late DateTime now;
  late UserProfileCache cache;
  late int calls;
  late Future<http.Response> Function() fetch;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    userId = 'u1';
    now = DateTime(2026, 9, 30, 12);
    calls = 0;
    cache = UserProfileCache(currentUserId: () => userId, now: () => now);
    fetch = () async {
      calls++;
      return _profile(userId ?? 'anon', name: 'n$calls');
    };
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('second read within the session is served from memory', () async {
    await cache.get(fetch);
    final second = await cache.get(fetch);
    expect(calls, 1);
    expect(_name(second), 'n1');
  });

  test('concurrent reads share one in-flight request', () async {
    final gate = Completer<http.Response>();
    var slowCalls = 0;
    Future<http.Response> slow() {
      slowCalls++;
      return gate.future;
    }

    final reads = [cache.get(slow), cache.get(slow), cache.get(slow)];
    await settle();
    gate.complete(_profile('u1'));
    await Future.wait(reads);
    expect(slowCalls, 1);
  });

  test('stale memory is returned and revalidated in the background', () async {
    await cache.get(fetch);
    now = now.add(const Duration(minutes: 6));
    final stale = await cache.get(fetch);
    expect(_name(stale), 'n1');
    await settle();
    expect(calls, 2);
    expect(_name(await cache.get(fetch)), 'n2');
  });

  test('persisted profile is shown on relaunch and revalidated', () async {
    await cache.get(fetch);
    await settle();
    final relaunched =
        UserProfileCache(currentUserId: () => userId, now: () => now);
    final first = await relaunched.get(fetch);
    expect(_name(first), 'n1');
    await settle();
    expect(calls, 2);
  });

  test('invalidate forces a network read', () async {
    await cache.get(fetch);
    await cache.invalidate();
    await cache.get(fetch);
    expect(calls, 2);
  });

  test('a response started before invalidation is not cached', () async {
    final gate = Completer<http.Response>();
    final read = cache.get(() => gate.future);
    await settle();
    await cache.invalidate();
    gate.complete(_profile('u1', name: 'old'));
    await read;
    expect(_name(await cache.get(fetch)), 'n1');
  });

  test('users are isolated in memory and on disk', () async {
    await cache.get(fetch);
    await settle();
    userId = 'u2';
    final other = await cache.get(fetch);
    expect(json.decode(other.body)['data']['id'], 'u2');
    expect(calls, 2);

    final prefs = await SharedPreferences.getInstance();
    await settle();
    expect(prefs.getKeys().where((k) => k.contains('u1')), isNotEmpty);
    expect(prefs.getKeys().where((k) => k.contains('u2')), isNotEmpty);
  });

  test('clearAll removes every persisted profile (logout)', () async {
    await cache.get(fetch);
    await settle();
    await cache.clearAll();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    await cache.get(fetch);
    expect(calls, 2);
  });

  test('errors and signed-out reads are not cached', () async {
    var n = 0;
    Future<http.Response> failing() async {
      n++;
      return http.Response('{"error":"x"}', 404);
    }

    expect((await cache.get(failing)).statusCode, 404);
    expect((await cache.get(failing)).statusCode, 404);
    expect(n, 2);

    userId = null;
    await cache.get(fetch);
    await cache.get(fetch);
    expect(calls, 2);
  });
}
