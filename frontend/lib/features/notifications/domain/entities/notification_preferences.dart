// ============================================================================
// Notification Preferences Entity
// ============================================================================
// Domain entity representing user notification preferences

import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  final String userId;
  final bool dailyVerseEnabled;
  final bool recommendedTopicEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.userId,
    required this.dailyVerseEnabled,
    required this.recommendedTopicEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  NotificationPreferences copyWith({
    String? userId,
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      dailyVerseEnabled: dailyVerseEnabled ?? this.dailyVerseEnabled,
      recommendedTopicEnabled:
          recommendedTopicEnabled ?? this.recommendedTopicEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        dailyVerseEnabled,
        recommendedTopicEnabled,
        createdAt,
        updatedAt,
      ];
}
