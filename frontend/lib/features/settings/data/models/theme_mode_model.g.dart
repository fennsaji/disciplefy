// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeModeModel _$ThemeModeModelFromJson(Map<String, dynamic> json) => ThemeModeModel(
      mode: $enumDecode(_$AppThemeModeEnumMap, json['mode']),
      isSystemMode: json['isSystemMode'] as bool,
      isDarkMode: json['isDarkMode'] as bool,
    );

Map<String, dynamic> _$ThemeModeModelToJson(ThemeModeModel instance) => <String, dynamic>{
      'mode': _$AppThemeModeEnumMap[instance.mode]!,
      'isSystemMode': instance.isSystemMode,
      'isDarkMode': instance.isDarkMode,
    };

const _$AppThemeModeEnumMap = {
  AppThemeMode.light: 'light',
  AppThemeMode.dark: 'dark',
  AppThemeMode.system: 'system',
};
