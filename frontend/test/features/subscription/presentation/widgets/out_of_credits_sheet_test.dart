import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/out_of_credits_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

TokenStatus tokenStatus({required int total, bool canPurchase = false}) =>
    TokenStatus(
      availableTokens: total,
      purchasedTokens: 0,
      totalTokens: total,
      dailyLimit: 20,
      totalConsumedToday: 0,
      userPlan: UserPlan.free,
      lastReset: DateTime(2026),
      nextResetTime: DateTime(2026, 1, 2),
      authenticationType: AuthenticationType.authenticated,
      isPremium: false,
      unlimitedUsage: false,
      canPurchaseTokens: canPurchase,
      planDescription: '',
    );

void main() {
  late FakeTranslationService translations;

  setUpAll(() async {
    await loadAppFonts();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });
  tearDownAll(sl.reset);
  setUp(() => translations.language = AppLanguage.english);

  Future<void> open(
    WidgetTester tester,
    TokenStatus status, {
    bool dark = false,
    Size size = const Size(390, 800),
  }) async {
    useSurface(tester, size);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () =>
                  OutOfCreditsSheet.show(c, status: status, needed: 20),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      for (final p in const [
        '/token-management/purchase',
        '/my-plan',
        '/saved'
      ])
        GoRoute(
          path: p,
          builder: (_, state) => Scaffold(
            body: Text('stub:${state.uri}|${state.extra.runtimeType}'),
          ),
        ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('header and sheet agree', (tester) async {
    await open(tester, tokenStatus(total: 5));
    expect(find.text('You need 20 credits — 5 left today.'), findsOneWidget);
    expect(find.textContaining('Token'), findsNothing);
  });

  testWidgets('get credits opens purchase when allowed', (tester) async {
    await open(tester, tokenStatus(total: 5, canPurchase: true));
    await tester.tap(find.text('Get credits'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('stub:/token-management/purchase'), findsOneWidget);
    expect(find.textContaining('TokenStatus'), findsOneWidget);
  });

  testWidgets('get credits opens My Plan otherwise', (tester) async {
    await open(tester, tokenStatus(total: 5));
    await tester.tap(find.text('Get credits'));
    await tester.pumpAndSettle();
    expect(find.textContaining('stub:/my-plan'), findsOneWidget);
  });

  testWidgets('view saved guides routes to saved', (tester) async {
    await open(tester, tokenStatus(total: 5));
    await tester.tap(find.text('View saved guides'));
    await tester.pumpAndSettle();
    expect(find.textContaining('stub:/saved?tab=saved&source=generate'),
        findsOneWidget);
  });

  testWidgets('maybe later just closes', (tester) async {
    await open(tester, tokenStatus(total: 5));
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(find.text('Out of study credits'), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });

  for (final lang in [
    AppLanguage.english,
    AppLanguage.hindi,
    AppLanguage.malayalam
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
          '${lang.name} ${dark ? 'dark' : 'light'} fits 320px, 40px buttons',
          (tester) async {
        translations.language = lang;
        await open(tester, tokenStatus(total: 5),
            dark: dark, size: const Size(320, 640));
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        for (final type in [FilledButton, OutlinedButton]) {
          expect(tester.getSize(find.byType(type)).height, 40);
        }
      });
    }
  }
}
