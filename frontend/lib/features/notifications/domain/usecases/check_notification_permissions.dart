// ============================================================================
// Check Notification Permissions Use Case
// ============================================================================
// Checks current OS permission status without requesting

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/notification_repository.dart';

class CheckNotificationPermissions implements UseCase<bool, NoParams> {
  final NotificationRepository repository;

  CheckNotificationPermissions(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    return await repository.areNotificationsEnabled();
  }
}
