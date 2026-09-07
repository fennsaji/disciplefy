// ============================================================================
// Notification Preferences Model
// ============================================================================
// Data layer model for notification preferences

import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/time_of_day_vo.dart';

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.userId,
    required super.dailyVerseEnabled,
    required super.recommendedTopicEnabled,
    required super.streakReminderEnabled,
    required super.streakMilestoneEnabled,
    required super.streakLostEnabled,
    required super.streakReminderTime,
    required super.memoryVerseReminderEnabled,
    required super.memoryVerseOverdueEnabled,
    required super.memoryVerseReminderTime,
    super.continueLearningEnabled,
    super.achievementUnlockedEnabled,
    super.fellowshipDailyPostEnabled,
    super.fellowshipNewPostEnabled,
    super.fellowshipNewCommentEnabled,
    super.fellowshipReactionEnabled,
    super.fellowshipDisciplerReplyEnabled,
    super.fellowshipDisciplerActivityEnabled,
    super.fellowshipMeetingEnabled,
    super.fellowshipMeetingReminderEnabled,
    super.fellowshipMeetingCancelledEnabled,
    super.fellowshipMeetingInviteEnabled,
    super.meetingInviteEnabled,
    super.fellowshipMentorPromotedEnabled,
    super.fellowshipMemberJoinedEnabled,
    super.fellowshipMentionEnabled,
    required super.createdAt,
    required super.updatedAt,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    // Parse streak_reminder_time from TIME format (e.g., "20:00:00")
    TimeOfDayVO parseTime(String? timeString) {
      if (timeString == null) {
        return const TimeOfDayVO(hour: 20, minute: 0); // Default 8 PM
      }

      final parts = timeString.split(':');
      if (parts.length >= 2) {
        return TimeOfDayVO(
          hour: int.tryParse(parts[0]) ?? 20,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      return const TimeOfDayVO(hour: 20, minute: 0);
    }

    // Parse memory_verse_reminder_time with 9 AM default
    TimeOfDayVO parseMemoryVerseTime(String? timeString) {
      if (timeString == null) {
        return const TimeOfDayVO(hour: 9, minute: 0); // Default 9 AM
      }

      final parts = timeString.split(':');
      if (parts.length >= 2) {
        return TimeOfDayVO(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      return const TimeOfDayVO(hour: 9, minute: 0);
    }

    return NotificationPreferencesModel(
      userId: json['user_id'] as String? ?? json['userId'] as String,
      dailyVerseEnabled: json['daily_verse_enabled'] as bool? ??
          json['dailyVerseEnabled'] as bool? ??
          true,
      recommendedTopicEnabled: json['recommended_topic_enabled'] as bool? ??
          json['recommendedTopicEnabled'] as bool? ??
          true,
      streakReminderEnabled: json['streak_reminder_enabled'] as bool? ??
          json['streakReminderEnabled'] as bool? ??
          true,
      streakMilestoneEnabled: json['streak_milestone_enabled'] as bool? ??
          json['streakMilestoneEnabled'] as bool? ??
          true,
      streakLostEnabled: json['streak_lost_enabled'] as bool? ??
          json['streakLostEnabled'] as bool? ??
          true,
      streakReminderTime: parseTime(
        json['streak_reminder_time'] as String? ??
            json['streakReminderTime'] as String?,
      ),
      memoryVerseOverdueEnabled:
          json['memory_verse_overdue_enabled'] as bool? ??
              json['memoryVerseOverdueEnabled'] as bool? ??
              true,
      memoryVerseReminderEnabled:
          json['memory_verse_reminder_enabled'] as bool? ??
              json['memoryVerseReminderEnabled'] as bool? ??
              true,
      memoryVerseReminderTime: parseMemoryVerseTime(
        json['memory_verse_reminder_time'] as String? ??
            json['memoryVerseReminderTime'] as String?,
      ),
      continueLearningEnabled: json['continue_learning_enabled'] as bool? ??
          json['continueLearningEnabled'] as bool? ??
          true,
      achievementUnlockedEnabled:
          json['achievement_unlocked_enabled'] as bool? ??
              json['achievementUnlockedEnabled'] as bool? ??
              true,
      fellowshipDailyPostEnabled:
          json['fellowship_daily_post_enabled'] as bool? ??
              json['fellowshipDailyPostEnabled'] as bool? ??
              true,
      fellowshipNewPostEnabled: json['fellowship_new_post_enabled'] as bool? ??
          json['fellowshipNewPostEnabled'] as bool? ??
          true,
      fellowshipNewCommentEnabled:
          json['fellowship_new_comment_enabled'] as bool? ??
              json['fellowshipNewCommentEnabled'] as bool? ??
              true,
      fellowshipReactionEnabled: json['fellowship_reaction_enabled'] as bool? ??
          json['fellowshipReactionEnabled'] as bool? ??
          true,
      fellowshipDisciplerReplyEnabled:
          json['fellowship_discipler_reply_enabled'] as bool? ??
              json['fellowshipDisciplerReplyEnabled'] as bool? ??
              true,
      fellowshipDisciplerActivityEnabled:
          json['fellowship_discipler_activity_enabled'] as bool? ??
              json['fellowshipDisciplerActivityEnabled'] as bool? ??
              true,
      fellowshipMeetingEnabled: json['fellowship_meeting_enabled'] as bool? ??
          json['fellowshipMeetingEnabled'] as bool? ??
          true,
      fellowshipMeetingReminderEnabled:
          json['fellowship_meeting_reminder_enabled'] as bool? ??
              json['fellowshipMeetingReminderEnabled'] as bool? ??
              true,
      fellowshipMeetingCancelledEnabled:
          json['fellowship_meeting_cancelled_enabled'] as bool? ??
              json['fellowshipMeetingCancelledEnabled'] as bool? ??
              true,
      fellowshipMeetingInviteEnabled:
          json['fellowship_meeting_invite_enabled'] as bool? ??
              json['fellowshipMeetingInviteEnabled'] as bool? ??
              true,
      meetingInviteEnabled: json['meeting_invite_enabled'] as bool? ??
          json['meetingInviteEnabled'] as bool? ??
          true,
      fellowshipMentorPromotedEnabled:
          json['fellowship_mentor_promoted_enabled'] as bool? ??
              json['fellowshipMentorPromotedEnabled'] as bool? ??
              true,
      fellowshipMemberJoinedEnabled:
          json['fellowship_member_joined_enabled'] as bool? ??
              json['fellowshipMemberJoinedEnabled'] as bool? ??
              true,
      fellowshipMentionEnabled: json['fellowship_mention_enabled'] as bool? ??
          json['fellowshipMentionEnabled'] as bool? ??
          true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    // Format TimeOfDayVO to TIME format (e.g., "20:00:00")
    String formatTime(TimeOfDayVO time) {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}:00';
    }

    return {
      'user_id': userId,
      'daily_verse_enabled': dailyVerseEnabled,
      'recommended_topic_enabled': recommendedTopicEnabled,
      'streak_reminder_enabled': streakReminderEnabled,
      'streak_milestone_enabled': streakMilestoneEnabled,
      'streak_lost_enabled': streakLostEnabled,
      'streak_reminder_time': formatTime(streakReminderTime),
      'memory_verse_reminder_enabled': memoryVerseReminderEnabled,
      'memory_verse_overdue_enabled': memoryVerseOverdueEnabled,
      'memory_verse_reminder_time': formatTime(memoryVerseReminderTime),
      'continue_learning_enabled': continueLearningEnabled,
      'achievement_unlocked_enabled': achievementUnlockedEnabled,
      'fellowship_daily_post_enabled': fellowshipDailyPostEnabled,
      'fellowship_new_post_enabled': fellowshipNewPostEnabled,
      'fellowship_new_comment_enabled': fellowshipNewCommentEnabled,
      'fellowship_reaction_enabled': fellowshipReactionEnabled,
      'fellowship_discipler_reply_enabled': fellowshipDisciplerReplyEnabled,
      'fellowship_discipler_activity_enabled':
          fellowshipDisciplerActivityEnabled,
      'fellowship_meeting_enabled': fellowshipMeetingEnabled,
      'fellowship_meeting_reminder_enabled': fellowshipMeetingReminderEnabled,
      'fellowship_meeting_cancelled_enabled': fellowshipMeetingCancelledEnabled,
      'fellowship_meeting_invite_enabled': fellowshipMeetingInviteEnabled,
      'meeting_invite_enabled': meetingInviteEnabled,
      'fellowship_mentor_promoted_enabled': fellowshipMentorPromotedEnabled,
      'fellowship_member_joined_enabled': fellowshipMemberJoinedEnabled,
      'fellowship_mention_enabled': fellowshipMentionEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NotificationPreferencesModel.fromEntity(
      NotificationPreferences entity) {
    return NotificationPreferencesModel(
      userId: entity.userId,
      dailyVerseEnabled: entity.dailyVerseEnabled,
      recommendedTopicEnabled: entity.recommendedTopicEnabled,
      streakReminderEnabled: entity.streakReminderEnabled,
      streakMilestoneEnabled: entity.streakMilestoneEnabled,
      streakLostEnabled: entity.streakLostEnabled,
      streakReminderTime: entity.streakReminderTime,
      memoryVerseReminderEnabled: entity.memoryVerseReminderEnabled,
      memoryVerseOverdueEnabled: entity.memoryVerseOverdueEnabled,
      memoryVerseReminderTime: entity.memoryVerseReminderTime,
      continueLearningEnabled: entity.continueLearningEnabled,
      achievementUnlockedEnabled: entity.achievementUnlockedEnabled,
      fellowshipDailyPostEnabled: entity.fellowshipDailyPostEnabled,
      fellowshipNewPostEnabled: entity.fellowshipNewPostEnabled,
      fellowshipNewCommentEnabled: entity.fellowshipNewCommentEnabled,
      fellowshipReactionEnabled: entity.fellowshipReactionEnabled,
      fellowshipDisciplerReplyEnabled: entity.fellowshipDisciplerReplyEnabled,
      fellowshipDisciplerActivityEnabled:
          entity.fellowshipDisciplerActivityEnabled,
      fellowshipMeetingEnabled: entity.fellowshipMeetingEnabled,
      fellowshipMeetingReminderEnabled: entity.fellowshipMeetingReminderEnabled,
      fellowshipMeetingCancelledEnabled:
          entity.fellowshipMeetingCancelledEnabled,
      fellowshipMeetingInviteEnabled: entity.fellowshipMeetingInviteEnabled,
      meetingInviteEnabled: entity.meetingInviteEnabled,
      fellowshipMentorPromotedEnabled: entity.fellowshipMentorPromotedEnabled,
      fellowshipMemberJoinedEnabled: entity.fellowshipMemberJoinedEnabled,
      fellowshipMentionEnabled: entity.fellowshipMentionEnabled,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
