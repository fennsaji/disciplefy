// ============================================================================
// Notification Preferences Entity
// ============================================================================
// Domain entity representing user notification preferences

import 'package:equatable/equatable.dart';
import 'time_of_day_vo.dart';

class NotificationPreferences extends Equatable {
  final String userId;
  final bool dailyVerseEnabled;
  final bool recommendedTopicEnabled;

  // Streak notification preferences
  final bool streakReminderEnabled;
  final bool streakMilestoneEnabled;
  final bool streakLostEnabled;
  final TimeOfDayVO streakReminderTime;

  // Memory verse notification preferences
  final bool memoryVerseReminderEnabled;
  final bool memoryVerseOverdueEnabled;
  final TimeOfDayVO memoryVerseReminderTime;

  // Study, fellowship and meeting notification preferences. Every push type
  // in notification_logs has a switch here; defaults are on so adding them
  // changed nothing about what an existing user receives.
  final bool continueLearningEnabled;
  final bool achievementUnlockedEnabled;
  final bool fellowshipDailyPostEnabled;
  final bool fellowshipNewPostEnabled;
  final bool fellowshipNewCommentEnabled;
  final bool fellowshipReactionEnabled;
  final bool fellowshipDisciplerReplyEnabled;
  final bool fellowshipDisciplerActivityEnabled;
  final bool fellowshipMeetingEnabled;
  final bool fellowshipMeetingReminderEnabled;
  final bool fellowshipMeetingCancelledEnabled;
  final bool fellowshipMeetingInviteEnabled;
  final bool meetingInviteEnabled;
  final bool fellowshipMentorPromotedEnabled;

  /// Someone joined a fellowship this user mentors.
  final bool fellowshipMemberJoinedEnabled;

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
    required this.memoryVerseReminderEnabled,
    required this.memoryVerseOverdueEnabled,
    required this.memoryVerseReminderTime,
    this.continueLearningEnabled = true,
    this.achievementUnlockedEnabled = true,
    this.fellowshipDailyPostEnabled = true,
    this.fellowshipNewPostEnabled = true,
    this.fellowshipNewCommentEnabled = true,
    this.fellowshipReactionEnabled = true,
    this.fellowshipDisciplerReplyEnabled = true,
    this.fellowshipDisciplerActivityEnabled = true,
    this.fellowshipMeetingEnabled = true,
    this.fellowshipMeetingReminderEnabled = true,
    this.fellowshipMeetingCancelledEnabled = true,
    this.fellowshipMeetingInviteEnabled = true,
    this.meetingInviteEnabled = true,
    this.fellowshipMentorPromotedEnabled = true,
    this.fellowshipMemberJoinedEnabled = true,
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
    bool? fellowshipMentorPromotedEnabled,
    bool? fellowshipMemberJoinedEnabled,
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
      memoryVerseReminderEnabled:
          memoryVerseReminderEnabled ?? this.memoryVerseReminderEnabled,
      memoryVerseOverdueEnabled:
          memoryVerseOverdueEnabled ?? this.memoryVerseOverdueEnabled,
      memoryVerseReminderTime:
          memoryVerseReminderTime ?? this.memoryVerseReminderTime,
      continueLearningEnabled:
          continueLearningEnabled ?? this.continueLearningEnabled,
      achievementUnlockedEnabled:
          achievementUnlockedEnabled ?? this.achievementUnlockedEnabled,
      fellowshipDailyPostEnabled:
          fellowshipDailyPostEnabled ?? this.fellowshipDailyPostEnabled,
      fellowshipNewPostEnabled:
          fellowshipNewPostEnabled ?? this.fellowshipNewPostEnabled,
      fellowshipNewCommentEnabled:
          fellowshipNewCommentEnabled ?? this.fellowshipNewCommentEnabled,
      fellowshipReactionEnabled:
          fellowshipReactionEnabled ?? this.fellowshipReactionEnabled,
      fellowshipDisciplerReplyEnabled: fellowshipDisciplerReplyEnabled ??
          this.fellowshipDisciplerReplyEnabled,
      fellowshipDisciplerActivityEnabled: fellowshipDisciplerActivityEnabled ??
          this.fellowshipDisciplerActivityEnabled,
      fellowshipMeetingEnabled:
          fellowshipMeetingEnabled ?? this.fellowshipMeetingEnabled,
      fellowshipMeetingReminderEnabled: fellowshipMeetingReminderEnabled ??
          this.fellowshipMeetingReminderEnabled,
      fellowshipMeetingCancelledEnabled: fellowshipMeetingCancelledEnabled ??
          this.fellowshipMeetingCancelledEnabled,
      fellowshipMeetingInviteEnabled:
          fellowshipMeetingInviteEnabled ?? this.fellowshipMeetingInviteEnabled,
      meetingInviteEnabled: meetingInviteEnabled ?? this.meetingInviteEnabled,
      fellowshipMentorPromotedEnabled: fellowshipMentorPromotedEnabled ??
          this.fellowshipMentorPromotedEnabled,
      fellowshipMemberJoinedEnabled:
          fellowshipMemberJoinedEnabled ?? this.fellowshipMemberJoinedEnabled,
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
        memoryVerseReminderEnabled,
        memoryVerseOverdueEnabled,
        memoryVerseReminderTime,
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
        fellowshipMentorPromotedEnabled,
        createdAt,
        updatedAt,
      ];
}
