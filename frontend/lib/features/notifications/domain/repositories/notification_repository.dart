// ============================================================================
// Notification Repository Interface
// ============================================================================
// Domain layer contract for notification operations

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import '../../../../core/error/failures.dart';
import '../entities/notification_preferences.dart';

abstract class NotificationRepository {
  /// Get user notification preferences
  Future<Either<Failure, NotificationPreferences>> getPreferences();

  /// Update user notification preferences
  Future<Either<Failure, NotificationPreferences>> updatePreferences({
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
    bool? streakReminderEnabled,
    bool? streakMilestoneEnabled,
    bool? streakLostEnabled,
    TimeOfDay? streakReminderTime,
  });

  /// Check if notifications are enabled on device
  Future<Either<Failure, bool>> areNotificationsEnabled();

  /// Request notification permissions
  Future<Either<Failure, bool>> requestPermissions();
}
