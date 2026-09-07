// ============================================================================
// Update Notification Preferences Use Case
// ============================================================================

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/notification_preferences.dart';
import '../entities/time_of_day_vo.dart';
import '../repositories/notification_repository.dart';

class UpdateNotificationPreferences
    implements UseCase<NotificationPreferences, UpdatePreferencesParams> {
  final NotificationRepository repository;

  UpdateNotificationPreferences(this.repository);

  @override
  Future<Either<Failure, NotificationPreferences>> call(
      UpdatePreferencesParams params) async {
    return await repository.updatePreferences(
      dailyVerseEnabled: params.dailyVerseEnabled,
      recommendedTopicEnabled: params.recommendedTopicEnabled,
      streakReminderEnabled: params.streakReminderEnabled,
      streakMilestoneEnabled: params.streakMilestoneEnabled,
      streakLostEnabled: params.streakLostEnabled,
      streakReminderTime: params.streakReminderTime,
      memoryVerseReminderEnabled: params.memoryVerseReminderEnabled,
      memoryVerseOverdueEnabled: params.memoryVerseOverdueEnabled,
      memoryVerseReminderTime: params.memoryVerseReminderTime,
      continueLearningEnabled: params.continueLearningEnabled,
      achievementUnlockedEnabled: params.achievementUnlockedEnabled,
      fellowshipDailyPostEnabled: params.fellowshipDailyPostEnabled,
      fellowshipNewPostEnabled: params.fellowshipNewPostEnabled,
      fellowshipNewCommentEnabled: params.fellowshipNewCommentEnabled,
      fellowshipReactionEnabled: params.fellowshipReactionEnabled,
      fellowshipDisciplerReplyEnabled: params.fellowshipDisciplerReplyEnabled,
      fellowshipDisciplerActivityEnabled:
          params.fellowshipDisciplerActivityEnabled,
      fellowshipMeetingEnabled: params.fellowshipMeetingEnabled,
      fellowshipMeetingReminderEnabled: params.fellowshipMeetingReminderEnabled,
      fellowshipMeetingCancelledEnabled:
          params.fellowshipMeetingCancelledEnabled,
      fellowshipMeetingInviteEnabled: params.fellowshipMeetingInviteEnabled,
      meetingInviteEnabled: params.meetingInviteEnabled,
    );
  }
}

class UpdatePreferencesParams extends Equatable {
  final bool? dailyVerseEnabled;
  final bool? recommendedTopicEnabled;
  final bool? streakReminderEnabled;
  final bool? streakMilestoneEnabled;
  final bool? streakLostEnabled;
  final TimeOfDayVO? streakReminderTime;
  final bool? memoryVerseReminderEnabled;
  final bool? memoryVerseOverdueEnabled;
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
  final TimeOfDayVO? memoryVerseReminderTime;

  const UpdatePreferencesParams({
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
      ];
}
