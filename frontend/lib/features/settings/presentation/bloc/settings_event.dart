import 'package:equatable/equatable.dart';
import '../../domain/entities/theme_mode_entity.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class UpdateThemeMode extends SettingsEvent {
  final ThemeModeEntity themeMode;

  const UpdateThemeMode(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class UpdateLanguage extends SettingsEvent {
  final String language;

  const UpdateLanguage(this.language);

  @override
  List<Object?> get props => [language];
}

class ToggleNotifications extends SettingsEvent {
  final bool enabled;

  const ToggleNotifications(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class LoadAppVersion extends SettingsEvent {}

class ClearAllSettings extends SettingsEvent {}

class LogoutUser extends SettingsEvent {}