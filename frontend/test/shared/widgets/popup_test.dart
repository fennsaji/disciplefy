import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/widgets/upgrade_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/achievement.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/widgets/achievement_unlock_dialog.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/guide_complete_sheet.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/insufficient_tokens_dialog.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/shared/widgets/sign_in_required_dialog.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
}

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// App whose home has an "open" button running [open]; `/pricing`,
/// `/token-management/purchase` and `/login` record where navigation went.
Widget _app({
  required bool dark,
  required void Function(BuildContext context) open,
  required List<String> visited,
}) {
  Widget page(String name) => Builder(builder: (_) {
        visited.add(name);
        return Scaffold(body: Text('page:$name'));
      });
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
    GoRoute(path: '/pricing', builder: (_, __) => page('pricing')),
    GoRoute(
        path: '/token-management/purchase',
        builder: (_, __) => page('purchase')),
    GoRoute(path: '/login', builder: (_, __) => page('login')),
  ]);
  return MaterialApp.router(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    routerConfig: router,
  );
}

TokenStatus _tokens({bool canPurchase = true}) => TokenStatus(
      availableTokens: 2,
      purchasedTokens: 0,
      totalTokens: 2,
      dailyLimit: 15,
      totalConsumedToday: 13,
      userPlan: UserPlan.free,
      lastReset: DateTime(2026, 9, 29),
      nextResetTime: DateTime(2026, 9, 30),
      authenticationType: AuthenticationType.authenticated,
      isPremium: false,
      unlimitedUsage: false,
      canPurchaseTokens: canPurchase,
      planDescription: 'Free',
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<TranslationService>(
        TranslationService(_FakeLanguageService(), prefs));
  });

  tearDown(() => GetIt.instance.reset());

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';
    final gold = dark ? AppColors.brandGold : AppColors.brandGoldDeep;
    final ctaFill = dark ? Colors.white : AppColors.brandPrimary;

    Color? pillFill(WidgetTester tester, Finder button) => tester
        .widget<FilledButton>(
            find.descendant(of: button, matching: find.byType(FilledButton)))
        .style
        ?.backgroundColor
        ?.resolve({});

    testWidgets('$theme: achievement unlocked fits 320pt, CTA dismisses',
        (tester) async {
      _useNarrowPhone(tester);
      var dismissed = 0;
      await tester.pumpWidget(_app(
        dark: dark,
        visited: [],
        open: (context) => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AchievementUnlockDialog(
            achievement: const AchievementUnlockResult(
              achievementId: 'a1',
              achievementName: 'Faithful Reader of the Whole Gospel',
              xpReward: 50,
              isNew: true,
            ),
            onDismiss: () {
              dismissed++;
              Navigator.of(dialogContext).pop();
            },
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ACHIEVEMENT UNLOCKED'), findsOneWidget);
      final eyebrow = tester.widget<Text>(find.text('ACHIEVEMENT UNLOCKED'));
      expect(eyebrow.style?.color, gold);
      expect(find.text('Faithful Reader of the Whole Gospel'), findsOneWidget);
      expect(find.text('+50 XP'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(
          pillFill(tester, find.byKey(const Key('achievement_unlock_dismiss'))),
          ctaFill);

      await tester.tap(find.byKey(const Key('achievement_unlock_dismiss')));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(find.byType(AchievementUnlockDialog), findsNothing);
    });

    testWidgets('$theme: guide complete sheet rows and buttons fire',
        (tester) async {
      _useNarrowPhone(tester);
      final taps = <String>[];
      await tester.pumpWidget(_app(
        dark: dark,
        visited: [],
        open: (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => GuideCompleteSheet(
            guideTitle: 'What does the Bible say about suffering?',
            isFromLearningPath: false,
            actions: [
              GuideCompleteAction(
                icon: Icons.edit_note_rounded,
                label: 'Add notes',
                onTap: () => taps.add('notes'),
              ),
              GuideCompleteAction(
                icon: Icons.people_outline_rounded,
                label: 'Share to fellowship',
                onTap: () => taps.add('share'),
              ),
              GuideCompleteAction(
                icon: Icons.psychology_rounded,
                leading: const DisciplerGlyph(size: 20),
                label: 'Ask Discipler',
                onTap: () => taps.add('ask'),
              ),
            ],
            onPrimary: () => taps.add('done'),
            onNotNow: () => taps.add('not_now'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('GUIDE COMPLETE'), findsOneWidget);
      expect(find.text('What would you like to do next?'), findsOneWidget);
      expect(find.byType(DisciplerGlyph), findsOneWidget);
      expect(find.byType(DisciplerAvatar), findsNothing);

      await tester.tap(find.text('Add notes'));
      await tester.tap(find.text('Share to fellowship'));
      await tester.tap(find.text('Ask Discipler'));
      await tester.tap(find.text('Done'));
      await tester.tap(find.text('Not now'));
      expect(taps, ['notes', 'share', 'ask', 'done', 'not_now']);
    });

    testWidgets('$theme: learning-path variant says continue path',
        (tester) async {
      _useNarrowPhone(tester);
      await tester.pumpWidget(_app(
        dark: dark,
        visited: [],
        open: (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => GuideCompleteSheet(
            guideTitle: 'John 3:16',
            isFromLearningPath: true,
            actions: const [],
            onPrimary: () {},
            onNotNow: () {},
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Continue learning path'), findsOneWidget);
      expect(
          find.text('Ready to continue your learning path?'), findsOneWidget);
    });

    testWidgets('$theme: upgrade sheet navigates to pricing / closes',
        (tester) async {
      _useNarrowPhone(tester);
      final visited = <String>[];
      void open(BuildContext context) => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const UpgradeDialog(
              featureKey: 'lectio_divina_mode',
              currentPlan: 'free',
              requiredPlans: ['plus', 'premium'],
            ),
          );
      await tester.pumpWidget(_app(dark: dark, visited: visited, open: open));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('LOCKED ON YOUR PLAN'), findsOneWidget);
      expect(find.text('Lectio Divina Mode'), findsOneWidget);
      expect(find.text('Your plan: Free'), findsOneWidget);
      expect(find.text('Plus'), findsOneWidget);
      expect(pillFill(tester, find.byKey(const Key('upgrade_dialog_upgrade'))),
          ctaFill);

      await tester.tap(find.byKey(const Key('upgrade_dialog_later')));
      await tester.pumpAndSettle();
      expect(find.byType(UpgradeDialog), findsNothing);
      expect(visited, isEmpty);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('upgrade_dialog_upgrade')));
      await tester.pumpAndSettle();
      expect(visited, contains('pricing'));
    });

    testWidgets('$theme: insufficient credits dialog actions', (tester) async {
      _useNarrowPhone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(
        dark: dark,
        visited: visited,
        open: (context) => InsufficientTokensDialog.show(
          context,
          tokenStatus: _tokens(),
          requiredTokens: 10,
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('OUT OF CREDITS'), findsOneWidget);
      expect(find.textContaining('10'), findsWidgets);
      expect(
          pillFill(
              tester, find.byKey(const Key('insufficient_tokens_view_plans'))),
          ctaFill);

      await tester
          .ensureVisible(find.byKey(const Key('insufficient_tokens_later')));
      await tester.tap(find.byKey(const Key('insufficient_tokens_later')));
      await tester.pumpAndSettle();
      expect(find.byType(InsufficientTokensDialog), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const Key('insufficient_tokens_purchase')));
      await tester.tap(find.byKey(const Key('insufficient_tokens_purchase')));
      await tester.pumpAndSettle();
      expect(visited, contains('purchase'));
    });

    testWidgets('$theme: insufficient credits → view plans', (tester) async {
      _useNarrowPhone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(
        dark: dark,
        visited: visited,
        open: (context) => InsufficientTokensDialog.show(
          context,
          tokenStatus: _tokens(canPurchase: false),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('insufficient_tokens_purchase')), findsNothing);
      await tester.ensureVisible(
          find.byKey(const Key('insufficient_tokens_view_plans')));
      await tester.tap(find.byKey(const Key('insufficient_tokens_view_plans')));
      await tester.pumpAndSettle();
      expect(visited, contains('pricing'));
    });

    testWidgets('$theme: sign-in required dialog', (tester) async {
      _useNarrowPhone(tester);
      var signIns = 0;
      await tester.pumpWidget(_app(
        dark: dark,
        visited: [],
        open: (context) => SignInRequiredDialog.show(
          context,
          title: 'Sign in to save this guide',
          message: 'Create a free account to keep guides across devices.',
          signInLabel: 'Sign In',
          cancelLabel: 'Cancel',
          onSignIn: () => signIns++,
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('YOUR ACCOUNT'), findsOneWidget);
      final (fill, _) = PopupIconCircle.colorsFor(
          tester.element(find.byType(PopupIconCircle)), PopupTone.indigo);
      expect(fill.a, greaterThan(0));

      await tester.tap(find.byKey(const Key('sign_in_required_cancel')));
      await tester.pumpAndSettle();
      expect(signIns, 0);
      expect(find.byType(SignInRequiredDialog), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign_in_required_sign_in')));
      await tester.pumpAndSettle();
      expect(signIns, 1);
      expect(find.byType(SignInRequiredDialog), findsNothing);
    });
  }
}
