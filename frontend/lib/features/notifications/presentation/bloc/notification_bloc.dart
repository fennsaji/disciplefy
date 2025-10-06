// ============================================================================
// Notification BLoC
// ============================================================================

import 'package:bloc/bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_notification_preferences.dart';
import '../../domain/usecases/request_notification_permissions.dart'
    as request_usecases;
import '../../domain/usecases/update_notification_preferences.dart'
    as update_usecases;
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationPreferences getPreferences;
  final update_usecases.UpdateNotificationPreferences updatePreferences;
  final request_usecases.RequestNotificationPermissions requestPermissions;

  NotificationBloc({
    required this.getPreferences,
    required this.updatePreferences,
    required this.requestPermissions,
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
    emit(const NotificationLoading());

    final result = await getPreferences(NoParams());

    result.fold(
      (failure) => emit(NotificationError(message: failure.message)),
      (preferences) => emit(NotificationPreferencesLoaded(
        preferences: preferences,
        permissionsGranted: true, // Will be checked separately
      )),
    );
  }

  Future<void> _onUpdatePreferences(
    UpdateNotificationPreferences event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());

    final result = await updatePreferences(
      update_usecases.UpdatePreferencesParams(
        dailyVerseEnabled: event.dailyVerseEnabled,
        recommendedTopicEnabled: event.recommendedTopicEnabled,
      ),
    );

    result.fold(
      (failure) => emit(NotificationError(message: failure.message)),
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
      (failure) => emit(NotificationError(message: failure.message)),
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
      (failure) => emit(NotificationError(message: failure.message)),
      (granted) => emit(NotificationPermissionResult(granted: granted)),
    );
  }
}
