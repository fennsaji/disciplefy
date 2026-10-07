import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/lesson_launch_from_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/choose_first_path_card.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/path_progress_strip.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/save_progress_row.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/today_lesson_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// Home's path block: the active path's header ("See path"), its progress
/// strip, "Lesson n of m" / "k to go", and today's lesson card; for a guest
/// also the "Save progress to your account" row.
///
/// Without a path (and not loading) it shows [ChooseFirstPathCard] instead,
/// never a lesson card.
class HomePathSection extends StatelessWidget {
  final ActivePathSummary? summary;
  final bool loading;
  final StudyMode mode;
  final ValueChanged<StudyMode> onModeChanged;

  const HomePathSection({
    super.key,
    required this.summary,
    required this.loading,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null) {
      return loading ? const _PathPlaceholder() : const ChooseFirstPathCard();
    }
    return _ActivePath(
      summary: summary,
      mode: mode,
      onModeChanged: onModeChanged,
    );
  }
}

class _ActivePath extends StatelessWidget {
  final ActivePathSummary summary;
  final StudyMode mode;
  final ValueChanged<StudyMode> onModeChanged;

  const _ActivePath({
    required this.summary,
    required this.mode,
    required this.onModeChanged,
  });

  void _openPath(BuildContext context) =>
      context.push<bool>('/learning-path/${summary.pathId}?source=home');

  void _start(BuildContext context) {
    final language = sl<TranslationService>().currentLanguage.code;
    context.push(buildLessonLaunchFromSummary(summary, mode, language));
  }

  Future<void> _chooseNextPath(BuildContext context) async {
    // A guest's second path needs an account; a full account goes straight on.
    final allowed = await requireAccount(context, AccountReason.secondPath);
    if (allowed && context.mounted) context.push(AppRoutes.studyTopics);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final next = summary.next;
    final total = summary.lessonTotal;
    final remaining = (total - summary.lessonsCompleted).clamp(0, total);
    final captionStyle = AppFonts.inter(fontSize: 12, color: palette.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                summary.displayTitle,
                maxLines: 1,
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
              onPressed: () => _openPath(context),
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
          total: total,
          completed: summary.lessonsCompleted,
          current: next?.number ?? total,
          milestones: summary.milestoneNumbers,
          onTap: () => _openPath(context),
        ),
        if (next != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(TranslationKeys.homeTodayLessonOf,
                        {'n': next.number, 'm': total}),
                    style: captionStyle,
                  ),
                ),
                if (remaining > 0)
                  Text(
                    context.tr(TranslationKeys.homeTodayToGo, {'k': remaining}),
                    style: captionStyle,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TodayLessonCard(
          summary: summary,
          mode: mode,
          onModeChanged: onModeChanged,
          onStart: () => _start(context),
          onChooseNextPath: () => _chooseNextPath(context),
        ),
        if (AccountGate.isActive) ...[
          const SizedBox(height: 10),
          SaveProgressRow(
            onTap: () => requireAccount(context, AccountReason.saveProgress),
          ),
        ],
      ],
    );
  }
}

/// Quiet block of the section's height while the path loads.
class _PathPlaceholder extends StatelessWidget {
  const _PathPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      key: const Key('home_path_placeholder'),
      height: 200,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
    );
  }
}
