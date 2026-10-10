import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/personalization/data/growth_goal_repository_impl.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_remote.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_repository.dart';

/// In-memory server: one goal per user.
class _FakeRemote implements GrowthGoalRemote {
  final Map<String, String> goals = {};
  final List<(String, String)> saves = [];
  String userId = 'u1';
  bool fail = false;
  int fetches = 0;

  @override
  Future<String?> fetchGoal() async {
    fetches++;
    if (fail) throw Exception('offline');
    return goals[userId];
  }

  @override
  Future<void> saveGoal(String goal, String source) async {
    if (fail) throw Exception('offline');
    saves.add((goal, source));
    goals[userId] = goal;
  }
}

void main() {
  late Directory tempDir;
  late Box settings;
  late _FakeRemote remote;
  String? userId = 'u1';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('growth_goal_repo_test');
    Hive.init(tempDir.path);
    settings = await Hive.openBox('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await settings.clear();
    remote = _FakeRemote();
    userId = 'u1';
  });

  GrowthGoalRepository repo() => GrowthGoalRepositoryImpl(
        remote: remote,
        settings: settings,
        currentUserId: () => userId,
      );

  test('save writes the server goal and caches it on the device', () async {
    final r = repo();
    final result = await r.saveGoal(GrowthGoal.readGospel,
        source: GrowthGoalSource.settings);

    expect(result.isRight(), isTrue);
    expect(remote.saves, [('read_gospel', 'settings')]);
    expect(r.cachedGoal, GrowthGoal.readGospel);
    expect(settings.get(GrowthGoalRepositoryImpl.cacheKey), 'readGospel');
  });

  test('a failed save keeps the old goal and reports a failure', () async {
    final r = repo();
    await r.saveGoal(GrowthGoal.freshStart);
    remote.fail = true;

    final result = await r.saveGoal(GrowthGoal.hopeHardTimes);

    expect(result.isLeft(), isTrue);
    expect(r.cachedGoal, GrowthGoal.freshStart);
  });

  test('load reads the server goal and refreshes the cache', () async {
    remote.goals['u1'] = 'understand_gospel';
    final r = repo();

    expect(await r.loadGoal(), GrowthGoal.understandGospel);
    expect(r.cachedGoal, GrowthGoal.understandGospel);
  });

  test('load falls back to the cache when offline', () async {
    final r = repo();
    await r.saveGoal(GrowthGoal.walkWithGod);
    remote.fail = true;

    expect(await r.loadGoal(), GrowthGoal.walkWithGod);
  });

  test('sync uploads a goal that was only on this device (first run)',
      () async {
    await settings.put('first_run_goal', 'hopeHardTimes');
    final r = repo();

    expect(await r.syncOnce(), isTrue);

    expect(remote.saves, [('hope_hard_times', 'first_run')]);
    expect(r.cachedGoal, GrowthGoal.hopeHardTimes);
  });

  test('sync keeps the server goal over the device one, once per user',
      () async {
    await settings.put('first_run_goal', 'hopeHardTimes');
    remote.goals['u1'] = 'read_gospel';
    final r = repo();

    expect(await r.syncOnce(), isFalse);
    expect(await r.syncOnce(), isFalse);

    expect(remote.saves, isEmpty);
    expect(remote.fetches, 1);
    expect(r.cachedGoal, GrowthGoal.readGospel);
  });

  test('another user never sees the cached goal of the last one', () async {
    final r = repo();
    await r.saveGoal(GrowthGoal.readGospel);

    userId = 'u2';
    remote.userId = 'u2';

    expect(r.cachedGoal, isNull);
    await r.syncOnce();
    expect(remote.fetches, 1);
  });

  test('signed out: nothing is read or written', () async {
    userId = null;
    final r = repo();

    await r.syncOnce();
    final result = await r.saveGoal(GrowthGoal.newToFaith);

    expect(remote.fetches, 0);
    expect(result.isLeft(), isTrue);
  });

  test('server keys map to goals and back', () {
    for (final goal in GrowthGoal.values) {
      expect(GrowthGoal.fromServerKey(goal.serverKey), goal);
    }
    expect(GrowthGoal.fromServerKey('readGospel'), isNull);
  });
}
