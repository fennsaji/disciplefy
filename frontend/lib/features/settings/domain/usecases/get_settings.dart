import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/app_settings_entity.dart';
import '../repositories/settings_repository.dart';

class GetSettings implements UseCase<AppSettingsEntity, NoParams> {
  final SettingsRepository repository;

  const GetSettings(this.repository);

  @override
  Future<Either<Failure, AppSettingsEntity>> call(NoParams params) async => await repository.getSettings();
}