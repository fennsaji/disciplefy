import 'package:equatable/equatable.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeModeEntity extends Equatable {
  final AppThemeMode mode;
  final bool isSystemMode;
  final bool isDarkMode;

  const ThemeModeEntity({
    required this.mode,
    required this.isSystemMode,
    required this.isDarkMode,
  });

  factory ThemeModeEntity.light() {
    return const ThemeModeEntity(
      mode: AppThemeMode.light,
      isSystemMode: false,
      isDarkMode: false,
    );
  }

  factory ThemeModeEntity.dark() {
    return const ThemeModeEntity(
      mode: AppThemeMode.dark,
      isSystemMode: false,
      isDarkMode: true,
    );
  }

  factory ThemeModeEntity.system({required bool isDarkMode}) {
    return ThemeModeEntity(
      mode: AppThemeMode.system,
      isSystemMode: true,
      isDarkMode: isDarkMode,
    );
  }

  ThemeModeEntity copyWith({
    AppThemeMode? mode,
    bool? isSystemMode,
    bool? isDarkMode,
  }) {
    return ThemeModeEntity(
      mode: mode ?? this.mode,
      isSystemMode: isSystemMode ?? this.isSystemMode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  @override
  List<Object?> get props => [mode, isSystemMode, isDarkMode];
}