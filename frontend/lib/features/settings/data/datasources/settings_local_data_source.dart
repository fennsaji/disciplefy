import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  final SharedPreferences sharedPreferences;

  const SettingsLocalDataSourceImpl({required this.sharedPreferences});

  static const String _themeModeKey = 'theme_mode';
  static const String _languageKey = 'language';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _appVersionKey = 'app_version';

  @override
  Future<AppSettingsModel> getSettings() async {
    try {
      final themeString = sharedPreferences.getString(_themeModeKey) ?? 'light';
      final language = sharedPreferences.getString(_languageKey) ?? 'en';
      final notificationsEnabled = sharedPreferences.getBool(_notificationsKey) ?? true;
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
      await sharedPreferences.setString(_themeModeKey, themeModel.toStringValue());
      await sharedPreferences.setString(_languageKey, settings.language);
      await sharedPreferences.setBool(_notificationsKey, settings.notificationsEnabled);
      await sharedPreferences.setString(_appVersionKey, settings.appVersion);
    } catch (e) {
      throw CacheException(message: 'Failed to save settings: $e');
    }
  }

  @override
  Future<void> updateThemeMode(ThemeModeModel themeMode) async {
    try {
      await sharedPreferences.setString(_themeModeKey, themeMode.toStringValue());
    } catch (e) {
      throw CacheException(message: 'Failed to update theme mode: $e');
    }
  }

  @override
  Future<void> updateLanguage(String language) async {
    try {
      await sharedPreferences.setString(_languageKey, language);
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
      throw CacheException(message: 'Failed to get app version: $e');
    }
  }

  @override
  Future<void> clearAllSettings() async {
    try {
      await sharedPreferences.remove(_themeModeKey);
      await sharedPreferences.remove(_languageKey);
      await sharedPreferences.remove(_notificationsKey);
      await sharedPreferences.remove(_appVersionKey);
    } catch (e) {
      throw CacheException(message: 'Failed to clear settings: $e');
    }
  }
}