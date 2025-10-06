// ============================================================================
// Notification Events
// ============================================================================

import 'package:equatable/equatable.dart';

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

  const UpdateNotificationPreferences({
    this.dailyVerseEnabled,
    this.recommendedTopicEnabled,
  });

  @override
  List<Object?> get props => [dailyVerseEnabled, recommendedTopicEnabled];
}

/// Request notification permissions from OS
class RequestNotificationPermissions extends NotificationEvent {
  const RequestNotificationPermissions();
}

/// Check notification permission status
class CheckNotificationPermissions extends NotificationEvent {
  const CheckNotificationPermissions();
}
