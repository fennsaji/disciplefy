import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/study_guide_screen_v2.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';

/// Counts how many times its State is created and remembers the mode it was
/// first built with, like the reader's State does with its guide.
class _Probe extends StatefulWidget {
  final StudyMode mode;
  const _Probe({required this.mode});

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final StudyMode loadedMode = widget.mode;

  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) =>
      Text('loaded:${loadedMode.name} shown:${widget.mode.name}');
}

GoRouter _router({required bool keyed}) => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
        GoRoute(
          path: '/lesson',
          pageBuilder: (context, state) {
            final mode =
                studyModeFromString(state.uri.queryParameters['mode'])!;
            final probe = _Probe(mode: mode);
            return NoTransitionPage(
              key: state.pageKey,
              child: keyed
                  ? KeyedSubtree(
                      key: StudyGuideScreenV2.guideKey(
                        input: 'Who is Jesus Christ?',
                        type: 'topic',
                        studyMode: mode,
                      ),
                      child: probe,
                    )
                  : probe,
            );
          },
        ),
      ],
    );

Future<void> _openThenSwitch(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  // First-run lesson 1 is opened with `go`, not `push`.
  router.go('/lesson?mode=quick');
  await tester.pumpAndSettle();
  router.pushReplacement('/lesson?mode=standard');
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _Probe.created = 0);

  testWidgets(
      'go_router keeps the page of a go-opened lesson on pushReplacement, so '
      'the reader State survives a mode switch', (tester) async {
    await _openThenSwitch(tester, _router(keyed: false));

    // The cause of the bug: one State, still holding the quick guide.
    expect(_Probe.created, 1);
    expect(find.text('loaded:quick shown:standard'), findsOneWidget);
  });

  testWidgets('keying the reader by its guide restarts it in the new mode',
      (tester) async {
    await _openThenSwitch(tester, _router(keyed: true));

    expect(_Probe.created, 2);
    expect(find.text('loaded:standard shown:standard'), findsOneWidget);
  });

  testWidgets('StudyGuideScreenV2 keys its content by study mode',
      (tester) async {
    late Widget quick;
    late Widget standard;
    late Widget quickAgain;
    await tester.pumpWidget(Builder(builder: (context) {
      quick = const StudyGuideScreenV2(
              input: 'Who is Jesus Christ?',
              type: 'topic',
              studyMode: StudyMode.quick)
          .build(context);
      // Standard is the default mode.
      standard =
          const StudyGuideScreenV2(input: 'Who is Jesus Christ?', type: 'topic')
              .build(context);
      quickAgain = const StudyGuideScreenV2(
              input: 'Who is Jesus Christ?',
              type: 'topic',
              studyMode: StudyMode.quick)
          .build(context);
      return const SizedBox();
    }));

    expect(quick.key, isNotNull);
    expect(quick.key, isNot(standard.key));
    expect(quick.key, quickAgain.key);
  });

  group('lessonModeLocation', () {
    const base = '/study-guide-v2?input=Who+is+Jesus+Christ%3F&type=topic'
        '&mode=quick&path_id=p1&lesson_number=1&lesson_total=8';

    test('sets the new mode, keeps the lesson query and records the old one',
        () {
      final uri = Uri.parse(lessonModeLocation(
          Uri.parse(base), StudyMode.standard,
          from: StudyMode.quick));
      expect(uri.path, '/study-guide-v2');
      expect(uri.queryParameters['mode'], 'standard');
      expect(uri.queryParameters['from_mode'], 'quick');
      expect(uri.queryParameters['input'], 'Who is Jesus Christ?');
      expect(uri.queryParameters['lesson_total'], '8');
    });

    test('drops the recorded mode when returning without one', () {
      final switched = lessonModeLocation(Uri.parse(base), StudyMode.standard,
          from: StudyMode.quick);
      final back =
          Uri.parse(lessonModeLocation(Uri.parse(switched), StudyMode.quick));
      expect(back.queryParameters['mode'], 'quick');
      expect(back.queryParameters.containsKey('from_mode'), isFalse);
    });
  });
}
