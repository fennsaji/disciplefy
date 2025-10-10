// ============================================================================
// Notification Preferences Model
// ============================================================================
// Data layer model for notification preferences

import '../../domain/entities/notification_preferences.dart';

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.userId,
    required super.dailyVerseEnabled,
    required super.recommendedTopicEnabled,
    required super.createdAt,
    required super.updatedAt,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      userId: json['user_id'] as String? ?? json['userId'] as String,
      dailyVerseEnabled: json['daily_verse_enabled'] as bool? ??
          json['dailyVerseEnabled'] as bool? ??
          true,
      recommendedTopicEnabled: json['recommended_topic_enabled'] as bool? ??
          json['recommendedTopicEnabled'] as bool? ??
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
    return {
      'user_id': userId,
      'daily_verse_enabled': dailyVerseEnabled,
      'recommended_topic_enabled': recommendedTopicEnabled,
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
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
