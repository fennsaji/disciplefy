import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/theme_mode_entity.dart';

part 'theme_mode_model.g.dart';

@JsonSerializable()
class ThemeModeModel extends ThemeModeEntity {
  const ThemeModeModel({
    required super.mode,
    required super.isSystemMode,
    required super.isDarkMode,
  });

  factory ThemeModeModel.fromJson(Map<String, dynamic> json) =>
      _$ThemeModeModelFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeModeModelToJson(this);

  factory ThemeModeModel.fromEntity(ThemeModeEntity entity) => ThemeModeModel(
        mode: entity.mode,
        isSystemMode: entity.isSystemMode,
        isDarkMode: entity.isDarkMode,
      );

  factory ThemeModeModel.fromString(String themeString) {
    switch (themeString) {
      case 'light':
        return const ThemeModeModel(
          mode: AppThemeMode.light,
          isSystemMode: false,
          isDarkMode: false,
        );
      case 'dark':
        return const ThemeModeModel(
          mode: AppThemeMode.dark,
          isSystemMode: false,
          isDarkMode: true,
        );
      case 'system':
        return const ThemeModeModel(
          mode: AppThemeMode.system,
          isSystemMode: true,
          isDarkMode: false,
        );
      default:
        return const ThemeModeModel(
          mode: AppThemeMode.light,
          isSystemMode: false,
          isDarkMode: false,
        );
    }
  }

  String toStringValue() {
    switch (mode) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }
}
