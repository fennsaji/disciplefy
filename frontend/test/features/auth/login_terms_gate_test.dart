// Verifies the Apple Guideline 1.2 terms gate: sign-in is blocked until the
// user explicitly accepts the Terms of Use and Privacy Policy, and the
// acceptance is persisted so returning users are not asked again.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/login_screen.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/terms_acceptance_checkbox.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';

import 'login_terms_gate_test.mocks.dart';

@GenerateMocks([AuthBloc, TranslationService])
void main() {
  late MockAuthBloc mockAuthBloc;
  late MockTranslationService mockTranslationService;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('terms_gate_test');
    Hive.init(tempDir.path);

    // Register a mock translation service so context.tr(...) does not throw
    // (LoginScreen and the terms widgets resolve translations via GetIt).
    mockTranslationService = MockTranslationService();
    sl.registerLazySingleton<TranslationService>(() => mockTranslationService);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
    await sl.reset();
  });

  setUp(() async {
    if (Hive.isBoxOpen('app_settings')) {
      await Hive.box('app_settings').clear();
    } else {
      await Hive.openBox('app_settings');
    }
    mockAuthBloc = MockAuthBloc();
    when(mockAuthBloc.state).thenReturn(const AuthInitialState());
    when(mockAuthBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());

    // Fall back to returning the key itself — these tests assert on widget
    // types and Hive state, not on rendered translation text.
    when(mockTranslationService.getTranslation(any, any)).thenAnswer(
      (invocation) => invocation.positionalArguments[0] as String,
    );
  });

  Widget harness() => MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: const LoginScreen(),
        ),
      );

  testWidgets('blocks sign-in until the terms checkbox is ticked',
      (tester) async {
    // Default 800x600 test surface clips the sign-in buttons below the
    // fold once the gate widget adds height; widen it so tap() can
    // hit-test them.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // The gate is visible on a device that has never accepted.
    expect(find.byType(TermsAcceptanceCheckbox), findsOneWidget);

    // Every sign-in button is disabled while unaccepted.
    final buttons =
        tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)).toList();
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.onPressed, isNull,
          reason: 'sign-in buttons must be disabled before acceptance');
    }

    // Tick the box.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final enabled =
        tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)).toList();
    for (final button in enabled) {
      expect(button.onPressed, isNotNull,
          reason: 'sign-in buttons must enable once accepted');
    }
  });

  testWidgets('persists acceptance when a sign-in button is tapped',
      (tester) async {
    // Default 800x600 test surface clips the sign-in buttons below the
    // fold once the gate widget adds height; widen it so tap() can
    // hit-test them.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Tap the Google button (first sign-in button on the screen).
    // _handleGoogleSignIn fires a real (un-awaited) Hive write; running the
    // tap through runAsync keeps that write out of the FakeAsync zone so it
    // cannot stall the test binding's teardown.
    await tester.runAsync(() => tester.tap(find.byType(OutlinedButton).first));
    await tester.pump();

    expect(
      Hive.box('app_settings').get('terms_accepted', defaultValue: false),
      isTrue,
      reason: 'acceptance must persist at button-tap time so it survives the '
          'OAuth round-trip to the provider and back',
    );
    verify(mockAuthBloc.add(const GoogleSignInRequested())).called(1);
  });

  testWidgets('skips the checkbox for a user who already accepted',
      (tester) async {
    // Real disk I/O must run via runAsync — inside the FakeAsync zone that
    // wraps a testWidgets body, an awaited real (non-timer) Future can
    // stall indefinitely.
    await tester
        .runAsync(() => Hive.box('app_settings').put('terms_accepted', true));

    // Default 800x600 test surface clips the sign-in buttons below the
    // fold once the gate widget adds height; widen it so tap() can
    // hit-test them.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(TermsAcceptanceCheckbox), findsNothing);
    expect(find.byType(LegalLinksLine), findsOneWidget);

    final buttons =
        tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)).toList();
    for (final button in buttons) {
      expect(button.onPressed, isNotNull,
          reason: 'a returning user must not be re-gated');
    }
  });
}
