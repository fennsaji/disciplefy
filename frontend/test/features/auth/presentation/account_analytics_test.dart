import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/save_progress_block.dart';

import '../../../helpers/mock_activation_analytics.dart';
import '../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

void main() {
  late MockActivationAnalytics analytics;

  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    final guest = _MockGuest();
    final flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
    analytics = registerMockAnalytics();
  });

  tearDown(() async => sl.reset());

  testWidgets('the account sheet reports it was shown and Continue as guest',
      (tester) async {
    await tester.pumpWidget(welcomeApp(
      screen: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => requireAccount(c, AccountReason.memoryVerses),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    verify(() => analytics.track(
        NuxEvent.accountNeededShown, {'reason': 'memory_verses'})).called(1);

    await tester.tap(find.byKey(const Key('account_continue_guest')));
    await tester.pumpAndSettle();

    verify(() => analytics.track(NuxEvent.guestContinued, {
          'source': 'account_sheet',
          'reason': 'memory_verses',
        })).called(1);
  });

  testWidgets('Not now on the save-progress block reports guest_continued',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(welcomeApp(
      screen: Scaffold(
        body: SingleChildScrollView(
          child: SaveProgressBlock(onNotNow: () => dismissed = true),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_progress_not_now')));
    await tester.pump();

    expect(dismissed, isTrue);
    verify(() => analytics
        .track(NuxEvent.guestContinued, {'source': 'save_progress'})).called(1);
  });
}
