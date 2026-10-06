import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';

/// Shared harness for the pre-auth screen tests (onboarding, login, email
/// auth, language selection).

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Resolves keys against the real translation table for [language], with an
/// English fallback, so hi/ml strings are laid out for overflow checks and a
/// missing key shows up as the raw key.
class FakeTranslationService extends Fake implements TranslationService {
  AppLanguage language;

  FakeTranslationService([this.language = AppLanguage.english]);

  static String? _lookup(AppLanguage language, String key) {
    dynamic node = AppTranslations.translations[language];
    for (final part in key.split('.')) {
      if (node is Map && node.containsKey(part)) {
        node = node[part];
      } else {
        return null;
      }
    }
    return node is String ? node : null;
  }

  @override
  AppLanguage get currentLanguage => language;

  @override
  String getTranslation(String key, [Map<String, dynamic>? args]) {
    var text = _lookup(language, key) ?? _lookup(AppLanguage.english, key);
    if (text == null) return key;
    args?.forEach((k, v) => text = text!.replaceAll('{$k}', '$v'));
    return text!;
  }
}

/// Records what the language screen saves.
class FakeLanguagePreferenceService extends Fake
    implements LanguagePreferenceService {
  AppLanguage initial;
  final List<AppLanguage> saved = [];

  FakeLanguagePreferenceService([this.initial = AppLanguage.english]);

  @override
  Future<AppLanguage> getSelectedLanguage() async => initial;

  @override
  Future<void> saveLanguagePreference(AppLanguage language) async {
    saved.add(language);
  }

  @override
  Future<bool> hasCompletedLanguageSelection() async => saved.isNotEmpty;
}

/// Sets a logical [size] test surface (dpr 1) and resets it afterwards.
void useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Mounts [screen] at [initial] inside a GoRouter with stub destination
/// routes, themed [dark] or light, with [bloc] provided.
Widget welcomeApp({
  required Widget screen,
  String path = '/',
  bool dark = false,
  AuthBloc? bloc,
  String? language,
}) {
  if (language != null) {
    final service = sl<TranslationService>();
    if (service is FakeTranslationService) {
      service.language = AppLanguage.values.firstWhere(
        (l) => l.code == language,
        orElse: () => AppLanguage.english,
      );
    }
  }
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (_, __) => screen),
      for (final stub in const [
        '/',
        '/login',
        '/email-auth',
        '/password-reset',
        '/premium-upgrade',
      ])
        if (stub != path)
          GoRoute(
            path: stub,
            builder: (_, __) => Scaffold(body: Text('stub:$stub')),
          ),
    ],
  );
  final app = MaterialApp.router(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    routerConfig: router,
  );
  return bloc == null
      ? app
      : BlocProvider<AuthBloc>.value(value: bloc, child: app);
}
