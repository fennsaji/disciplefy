import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
                      const SizedBox(height: 64),
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: palette.gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 28, color: ReaderPalette.ink),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                      if (upNext.isNotEmpty) ...[
                        const SizedBox(height: 24),
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
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );

  ButtonStyle _outlinedStyle(ReaderPalette palette) => OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.outline),
        minimumSize: const Size.fromHeight(40),
        maximumSize: const Size.fromHeight(40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      );
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(TranslationKeys.lessonUpNext).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < topics.length; i++)
            InkWell(
              onTap: () => onTap(topics[i]),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == 0 ? palette.gold : palette.outline,
                        ),
                      ),
                      child: Text(
                        '${firstNumber + i}',
                        style: TextStyle(
                          fontSize: 12,
                          color: i == 0 ? palette.gold : palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        topics[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              i == 0 ? FontWeight.w600 : FontWeight.w400,
                          color: i == 0 ? palette.text : palette.muted,
                        ),
                      ),
                    ),
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
