import 'package:equatable/equatable.dart';
import '../../domain/entities/theme_mode_entity.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class ThemeModeChanged extends SettingsEvent {
  final ThemeModeEntity themeMode;

  const ThemeModeChanged(this.themeMode);

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

/// Fired when the app language changed outside the settings screen
/// (e.g. DB-driven sync at startup) so the settings state stays consistent.
class LanguageChangedExternally extends SettingsEvent {
  final String language;

  const LanguageChangedExternally(this.language);

  @override
  List<Object?> get props => [language];
}

class LoadAppVersion extends SettingsEvent {}

class ClearAllSettings extends SettingsEvent {}
