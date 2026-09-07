// ============================================================================
// Notification Repository Interface
// ============================================================================
// Domain layer contract for notification operations

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/notification_preferences.dart';
import '../entities/time_of_day_vo.dart';

abstract class NotificationRepository {
  /// Get user notification preferences
  Future<Either<Failure, NotificationPreferences>> getPreferences();

  /// Update user notification preferences
  Future<Either<Failure, NotificationPreferences>> updatePreferences({
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
    bool? streakReminderEnabled,
    bool? streakMilestoneEnabled,
    bool? streakLostEnabled,
    TimeOfDayVO? streakReminderTime,
    bool? memoryVerseReminderEnabled,
    bool? memoryVerseOverdueEnabled,
    TimeOfDayVO? memoryVerseReminderTime,
    bool? continueLearningEnabled,
    bool? achievementUnlockedEnabled,
    bool? fellowshipDailyPostEnabled,
    bool? fellowshipNewPostEnabled,
    bool? fellowshipNewCommentEnabled,
    bool? fellowshipReactionEnabled,
    bool? fellowshipDisciplerReplyEnabled,
    bool? fellowshipDisciplerActivityEnabled,
    bool? fellowshipMeetingEnabled,
    bool? fellowshipMeetingReminderEnabled,
    bool? fellowshipMeetingCancelledEnabled,
    bool? fellowshipMeetingInviteEnabled,
    bool? meetingInviteEnabled,
  });

  /// Check if notifications are enabled on device
  Future<Either<Failure, bool>> areNotificationsEnabled();

  /// Request notification permissions
  Future<Either<Failure, bool>> requestPermissions();
}
