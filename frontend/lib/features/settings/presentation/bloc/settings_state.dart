import 'package:equatable/equatable.dart';
import '../../domain/entities/app_settings_entity.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final AppSettingsEntity settings;

  const SettingsLoaded({required this.settings});

  @override
  List<Object?> get props => [settings];
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError({required this.message});

  @override
  List<Object?> get props => [message];
}

class SettingsUpdateSuccess extends SettingsState {
  final String message;

  const SettingsUpdateSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class LogoutSuccess extends SettingsState {}

class LogoutError extends SettingsState {
  final String message;

  const LogoutError({required this.message});

  @override
  List<Object?> get props => [message];
}