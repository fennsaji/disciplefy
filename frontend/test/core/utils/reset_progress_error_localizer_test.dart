import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/utils/reset_progress_error_localizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reset_progress_error_localizer_test.mocks.dart';

// Short, human-sized stand-ins for the translation keys under test — mirrors
// the pattern used in memory_verses_reset_flow_test.dart.
const _rateLimitedMessage = 'Please wait before trying again.';
const _authMessage = 'Please sign in again.';
const _networkMessage = 'Check your connection and try again.';
const _genericMessage = 'Something went wrong. Please try again.';
const _fallbackMessage = 'raw failure message from the data layer';

@GenerateMocks([TranslationService])
void main() {
  late MockTranslationService mockTranslationService;

  setUp(() {
    mockTranslationService = MockTranslationService();
    when(mockTranslationService.getTranslation(any, any)).thenAnswer(
      (invocation) {
        final key = invocation.positionalArguments[0] as String;
        switch (key) {
          case TranslationKeys.resetProgressErrorRateLimited:
            return _rateLimitedMessage;
          case TranslationKeys.resetProgressErrorAuth:
            return _authMessage;
          case TranslationKeys.resetProgressErrorNetwork:
            return _networkMessage;
          case TranslationKeys.resetProgressErrorGeneric:
            return _genericMessage;
          default:
            // Simulates a key with no translation entry: the translation
            // service returns the key itself, which is the localizer's
            // signal to fall back to the raw failure message.
            return key;
        }
      },
    );

    if (sl.isRegistered<TranslationService>()) {
      sl.unregister<TranslationService>();
    }
    sl.registerLazySingleton<TranslationService>(() => mockTranslationService);
  });

  tearDown(() {
    if (sl.isRegistered<TranslationService>()) {
      sl.unregister<TranslationService>();
    }
  });

  /// Pumps a minimal widget tree and returns the [BuildContext] needed to
  /// call `localizeResetProgressError`, which reads translations via
  /// `context.tr` (`sl<TranslationService>()`), not an InheritedWidget.
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return capturedContext;
  }

  group('authentication codes', () {
    // The three codes HttpService actually throws on a real 401
    // (http_service.dart:139 SESSION_EXPIRED, :147 AUTHENTICATION_REQUIRED,
    // :105/:261 TOKEN_INVALID), plus the two the datasources' own
    // (HttpService-preempted) 401 branches use.
    for (final code in [
      'SESSION_EXPIRED',
      'AUTHENTICATION_REQUIRED',
      'TOKEN_INVALID',
      'UNAUTHORIZED',
      'AUTHENTICATION_ERROR',
    ]) {
      testWidgets('$code maps to the auth message', (tester) async {
        final context = await pumpContext(tester);

        final message = localizeResetProgressError(
          context,
          code: code,
          isNetworkError: false,
          fallbackMessage: _fallbackMessage,
        );

        expect(message, _authMessage);
        expect(message, isNot(_genericMessage));
      });
    }
  });

  testWidgets('RATE_LIMIT_EXCEEDED maps to the rate-limit message',
      (tester) async {
    final context = await pumpContext(tester);

    final message = localizeResetProgressError(
      context,
      code: 'RATE_LIMIT_EXCEEDED',
      isNetworkError: false,
      fallbackMessage: _fallbackMessage,
    );

    expect(message, _rateLimitedMessage);
  });

  testWidgets(
      'isNetworkError true maps to the network message regardless of code',
      (tester) async {
    final context = await pumpContext(tester);

    final message = localizeResetProgressError(
      context,
      code: 'REQUEST_FAILED',
      isNetworkError: true,
      fallbackMessage: _fallbackMessage,
    );

    expect(message, _networkMessage);
  });

  testWidgets('an unknown code falls through to the generic message',
      (tester) async {
    final context = await pumpContext(tester);

    final message = localizeResetProgressError(
      context,
      code: 'SOME_UNRECOGNIZED_CODE',
      isNetworkError: false,
      fallbackMessage: _fallbackMessage,
    );

    expect(message, _genericMessage);
  });
}
