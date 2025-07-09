import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_settings_entity.dart';
import '../entities/theme_mode_entity.dart';

abstract class SettingsRepository {
  Future<Either<Failure, AppSettingsEntity>> getSettings();
  Future<Either<Failure, void>> saveSettings(AppSettingsEntity settings);
  Future<Either<Failure, void>> updateThemeMode(ThemeModeEntity themeMode);
  Future<Either<Failure, void>> updateLanguage(String language);
  Future<Either<Failure, String>> getAppVersion();
  Future<Either<Failure, void>> clearAllSettings();
}