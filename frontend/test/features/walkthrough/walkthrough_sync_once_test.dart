import 'dart:async';
import 'dart:io';

import 'package:disciplefy_bible_study/features/walkthrough/data/walkthrough_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

User _user(String id) => User(
      id: id,
      appMetadata: const {'provider': 'google'},
      userMetadata: const {},
      aud: 'authenticated',
      email: '$id@example.com',
      createdAt: DateTime(2026).toIso8601String(),
    );

void main() {
  late Directory dir;
  late _MockAuth auth;
  late WalkthroughRepositoryImpl repository;
  late List<String> remoteReads;
  late Completer<void> gate;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('walkthrough_sync_test');
    Hive.init(dir.path);
    remoteReads = [];
    gate = Completer<void>()..complete();

    final client = _MockSupabaseClient();
    auth = _MockAuth();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(_user('user-a'));

    repository = WalkthroughRepositoryImpl(
      supabase: client,
      loadRemoteSeen: (userId) async {
        remoteReads.add(userId);
        await gate.future;
        return {
          'walkthrough_seen': ['home'],
        };
      },
    );
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('sign-in and Home share one remote read per user per session', () async {
    gate = Completer<void>();
    final first = repository.syncFromRemote();
    final second = repository.syncFromRemote();
    gate.complete();
    await Future.wait([first, second]);
    await repository.syncFromRemote();

    expect(remoteReads, ['user-a']);
  });

  test('a different account is synced again', () async {
    await repository.syncFromRemote();
    when(() => auth.currentUser).thenReturn(_user('user-b'));
    await repository.syncFromRemote();

    expect(remoteReads, ['user-a', 'user-b']);
  });

  test('a failed read is retried on the next call', () async {
    var fail = true;
    final client = _MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);
    final flaky = WalkthroughRepositoryImpl(
      supabase: client,
      loadRemoteSeen: (userId) async {
        remoteReads.add(userId);
        if (fail) throw Exception('offline');
        return null;
      },
    );

    await flaky.syncFromRemote();
    fail = false;
    await flaky.syncFromRemote();
    await flaky.syncFromRemote();

    expect(remoteReads, ['user-a', 'user-a']);
  });
}
