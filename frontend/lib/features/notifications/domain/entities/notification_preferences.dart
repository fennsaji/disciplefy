// ============================================================================
// Notification Preferences Entity
// ============================================================================
// Domain entity representing user notification preferences

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class NotificationPreferences extends Equatable {
  final String userId;
  final bool dailyVerseEnabled;
  final bool recommendedTopicEnabled;

  // Streak notification preferences
  final bool streakReminderEnabled;
  final bool streakMilestoneEnabled;
  final bool streakLostEnabled;
  final TimeOfDay streakReminderTime;

  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.userId,
    required this.dailyVerseEnabled,
    required this.recommendedTopicEnabled,
    required this.streakReminderEnabled,
    required this.streakMilestoneEnabled,
    required this.streakLostEnabled,
    required this.streakReminderTime,
    required this.createdAt,
    required this.updatedAt,
  });

  NotificationPreferences copyWith({
    String? userId,
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
    bool? streakReminderEnabled,
    bool? streakMilestoneEnabled,
    bool? streakLostEnabled,
    TimeOfDay? streakReminderTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      dailyVerseEnabled: dailyVerseEnabled ?? this.dailyVerseEnabled,
      recommendedTopicEnabled:
          recommendedTopicEnabled ?? this.recommendedTopicEnabled,
      streakReminderEnabled:
          streakReminderEnabled ?? this.streakReminderEnabled,
      streakMilestoneEnabled:
          streakMilestoneEnabled ?? this.streakMilestoneEnabled,
      streakLostEnabled: streakLostEnabled ?? this.streakLostEnabled,
      streakReminderTime: streakReminderTime ?? this.streakReminderTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        dailyVerseEnabled,
        recommendedTopicEnabled,
        streakReminderEnabled,
        streakMilestoneEnabled,
        streakLostEnabled,
        streakReminderTime,
        createdAt,
        updatedAt,
      ];
}
