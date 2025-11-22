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
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
