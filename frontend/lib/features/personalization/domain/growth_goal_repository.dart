import 'package:dartz/dartz.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';

/// Where a goal was picked; stored with it on the server.
enum GrowthGoalSource {
  firstRun('first_run'),
  settings('settings'),
  app('app');

  final String value;
  const GrowthGoalSource(this.value);
}

/// The user's growth goal: the only personalisation question. Kept on the
/// server (it drives what paths come next) with a copy on the device.
abstract class GrowthGoalRepository {
  /// The goal on this device for the signed-in user: the server copy, else
  /// the goal picked in the first run on this device. Never throws.
  GrowthGoal? get cachedGoal;

  /// The server goal (cached on success). Offline: [cachedGoal].
  Future<GrowthGoal?> loadGoal();

  /// Saves [goal] on the server, then on the device.
  Future<Either<Failure, GrowthGoal>> saveGoal(
    GrowthGoal goal, {
    GrowthGoalSource source = GrowthGoalSource.app,
  });

  /// Once per signed-in user and app session: takes the server goal, or
  /// uploads a goal that so far only lives on this device (picked in a first
  /// run before goals were saved on the server). True when it uploaded one,
  /// so what comes next may have changed. Never throws.
  Future<bool> syncOnce();
}
