// ============================================================================
// Notification BLoC
// ============================================================================

import 'package:bloc/bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/check_notification_permissions.dart'
    as check_permissions_usecase;
import '../../domain/usecases/get_notification_preferences.dart';
import '../../domain/usecases/request_notification_permissions.dart'
    as request_usecases;
import '../../domain/usecases/update_notification_preferences.dart'
    as update_usecases;
import '../utils/time_of_day_extensions.dart';
import 'notification_event.dart';
import 'notification_state.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationPreferences getPreferences;
  final update_usecases.UpdateNotificationPreferences updatePreferences;
  final request_usecases.RequestNotificationPermissions requestPermissions;
  final check_permissions_usecase.CheckNotificationPermissions checkPermissions;

  NotificationBloc({
    required this.getPreferences,
    required this.updatePreferences,
    required this.requestPermissions,
    required this.checkPermissions,
  }) : super(const NotificationInitial()) {
    on<LoadNotificationPreferences>(_onLoadPreferences);
    on<UpdateNotificationPreferences>(_onUpdatePreferences);
    on<RequestNotificationPermissions>(_onRequestPermissions);
    on<CheckNotificationPermissions>(_onCheckPermissions);
  }

  Future<void> _onLoadPreferences(
    LoadNotificationPreferences event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      emit(const NotificationLoading());

      final preferencesResult = await getPreferences(NoParams());
      final permissionResult = await checkPermissions(NoParams());

      // Use fold to extract values and emit state synchronously
      preferencesResult.fold(
        (failure) {
          emit(NotificationError(
              message: ErrorMessageSanitizer.sanitize(failure)));
        },
        (preferences) {
          final permissionsGranted = permissionResult.fold(
            (_) => false,
            (granted) => granted,
          );
          emit(NotificationPreferencesLoaded(
            preferences: preferences,
            permissionsGranted: permissionsGranted,
          ));
        },
      );
    } catch (e) {
      emit(NotificationError(message: 'Failed to load preferences: $e'));
    }
  }

  Future<void> _onUpdatePreferences(
    UpdateNotificationPreferences event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());

    // Convert Flutter TimeOfDay to domain TimeOfDayVO at presentation boundary
    final domainStreakReminderTime = event.streakReminderTime?.toTimeOfDayVO();
    final domainMemoryVerseReminderTime =
        event.memoryVerseReminderTime?.toTimeOfDayVO();

    final result = await updatePreferences(
      update_usecases.UpdatePreferencesParams(
        dailyVerseEnabled: event.dailyVerseEnabled,
        recommendedTopicEnabled: event.recommendedTopicEnabled,
        streakReminderEnabled: event.streakReminderEnabled,
        streakMilestoneEnabled: event.streakMilestoneEnabled,
        streakLostEnabled: event.streakLostEnabled,
        streakReminderTime: domainStreakReminderTime,
        memoryVerseReminderEnabled: event.memoryVerseReminderEnabled,
        memoryVerseOverdueEnabled: event.memoryVerseOverdueEnabled,
        memoryVerseReminderTime: domainMemoryVerseReminderTime,
        continueLearningEnabled: event.continueLearningEnabled,
        achievementUnlockedEnabled: event.achievementUnlockedEnabled,
        fellowshipDailyPostEnabled: event.fellowshipDailyPostEnabled,
        fellowshipNewPostEnabled: event.fellowshipNewPostEnabled,
        fellowshipNewCommentEnabled: event.fellowshipNewCommentEnabled,
        fellowshipReactionEnabled: event.fellowshipReactionEnabled,
        fellowshipDisciplerReplyEnabled: event.fellowshipDisciplerReplyEnabled,
        fellowshipDisciplerActivityEnabled:
            event.fellowshipDisciplerActivityEnabled,
        fellowshipMeetingEnabled: event.fellowshipMeetingEnabled,
        fellowshipMeetingReminderEnabled:
            event.fellowshipMeetingReminderEnabled,
        fellowshipMeetingCancelledEnabled:
            event.fellowshipMeetingCancelledEnabled,
        fellowshipMeetingInviteEnabled: event.fellowshipMeetingInviteEnabled,
        meetingInviteEnabled: event.meetingInviteEnabled,
        fellowshipMentorPromotedEnabled: event.fellowshipMentorPromotedEnabled,
      ),
    );

    result.fold(
      (failure) => emit(
          NotificationError(message: ErrorMessageSanitizer.sanitize(failure))),
      (preferences) => emit(NotificationPreferencesUpdated(
        preferences: preferences,
      )),
    );
  }

  Future<void> _onRequestPermissions(
    RequestNotificationPermissions event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());

    final result = await requestPermissions(NoParams());

    result.fold(
      (failure) => emit(
          NotificationError(message: ErrorMessageSanitizer.sanitize(failure))),
      (granted) => emit(NotificationPermissionResult(granted: granted)),
    );
  }

  Future<void> _onCheckPermissions(
    CheckNotificationPermissions event,
    Emitter<NotificationState> emit,
  ) async {
    // This would check permission status without requesting
    // For now, we'll use the same logic as requesting
    final result = await requestPermissions(NoParams());

    result.fold(
      (failure) => emit(
          NotificationError(message: ErrorMessageSanitizer.sanitize(failure))),
      (granted) => emit(NotificationPermissionResult(granted: granted)),
    );
  }
}
