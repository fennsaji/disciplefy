// ============================================================================
// Get Notification Preferences Use Case
// ============================================================================

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/notification_preferences.dart';
import '../repositories/notification_repository.dart';

class GetNotificationPreferences
    implements UseCase<NotificationPreferences, NoParams> {
  final NotificationRepository repository;

  GetNotificationPreferences(this.repository);

  @override
  Future<Either<Failure, NotificationPreferences>> call(NoParams params) async {
    return await repository.getPreferences();
  }
}
