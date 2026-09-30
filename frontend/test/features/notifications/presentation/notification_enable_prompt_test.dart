import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/core/services/notification_service.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/widgets/notification_enable_prompt.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_event.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' as mt;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/text_fit.dart';
import '../../../helpers/welcome_test_harness.dart';
import 'notification_enable_prompt_test.mocks.dart';

class _MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

/// Daily verse notifications are on by default. The "turn on notifications"
/// sheet is for users who turned them off — never for a permission that was
/// simply not answered yet (the system asks for that itself).
@GenerateMocks([NotificationService])
void main() {
  late MockNotificationService service;
  late FakeTranslationService translations;

  setUpAll(loadAppFonts);

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    SharedPreferences.setMockInitialValues({});
    service = MockNotificationService();
    if (sl.isRegistered<NotificationService>()) {
      sl.unregister<NotificationService>();
    }
    sl.registerLazySingleton<NotificationService>(() => service);
  });

  tearDown(() => sl.reset());

  Future<void> prompt(WidgetTester tester) async {
    final bloc = _MockNotificationBloc();
    whenListen<NotificationState>(bloc, const Stream<NotificationState>.empty(),
        initialState: const NotificationInitial());
    await tester.pumpWidget(BlocProvider<NotificationBloc>.value(
      value: bloc,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNotificationEnablePrompt(
              context: context,
              type: NotificationPromptType.dailyVerse,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('permission not answered yet: no sheet', (tester) async {
    when(service.areNotificationsEnabled()).thenAnswer((_) async => false);
    when(service.isNotificationPermissionDenied())
        .thenAnswer((_) async => false);

    await prompt(tester);

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('permission refused by the user: sheet asks again',
      (tester) async {
    when(service.areNotificationsEnabled()).thenAnswer((_) async => false);
    when(service.isNotificationPermissionDenied())
        .thenAnswer((_) async => true);

    await prompt(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
  });

  group('restyled sheet at 320x640', () {
    const languages = {
      'en': AppLanguage.english,
      'hi': AppLanguage.hindi,
      'ml': AppLanguage.malayalam,
    };

    Future<(List<bool?>, _MockNotificationBloc)> open(WidgetTester tester,
        {required bool dark, required String code}) async {
      useSurface(tester, const Size(320, 640));
      translations.language = languages[code]!;
      final bloc = _MockNotificationBloc();
      whenListen<NotificationState>(
          bloc, const Stream<NotificationState>.empty(),
          initialState: const NotificationInitial());
      final results = <bool?>[];
      await tester.pumpWidget(BlocProvider<NotificationBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showNotificationEnablePrompt(
                    context: context,
                    type: NotificationPromptType.streakLost,
                    languageCode: code,
                    forceShow: true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (results, bloc);
    }

    for (final dark in [false, true]) {
      for (final code in languages.keys) {
        testWidgets('${dark ? 'dark' : 'light'} $code: fits, not now closes',
            (tester) async {
          final (results, _) = await open(tester, dark: dark, code: code);
          expect(tester.takeException(), isNull);
          expect(find.byType(PopupSheet), findsOneWidget);
          expect(find.byType(PopupEyebrow), findsOneWidget);
          expectNoTruncatedText(tester);

          await tester.tap(find.byType(PopupTextButton));
          await tester.pumpAndSettle();
          expect(results, [false]);
        });
      }
    }

    testWidgets('enable turns the preference on', (tester) async {
      when(service.areNotificationsEnabled()).thenAnswer((_) async => true);
      final (_, bloc) = await open(tester, dark: true, code: 'en');

      await tester.tap(find.byType(PopupPrimaryButton));
      await tester.pumpAndSettle();

      mt
          .verify(() => bloc.add(
              const UpdateNotificationPreferences(streakLostEnabled: true)))
          .called(1);
    });
  });
}
