import 'dart:async';
import 'dart:io';

import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockTable extends Mock implements SupabaseQueryBuilder {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id);
  @override
  final String id;
}

class _OkFilter extends Fake implements PostgrestFilterBuilder<dynamic> {
  @override
  Future<S> then<S>(FutureOr<S> Function(dynamic) onValue,
          {Function? onError}) =>
      Future<dynamic>.value().then(onValue, onError: onError);
}

void main() {
  late Directory dir;
  late Box<dynamic> queue;
  late _MockClient client;
  late _MockAuth auth;
  late _MockTable table;
  late ActivationAnalytics a;
  final clockTime = DateTime.utc(2026, 10, 6, 4);

  User user(String id) => _FakeUser(id);

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nux_test');
    Hive.init(dir.path);
    queue = await Hive.openBox('nux_events');
    client = _MockClient();
    auth = _MockAuth();
    table = _MockTable();
    when(() => client.auth).thenReturn(auth);
    when(() => client.from('analytics_events')).thenAnswer((_) => table);
    when(() => table.insert(any())).thenAnswer((_) => _OkFilter());
    a = ActivationAnalytics(client: client, clock: () => clockTime);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('event names are snake_case nux.*', () {
    expect(NuxEvent.firstOpen.type, 'nux.first_open');
    expect(NuxEvent.nfyTap.type, 'nux.nfy_tap');
    expect(NuxEvent.creditWarningShown.type, 'nux.credit_warning_shown');
  });

  test('signed out: queued, then flushed with user id and original time',
      () async {
    when(() => auth.currentUser).thenReturn(null);
    await a.track(NuxEvent.languageSelected, {'language': 'ml'});
    expect(queue.length, 1);
    verifyNever(() => table.insert(any()));
    when(() => auth.currentUser).thenReturn(user('g1'));
    await a.flush();
    final row = verify(() => table.insert(captureAny())).captured.single as Map;
    expect(row['user_id'], 'g1');
    expect(row['event_type'], 'nux.language_selected');
    expect(row['created_at'], clockTime.toIso8601String());
    expect(queue.length, 0);
  });

  test('signed in: inserts directly with session id', () async {
    when(() => auth.currentUser).thenReturn(user('u1'));
    await a.track(NuxEvent.verseViewed);
    final row = verify(() => table.insert(captureAny())).captured.single as Map;
    expect(row['user_id'], 'u1');
    expect(row['session_id'], ActivationAnalytics.appSessionId);
    expect(queue.length, 0);
  });

  test('insert failure never throws and requeues', () async {
    when(() => auth.currentUser).thenReturn(user('u1'));
    when(() => table.insert(any())).thenThrow(Exception('offline'));
    await a.track(NuxEvent.verseViewed);
    expect(queue.length, 1);
  });

  test('flush keeps order, stops at first failure, removes sent items',
      () async {
    when(() => auth.currentUser).thenReturn(null);
    await a.track(NuxEvent.firstOpen);
    await a.track(NuxEvent.verseViewed);
    await a.track(NuxEvent.lessonStarted);
    when(() => auth.currentUser).thenReturn(user('u1'));
    var n = 0;
    when(() => table.insert(any())).thenAnswer((_) {
      if (++n == 2) throw Exception('offline');
      return _OkFilter();
    });
    await a.flush();
    expect(queue.length, 2);
    when(() => table.insert(any())).thenAnswer((_) => _OkFilter());
    await a.flush();
    expect(queue.length, 0);
    final types = verify(() => table.insert(captureAny()))
        .captured
        .map((r) => (r as Map)['event_type'])
        .toList();
    expect(types.take(1), ['nux.first_open']);
    expect(types.skip(1),
        ['nux.verse_viewed', 'nux.verse_viewed', 'nux.lesson_started']);
  });

  test('drops long strings and non-scalars', () async {
    when(() => auth.currentUser).thenReturn(user('u1'));
    await a.track(NuxEvent.goalSelected, {
      'goal': 'newToFaith',
      'text': 'x' * 200,
      'edge': 'y' * 64,
      'obj': {'a': 1},
      'n': 3,
      'b': true,
      'nul': null,
    });
    final row = verify(() => table.insert(captureAny())).captured.single as Map;
    final d = row['event_data'] as Map;
    expect(d.keys, containsAll(['goal', 'client_ts', 'edge', 'n', 'b']));
    expect(d.containsKey('text'), isFalse);
    expect(d.containsKey('obj'), isFalse);
    expect(d.containsKey('nul'), isFalse);
  });

  test('first_open only once per install', () async {
    when(() => auth.currentUser).thenReturn(user('u1'));
    await a.trackFirstOpenOnce();
    await a.trackFirstOpenOnce();
    verify(() => table.insert(any())).called(1);
  });

  test('first_open carries its data', () async {
    when(() => auth.currentUser).thenReturn(user('u1'));
    await a.trackFirstOpenOnce({'language': 'hi'});
    final row = verify(() => table.insert(captureAny())).captured.single as Map;
    expect((row['event_data'] as Map)['language'], 'hi');
  });

  test('never throws when client or box throws', () async {
    when(() => client.auth).thenThrow(Exception('boom'));
    await a.track(NuxEvent.firstOpen);
    await a.flush();
    await a.trackFirstOpenOnce();
    await queue.close();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);
    await a.track(NuxEvent.firstOpen);
    await a.flush();
    await a.trackFirstOpenOnce();
  });

  test('logout closing every Hive box does not stop queueing (I3)', () async {
    when(() => auth.currentUser).thenReturn(null);
    await a.track(NuxEvent.firstOpen);
    // Logout (LocalStoreRepositoryImpl.clearAll) closes every box.
    await Hive.close();
    await a.track(NuxEvent.languageSelected, {'language': 'hi'});
    final reopened = Hive.box<dynamic>('nux_events');
    expect(reopened.length, 2);
    expect((reopened.getAt(1) as Map)['type'], 'nux.language_selected');
  });

  group('queued events and users', () {
    test('a failed signed-in event keeps its user and is sent only as them',
        () async {
      when(() => auth.currentUser).thenReturn(user('a'));
      when(() => table.insert(any())).thenThrow(Exception('offline'));
      await a.track(NuxEvent.verseViewed);
      expect((queue.getAt(0) as Map)['user_id'], 'a');

      // User A signs out, user B signs in on the same device.
      clearInteractions(table);
      when(() => table.insert(any())).thenAnswer((_) => _OkFilter());
      when(() => auth.currentUser).thenReturn(user('b'));
      await a.flush();
      verifyNever(() => table.insert(any()));
      expect(queue.length, 0, reason: "A's event is dropped, not sent as B");
    });

    test('the same user gets their own failed event on the next flush',
        () async {
      when(() => auth.currentUser).thenReturn(user('a'));
      when(() => table.insert(any())).thenThrow(Exception('offline'));
      await a.track(NuxEvent.verseViewed);
      clearInteractions(table);
      when(() => table.insert(any())).thenAnswer((_) => _OkFilter());
      await a.flush();
      final row =
          verify(() => table.insert(captureAny())).captured.single as Map;
      expect(row['user_id'], 'a');
      expect(queue.length, 0);
    });

    test('a signed-out event carries no user and goes to the next user',
        () async {
      when(() => auth.currentUser).thenReturn(null);
      await a.track(NuxEvent.firstOpen);
      expect((queue.getAt(0) as Map).containsKey('user_id'), isFalse);
      when(() => auth.currentUser).thenReturn(user('b'));
      await a.flush();
      final row =
          verify(() => table.insert(captureAny())).captured.single as Map;
      expect(row['user_id'], 'b');
    });
  });

  test('the queue is capped; the oldest events are dropped', () async {
    when(() => auth.currentUser).thenReturn(null);
    for (var i = 0; i < ActivationAnalytics.maxQueued + 5; i++) {
      await a.track(NuxEvent.nfyImpression, {'i': i});
    }
    final items = queue.keys
        .whereType<int>()
        .map((k) => ((queue.get(k) as Map)['data'] as Map)['i'])
        .toList();
    expect(items.length, ActivationAnalytics.maxQueued);
    expect(items.first, 5);
    expect(items.last, ActivationAnalytics.maxQueued + 4);
  });

  group('a permanently rejected event', () {
    test('is dropped during flush and does not block the rest', () async {
      when(() => auth.currentUser).thenReturn(null);
      await a.track(NuxEvent.firstOpen);
      await a.track(NuxEvent.verseViewed);
      when(() => auth.currentUser).thenReturn(user('u1'));
      var n = 0;
      when(() => table.insert(any())).thenAnswer((_) {
        if (++n == 1) {
          throw const PostgrestException(message: 'bad', code: '23514');
        }
        return _OkFilter();
      });
      await a.flush();
      expect(queue.length, 0);
      final types = verify(() => table.insert(captureAny()))
          .captured
          .map((r) => (r as Map)['event_type'])
          .toList();
      expect(types, ['nux.first_open', 'nux.verse_viewed']);
    });

    test('is not queued when the direct insert is rejected', () async {
      when(() => auth.currentUser).thenReturn(user('u1'));
      when(() => table.insert(any()))
          .thenThrow(const PostgrestException(message: 'bad', code: '400'));
      await a.track(NuxEvent.verseViewed);
      expect(queue.length, 0);
    });

    test('expired token, rate limit and network errors stay retryable', () {
      bool permanent(String code) => ActivationAnalytics.isPermanentInsertError(
          PostgrestException(message: 'x', code: code));
      expect(permanent('401'), isFalse);
      expect(permanent('429'), isFalse);
      expect(permanent('408'), isFalse);
      expect(permanent('500'), isFalse);
      expect(permanent('PGRST301'), isFalse);
      expect(ActivationAnalytics.isPermanentInsertError(Exception('offline')),
          isFalse);
      expect(permanent('403'), isTrue);
      expect(permanent('42501'), isTrue);
      expect(permanent('PGRST204'), isTrue);
    });
  });
}
