import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/share_guide_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/reaction_button.dart';

import '../../../helpers/welcome_test_harness.dart';
import '../../settings/text_fit.dart';

const _summary = 'God works all things together for good for those who love '
    'Him — even the hard things.';

FellowshipPostEntity _post(
  String type, {
  String id = 'p',
  Map<String, int> reactions = const {},
  String? userReaction,
  String? guideInputType,
  String? guideLanguage,
  String? guideStudyMode,
  String? guideSummary,
}) =>
    FellowshipPostEntity(
      id: id,
      fellowshipId: 'f1',
      authorUserId: 'u-anna',
      content: 'This helped me so much this morning.',
      postType: type,
      reactionCounts: reactions,
      isDeleted: false,
      createdAt: DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
      authorDisplayName: 'Anna George',
      userReaction: userReaction,
      commentCount: 1,
      guideTitle: type == 'shared_guide' ? 'Romans 8:28' : null,
      studyGuideId: type == 'shared_guide' ? 'g1' : null,
      guideInputType: guideInputType,
      guideLanguage: guideLanguage,
      guideStudyMode: guideStudyMode,
      guideSummary: guideSummary,
    );

final _guideWithMode = _post(
  'shared_guide',
  id: 'sg',
  reactions: const {'fire': 5},
  guideInputType: 'scripture',
  guideLanguage: 'en',
  guideStudyMode: 'standard',
  guideSummary: _summary,
);

/// Records what the share sheet sends.
class _RecordingRepository extends Fake implements CommunityRepository {
  final List<Map<String, Object?>> calls = [];

  @override
  Future<Either<Failure, FellowshipPostEntity>> createPost({
    required String fellowshipId,
    required String content,
    required String postType,
    String? topicId,
    String? topicTitle,
    String? guideTitle,
    int? lessonIndex,
    String? studyGuideId,
    String? guideInputType,
    String? guideLanguage,
    String? guideStudyMode,
    String? guideSummary,
    bool disciplerReplyOptOut = false,
    List<String> mentionedUserIds = const [],
  }) async {
    calls.add({
      'fellowshipId': fellowshipId,
      'postType': postType,
      'guideStudyMode': guideStudyMode,
      'guideSummary': guideSummary,
    });
    return Right(_post('shared_guide'));
  }
}

void main() {
  late FakeTranslationService translations;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async => sl.reset());

  Widget app(
    Widget home, {
    bool dark = true,
    AppLanguage language = AppLanguage.english,
  }) {
    translations.language = language;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  Widget feed(List<FellowshipPostEntity> posts) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FellowshipPostCard(
                  post: p,
                  fellowshipId: 'f1',
                  onCommentTap: () {},
                  onShareTap: () {},
                ),
              ),
          ],
        ),
      );

  group('Shared guide label and summary', () {
    const expectedLabel = {
      AppLanguage.english: 'SCRIPTURE · STANDARD · 8 MIN',
      AppLanguage.hindi: 'वचन · सामान्य · 8 मिनट',
      AppLanguage.malayalam: 'വേദഭാഗം · സ്റ്റാൻഡേർഡ് · 8 മിനിറ്റ്',
    };

    for (final entry in expectedLabel.entries) {
      testWidgets('${entry.key.code}: input type, mode and minutes',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester
            .pumpWidget(app(feed([_guideWithMode]), language: entry.key));
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        final summary = tester
            .widget<Text>(find.byKey(const ValueKey('shared-guide-summary')));
        expect(summary.data, _summary);
        expect(summary.maxLines, 2);
      });
    }

    testWidgets('older posts without mode or summary keep the language label',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(feed([
        _post('shared_guide', guideInputType: 'topic', guideLanguage: 'en'),
      ])));
      await tester.pumpAndSettle();

      expect(find.text('TOPIC · ENGLISH'), findsOneWidget);
      expect(find.byKey(const ValueKey('shared-guide-summary')), findsNothing);
    });

    testWidgets('an unknown mode falls back to the language label',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(feed([
        _post('shared_guide',
            guideInputType: 'scripture',
            guideLanguage: 'hi',
            guideStudyMode: 'recommended'),
      ])));
      await tester.pumpAndSettle();

      expect(find.text('SCRIPTURE · हिन्दी'), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('320pt ${language.code}: label and summary fit',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(feed([_guideWithMode]),
            dark: language != AppLanguage.hindi, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The summary is a two-line preview by design; the author name is
        // user content.
        expectNoTruncatedText(tester, allowed: {_summary, 'Anna George'});
      });
    }
  });

  group('Reaction pills', () {
    List<FellowshipPostEntity> posts() => [
          _post('prayer', id: 'pr', reactions: const {'i_prayed': 4}),
          _post('praise', id: 'pa', reactions: const {'amen': 9}),
          _post('question', id: 'q', reactions: const {'heart': 2}),
          _post('shared_guide',
              id: 'sg',
              reactions: const {'fire': 5},
              guideInputType: 'scripture',
              guideLanguage: 'en'),
          _post('study_note', id: 'sn', reactions: const {'fire': 3}),
          _post('general', id: 'g', reactions: const {'amen': 6}),
          _post('general', id: 'g0'),
        ];

    const expected = {
      AppLanguage.english: [
        'I prayed 4',
        'Praise 9',
        'Love 2',
        'Amen 5',
        'Amen 3',
        'Amen 6',
        'Amen',
      ],
      AppLanguage.hindi: [
        'मैंने प्रार्थना की 4',
        'स्तुति 9',
        'प्रेम 2',
        'आमीन 5',
        'आमीन 3',
        'आमीन 6',
        'आमीन',
      ],
      AppLanguage.malayalam: [
        'ഞാൻ പ്രാർത്ഥിച്ചു 4',
        'സ്തുതി 9',
        'സ്നേഹം 2',
        'ആമേൻ 5',
        'ആമേൻ 3',
        'ആമേൻ 6',
        'ആമേൻ',
      ],
    };

    for (final entry in expected.entries) {
      testWidgets('${entry.key.code}: label per post type, count when > 0',
          (tester) async {
        useSurface(tester, const Size(390, 2600));
        await tester.pumpWidget(app(feed(posts()), language: entry.key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final label in entry.value) {
          expect(
            find.descendant(
                of: find.byType(FellowshipReactionButton),
                matching: find.text(label)),
            findsOneWidget,
            reason: label,
          );
        }
      });
    }

    testWidgets('pill outline icon matches the picker per post type',
        (tester) async {
      useSurface(tester, const Size(390, 2600));
      await tester.pumpWidget(app(feed(posts())));
      await tester.pumpAndSettle();

      Finder icon(IconData i) => find.descendant(
          of: find.byType(FellowshipReactionButton), matching: find.byIcon(i));
      expect(icon(Icons.volunteer_activism_outlined), findsOneWidget);
      expect(icon(Icons.celebration_outlined), findsOneWidget);
      expect(icon(Icons.favorite_border_rounded), findsOneWidget);
      expect(icon(Icons.front_hand_outlined), findsNWidgets(4));
      // No colour emoji left in the pill.
      expect(
          find.descendant(
              of: find.byType(FellowshipReactionButton),
              matching: find.text('🙏')),
          findsNothing);
    });

    test('default reaction key per post type', () {
      expect(defaultReactionFor('prayer'), 'i_prayed');
      expect(defaultReactionFor('praise'), 'hands');
      expect(defaultReactionFor('question'), 'heart');
      expect(defaultReactionFor('study_note'), 'amen');
      expect(defaultReactionFor('shared_guide'), 'amen');
      expect(defaultReactionFor('daily'), 'fire');
      expect(defaultReactionFor('general'), 'amen');
    });

    test('a reaction picked from the picker shows as itself', () {
      expect(reactionDisplayFor('prayer', 'fire').labelKey,
          'community_post.reaction_fire');
      expect(reactionDisplayFor('question', 'heart').labelKey,
          'community_post.reaction_love');
      expect(reactionDisplayFor('prayer', 'i_prayed').icon,
          Icons.volunteer_activism_outlined);
      expect(reactionDisplayFor('general', 'heart').labelKey,
          'community_post.reaction_love');
      expect(reactionDisplayFor('daily', null).labelKey,
          'community_post.reaction_fire');
    });

    for (final language in AppLanguage.values) {
      testWidgets('320pt ${language.code}: pills fit without truncation',
          (tester) async {
        useSurface(tester, const Size(320, 3200));
        await tester.pumpWidget(app(feed(posts()), language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester, allowed: {'Anna George'});
      });
    }
  });

  group('Post timestamps', () {
    final now = DateTime(2026, 9, 30, 12);

    Future<String> format(WidgetTester tester, DateTime at,
        {AppLanguage language = AppLanguage.english}) async {
      late String result;
      await tester.pumpWidget(app(
        Builder(builder: (context) {
          result = formatPostTimestamp(context, at.toUtc().toIso8601String(),
              now: now);
          return const SizedBox();
        }),
        language: language,
      ));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('en relative times', (tester) async {
      expect(await format(tester, now.subtract(const Duration(seconds: 20))),
          'Just now');
      expect(await format(tester, now.subtract(const Duration(minutes: 35))),
          '35m ago');
      expect(await format(tester, now.subtract(const Duration(hours: 5))),
          '5h ago');
      expect(await format(tester, DateTime(2026, 9, 29, 8)), 'Yesterday');
      expect(await format(tester, DateTime(2026, 9, 28, 8)), '2 days ago');
      expect(await format(tester, DateTime(2026, 9, 14, 8)), 'Sep 14');
      expect(await format(tester, DateTime(2025, 9, 14, 8)), 'Sep 14, 2025');
    });

    testWidgets('hi relative times and date', (tester) async {
      const hi = AppLanguage.hindi;
      expect(
          await format(tester, now.subtract(const Duration(minutes: 35)),
              language: hi),
          '35 मिनट पहले');
      expect(
          await format(tester, DateTime(2026, 9, 29, 8), language: hi), 'कल');
      expect(await format(tester, DateTime(2026, 9, 28, 8), language: hi),
          '2 दिन पहले');
      expect(await format(tester, DateTime(2026, 9, 14, 8), language: hi),
          DateFormat.MMMd('hi').format(DateTime(2026, 9, 14, 8)));
    });

    testWidgets('ml relative times and date', (tester) async {
      const ml = AppLanguage.malayalam;
      expect(
          await format(tester, now.subtract(const Duration(hours: 2)),
              language: ml),
          '2 മണിക്കൂർ മുമ്പ്');
      expect(await format(tester, DateTime(2026, 9, 29, 8), language: ml),
          'ഇന്നലെ');
      final date = await format(tester, DateTime(2026, 9, 14, 8), language: ml);
      expect(date, DateFormat.MMMd('ml').format(DateTime(2026, 9, 14, 8)));
      expect(date, isNot('14/9/2026'));
    });
  });

  group('Share sheet with a known study mode', () {
    final fellowships = [
      const FellowshipEntity(
        id: 'f1',
        name: 'Disciplefy',
        memberCount: 4,
        userRole: 'member',
        joinedAt: '2026-01-01T00:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
        isOfficial: true,
      ),
    ];

    Widget host(Widget sheet) {
      final auth = MockAuthBloc();
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: AuthenticatedState(
          user: User(
            id: 'u-1',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime(2026).toIso8601String(),
          ),
        ),
      );
      return BlocProvider<AuthBloc>.value(
        value: auth,
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => sheet,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    ShareGuideSheet sheet({String? mode = 'standard'}) => ShareGuideSheet(
          studyGuideId: 'g1',
          guideTitle: 'Romans 8:28',
          guideInputType: 'scripture',
          guideLanguage: 'en',
          guideStudyMode: mode,
          guideSummary: '## Summary\n**God works** all things together for '
              'good. For those who love Him. Paul then turns to election.',
          fellowships: fellowships,
        );

    const subtitles = {
      AppLanguage.english: 'Standard study guide · 8 min',
      AppLanguage.hindi: 'सामान्य स्टडी गाइड · 8 मिनट',
      AppLanguage.malayalam: 'സ്റ്റാൻഡേർഡ് പഠന ഗൈഡ് · 8 മിനിറ്റ്',
    };

    for (final entry in subtitles.entries) {
      testWidgets('320pt ${entry.key.code}: preview subtitle, no truncation',
          (tester) async {
        useSurface(tester, const Size(320, 700));
        await tester.pumpWidget(app(host(sheet()), language: entry.key));
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsOneWidget);
        expectNoTruncatedText(tester);
      });
    }

    testWidgets('without a mode the subtitle is unchanged', (tester) async {
      useSurface(tester, const Size(390, 900));
      await tester.pumpWidget(app(host(sheet(mode: null))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Verse study · English'), findsOneWidget);
    });

    testWidgets('sharing sends the mode and a condensed summary',
        (tester) async {
      final repo = _RecordingRepository();
      sl.registerSingleton<CommunityRepository>(repo);
      useSurface(tester, const Size(390, 900));
      await tester.pumpWidget(app(host(sheet())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disciplefy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share to 1 fellowship'));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single['postType'], 'shared_guide');
      expect(repo.calls.single['guideStudyMode'], 'standard');
      expect(repo.calls.single['guideSummary'],
          'Summary God works all things together for good. For those who love Him.');
    });
  });

  group('Daily post action row', () {
    final daily = [
      _post('daily', id: 'd', reactions: const {'fire': 3}),
    ];

    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets(
            '360pt ${language.code} ${dark ? 'dark' : 'light'}: Start study '
            'shares the row with reaction, replies and share', (tester) async {
          useSurface(tester, const Size(360, 1400));
          await tester
              .pumpWidget(app(feed(daily), language: language, dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester, allowed: {'Anna George'});

          final footer = find.byType(FellowshipPostFooter);
          expect(footer, findsOneWidget);
          final start = find.descendant(
              of: footer, matching: find.byType(CommunityCtaPill));
          final reaction = find.descendant(
              of: footer, matching: find.byType(FellowshipReactionButton));
          expect(start, findsOneWidget);
          expect(reaction, findsOneWidget);
          expect(
              find.descendant(
                  of: footer, matching: find.byIcon(Icons.share_outlined)),
              findsOneWidget);
          // One row: all actions share a vertical centre.
          final y = tester.getCenter(start).dy;
          expect(tester.getCenter(reaction).dy, closeTo(y, 1));
          // Outline icon, not the colour emoji.
          expect(
              find.descendant(
                  of: reaction,
                  matching: find.byIcon(Icons.local_fire_department_outlined)),
              findsOneWidget);
          expect(find.text('🔥'), findsNothing);
        });
      }
    }
  });
}
