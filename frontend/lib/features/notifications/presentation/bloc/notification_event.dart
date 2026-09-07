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
  final bool? memoryVerseOverdueEnabled;
  final TimeOfDay? memoryVerseReminderTime;
  final bool? continueLearningEnabled;
  final bool? achievementUnlockedEnabled;
  final bool? fellowshipDailyPostEnabled;
  final bool? fellowshipNewPostEnabled;
  final bool? fellowshipNewCommentEnabled;
  final bool? fellowshipReactionEnabled;
  final bool? fellowshipDisciplerReplyEnabled;
  final bool? fellowshipDisciplerActivityEnabled;
  final bool? fellowshipMeetingEnabled;
  final bool? fellowshipMeetingReminderEnabled;
  final bool? fellowshipMeetingCancelledEnabled;
  final bool? fellowshipMeetingInviteEnabled;
  final bool? meetingInviteEnabled;

  const UpdateNotificationPreferences({
    this.dailyVerseEnabled,
    this.recommendedTopicEnabled,
    this.streakReminderEnabled,
    this.streakMilestoneEnabled,
    this.streakLostEnabled,
    this.streakReminderTime,
    this.memoryVerseReminderEnabled,
    this.memoryVerseOverdueEnabled,
    this.memoryVerseReminderTime,
    this.continueLearningEnabled,
    this.achievementUnlockedEnabled,
    this.fellowshipDailyPostEnabled,
    this.fellowshipNewPostEnabled,
    this.fellowshipNewCommentEnabled,
    this.fellowshipReactionEnabled,
    this.fellowshipDisciplerReplyEnabled,
    this.fellowshipDisciplerActivityEnabled,
    this.fellowshipMeetingEnabled,
    this.fellowshipMeetingReminderEnabled,
    this.fellowshipMeetingCancelledEnabled,
    this.fellowshipMeetingInviteEnabled,
    this.meetingInviteEnabled,
  });

  @override
  List<Object?> get props => [
        continueLearningEnabled,
        achievementUnlockedEnabled,
        fellowshipDailyPostEnabled,
        fellowshipNewPostEnabled,
        fellowshipNewCommentEnabled,
        fellowshipReactionEnabled,
        fellowshipDisciplerReplyEnabled,
        fellowshipDisciplerActivityEnabled,
        fellowshipMeetingEnabled,
        fellowshipMeetingReminderEnabled,
        fellowshipMeetingCancelledEnabled,
        fellowshipMeetingInviteEnabled,
        meetingInviteEnabled,
        dailyVerseEnabled,
        recommendedTopicEnabled,
        streakReminderEnabled,
        streakMilestoneEnabled,
        streakLostEnabled,
        streakReminderTime,
        memoryVerseReminderEnabled,
        memoryVerseOverdueEnabled,
        memoryVerseReminderTime,
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
