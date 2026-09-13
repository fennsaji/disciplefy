// Verifies implicit terms consent on the login screen: there is no checkbox,
// the Terms of Use and Privacy Policy notice is always shown, sign-in starts
// on the first tap, and acceptance is recorded at that tap so it survives the
// OAuth round-trip and satisfies the router's terms gate.

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

  testWidgets('shows the terms notice and no checkbox on first run',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(LegalLinksLine), findsOneWidget);
  });

  testWidgets(
      'first sign-in tap starts sign-in and records acceptance, no toast',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      Hive.box('app_settings').get('terms_accepted', defaultValue: false),
      isFalse,
    );

    // Tap the Google button (first sign-in button on the screen).
    // _handleGoogleSignIn fires a real (un-awaited) Hive write; running the
    // tap through runAsync keeps that write out of the FakeAsync zone so it
    // cannot stall the test binding's teardown.
    await tester.runAsync(() => tester.tap(find.byType(OutlinedButton).first));
    await tester.pump();

    verify(mockAuthBloc.add(const GoogleSignInRequested())).called(1);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      Hive.box('app_settings').get('terms_accepted', defaultValue: false),
      isTrue,
      reason: 'acceptance must persist at button-tap time so it survives the '
          'OAuth round-trip to the provider and back',
    );
  });

  testWidgets('a returning user sees the same notice and enabled buttons',
      (tester) async {
    // Real disk I/O must run via runAsync — inside the FakeAsync zone that
    // wraps a testWidgets body, an awaited real (non-timer) Future can
    // stall indefinitely.
    await tester
        .runAsync(() => Hive.box('app_settings').put('terms_accepted', true));

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(LegalLinksLine), findsOneWidget);

    final buttons =
        tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)).toList();
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.onPressed, isNotNull);
    }
  });
}
