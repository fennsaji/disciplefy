import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/settings_repository.dart';

class GetAppVersion implements UseCase<String, NoParams> {
  final SettingsRepository repository;

  const GetAppVersion(this.repository);

  @override
  Future<Either<Failure, String>> call(NoParams params) async =>
      await repository.getAppVersion();
}
