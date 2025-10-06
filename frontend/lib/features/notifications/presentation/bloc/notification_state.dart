// ============================================================================
// Notification States
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_preferences.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

/// Loading state
class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

/// Preferences loaded successfully
class NotificationPreferencesLoaded extends NotificationState {
  final NotificationPreferences preferences;
  final bool permissionsGranted;

  const NotificationPreferencesLoaded({
    required this.preferences,
    required this.permissionsGranted,
  });

  @override
  List<Object?> get props => [preferences, permissionsGranted];
}

/// Preferences updated successfully
class NotificationPreferencesUpdated extends NotificationState {
  final NotificationPreferences preferences;

  const NotificationPreferencesUpdated({required this.preferences});

  @override
  List<Object?> get props => [preferences];
}

/// Permission request result
class NotificationPermissionResult extends NotificationState {
  final bool granted;

  const NotificationPermissionResult({required this.granted});

  @override
  List<Object?> get props => [granted];
}

/// Error state
class NotificationError extends NotificationState {
  final String message;

  const NotificationError({required this.message});

  @override
  List<Object?> get props => [message];
}
