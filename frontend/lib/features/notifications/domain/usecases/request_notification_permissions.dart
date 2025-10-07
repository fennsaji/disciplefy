// ============================================================================
// Request Notification Permissions Use Case
// ============================================================================

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/notification_repository.dart';

class RequestNotificationPermissions implements UseCase<bool, NoParams> {
  final NotificationRepository repository;

  RequestNotificationPermissions(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    return await repository.requestPermissions();
  }
}
