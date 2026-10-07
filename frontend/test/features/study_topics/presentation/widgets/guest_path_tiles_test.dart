import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/domain/entities/account_reason.dart';
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
    GuestPathEnrollment.currentUserId = () => 'guest-1';
  });

  tearDown(() async {
    GuestPathEnrollment.reset();
    await sl.reset();
  });

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

  group('one path per guest', () {
    // The six guest-accessible paths, as in the catalogue.
    final accessible = [
      for (final id in ['a1', 'a2', 'a3', 'a4', 'a5', 'a6'])
        _path(id, guestAccessible: true),
    ];
    final closed = _path('rooted');

    test('no enrolment yet: the six accessible paths are open, others not', () {
      for (final p in accessible) {
        expect(guestPathLockReason(p, guest: true), isNull, reason: p.id);
      }
      expect(guestPathLockReason(closed, guest: true), AccountReason.otherPath);
    });

    test(
        'enrolled guest: own path open, other accessible paths second_path, '
        'non-accessible paths other_path', () {
      GuestPathEnrollment.record('a1');
      expect(guestPathLockReason(accessible[0], guest: true), isNull);
      for (final p in accessible.skip(1)) {
        expect(guestPathLockReason(p, guest: true), AccountReason.secondPath,
            reason: p.id);
      }
      expect(guestPathLockReason(closed, guest: true), AccountReason.otherPath);
    });

    test('the path the data marks enrolled is open even before it is recorded',
        () {
      expect(
          guestPathLockReason(
              _path('a1', guestAccessible: true, enrolled: true),
              guest: true,
              enrolledPathId: 'a2'),
          isNull);
    });

    test('a full account has no locks', () {
      GuestPathEnrollment.record('a1');
      for (final p in [...accessible, closed]) {
        expect(guestPathLockReason(p, guest: false), isNull, reason: p.id);
      }
    });

    test("another user's record does not apply (a new guest after sign-out)",
        () {
      GuestPathEnrollment.record('a1');
      GuestPathEnrollment.currentUserId = () => 'guest-2';
      expect(guestPathLockReason(accessible[1], guest: true), isNull);
    });

    for (final entry in _tiles.entries) {
      testWidgets(
          '${entry.key}: an enrolled guest sees another accessible path locked',
          (tester) async {
        GuestPathEnrollment.record('mine');
        final opened = <String>[];
        final other = _path('other', guestAccessible: true);
        await tester.pumpWidget(host(other, entry.value, opened));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('guest_path_lock_other')), findsOneWidget);
        await tester.tap(find.text('Path other'));
        await tester.pumpAndSettle();
        expect(find.text('Your next path needs an account'), findsOneWidget);
        expect(opened, isEmpty);
      });

      testWidgets('${entry.key}: the lock appears once the enrolment is known',
          (tester) async {
        final other = _path('other', guestAccessible: true);
        await tester.pumpWidget(host(other, entry.value, []));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('guest_path_lock_other')), findsNothing);

        GuestPathEnrollment.record('mine');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('guest_path_lock_other')), findsOneWidget);
      });
    }
  });
}
