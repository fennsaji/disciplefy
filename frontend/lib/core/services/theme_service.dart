import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/domain/entities/theme_mode_entity.dart';
import '../../features/settings/data/models/theme_mode_model.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  ThemeModeEntity _currentTheme = ThemeModeEntity.light();
  bool _isInitialized = false;

  ThemeModeEntity get currentTheme => _currentTheme;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeModeKey) ?? 'light';
      _currentTheme = ThemeModeModel.fromString(themeString);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _currentTheme = ThemeModeEntity.light();
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> updateTheme(ThemeModeEntity theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModel = ThemeModeModel.fromEntity(theme);
      await prefs.setString(_themeModeKey, themeModel.toStringValue());

      _currentTheme = theme;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update theme: $e');
    }
  }

  ThemeMode get flutterThemeMode {
    switch (_currentTheme.mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
