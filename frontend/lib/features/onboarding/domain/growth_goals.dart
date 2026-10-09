import 'package:equatable/equatable.dart';

/// What a new person wants to grow in, picked on the first-run goal screen.
/// Each goal opens one guest-accessible learning path.
///
/// Declared in screen order. The goal's [name] is what is stored in Hive
/// `app_settings['first_run_goal']`.
enum GrowthGoal {
  newToFaith('new-believer-essentials', 'goal.new_to_faith'),
  freshStart('sin-repentance-and-grace', 'goal.fresh_start'),
  walkWithGod('growing-in-discipleship', 'goal.walk_with_god'),
  hopeHardTimes('theology-of-suffering', 'goal.hope_hard_times'),
  readGospel('gospel-of-mark', 'goal.read_gospel'),
  understandGospel('romans-gospel-unfolded', 'goal.understand_gospel');

  /// Slug of the learning path this goal starts.
  final String pathSlug;

  /// Translation key of the goal's label.
  final String labelKey;

  const GrowthGoal(this.pathSlug, this.labelKey);

  /// The goal stored under [name], or null when unknown (for example a goal
  /// from an older build).
  static GrowthGoal? fromName(Object? name) {
    for (final goal in values) {
      if (goal.name == name) return goal;
    }
    return null;
  }
}

/// Title and lesson count of a goal's path, for the row's second line.
class StarterPathInfo extends Equatable {
  final String title;
  final int lessonCount;

  const StarterPathInfo({required this.title, required this.lessonCount});

  @override
  List<Object?> get props => [title, lessonCount];
}

/// What the goal screen knows about the goal paths. Anything missing is
/// simply not shown; the screen never waits on it.
class StarterPaths extends Equatable {
  /// Path info by slug.
  final Map<String, StarterPathInfo> bySlug;

  /// Number of active paths, when the list could be loaded.
  final int? totalPaths;

  const StarterPaths({this.bySlug = const {}, this.totalPaths});

  static const StarterPaths empty = StarterPaths();

  StarterPathInfo? forGoal(GrowthGoal goal) => bySlug[goal.pathSlug];

  @override
  List<Object?> get props => [bySlug, totalPaths];
}
