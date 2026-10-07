import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_card.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_header_cards.dart';

import '../../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

LearningPath _path(
  String id, {
  bool guestAccessible = false,
  bool featured = false,
  bool enrolled = false,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: 'Path $id',
      description: '',
      iconName: '',
      color: '',
      totalXp: 250,
      estimatedDays: 21,
      discipleLevel: 'seeker',
      guestAccessible: guestAccessible,
      isFeatured: featured,
      isEnrolled: enrolled,
      topicsCount: 5,
      progressPercentage: enrolled ? 20 : 0,
    );

/// Every widget that renders a path tile on the Topics tab, built for
/// [path] with [onTap] wired the way the screen wires it (through
/// [guestPathGate]).
///
/// - LearningPathCard: the "For you" carousel (ForYouLearningPathsSection)
///   and its featured / in-progress cards.
/// - PathListRow: category rows, search results (the filtered category rows)
///   and the category "See all" page.
/// - TopicsContinueCard: the Continue card at the top.
Map<String, Widget Function(BuildContext, LearningPath, VoidCallback)> _tiles =
    {
  'LearningPathCard (For you)': (_, p, onTap) =>
      LearningPathCard(path: p, onTap: onTap),
  'LearningPathCard (featured, wide)': (_, p, onTap) =>
      LearningPathCard(path: p, compact: false, onTap: onTap),
  'PathListRow (categories, search, See all)': (_, p, onTap) =>
      PathListRow(path: p, onTap: onTap),
  'TopicsContinueCard': (_, p, onTap) => GuestLockedPathTile(
        path: p,
        child: TopicsContinueCard(
          data: TopicsContinueData(
            pathId: p.id,
            title: p.title,
            currentTopic: 2,
            totalTopics: p.topicsCount,
            progressPercentage: 20,
          ),
          onTap: onTap,
        ),
      ),
};

void main() {
  late _MockGuest guest;

  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    guest = _MockGuest();
    final flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
  });

  tearDown(() async => sl.reset());

  Widget host(
          LearningPath path,
          Widget Function(BuildContext, LearningPath, VoidCallback) tile,
          List<String> opened) =>
      welcomeApp(
        screen: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => tile(
                context,
                path,
                () => guestPathGate(
                    context, path, () async => opened.add(path.id)),
              ),
            ),
          ),
        ),
      );

  for (final entry in _tiles.entries) {
    group(entry.key, () {
      testWidgets('a locked path shows the lock and opens the account sheet',
          (tester) async {
        final opened = <String>[];
        final path = _path('rooted', featured: true);
        await tester.pumpWidget(host(path, entry.value, opened));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('guest_path_lock_rooted')), findsOneWidget);
        await tester.tap(find.text('Path rooted'));
        await tester.pumpAndSettle();
        expect(find.text('Your next path needs an account'), findsOneWidget);
        expect(opened, isEmpty);
      });

      testWidgets("the guest's own path is open", (tester) async {
        final opened = <String>[];
        final path = _path('mine', guestAccessible: true, enrolled: true);
        await tester.pumpWidget(host(path, entry.value, opened));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('guest_path_lock_mine')), findsNothing);
        await tester.tap(find.text('Path mine'));
        await tester.pumpAndSettle();
        expect(opened, ['mine']);
      });

      testWidgets('a full account sees no lock', (tester) async {
        when(() => guest.isGuest).thenReturn(false);
        final opened = <String>[];
        final path = _path('rooted', featured: true);
        await tester.pumpWidget(host(path, entry.value, opened));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('guest_path_lock_rooted')), findsNothing);
        await tester.tap(find.text('Path rooted'));
        await tester.pumpAndSettle();
        expect(opened, ['rooted']);
      });
    });
  }

  // In the For you carousel the second card is only partly on screen; the
  // lock used to sit in its top-right corner, off the edge, so the card
  // looked open.
  testWidgets('the For you card shows its lock on the left, before the badge',
      (tester) async {
    await tester.pumpWidget(host(_path('rooted', featured: true),
        _tiles['LearningPathCard (For you)']!, []));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(LearningPathCard));
    final lock =
        tester.getRect(find.byKey(const Key('guest_path_lock_rooted')));
    expect(lock.left - card.left, lessThan(LearningPathCard.compactWidth / 3));
    expect(lock.top - card.top, lessThan(40));
    expect(find.text('Featured'), findsOneWidget);
  });
}
