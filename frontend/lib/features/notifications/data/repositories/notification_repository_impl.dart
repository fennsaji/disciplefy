// ============================================================================
// Notification Repository Implementation
// ============================================================================

import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/time_of_day_vo.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_preferences_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseClient supabaseClient;
  final NotificationService notificationService;

  NotificationRepositoryImpl({
    required this.supabaseClient,
    required this.notificationService,
  });

  @override
  Future<Either<Failure, NotificationPreferences>> getPreferences() async {
    try {
      // Check if user is authenticated
      final currentUser = supabaseClient.auth.currentUser;

      // For anonymous users, load preferences from SharedPreferences
      if (currentUser == null || currentUser.isAnonymous) {
        final prefs = await SharedPreferences.getInstance();
        final dailyVerseEnabled =
            prefs.getBool('notification_pref_daily_verse_enabled') ?? true;
        final recommendedTopicEnabled =
            prefs.getBool('notification_pref_recommended_topic_enabled') ??
                true;
        final streakReminderEnabled =
            prefs.getBool('notification_pref_streak_reminder_enabled') ?? true;
        final streakMilestoneEnabled =
            prefs.getBool('notification_pref_streak_milestone_enabled') ?? true;
        final streakLostEnabled =
            prefs.getBool('notification_pref_streak_lost_enabled') ?? true;
        final reminderHour =
            prefs.getInt('notification_pref_streak_reminder_hour') ?? 20;
        final reminderMinute =
            prefs.getInt('notification_pref_streak_reminder_minute') ?? 0;
        final memoryVerseReminderEnabled =
            prefs.getBool('notification_pref_memory_verse_reminder_enabled') ??
                true;
        final memoryVerseReminderHour =
            prefs.getInt('notification_pref_memory_verse_reminder_hour') ?? 9;
        final memoryVerseReminderMinute =
            prefs.getInt('notification_pref_memory_verse_reminder_minute') ?? 0;
        final memoryVerseOverdueEnabled =
            prefs.getBool('notification_pref_memory_verse_overdue_enabled') ??
                true;

        return Right(NotificationPreferencesModel(
          userId: currentUser?.id ?? '',
          dailyVerseEnabled: dailyVerseEnabled,
          recommendedTopicEnabled: recommendedTopicEnabled,
          streakReminderEnabled: streakReminderEnabled,
          streakMilestoneEnabled: streakMilestoneEnabled,
          streakLostEnabled: streakLostEnabled,
          streakReminderTime:
              TimeOfDayVO(hour: reminderHour, minute: reminderMinute),
          memoryVerseReminderEnabled: memoryVerseReminderEnabled,
          memoryVerseReminderTime: TimeOfDayVO(
              hour: memoryVerseReminderHour, minute: memoryVerseReminderMinute),
          memoryVerseOverdueEnabled: memoryVerseOverdueEnabled,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      final response = await supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.get,
      );

      if (response.status == 200 && response.data != null) {
        // Check if backend returns preferences directly (not wrapped in 'data')
        final preferencesData =
            response.data['preferences'] as Map<String, dynamic>?;

        if (preferencesData != null) {
          // Add userId to preferences data for model
          final preferencesWithUser = {
            ...preferencesData,
            'userId': currentUser.id,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };

          final model =
              NotificationPreferencesModel.fromJson(preferencesWithUser);
          return Right(model);
        }

        // Fallback: Try old structure with 'data' wrapper
        final dataWrapper = response.data['data'] as Map<String, dynamic>?;
        if (dataWrapper != null) {
          final preferences =
              dataWrapper['preferences'] as Map<String, dynamic>?;
          if (preferences != null) {
            final model = NotificationPreferencesModel.fromJson(preferences);
            return Right(model);
          }
        }

        // Return default preferences if data structure is unexpected
        return Right(NotificationPreferencesModel(
          userId: currentUser.id,
          dailyVerseEnabled: true,
          recommendedTopicEnabled: true,
          streakReminderEnabled: true,
          streakMilestoneEnabled: true,
          streakLostEnabled: true,
          streakReminderTime: const TimeOfDayVO(hour: 20, minute: 0),
          memoryVerseReminderEnabled: true,
          memoryVerseReminderTime: const TimeOfDayVO(hour: 9, minute: 0),
          memoryVerseOverdueEnabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // For any other status code, return default preferences instead of failure
      // This ensures the UI doesn't get stuck loading
      return Right(NotificationPreferencesModel(
        userId: currentUser.id,
        dailyVerseEnabled: true,
        recommendedTopicEnabled: true,
        streakReminderEnabled: true,
        streakMilestoneEnabled: true,
        streakLostEnabled: true,
        streakReminderTime: const TimeOfDayVO(hour: 20, minute: 0),
        memoryVerseReminderEnabled: true,
        memoryVerseReminderTime: const TimeOfDayVO(hour: 9, minute: 0),
        memoryVerseOverdueEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    } on AuthException {
      // Even on auth errors, return default preferences to prevent UI blocking
      return Right(NotificationPreferencesModel(
        userId: supabaseClient.auth.currentUser?.id ?? '',
        dailyVerseEnabled: true,
        recommendedTopicEnabled: true,
        streakReminderEnabled: true,
        streakMilestoneEnabled: true,
        streakLostEnabled: true,
        streakReminderTime: const TimeOfDayVO(hour: 20, minute: 0),
        memoryVerseReminderEnabled: true,
        memoryVerseReminderTime: const TimeOfDayVO(hour: 9, minute: 0),
        memoryVerseOverdueEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    } catch (e) {
      // On any error, return default preferences instead of failure
      // This ensures the notification settings screen always loads
      return Right(NotificationPreferencesModel(
        userId: supabaseClient.auth.currentUser?.id ?? '',
        dailyVerseEnabled: true,
        recommendedTopicEnabled: true,
        streakReminderEnabled: true,
        streakMilestoneEnabled: true,
        streakLostEnabled: true,
        streakReminderTime: const TimeOfDayVO(hour: 20, minute: 0),
        memoryVerseReminderEnabled: true,
        memoryVerseReminderTime: const TimeOfDayVO(hour: 9, minute: 0),
        memoryVerseOverdueEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<Either<Failure, NotificationPreferences>> updatePreferences({
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
    bool? streakReminderEnabled,
    bool? streakMilestoneEnabled,
    bool? streakLostEnabled,
    TimeOfDayVO? streakReminderTime,
    bool? memoryVerseReminderEnabled,
    TimeOfDayVO? memoryVerseReminderTime,
    bool? memoryVerseOverdueEnabled,
  }) async {
    try {
      // Check if user is authenticated
      final currentUser = supabaseClient.auth.currentUser;

      // For anonymous users, save preferences to SharedPreferences
      if (currentUser == null || currentUser.isAnonymous) {
        final prefs = await SharedPreferences.getInstance();

        // Load current preferences
        final currentDailyVerse =
            prefs.getBool('notification_pref_daily_verse_enabled') ?? true;
        final currentRecommendedTopic =
            prefs.getBool('notification_pref_recommended_topic_enabled') ??
                true;
        final currentStreakReminder =
            prefs.getBool('notification_pref_streak_reminder_enabled') ?? true;
        final currentStreakMilestone =
            prefs.getBool('notification_pref_streak_milestone_enabled') ?? true;
        final currentStreakLost =
            prefs.getBool('notification_pref_streak_lost_enabled') ?? true;
        final currentReminderHour =
            prefs.getInt('notification_pref_streak_reminder_hour') ?? 20;
        final currentReminderMinute =
            prefs.getInt('notification_pref_streak_reminder_minute') ?? 0;
        final currentMemoryVerseReminder =
            prefs.getBool('notification_pref_memory_verse_reminder_enabled') ??
                true;
        final currentMemoryVerseReminderHour =
            prefs.getInt('notification_pref_memory_verse_reminder_hour') ?? 9;
        final currentMemoryVerseReminderMinute =
            prefs.getInt('notification_pref_memory_verse_reminder_minute') ?? 0;
        final currentMemoryVerseOverdue =
            prefs.getBool('notification_pref_memory_verse_overdue_enabled') ??
                true;

        // Update preferences
        final newDailyVerse = dailyVerseEnabled ?? currentDailyVerse;
        final newRecommendedTopic =
            recommendedTopicEnabled ?? currentRecommendedTopic;
        final newStreakReminder =
            streakReminderEnabled ?? currentStreakReminder;
        final newStreakMilestone =
            streakMilestoneEnabled ?? currentStreakMilestone;
        final newStreakLost = streakLostEnabled ?? currentStreakLost;
        final newReminderTime = streakReminderTime ??
            TimeOfDayVO(
                hour: currentReminderHour, minute: currentReminderMinute);
        final newMemoryVerseReminder =
            memoryVerseReminderEnabled ?? currentMemoryVerseReminder;
        final newMemoryVerseReminderTime = memoryVerseReminderTime ??
            TimeOfDayVO(
                hour: currentMemoryVerseReminderHour,
                minute: currentMemoryVerseReminderMinute);
        final newMemoryVerseOverdue =
            memoryVerseOverdueEnabled ?? currentMemoryVerseOverdue;

        await prefs.setBool(
            'notification_pref_daily_verse_enabled', newDailyVerse);
        await prefs.setBool(
            'notification_pref_recommended_topic_enabled', newRecommendedTopic);
        await prefs.setBool(
            'notification_pref_streak_reminder_enabled', newStreakReminder);
        await prefs.setBool(
            'notification_pref_streak_milestone_enabled', newStreakMilestone);
        await prefs.setBool(
            'notification_pref_streak_lost_enabled', newStreakLost);
        await prefs.setInt(
            'notification_pref_streak_reminder_hour', newReminderTime.hour);
        await prefs.setInt(
            'notification_pref_streak_reminder_minute', newReminderTime.minute);
        await prefs.setBool('notification_pref_memory_verse_reminder_enabled',
            newMemoryVerseReminder);
        await prefs.setInt('notification_pref_memory_verse_reminder_hour',
            newMemoryVerseReminderTime.hour);
        await prefs.setInt('notification_pref_memory_verse_reminder_minute',
            newMemoryVerseReminderTime.minute);
        await prefs.setBool('notification_pref_memory_verse_overdue_enabled',
            newMemoryVerseOverdue);

        // Return updated preferences
        return Right(NotificationPreferencesModel(
          userId: currentUser?.id ?? '',
          dailyVerseEnabled: newDailyVerse,
          recommendedTopicEnabled: newRecommendedTopic,
          streakReminderEnabled: newStreakReminder,
          streakMilestoneEnabled: newStreakMilestone,
          streakLostEnabled: newStreakLost,
          streakReminderTime: newReminderTime,
          memoryVerseReminderEnabled: newMemoryVerseReminder,
          memoryVerseReminderTime: newMemoryVerseReminderTime,
          memoryVerseOverdueEnabled: newMemoryVerseOverdue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // For authenticated users, call backend API
      print('[NotificationRepo] Calling backend to update preferences...');
      print('[NotificationRepo] dailyVerseEnabled: $dailyVerseEnabled');
      print(
          '[NotificationRepo] recommendedTopicEnabled: $recommendedTopicEnabled');
      print('[NotificationRepo] streakReminderEnabled: $streakReminderEnabled');
      print(
          '[NotificationRepo] streakMilestoneEnabled: $streakMilestoneEnabled');
      print('[NotificationRepo] streakLostEnabled: $streakLostEnabled');
      print('[NotificationRepo] streakReminderTime: $streakReminderTime');
      print(
          '[NotificationRepo] memoryVerseReminderEnabled: $memoryVerseReminderEnabled');
      print(
          '[NotificationRepo] memoryVerseReminderTime: $memoryVerseReminderTime');
      print(
          '[NotificationRepo] memoryVerseOverdueEnabled: $memoryVerseOverdueEnabled');

      // Format TimeOfDayVO to TIME format for backend
      String? formattedStreakTime;
      if (streakReminderTime != null) {
        formattedStreakTime =
            '${streakReminderTime.hour.toString().padLeft(2, '0')}:'
            '${streakReminderTime.minute.toString().padLeft(2, '0')}:00';
      }

      String? formattedMemoryVerseTime;
      if (memoryVerseReminderTime != null) {
        formattedMemoryVerseTime =
            '${memoryVerseReminderTime.hour.toString().padLeft(2, '0')}:'
            '${memoryVerseReminderTime.minute.toString().padLeft(2, '0')}:00';
      }

      final response = await supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.put,
        body: {
          if (dailyVerseEnabled != null) 'dailyVerseEnabled': dailyVerseEnabled,
          if (recommendedTopicEnabled != null)
            'recommendedTopicEnabled': recommendedTopicEnabled,
          if (streakReminderEnabled != null)
            'streakReminderEnabled': streakReminderEnabled,
          if (streakMilestoneEnabled != null)
            'streakMilestoneEnabled': streakMilestoneEnabled,
          if (streakLostEnabled != null) 'streakLostEnabled': streakLostEnabled,
          if (formattedStreakTime != null)
            'streakReminderTime': formattedStreakTime,
          if (memoryVerseReminderEnabled != null)
            'memoryVerseReminderEnabled': memoryVerseReminderEnabled,
          if (formattedMemoryVerseTime != null)
            'memoryVerseReminderTime': formattedMemoryVerseTime,
          if (memoryVerseOverdueEnabled != null)
            'memoryVerseOverdueEnabled': memoryVerseOverdueEnabled,
        },
      );

      print('[NotificationRepo] Response status: ${response.status}');
      print('[NotificationRepo] Response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        // Check if backend returns preferences directly (not wrapped in 'data')
        final preferencesData =
            response.data['preferences'] as Map<String, dynamic>?;

        if (preferencesData != null) {
          // Add userId to preferences data for model
          final currentUser = supabaseClient.auth.currentUser;
          final preferencesWithUser = {
            ...preferencesData,
            'userId': currentUser?.id ?? '',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };

          final model =
              NotificationPreferencesModel.fromJson(preferencesWithUser);
          print('[NotificationRepo] Successfully updated preferences');
          return Right(model);
        }

        // Fallback: Try old structure with 'data' wrapper
        final dataWrapper = response.data['data'] as Map<String, dynamic>?;
        if (dataWrapper != null) {
          final preferences =
              dataWrapper['preferences'] as Map<String, dynamic>?;
          if (preferences != null) {
            final model = NotificationPreferencesModel.fromJson(preferences);
            print(
                '[NotificationRepo] Successfully updated preferences (legacy structure)');
            return Right(model);
          }
        }
      }

      print(
          '[NotificationRepo] Failed to update - unexpected response structure');
      return Left(
          ServerFailure(message: 'Failed to update notification preferences'));
    } on AuthException catch (e) {
      print('[NotificationRepo] Auth error: ${e.message}');
      return Left(AuthenticationFailure(message: e.message));
    } catch (e) {
      print('[NotificationRepo] Error updating preferences: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> areNotificationsEnabled() async {
    try {
      final enabled = await notificationService.areNotificationsEnabled();
      return Right(enabled);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> requestPermissions() async {
    try {
      final granted = await notificationService.requestPermissions();
      return Right(granted);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
