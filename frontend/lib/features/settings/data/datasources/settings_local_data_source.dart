import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/error/exceptions.dart';
import '../models/app_settings_model.dart';
import '../models/theme_mode_model.dart';

abstract class SettingsLocalDataSource {
  Future<AppSettingsModel> getSettings();
  Future<void> saveSettings(AppSettingsModel settings);
  Future<void> updateThemeMode(ThemeModeModel themeMode);
  Future<void> updateLanguage(String language);
  Future<String> getAppVersion();
  Future<void> clearAllSettings();
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  static const String _boxName = 'app_settings';
  static const String _themeModeKey = 'settings_theme_mode';
  static const String _languageKey = 'settings_language';
  static const String _notificationsKey = 'settings_notifications_enabled';
  static const String _appVersionKey = 'settings_app_version';

  Box get _box => Hive.box(_boxName);

  @override
  Future<AppSettingsModel> getSettings() async {
    try {
      final themeString =
          _box.get(_themeModeKey, defaultValue: 'system') as String;
      final language = _box.get(_languageKey, defaultValue: 'en') as String;
      final notificationsEnabled =
          _box.get(_notificationsKey, defaultValue: true) as bool;
      final appVersion = await getAppVersion();

      return AppSettingsModel(
        themeMode: ThemeModeModel.fromString(themeString),
        language: language,
        notificationsEnabled: notificationsEnabled,
        appVersion: appVersion,
      );
    } catch (e) {
      throw CacheException(message: 'Failed to get settings: $e');
    }
  }

  @override
  Future<void> saveSettings(AppSettingsModel settings) async {
    try {
      final themeModel = ThemeModeModel.fromEntity(settings.themeMode);
      await _box.put(_themeModeKey, themeModel.toStringValue());
      await _box.put(_languageKey, settings.language);
      await _box.put(_notificationsKey, settings.notificationsEnabled);
      await _box.put(_appVersionKey, settings.appVersion);
    } catch (e) {
      throw CacheException(message: 'Failed to save settings: $e');
    }
  }

  @override
  Future<void> updateThemeMode(ThemeModeModel themeMode) async {
    try {
      await _box.put(_themeModeKey, themeMode.toStringValue());
    } catch (e) {
      throw CacheException(message: 'Failed to update theme mode: $e');
    }
  }

  @override
  Future<void> updateLanguage(String language) async {
    try {
      await _box.put(_languageKey, language);
    } catch (e) {
      throw CacheException(message: 'Failed to update language: $e');
    }
  }

  @override
  Future<String> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      // Fallback for web environment - try to read version.json
      if (kIsWeb) {
        try {
          final response = await http.get(Uri.parse('/version.json'));
          if (response.statusCode == 200) {
            final versionData = json.decode(response.body);
            return versionData['version'] ?? '1.0.0+1';
          }
        } catch (webError) {
          // If version.json also fails, use default version
        }
      }

      // Default fallback version
      return '1.0.0+1';
    }
  }

  @override
  Future<void> clearAllSettings() async {
    try {
      await _box.delete(_themeModeKey);
      await _box.delete(_languageKey);
      await _box.delete(_notificationsKey);
      await _box.delete(_appVersionKey);
    } catch (e) {
      throw CacheException(message: 'Failed to clear settings: $e');
    }
  }
}
