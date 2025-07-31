import 'package:equatable/equatable.dart';
import 'theme_mode_entity.dart';

class AppSettingsEntity extends Equatable {
  final ThemeModeEntity themeMode;
  final String language;
  final bool notificationsEnabled;
  final String appVersion;

  const AppSettingsEntity({
    required this.themeMode,
    required this.language,
    required this.notificationsEnabled,
    required this.appVersion,
  });

  factory AppSettingsEntity.defaultSettings() => AppSettingsEntity(
      themeMode: ThemeModeEntity.light(),
      language: 'en',
      notificationsEnabled: true,
      appVersion: '', // Will be populated dynamically from PackageInfo
    );

  AppSettingsEntity copyWith({
    ThemeModeEntity? themeMode,
    String? language,
    bool? notificationsEnabled,
    String? appVersion,
  }) => AppSettingsEntity(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      appVersion: appVersion ?? this.appVersion,
    );

  @override
  List<Object?> get props => [
        themeMode,
        language,
        notificationsEnabled,
        appVersion,
      ];
}