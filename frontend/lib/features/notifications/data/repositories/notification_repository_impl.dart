// ============================================================================
// Notification Repository Implementation
// ============================================================================

import 'package:dartz/dartz.dart';
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
      final response = await supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.get,
      );

      if (response.status == 200 && response.data != null) {
        final preferences =
            response.data['preferences'] as Map<String, dynamic>?;

        if (preferences != null) {
          final model = NotificationPreferencesModel.fromJson(preferences);
          return Right(model);
        }

        // Return default preferences if none exist
        return Right(NotificationPreferencesModel(
          userId: supabaseClient.auth.currentUser?.id ?? '',
          dailyVerseEnabled: true,
          recommendedTopicEnabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      return Left(
          ServerFailure(message: 'Failed to fetch notification preferences'));
    } on AuthException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, NotificationPreferences>> updatePreferences({
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
  }) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.put,
        body: {
          if (dailyVerseEnabled != null) 'dailyVerseEnabled': dailyVerseEnabled,
          if (recommendedTopicEnabled != null)
            'recommendedTopicEnabled': recommendedTopicEnabled,
        },
      );

      if (response.status == 200 && response.data != null) {
        final preferences =
            response.data['preferences'] as Map<String, dynamic>?;

        if (preferences != null) {
          final model = NotificationPreferencesModel.fromJson(preferences);
          return Right(model);
        }
      }

      return Left(
          ServerFailure(message: 'Failed to update notification preferences'));
    } on AuthException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } catch (e) {
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
