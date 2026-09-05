import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';

/// Resolves keys against the real English translation map so dialog copy in
/// these tests stays in sync with `AppTranslations`.
class _EnglishTranslationService implements TranslationService {
  @override
  AppLanguage get currentLanguage => AppLanguage.english;

  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  String getTranslation(String key, [Map<String, dynamic>? args]) {
    dynamic value = AppTranslations.translations[AppLanguage.english];
    for (final part in key.split('.')) {
      if (value is Map<String, dynamic> && value.containsKey(part)) {
        value = value[part];
      } else {
        return key;
      }
    }
    return value is String ? value : key;
  }

  @override
  List<String> getTranslationList(String key) => const [];

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _tr(String key) => sl<TranslationService>().getTranslation(key);

void main() {
  setUpAll(() {
    sl.registerLazySingleton<TranslationService>(
        _EnglishTranslationService.new);
  });

  tearDownAll(sl.reset);

  group('AuthProtectedScreen', () {
    testWidgets('should allow navigation when canPop is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthProtectedScreen(
            canPop: true,
            child: const Scaffold(
              body: Center(child: Text('Protected Content')),
            ),
          ),
        ),
      );

      expect(find.text('Protected Content'), findsOneWidget);

      // Check that PopScope allows navigation when canPop is true
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isTrue);
    });

    testWidgets('should prevent navigation when isPostAuthScreen is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthProtectedScreen(
            child: const Scaffold(
              body: Center(child: Text('Protected Content')),
            ),
          ),
        ),
      );

      expect(find.text('Protected Content'), findsOneWidget);

      // The PopScope should prevent navigation
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('should call custom onBackPressed when provided',
        (tester) async {
      bool customHandlerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AuthProtectedScreen(
            onBackPressed: () {
              customHandlerCalled = true;
            },
            child: const Scaffold(
              body: Center(child: Text('Protected Content')),
            ),
          ),
        ),
      );

      expect(find.text('Protected Content'), findsOneWidget);

      // Trigger back press
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      popScope.onPopInvokedWithResult?.call(false, null);

      expect(customHandlerCalled, isTrue);
    });

    testWidgets('should show exit confirmation when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthProtectedScreen(
            showExitConfirmation: true,
            child: const Scaffold(
              body: Center(child: Text('Protected Content')),
            ),
          ),
        ),
      );

      expect(find.text('Protected Content'), findsOneWidget);

      // Trigger back press
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      popScope.onPopInvokedWithResult?.call(false, null);

      await tester.pumpAndSettle();

      // Should show exit confirmation dialog with localized copy
      expect(find.text(_tr('common.exit.title')), findsOneWidget);
      expect(find.text(_tr('common.exit.message')), findsOneWidget);
    });
  });

  group('HomeScreenProtection', () {
    testWidgets('should render child content correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreenProtection(
            child: Scaffold(
              body: Center(child: Text('Home Content')),
            ),
          ),
        ),
      );

      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('should have exit confirmation enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreenProtection(
            child: Scaffold(
              body: Center(child: Text('Home Content')),
            ),
          ),
        ),
      );

      // Find the AuthProtectedScreen widget inside HomeScreenProtection
      final authProtectedScreen = tester.widget<AuthProtectedScreen>(
        find.byType(AuthProtectedScreen),
      );

      expect(authProtectedScreen.showExitConfirmation, isTrue);
      // No hardcoded override — the dialog uses the localized default.
      expect(authProtectedScreen.exitConfirmationMessage, isNull);
    });

    testWidgets('should show localized exit message on back press',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreenProtection(
            child: Scaffold(
              body: Center(child: Text('Home Content')),
            ),
          ),
        ),
      );

      // Trigger back press
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      popScope.onPopInvokedWithResult?.call(false, null);

      await tester.pumpAndSettle();

      // Should show the localized exit confirmation
      expect(find.text(_tr('common.exit.title')), findsOneWidget);
      expect(find.text(_tr('common.exit.message')), findsOneWidget);
    });
  });

  group('CriticalAuthScreen', () {
    testWidgets('should never allow back navigation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CriticalAuthScreen(
            child: Scaffold(
              body: Center(child: Text('Critical Content')),
            ),
          ),
        ),
      );

      expect(find.text('Critical Content'), findsOneWidget);

      // Should prevent all navigation
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('should call custom unauthorized access handler',
        (tester) async {
      bool unauthorizedHandlerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CriticalAuthScreen(
            onUnauthorizedAccess: () {
              unauthorizedHandlerCalled = true;
            },
            child: const Scaffold(
              body: Center(child: Text('Critical Content')),
            ),
          ),
        ),
      );

      // Trigger back press
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      popScope.onPopInvokedWithResult?.call(false, null);

      expect(unauthorizedHandlerCalled, isTrue);
    });

    testWidgets('should show default security warning when no custom handler',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CriticalAuthScreen(
            child: Scaffold(
              body: Center(child: Text('Critical Content')),
            ),
          ),
        ),
      );

      // Trigger back press
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      popScope.onPopInvokedWithResult?.call(false, null);

      await tester.pumpAndSettle();

      // Should show security warning snackbar
      expect(find.text('Navigation restricted for security'), findsOneWidget);
    });
  });

  group('AuthProtection Extension Methods', () {
    testWidgets('withAuthProtection should wrap widget correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            body: Center(child: Text('Test Content')),
          ).withAuthProtection(),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(AuthProtectedScreen), findsOneWidget);

      final authProtectedScreen = tester.widget<AuthProtectedScreen>(
        find.byType(AuthProtectedScreen),
      );
      expect(authProtectedScreen.isPostAuthScreen, isTrue);
    });

    testWidgets('withHomeProtection should wrap widget correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            body: Center(child: Text('Home Content')),
          ).withHomeProtection(),
        ),
      );

      expect(find.text('Home Content'), findsOneWidget);
      expect(find.byType(HomeScreenProtection), findsOneWidget);
    });

    testWidgets('withCriticalAuthProtection should wrap widget correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            body: Center(child: Text('Critical Content')),
          ).withCriticalAuthProtection(),
        ),
      );

      expect(find.text('Critical Content'), findsOneWidget);
      expect(find.byType(CriticalAuthScreen), findsOneWidget);
    });
  });

  group('Integration Tests', () {
    testWidgets('should work with GoRouter navigation', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Home')),
            ).withHomeProtection(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Settings')),
            ).withAuthProtection(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(HomeScreenProtection), findsOneWidget);
    });

    testWidgets('should handle complex navigation scenarios', (tester) async {
      bool navigationIntercepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AuthProtectedScreen(
            onBackPressed: () {
              navigationIntercepted = true;
            },
            enableLogging: false, // Disable for testing
            child: const Scaffold(
              body: Center(child: Text('Protected Screen')),
            ),
          ),
        ),
      );

      expect(find.text('Protected Screen'), findsOneWidget);

      // Simulate complex back navigation scenario
      final popScope = tester.widget<PopScope>(find.byType(PopScope));

      // First attempt should be intercepted
      popScope.onPopInvokedWithResult?.call(false, null);
      expect(navigationIntercepted, isTrue);

      // Reset for second attempt
      navigationIntercepted = false;

      // Second attempt should also be intercepted
      popScope.onPopInvokedWithResult?.call(false, null);
      expect(navigationIntercepted, isTrue);
    });
  });
}
