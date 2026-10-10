// Scroll performance of the study guide reader on a real device.
//
// Opens StudyGuideScreenV2 with a long synthetic guide (a Malayalam Deep Dive
// of ~18k characters and an English Sermon Outline) passed as
// `existingGuideData`, so no network or LLM call is made, then flings the
// reader top -> bottom -> top several times while recording frame timings.
//
// Run on an Android EMULATOR in profile mode (never a physical phone):
//
//   cd frontend
//   flutter emulators --launch Pixel_3a_API_34_GooglePlay
//   flutter devices                      # note the emulator-XXXX id
//   flutter drive --profile --no-dds \
//     --dart-define-from-file=.env.android \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/study_guide_scroll_perf_test.dart \
//     -d emulator-5554
//
// Printed per guide (full data in build/integration_response_data.json):
//   *_open_ms          pumpWidget -> guide laid out and settled
//   *_idle_frames_3s   frames drawn in 3 s at rest (should be ~0)
//   *_frames           FrameTiming stats (watchPerformance): average, 90th
//                      and 99th percentile build / raster ms, missed budgets
//   *_cadence          frames per second while scrolling, total-span
//                      percentiles, and 25-100 ms gaps between presented
//                      frames (visible stutters)
// Emulator raster times swing between runs (the GPU blocks on buffer
// swaps); compare build times, fps and stutter gaps across commits.
//
// Supabase is initialised against an unreachable address so any background
// request the screen makes fails fast instead of reaching a server.

import 'dart:ui' show FramePhase, FrameTiming;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/navigation/study_navigator.dart';
import 'package:disciplefy_bible_study/core/services/font_scale_service.dart';
import 'package:disciplefy_bible_study/core/services/theme_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/saved_guides/data/models/saved_guide_model_adapter.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_bloc.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/study_guide_screen_v2.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

/// ~450 Malayalam characters with two scripture references.
String _ml(String tag, int i) =>
    '$tag $i. ദൈവം ലോകത്തെ ഇത്രയധികം സ്നേഹിച്ചതിനാൽ '
    'തന്റെ ഏകജാതനായ പുത്രനെ നൽകി (യോഹന്നാൻ 3:16). അവനിൽ വിശ്വസിക്കുന്ന '
    'ഏവനും നശിച്ചുപോകാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിനു തന്നേ. ഈ സ്നേഹം '
    'നമ്മുടെ യോഗ്യതയെ ആശ്രയിക്കുന്നില്ല; അത് ദൈവത്തിന്റെ കൃപയാണ് '
    '(റോമർ 5:8). ക്രിസ്തു നമുക്കുവേണ്ടി മരിച്ചതിനാൽ ദൈവം നമ്മോടുള്ള '
    'തന്റെ സ്നേഹം പ്രദർശിപ്പിക്കുന്നു, അതുകൊണ്ട് നാം അനുതപിച്ച് '
    'അവനിലേക്ക് തിരിയുന്നു.';

/// ~400 English characters with a scripture reference.
String _en(String tag, int i) => '$tag $i. The good news is not advice but '
    'an announcement: Christ died for our sins according to the Scriptures, '
    'was buried, and was raised on the third day (1 Corinthians 15:3-4). '
    'Because of this, the preacher calls hearers to repent and believe, '
    'trusting not in their own works but in the finished work of Jesus, who '
    'is able to save completely those who come to God through Him '
    '(Hebrews 7:25).';

String _paras(String Function(String, int) p, String tag, int n) =>
    [for (var i = 0; i < n; i++) p(tag, i)].join('\n\n');

Map<String, dynamic> _malayalamDeepDive() => {
      'id': 'perf-ml-deep',
      'type': 'scripture',
      'verse_reference': 'യോഹന്നാൻ 3:16',
      'summary': _paras(_ml, 'സംഗ്രഹം', 4),
      'context': _paras(_ml, 'പശ്ചാത്തലം', 6),
      'interpretation': [
        _paras(_ml, 'വ്യാഖ്യാനം', 8),
        '## പ്രധാന പാഠങ്ങൾ',
        [for (var i = 1; i <= 6; i++) '$i. ${_ml('പാഠം', i)}'].join('\n'),
        _paras(_ml, 'പ്രയോഗം', 6),
      ].join('\n\n'),
      'related_verses': [for (var i = 0; i < 8; i++) _ml('വാക്യം', i)],
      'reflection_questions': [for (var i = 0; i < 6; i++) _ml('ചോദ്യം', i)],
      'prayer_points': [for (var i = 0; i < 5; i++) _ml('പ്രാർത്ഥന', i)],
      'is_saved': false,
    };

Map<String, dynamic> _englishSermon() => {
      'id': 'perf-en-sermon',
      'type': 'scripture',
      'verse_reference': '1 Corinthians 15:1-8',
      'summary': _paras(_en, 'Thesis', 3),
      'context': _paras(_en, 'Background', 5),
      'interpretation': [
        for (var point = 1; point <= 4; point++) ...[
          '## Point $point: The gospel we received (10 minutes)',
          _paras(_en, 'Exposition $point', 4),
          [for (var i = 1; i <= 4; i++) '- ${_en('Illustration $point', i)}']
              .join('\n'),
          '**Application:** ${_en('Apply $point', 0)}',
        ],
        '## Altar call',
        _paras(_en, 'Invitation', 3),
      ].join('\n\n'),
      'related_verses': [for (var i = 0; i < 8; i++) _en('Verse', i)],
      'reflection_questions': [for (var i = 0; i < 6; i++) _en('Question', i)],
      'prayer_points': [for (var i = 0; i < 5; i++) _en('Prayer', i)],
      'is_saved': false,
    };

int _chars(Map<String, dynamic> g) => [
      g['summary'],
      g['context'],
      g['interpretation'],
      ...(g['related_verses'] as List),
      ...(g['reflection_questions'] as List),
      ...(g['prayer_points'] as List),
    ].fold<int>(0, (n, s) => n + (s as String).length);

Future<void> _bootApp() async {
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(SavedGuideModelAdapter());
  }
  await Hive.openBox('app_settings');
  await Hive.openBox<dynamic>('nux_events');
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Push and crash reporting are not needed to read a guide.
  }
  await Supabase.initialize(
    url: 'http://127.0.0.1:9',
    anonKey: 'perf-test-anon-key',
  );
  await initializeDependencies();
  await Future.wait([
    sl<ThemeService>().initialize(),
    sl<TranslationService>().ensureCurrentLanguageLoaded(),
    sl<FontScaleService>().initialize(),
  ]);
  // No first-run walkthrough overlays over the reader.
  for (final screen in WalkthroughScreen.values) {
    await sl<WalkthroughRepository>().markSeen(screen);
  }
}

Widget _reader(Map<String, dynamic> guide, StudyMode mode, String language) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => StudyGuideScreenV2(
        input: guide['verse_reference'] as String,
        type: 'scripture',
        language: language,
        studyMode: mode,
        navigationSource: StudyNavigationSource.saved,
        existingGuideData: guide,
      ),
    ),
  ]);
  return MultiBlocProvider(
    providers: [
      BlocProvider<ConnectivityBloc>(create: (_) => sl<ConnectivityBloc>()),
      BlocProvider<StudyBloc>(create: (_) => sl<StudyBloc>()),
      BlocProvider<TokenBloc>(create: (_) => sl<TokenBloc>()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// The reader's own vertical scroll view: the tallest vertical Scrollable.
ScrollableState _readerScrollable(WidgetTester tester) {
  final states = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) => s.position.axis == Axis.vertical)
      .toList()
    ..sort((a, b) =>
        b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent));
  return states.first;
}

/// Lets a fling run out, pumping real frames for up to [max].
Future<void> _settle(WidgetTester tester,
    {Duration max = const Duration(milliseconds: 1600)}) async {
  final end = DateTime.now().add(max);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
    if (!tester.binding.hasScheduledFrame) break;
  }
}

Future<void> _scrollTopToBottomToTop(WidgetTester tester, int rounds) async {
  for (var round = 0; round < rounds; round++) {
    for (final down in [true, false]) {
      for (var flings = 0; flings < 60; flings++) {
        final position = _readerScrollable(tester).position;
        final done = down
            ? position.pixels >= position.maxScrollExtent - 1
            : position.pixels <= position.minScrollExtent + 1;
        if (done) break;
        final viewport =
            tester.getRect(find.byWidget(_readerScrollable(tester).widget));
        await tester.flingFrom(
          viewport.center,
          Offset(0, down ? -500 : 500),
          4000,
        );
        await _settle(tester);
      }
    }
  }
}

/// Real frame cadence while scrolling, from the engine's FrameTimings: how
/// many frames reached the screen per second and how often the gap between
/// two consecutive frames was long enough to show as a stutter.
class _FrameRecorder {
  final List<FrameTiming> _timings = [];

  void _add(List<FrameTiming> timings) => _timings.addAll(timings);

  void start() => SchedulerBinding.instance.addTimingsCallback(_add);

  Future<Map<String, dynamic>> stop(Duration elapsed) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    SchedulerBinding.instance.removeTimingsCallback(_add);
    int us(FrameTiming t, FramePhase p) => t.timestampInMicroseconds(p);
    final spans = [
      for (final t in _timings) t.totalSpan.inMicroseconds / 1000.0,
    ]..sort();
    // Gaps between consecutive frames' presentation (raster finish). One
    // vsync is ~16.7 ms; a gap of 2–6 vsyncs mid-scroll is a visible
    // stutter (longer gaps are pauses between flings, not jank).
    var stutters = 0;
    for (var i = 1; i < _timings.length; i++) {
      final gap = (us(_timings[i], FramePhase.rasterFinish) -
              us(_timings[i - 1], FramePhase.rasterFinish)) /
          1000.0;
      if (gap > 25 && gap < 100) stutters++;
    }
    double pct(double p) =>
        spans.isEmpty ? 0 : spans[((spans.length - 1) * p / 100).round()];
    return {
      'frames': _timings.length,
      'seconds': elapsed.inMilliseconds / 1000.0,
      'fps': _timings.length / (elapsed.inMilliseconds / 1000.0),
      'total_span_p50_ms': pct(50),
      'total_span_p90_ms': pct(90),
      'total_span_p99_ms': pct(99),
      'stutter_gaps_25_100ms': stutters,
    };
  }
}

/// Frames the engine draws in [period] with no input.
Future<int> _countFrames(Duration period) async {
  var frames = 0;
  void count(List<FrameTiming> timings) => frames += timings.length;
  SchedulerBinding.instance.addTimingsCallback(count);
  await Future<void>.delayed(period);
  // Timings are reported in batches; let the last batch arrive.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  SchedulerBinding.instance.removeTimingsCallback(count);
  return frames;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('study guide reader scrolls smoothly', (tester) async {
    await _bootApp();

    final cases = <(String, Map<String, dynamic>, StudyMode, String)>[
      ('study_guide_ml_deep', _malayalamDeepDive(), StudyMode.deep, 'ml'),
      ('study_guide_en_sermon', _englishSermon(), StudyMode.sermon, 'en'),
    ];

    for (final (key, guide, mode, language) in cases) {
      final open = Stopwatch()..start();
      await tester.pumpWidget(_reader(guide, mode, language));
      // Until the guide text is laid out.
      while (find
              .textContaining(guide['verse_reference'] as String)
              .evaluate()
              .isEmpty &&
          open.elapsed < const Duration(seconds: 15)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await _settle(tester, max: const Duration(seconds: 2));
      open.stop();
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['${key}_open_ms'] = open.elapsedMilliseconds;
      binding.reportData!['${key}_chars'] = _chars(guide);

      // Only frames the framework or engine asks for, as on a real device:
      // no extra frames from the test's own pumps.
      binding.framePolicy =
          LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
      // Three idle seconds: a reader at rest should draw (almost) nothing.
      binding.reportData!['${key}_idle_frames_3s'] =
          await _countFrames(const Duration(seconds: 3));
      final recorder = _FrameRecorder()..start();
      final scrolling = Stopwatch()..start();
      await binding.watchPerformance(
        () => _scrollTopToBottomToTop(tester, 3),
        reportKey: '${key}_frames',
      );
      scrolling.stop();
      binding.reportData!['${key}_cadence'] =
          await recorder.stop(scrolling.elapsed);
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      // Back at the top after three full round trips.
      expect(_readerScrollable(tester).position.pixels, lessThan(1));

      // Dispose the reader before the next guide.
      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester, max: const Duration(milliseconds: 500));
    }
  });
}
