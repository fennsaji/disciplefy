import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/theme_mode_entity.dart';
import '../repositories/settings_repository.dart';

class UpdateThemeMode implements UseCase<void, UpdateThemeModeParams> {
  final SettingsRepository repository;

  const UpdateThemeMode(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateThemeModeParams params) async => await repository.updateThemeMode(params.themeMode);
}

class UpdateThemeModeParams extends Equatable {
  final ThemeModeEntity themeMode;

  const UpdateThemeModeParams({required this.themeMode});

  @override
  List<Object?> get props => [themeMode];
}