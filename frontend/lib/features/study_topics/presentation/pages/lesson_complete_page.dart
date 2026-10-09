import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/utils/achievement_popup_gate.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_event.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/first_run_flags.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/study_topics_refresh_requests.dart';

/// What the Lesson complete page needs to know about the finished lesson.
class LessonCompleteArgs {
  final LessonRef lesson;
  final String lessonTitle;
  final StudyMode mode;
  final String language;

  /// Lesson 1 opened from the first run (`first_run=1`).
  final bool firstRun;

  const LessonCompleteArgs({
    required this.lesson,
    required this.lessonTitle,
    required this.mode,
    required this.language,
    this.firstRun = false,
  });
}

/// Full-screen "Lesson N complete" page with the next lessons and a one-tap
/// way into the next one. No day gate: the next lesson opens immediately.
class LessonCompletePage extends StatefulWidget {
  final LessonCompleteArgs args;

  /// Extra blocks shown between the Up next card and the buttons.
  final List<Widget> extraSections;

  const LessonCompletePage({
    super.key,
    required this.args,
    this.extraSections = const [],
  });

  @override
  State<LessonCompletePage> createState() => _LessonCompletePageState();
}

class _LessonCompletePageState extends State<LessonCompletePage> {
  LearningPathDetail? _path;
  bool _popupsScheduled = false;

  @override
  void initState() {
    super.initState();
    unawaited(FirstRunFlags.markFirstLessonCompleted());
    _refreshProgressViews();
    sl<LearningPathsRepository>()
        .getLearningPathDetails(
          pathId: widget.args.lesson.pathId,
          language: widget.args.language,
          forceRefresh: true,
        )
        .then((r) => r.fold(
              (f) => Logger.warning(
                  '[LESSON_COMPLETE] path load failed: ${f.message}'),
              (p) {
                if (mounted) setState(() => _path = p);
              },
            ));
  }

  /// The lesson's progress is saved before this page opens. Home and Topics
  /// would only refresh when their push returns, which never happens here:
  /// the lesson was replaced by this page, and Back home uses `go`.
  void _refreshProgressViews() {
    if (sl.isRegistered<HomeBloc>()) {
      sl<HomeBloc>().add(const LoadActiveLearningPath(forceRefresh: true));
    }
    StudyTopicsRefreshRequests.instance.request();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_popupsScheduled) return;
    _popupsScheduled = true;
    // Achievement pop-ups waited through the lesson; they may show once
    // this page has finished sliding in.
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _releasePopups());
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(onStatus);
      _releasePopups();
    }

    animation.addStatusListener(onStatus);
  }

  /// A guest's page carries the sign-up block, which a pop-up must not
  /// cover: theirs wait until they leave the page.
  void _releasePopups() {
    if (!mounted || AccountGate.isActive) return;
    AchievementPopupGate.release();
  }

  @override
  void dispose() {
    AchievementPopupGate.endRelease();
    // Shown on the next route unless it holds them (another lesson).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => AchievementPopupGate.flush());
    super.dispose();
  }

  List<LearningPathTopic> get _upNext {
    final p = _path;
    if (p == null) return const [];
    final ordered = [...p.topics]
      ..sort((a, b) => a.position.compareTo(b.position));
    return ordered.skip(widget.args.lesson.lessonNumber).take(2).toList();
  }

  Future<void> _open(LearningPathTopic topic) async {
    final path = _path;
    if (path == null) return;
    final mode = await resolveNextLessonMode();
    if (!mounted) return;
    context.pushReplacement(buildLessonLaunchLocation(
      path: path,
      topic: topic,
      mode: mode,
      language: widget.args.language,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final primaryFill = palette.isDark ? palette.ctaFill : palette.selectedFill;
    final lesson = widget.args.lesson;
    final upNext = lesson.isLast ? const <LearningPathTopic>[] : _upNext;
    final title = lesson.isLast
        ? context
            .tr(TranslationKeys.lessonPathFinished, {'path': lesson.pathTitle})
        : context.tr(
            TranslationKeys.lessonCompleteTitle, {'n': lesson.lessonNumber});
    final subtitle = '${widget.args.lessonTitle} · '
        '${context.tr(TranslationKeys.lessonEyebrow, {
          'n': lesson.lessonNumber,
          'total': lesson.lessonTotal,
        })}';

    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const LessonCompleteCelebration(),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppFonts.poppins(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: palette.muted),
                      ),
                      if (upNext.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _UpNextCard(
                          topics: upNext,
                          firstNumber: lesson.lessonNumber + 1,
                          onTap: _open,
                        ),
                      ],
                      ...widget.extraSections,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!lesson.isLast && upNext.isNotEmpty) ...[
                FilledButton(
                  onPressed: () => _open(upNext.first),
                  style: _buttonStyle(
                    primaryFill,
                    ReaderPalette.ink,
                  ),
                  child: Text(
                    context.tr(TranslationKeys.lessonContinueTo,
                        {'n': lesson.lessonNumber + 1}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  style: _outlinedStyle(palette),
                  child: Text(context.tr(TranslationKeys.lessonBackHome),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ] else
                FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  style: _buttonStyle(primaryFill, ReaderPalette.ink),
                  child: Text(context.tr(TranslationKeys.lessonBackHome),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color bg, Color fg) => FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size.fromHeight(40),
        maximumSize: const Size.fromHeight(40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );

  ButtonStyle _outlinedStyle(ReaderPalette palette) => OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.outline),
        minimumSize: const Size.fromHeight(40),
        maximumSize: const Size.fromHeight(40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );
}

/// The gold check in a scatter of confetti. On open the check pops, then the
/// confetti bursts outward from it once and rests. Reduced motion shows the
/// final state at once.
class LessonCompleteCelebration extends StatefulWidget {
  const LessonCompleteCelebration({super.key});

  @override
  State<LessonCompleteCelebration> createState() =>
      _LessonCompleteCelebrationState();
}

class _LessonCompleteCelebrationState extends State<LessonCompleteCelebration>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 1250.0;
  static const _checkMs = 500.0;
  static const _burstStartMs = 300.0;
  static const _burstMs = 700.0;
  static const _centre = Offset(175, 60);

  /// x, y (in a 350 x 120 band), width, height, rotation in degrees, tone.
  static const _pieces = <(double, double, double, double, double, int)>[
    (20, 8, 8, 4, 0, 0),
    (103, 46, 9, 10, 37, 1),
    (186, 85, 10, 7, 74, 2),
    (269, 8, 9, 7, 21, 0),
    (22, 48, 10, 9, 58, 1),
    (105, 93, 6, 9, 5, 2),
    (188, 9, 9, 8, 42, 0),
    (271, 50, 10, 7, 79, 1),
    (24, 94, 8, 10, 26, 2),
    (107, 10, 7, 9, 63, 0),
    (273, 95, 10, 10, 47, 2),
    (26, 12, 5, 8, 84, 0),
    (192, 97, 10, 8, 68, 2),
    (275, 21, 9, 6, 15, 0),
    (28, 60, 10, 9, 52, 1),
    (111, 100, 9, 5, 89, 2),
  ];

  static const _tones = [
    AppColors.brandGold,
    Color(0xFFFFEEC0),
    Color(0xFFB8860B),
  ];

  // Per piece, computed once: rest centre offset from the check centre and the
  // stagger interval within the controller's 0..1 range.
  static final _offsets = <Offset>[
    for (final p in _pieces)
      Offset(p.$1 + 20 + p.$3 / 2, p.$2 + p.$4 / 2) - _centre,
  ];
  static final _intervals = <Interval>[
    for (var i = 0; i < _pieces.length; i++)
      () {
        final delay = (i * 250 / (_pieces.length - 1));
        final begin = _burstStartMs + delay;
        return Interval(begin / _totalMs, (begin + _burstMs) / _totalMs,
            curve: Curves.easeOutCubic);
      }(),
  ];
  static const _checkInterval =
      Interval(0, _checkMs / _totalMs, curve: Curves.easeOutBack);
  static const _fadeInterval = Interval(0, 0.2, curve: Curves.easeOut);
  static const _ringInterval = Interval(0.15, 0.6, curve: Curves.easeOut);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true;
    if (reduce) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: 350,
          height: 120,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final v = _controller.value;
              final checkScale = _checkInterval.transform(v) * 1.0;
              final ring = _ringInterval.transform(v);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < _pieces.length; i++)
                    _piece(i, _intervals[i].transform(v)),
                  Positioned(
                    left: 143,
                    top: 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (v > 0 && v < 1)
                          Positioned.fill(
                            child: Transform.scale(
                              scale: 1 + 0.6 * ring,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.selectedFill
                                        .withValues(alpha: 0.4 * (1 - ring)),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Opacity(
                          opacity: _fadeInterval.transform(v).clamp(0.0, 1.0),
                          child: Transform.scale(
                            key: const Key('lesson_complete_check_scale'),
                            scale: checkScale,
                            child: Container(
                              key: const Key('lesson_complete_check'),
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: palette.selectedFill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded,
                                  size: 30, color: palette.onSelected),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _piece(int i, double t) {
    final (x, y, w, h, deg, tone) = _pieces[i];
    return Positioned(
      left: x + 20,
      top: y,
      child: Transform.translate(
        offset: _offsets[i] * -(1 - t),
        child: Transform.scale(
          scale: t,
          child: Transform.rotate(
            angle: (deg + (1 - t) * -90) * math.pi / 180,
            child: Container(
              key: Key('lesson_complete_confetti_$i'),
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: _tones[tone],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpNextCard extends StatelessWidget {
  final List<LearningPathTopic> topics;
  final int firstNumber;
  final ValueChanged<LearningPathTopic> onTap;

  const _UpNextCard({
    required this.topics,
    required this.firstNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(TranslationKeys.lessonUpNext).toUpperCase(),
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < topics.length; i++)
            InkWell(
              onTap: () => onTap(topics[i]),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0 ? null : palette.raised,
                        border: i == 0 ? Border.all(color: palette.gold) : null,
                      ),
                      child: Text(
                        '${firstNumber + i}',
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: i == 0 ? palette.gold : palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        topics[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight:
                              i == 0 ? FontWeight.w600 : FontWeight.w500,
                          color: i == 0 ? palette.text : palette.muted,
                        ),
                      ),
                    ),
                    if (i == 0)
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: palette.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
