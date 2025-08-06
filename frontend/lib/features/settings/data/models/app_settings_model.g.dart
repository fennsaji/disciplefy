// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettingsModel _$AppSettingsModelFromJson(Map<String, dynamic> json) =>
    AppSettingsModel(
      themeMode:
          ThemeModeModel.fromJson(json['themeMode'] as Map<String, dynamic>),
      language: json['language'] as String,
      notificationsEnabled: json['notificationsEnabled'] as bool,
      appVersion: json['appVersion'] as String,
    );

Map<String, dynamic> _$AppSettingsModelToJson(AppSettingsModel instance) =>
    <String, dynamic>{
      'language': instance.language,
      'notificationsEnabled': instance.notificationsEnabled,
      'appVersion': instance.appVersion,
      'themeMode': AppSettingsModel._themeModeToJson(instance.themeMode),
    };
