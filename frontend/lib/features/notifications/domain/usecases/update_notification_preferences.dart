// ============================================================================
// Update Notification Preferences Use Case
// ============================================================================

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
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
    );
  }
}

class UpdatePreferencesParams extends Equatable {
  final bool? dailyVerseEnabled;
  final bool? recommendedTopicEnabled;

  const UpdatePreferencesParams({
    this.dailyVerseEnabled,
    this.recommendedTopicEnabled,
  });

  @override
  List<Object?> get props => [dailyVerseEnabled, recommendedTopicEnabled];
}
