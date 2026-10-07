import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/path_progress_strip.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

/// The path the Topics tab leads with: Home's enrolled path when Home has
/// loaded one, else the enrolled path from [fallback] (the recommended-path
/// call Topics makes itself). Null when the user has no enrolled path.
ActivePathSummary? topicsPathSummary(
  HomeState home,
  RecommendedPathResult? fallback,
) {
  if (home is HomeCombinedState && home.activeLearningPath != null) {
    return home.activeLearningPath!.isEnrolled ? home.activePathSummary : null;
  }
  if (fallback != null && fallback.path.isEnrolled) return fallback.summary;
  return null;
}

/// The enrolled path behind [topicsPathSummary], when it is known.
LearningPath? topicsCurrentPath(
  HomeState home,
  RecommendedPathResult? fallback,
) {
  if (home is HomeCombinedState && home.activeLearningPath != null) {
    final path = home.activeLearningPath!;
    return path.isEnrolled ? path : null;
  }
  if (fallback != null && fallback.path.isEnrolled) return fallback.path;
  return null;
}

/// The top of the Topics tab: the path the user is on, its progress strip
/// and one "Continue" button that opens the next lesson.
///
/// Without a path ([summary] is null) it shows a "Start a path" button that
/// calls [onBrowse] instead of an empty strip. A finished path (no next
/// lesson) shows its strip and the same "Start a path" button.
class TopicsCurrentPathCard extends StatelessWidget {
  final ActivePathSummary? summary;
  final VoidCallback onContinue;
  final VoidCallback onSeePath;
  final VoidCallback onBrowse;

  const TopicsCurrentPathCard({
    super.key,
    required this.summary,
    required this.onContinue,
    required this.onSeePath,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null) return _StartAPath(onBrowse: onBrowse);
    final palette = ReaderPalette.of(context);
    final next = summary.next;
    return Column(
      key: const Key('topics_current_path_card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                summary.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('topics_current_path_see_path'),
              onPressed: onSeePath,
              style: TextButton.styleFrom(
                foregroundColor: palette.gold,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    AppFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr(TranslationKeys.homeTodaySeePath)),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PathProgressStrip(
          total: summary.lessonTotal,
          completed: summary.lessonsCompleted,
          current: next?.number ?? summary.lessonTotal,
          milestones: summary.milestoneNumbers,
          onTap: onSeePath,
        ),
        const SizedBox(height: 10),
        TopicsPrimaryButton(
          key: const Key('topics_current_path_continue'),
          label: context.tr(next == null
              ? TranslationKeys.topicsStartAPath
              : TranslationKeys.topicsContinue),
          onPressed: next == null ? onBrowse : onContinue,
        ),
      ],
    );
  }
}

/// No path yet: one button that opens every path.
class _StartAPath extends StatelessWidget {
  final VoidCallback onBrowse;

  const _StartAPath({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      key: const Key('topics_start_a_path'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.route_outlined, size: 21, color: palette.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TopicsPrimaryButton(
              label: context.tr(TranslationKeys.topicsStartAPath),
              onPressed: onBrowse,
            ),
          ),
        ],
      ),
    );
  }
}

/// 40px primary pill: white on dark, ink on light.
class TopicsPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const TopicsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: palette.ctaFill,
        foregroundColor: palette.ctaInk,
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
