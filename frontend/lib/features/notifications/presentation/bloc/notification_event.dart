// ============================================================================
// Notification Events
// ============================================================================

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Load notification preferences from backend
class LoadNotificationPreferences extends NotificationEvent {
  const LoadNotificationPreferences();
}

/// Update notification preferences
class UpdateNotificationPreferences extends NotificationEvent {
  final bool? dailyVerseEnabled;
  final bool? recommendedTopicEnabled;
  final bool? streakReminderEnabled;
  final bool? streakMilestoneEnabled;
  final bool? streakLostEnabled;
  final TimeOfDay? streakReminderTime;
  final bool? memoryVerseReminderEnabled;
  final TimeOfDay? memoryVerseReminderTime;
  final bool? memoryVerseOverdueEnabled;

  const UpdateNotificationPreferences({
    this.dailyVerseEnabled,
    this.recommendedTopicEnabled,
    this.streakReminderEnabled,
    this.streakMilestoneEnabled,
    this.streakLostEnabled,
    this.streakReminderTime,
    this.memoryVerseReminderEnabled,
    this.memoryVerseReminderTime,
    this.memoryVerseOverdueEnabled,
  });

  @override
  List<Object?> get props => [
        dailyVerseEnabled,
        recommendedTopicEnabled,
        streakReminderEnabled,
        streakMilestoneEnabled,
        streakLostEnabled,
        streakReminderTime,
        memoryVerseReminderEnabled,
        memoryVerseReminderTime,
        memoryVerseOverdueEnabled,
      ];
}

/// Request notification permissions from OS
class RequestNotificationPermissions extends NotificationEvent {
  const RequestNotificationPermissions();
}

/// Check notification permission status
class CheckNotificationPermissions extends NotificationEvent {
  const CheckNotificationPermissions();
}
