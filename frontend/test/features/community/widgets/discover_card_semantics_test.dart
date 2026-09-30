import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/community_tab_screen.dart';

import '../../../helpers/welcome_test_harness.dart';

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });

  tearDown(() async => sl.reset());

  const fellowship = PublicFellowshipEntity(
    id: 'f1',
    name: 'Young Adults Bible Study',
    description: 'We read one chapter a week together.',
    language: 'en',
    memberCount: 4,
    maxMembers: null,
    mentorName: 'Fenn',
  );

  Widget app(Widget child) => MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [child],
          ),
        ),
      );

  testWidgets('Join is its own focusable button, separate from the card',
      (tester) async {
    final handle = tester.ensureSemantics();
    useSurface(tester, const Size(390, 844));
    var joins = 0;
    await tester.pumpWidget(app(DiscoverFellowshipCard(
      fellowship: fellowship,
      isJoining: false,
      onJoin: () => joins++,
    )));
    await tester.pumpAndSettle();

    final join = find.bySemanticsLabel('Join');
    expect(join, findsOneWidget);
    final node = tester.getSemantics(join);
    expect(node.label, 'Join');
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.hasFlag(SemanticsFlag.isFocusable), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    // The card's own text is not folded into the Join node.
    expect(node.label.contains('Young Adults'), isFalse);

    tester.semantics.tap(find.semantics.byLabel('Join'));
    await tester.pump();
    expect(joins, 1);
    handle.dispose();
  });
}
