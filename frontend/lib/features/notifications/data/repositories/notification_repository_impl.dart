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

        return Right(NotificationPreferencesModel(
          userId: currentUser?.id ?? '',
          dailyVerseEnabled: dailyVerseEnabled,
          recommendedTopicEnabled: recommendedTopicEnabled,
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    } on AuthException {
      // Even on auth errors, return default preferences to prevent UI blocking
      return Right(NotificationPreferencesModel(
        userId: supabaseClient.auth.currentUser?.id ?? '',
        dailyVerseEnabled: true,
        recommendedTopicEnabled: true,
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<Either<Failure, NotificationPreferences>> updatePreferences({
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
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

        // Update preferences
        final newDailyVerse = dailyVerseEnabled ?? currentDailyVerse;
        final newRecommendedTopic =
            recommendedTopicEnabled ?? currentRecommendedTopic;

        await prefs.setBool(
            'notification_pref_daily_verse_enabled', newDailyVerse);
        await prefs.setBool(
            'notification_pref_recommended_topic_enabled', newRecommendedTopic);

        // Return updated preferences
        return Right(NotificationPreferencesModel(
          userId: currentUser?.id ?? '',
          dailyVerseEnabled: newDailyVerse,
          recommendedTopicEnabled: newRecommendedTopic,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // For authenticated users, call backend API
      print('[NotificationRepo] Calling backend to update preferences...');
      print('[NotificationRepo] dailyVerseEnabled: $dailyVerseEnabled');
      print(
          '[NotificationRepo] recommendedTopicEnabled: $recommendedTopicEnabled');

      final response = await supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.put,
        body: {
          if (dailyVerseEnabled != null) 'dailyVerseEnabled': dailyVerseEnabled,
          if (recommendedTopicEnabled != null)
            'recommendedTopicEnabled': recommendedTopicEnabled,
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
