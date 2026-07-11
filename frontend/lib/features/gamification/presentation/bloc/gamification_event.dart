import 'package:equatable/equatable.dart';

import '../../domain/entities/achievement.dart';

abstract class GamificationEvent extends Equatable {
  const GamificationEvent();

  @override
  List<Object?> get props => [];
}

/// Load all gamification stats for a user
/// userId and languageCode are obtained from auth provider and language service
class LoadGamificationStats extends GamificationEvent {
  final bool forceRefresh;

  const LoadGamificationStats({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

/// Refresh stats (e.g., after completing a study)
class RefreshGamificationStats extends GamificationEvent {
  const RefreshGamificationStats();
}

/// Update study streak when a study guide is completed
class UpdateStudyStreak extends GamificationEvent {
  const UpdateStudyStreak();
}

/// Check achievements after study completion
class CheckStudyAchievements extends GamificationEvent {
  const CheckStudyAchievements();
}

/// Check achievements after memory verse added
class CheckMemoryAchievements extends GamificationEvent {
  const CheckMemoryAchievements();
}

/// Queue notifications for achievements already confirmed unlocked by the
/// backend (e.g. returned inline from submit-memory-practice). Skips the
/// checkMemoryAchievements RPC round-trip, avoiding a race where a client
/// re-check runs after the server already inserted the unlock row and so
/// reports it as not-new, silently dropping the popup.
class QueueAchievementNotifications extends GamificationEvent {
  final List<AchievementUnlockResult> achievements;

  const QueueAchievementNotifications(this.achievements);

  @override
  List<Object?> get props => [achievements];
}

/// Check achievements after voice session completed
class CheckVoiceAchievements extends GamificationEvent {
  const CheckVoiceAchievements();
}

/// Check achievements after saving a guide
class CheckSavedAchievements extends GamificationEvent {
  const CheckSavedAchievements();
}

/// Mark an achievement notification as seen
class DismissAchievementNotification extends GamificationEvent {
  const DismissAchievementNotification();
}

/// Clear all pending achievement notifications
class ClearAllAchievementNotifications extends GamificationEvent {
  const ClearAllAchievementNotifications();
}
