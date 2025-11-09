// ============================================================================
// Update Notification Preferences Use Case
// ============================================================================

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/notification_preferences.dart';
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
    );
  }
}

class UpdatePreferencesParams extends Equatable {
  final bool? dailyVerseEnabled;
  final bool? recommendedTopicEnabled;
  final bool? streakReminderEnabled;
  final bool? streakMilestoneEnabled;
  final bool? streakLostEnabled;
  final TimeOfDay? streakReminderTime;

  const UpdatePreferencesParams({
    this.dailyVerseEnabled,
    this.recommendedTopicEnabled,
    this.streakReminderEnabled,
    this.streakMilestoneEnabled,
    this.streakLostEnabled,
    this.streakReminderTime,
  });

  @override
  List<Object?> get props => [
        dailyVerseEnabled,
        recommendedTopicEnabled,
        streakReminderEnabled,
        streakMilestoneEnabled,
        streakLostEnabled,
        streakReminderTime,
      ];
}
