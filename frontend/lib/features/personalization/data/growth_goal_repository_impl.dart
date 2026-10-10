import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_remote.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_repository.dart';

/// [GrowthGoalRepository] over [GrowthGoalRemote] with a Hive cache in
/// `app_settings`.
///
/// The cache has its own keys ([cacheKey], [cacheUserKey]): the first run's
/// `first_run_goal` key keeps its meaning ("came through the new first run",
/// which holds back notification prompts and opens lesson 1 in Quick Read),
/// so a goal loaded from the server never changes those for an existing user.
/// Logs goal names only, never ids.
class GrowthGoalRepositoryImpl implements GrowthGoalRepository {
  /// Cached goal ([GrowthGoal.name]) and the user it belongs to.
  static const String cacheKey = 'growth_goal';
  static const String cacheUserKey = 'growth_goal_user';

  /// The goal the first run stored on this device.
  static const String firstRunGoalKey = 'first_run_goal';

  final GrowthGoalRemote _remote;
  final Box _settings;
  final String? Function() _currentUserId;

  /// User whose goal was synced this session.
  String? _syncedFor;

  GrowthGoalRepositoryImpl({
    required GrowthGoalRemote remote,
    required Box settings,
    required String? Function() currentUserId,
  })  : _remote = remote,
        _settings = settings,
        _currentUserId = currentUserId;

  @override
  GrowthGoal? get cachedGoal {
    try {
      final userId = _currentUserId();
      if (userId == null) return null;
      if (_settings.get(cacheUserKey) == userId) {
        return GrowthGoal.fromName(_settings.get(cacheKey));
      }
      return GrowthGoal.fromName(_settings.get(firstRunGoalKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cache(String userId, GrowthGoal goal) async {
    try {
      await _settings.putAll({cacheKey: goal.name, cacheUserKey: userId});
    } catch (e) {
      Logger.warning('Growth goal cache write failed',
          tag: 'GROWTH_GOAL', context: {'error': e.runtimeType.toString()});
    }
  }

  @override
  Future<GrowthGoal?> loadGoal() async {
    final userId = _currentUserId();
    if (userId == null) return null;
    try {
      final goal = GrowthGoal.fromServerKey(await _remote.fetchGoal());
      if (goal != null) await _cache(userId, goal);
      return goal ?? cachedGoal;
    } catch (e) {
      Logger.warning('Growth goal read failed',
          tag: 'GROWTH_GOAL', context: {'error': e.runtimeType.toString()});
      return cachedGoal;
    }
  }

  @override
  Future<Either<Failure, GrowthGoal>> saveGoal(
    GrowthGoal goal, {
    GrowthGoalSource source = GrowthGoalSource.app,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      return const Left(AuthenticationFailure(
          message: 'Sign in to save your goal.', code: 'NOT_SIGNED_IN'));
    }
    try {
      await _remote.saveGoal(goal.serverKey, source.value);
      await _cache(userId, goal);
      Logger.info('Growth goal saved',
          tag: 'GROWTH_GOAL',
          context: {'goal': goal.name, 'source': source.value});
      return Right(goal);
    } catch (e) {
      Logger.warning('Growth goal save failed',
          tag: 'GROWTH_GOAL', context: {'error': e.runtimeType.toString()});
      return const Left(NetworkFailure(message: 'Could not save your goal.'));
    }
  }

  @override
  Future<bool> syncOnce() async {
    final userId = _currentUserId();
    if (userId == null || _syncedFor == userId) return false;
    try {
      var uploaded = false;
      final server = GrowthGoal.fromServerKey(await _remote.fetchGoal());
      if (server != null) {
        await _cache(userId, server);
      } else {
        final local = cachedGoal;
        if (local != null) {
          await _remote.saveGoal(
              local.serverKey, GrowthGoalSource.firstRun.value);
          await _cache(userId, local);
          uploaded = true;
        }
      }
      _syncedFor = userId;
      return uploaded;
    } catch (e) {
      Logger.warning('Growth goal sync failed',
          tag: 'GROWTH_GOAL', context: {'error': e.runtimeType.toString()});
      return false;
    }
  }
}
