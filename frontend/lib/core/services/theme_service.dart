import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/domain/entities/theme_mode_entity.dart';
import '../../features/settings/data/models/theme_mode_model.dart';
import '../utils/logger.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  late ThemeModeEntity _currentTheme;
  bool _isInitialized = false;

  ThemeModeEntity get currentTheme => _currentTheme;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if this is first launch (no stored preference)
      final themeString = prefs.getString(_themeModeKey);

      if (themeString == null) {
        // First launch - default to system preference
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        _currentTheme =
            ThemeModeEntity.system(isDarkMode: brightness == Brightness.dark);

        // Save the default system preference
        final themeModel = ThemeModeModel.fromEntity(_currentTheme);
        await prefs.setString(_themeModeKey, themeModel.toStringValue());
      } else {
        // Load existing preference
        _currentTheme = ThemeModeModel.fromString(themeString);

        // If it's system mode, update with current brightness
        if (_currentTheme.mode == AppThemeMode.system) {
          final brightness =
              WidgetsBinding.instance.platformDispatcher.platformBrightness;
          _currentTheme =
              ThemeModeEntity.system(isDarkMode: brightness == Brightness.dark);
        }
      }

      // Set up system theme change listener
      _setupSystemThemeListener();

      // Initial system theme detection
      _detectSystemTheme();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Fallback to system default if anything goes wrong
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _currentTheme =
          ThemeModeEntity.system(isDarkMode: brightness == Brightness.dark);
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> updateTheme(ThemeModeEntity theme) async {
    Logger.debug(
        'ThemeService: updateTheme called - New theme: ${theme.mode}, isDark: ${theme.isDarkMode}');
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModel = ThemeModeModel.fromEntity(theme);
      await prefs.setString(_themeModeKey, themeModel.toStringValue());

      _currentTheme = theme;
      Logger.debug('ThemeService: Theme updated and notifyListeners called');
      notifyListeners();
    } catch (e) {
      Logger.debug('ThemeService: Failed to update theme: $e');
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

  /// Set up listener for system theme changes
  void _setupSystemThemeListener() {
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        _detectSystemTheme;
  }

  /// Detect system theme and update if necessary
  void _detectSystemTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (_currentTheme.mode == AppThemeMode.system) {
      final isDark = brightness == Brightness.dark;
      if (isDark != _currentTheme.isDarkMode) {
        _currentTheme = _currentTheme.copyWith(isDarkMode: isDark);
        notifyListeners();
      }
    }
  }

  /// Reset theme preferences (for testing/debugging)
  Future<void> resetToSystemDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themeModeKey);

      // Reinitialize with system default
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _currentTheme =
          ThemeModeEntity.system(isDarkMode: brightness == Brightness.dark);

      // Save the system preference
      final themeModel = ThemeModeModel.fromEntity(_currentTheme);
      await prefs.setString(_themeModeKey, themeModel.toStringValue());

      notifyListeners();
    } catch (e) {
      // Fallback
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _currentTheme =
          ThemeModeEntity.system(isDarkMode: brightness == Brightness.dark);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        null;
    super.dispose();
  }
}
