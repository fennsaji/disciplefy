import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// User-selectable text size levels.
enum FontScaleLevel {
  small,
  normal,
  large,
  extraLarge,
}

extension FontScaleLevelExt on FontScaleLevel {
  double get scaleFactor {
    switch (this) {
      case FontScaleLevel.small:
        return 0.85;
      case FontScaleLevel.normal:
        return 1.0;
      case FontScaleLevel.large:
        return 1.15;
      case FontScaleLevel.extraLarge:
        return 1.30;
    }
  }

  String get label {
    switch (this) {
      case FontScaleLevel.small:
        return 'Small';
      case FontScaleLevel.normal:
        return 'Normal';
      case FontScaleLevel.large:
        return 'Large';
      case FontScaleLevel.extraLarge:
        return 'Extra Large';
    }
  }

  String get storageKey => name;

  static FontScaleLevel fromString(String value) {
    return FontScaleLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FontScaleLevel.normal,
    );
  }
}

/// Manages the user's preferred text size, backed by [SharedPreferences].
///
/// Wire into [MaterialApp] via a [MediaQuery] override so every text widget
/// in the app scales uniformly:
/// ```dart
/// builder: (context, child) => MediaQuery(
///   data: MediaQuery.of(context).copyWith(
///     textScaler: TextScaler.linear(fontScaleService.scaleFactor),
///   ),
///   child: child!,
/// ),
/// ```
class FontScaleService extends ChangeNotifier {
  static const String _prefsKey = 'font_scale_level';

  FontScaleLevel _level = FontScaleLevel.normal;
  bool _isInitialized = false;

  FontScaleLevel get level => _level;
  double get scaleFactor => _level.scaleFactor;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _level = stored != null
          ? FontScaleLevelExt.fromString(stored)
          : FontScaleLevel.normal;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      Logger.debug('FontScaleService: initialize error — $e');
      _level = FontScaleLevel.normal;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> updateScale(FontScaleLevel level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, level.storageKey);
      _level = level;
      notifyListeners();
    } catch (e) {
      Logger.debug('FontScaleService: updateScale error — $e');
    }
  }
}
