import 'package:equatable/equatable.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/study_streak.dart';
import '../../domain/entities/user_level.dart';
import '../../domain/entities/user_stats.dart';

enum GamificationStatus { initial, loading, loaded, error }

class GamificationState extends Equatable {
  final GamificationStatus status;
  final UserStats? stats;
  final UserLevel? level;
  final List<Achievement> achievements;
  final StudyStreakUpdateResult? lastStreakUpdate;
  final List<AchievementUnlockResult> pendingNotifications;
  final String? errorMessage;
  final String? userId;
  final String languageCode;

  const GamificationState({
    this.status = GamificationStatus.initial,
    this.stats,
    this.level,
    this.achievements = const [],
    this.lastStreakUpdate,
    this.pendingNotifications = const [],
    this.errorMessage,
    this.userId,
    this.languageCode = 'en',
  });

  /// Check if there are pending achievement notifications
  bool get hasPendingNotifications => pendingNotifications.isNotEmpty;

  /// Get the next achievement to show notification for
  AchievementUnlockResult? get nextNotification =>
      pendingNotifications.isNotEmpty ? pendingNotifications.first : null;

  /// Get unlocked achievements count
  int get unlockedCount => achievements.where((a) => a.isUnlocked).length;

  /// Get total achievements count
  int get totalCount => achievements.length;

  /// Get achievement progress as percentage string
  String get achievementProgressText => '$unlockedCount/$totalCount';

  GamificationState copyWith({
    GamificationStatus? status,
    UserStats? stats,
    UserLevel? level,
    List<Achievement>? achievements,
    StudyStreakUpdateResult? lastStreakUpdate,
    List<AchievementUnlockResult>? pendingNotifications,
    String? errorMessage,
    String? userId,
    String? languageCode,
  }) {
    return GamificationState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      level: level ?? this.level,
      achievements: achievements ?? this.achievements,
      lastStreakUpdate: lastStreakUpdate ?? this.lastStreakUpdate,
      pendingNotifications: pendingNotifications ?? this.pendingNotifications,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId ?? this.userId,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  @override
  List<Object?> get props => [
        status,
        stats,
        level,
        achievements,
        lastStreakUpdate,
        pendingNotifications,
        errorMessage,
        userId,
        languageCode,
      ];
}
