import 'dart:async';
import 'package:flutter/material.dart';

import '../models/app_language.dart';
import 'language_preference_service.dart';
import '../utils/logger.dart';

/// Service for managing app locale with change notifications.
///
/// This service listens to language preference changes and exposes
/// a [Locale] that can be used by MaterialApp to update the UI language.
class LocaleService extends ChangeNotifier {
  final LanguagePreferenceService _languagePreferenceService;

  Locale _currentLocale = const Locale('en', '');
  bool _isInitialized = false;
  StreamSubscription<AppLanguage>? _languageSubscription;

  LocaleService({
    required LanguagePreferenceService languagePreferenceService,
  }) : _languagePreferenceService = languagePreferenceService;

  Locale get currentLocale => _currentLocale;
  bool get isInitialized => _isInitialized;

  /// Initialize the locale service from the language stored on this device.
  ///
  /// Runs before the first frame, so it never touches the network: the
  /// server's language is reconciled later by [LanguagePreferenceService],
  /// which announces any difference on [LanguagePreferenceService.languageChanges]
  /// that this service is subscribed to.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final language =
          _languagePreferenceService.getLocalLanguage() ?? AppLanguage.english;
      _currentLocale = Locale(language.code, '');
      Logger.debug(
          '🌐 [LOCALE_SERVICE] Initialized with locale: ${language.code}');

      // Listen to language changes
      _languageSubscription =
          _languagePreferenceService.languageChanges.listen(_onLanguageChanged);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      Logger.debug('🌐 [LOCALE_SERVICE] Error initializing: $e');
      // Default to English on error
      _currentLocale = const Locale('en', '');
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _onLanguageChanged(AppLanguage language) {
    Logger.debug(
        '🌐 [LOCALE_SERVICE] Language changed to: ${language.displayName}');
    _currentLocale = Locale(language.code, '');
    notifyListeners();
  }

  /// Manually update the locale (used when language is changed).
  void updateLocale(AppLanguage language) {
    Logger.debug(
        '🌐 [LOCALE_SERVICE] Manually updating locale to: ${language.displayName}');
    _currentLocale = Locale(language.code, '');
    notifyListeners();
  }

  /// Refresh the locale from the language preference service.
  Future<void> refresh() async {
    try {
      final language = await _languagePreferenceService.getSelectedLanguage();
      if (_currentLocale.languageCode != language.code) {
        _currentLocale = Locale(language.code, '');
        Logger.debug(
            '🌐 [LOCALE_SERVICE] Refreshed locale to: ${language.code}');
        notifyListeners();
      }
    } catch (e) {
      Logger.debug('🌐 [LOCALE_SERVICE] Error refreshing locale: $e');
    }
  }

  @override
  void dispose() {
    _languageSubscription?.cancel();
    super.dispose();
  }
}
