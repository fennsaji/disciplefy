import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/tap_guard.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/lesson_launch_from_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/choose_first_path_card.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/today_lesson_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/next_paths_card.dart';

/// Home's path block: the active path's header ("See path") above one card
/// holding its progress strip and today's lesson ([TodayLessonCard]).
///
/// Without a path (and not loading) it shows [ChooseFirstPathCard] instead,
/// never a lesson card. A finished path is followed by "What next?"
/// ([NextPathsCard]).
class HomePathSection extends StatelessWidget {
  final ActivePathSummary? summary;
  final bool loading;
  final StudyMode mode;

  /// Called on return from a lesson, or from the path page when it reports
  /// a change, so Home can refresh the path's progress.
  final VoidCallback? onProgressMayHaveChanged;

  const HomePathSection({
    super.key,
    required this.summary,
    required this.loading,
    required this.mode,
    this.onProgressMayHaveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null) {
      return loading
          ? const _PathPlaceholder()
          : ChooseFirstPathCard(onPathChanged: onProgressMayHaveChanged);
    }
    return _ActivePath(
      summary: summary,
      mode: mode,
      onProgressMayHaveChanged: onProgressMayHaveChanged,
    );
  }
}

class _ActivePath extends StatefulWidget {
  final ActivePathSummary summary;
  final StudyMode mode;
  final VoidCallback? onProgressMayHaveChanged;

  const _ActivePath({
    required this.summary,
    required this.mode,
    this.onProgressMayHaveChanged,
  });

  @override
  State<_ActivePath> createState() => _ActivePathState();
}

class _ActivePathState extends State<_ActivePath> {
  /// Ignores a quick second tap (a double tap would push twice). Never held
  /// across the awaited push, which go_router may never complete.
  final TapGuard _tapGuard = TapGuard();

  @override
  void dispose() {
    _tapGuard.dispose();
    super.dispose();
  }

  Future<void> _openPath(BuildContext context) async {
    if (!_tapGuard.tryAcquire()) return;
    final changed = await context
        .push<bool>('/learning-path/${widget.summary.pathId}?source=home');
    if (changed == true) widget.onProgressMayHaveChanged?.call();
  }

  Future<void> _start(BuildContext context) async {
    if (!_tapGuard.tryAcquire()) return;
    final language = sl<TranslationService>().currentLanguage.code;
    await context.push(
        buildLessonLaunchFromSummary(widget.summary, widget.mode, language));
    widget.onProgressMayHaveChanged?.call();
  }

  Future<void> _chooseNextPath(BuildContext context) async {
    // A guest's second path needs an account; a full account goes straight on.
    final allowed = await requireAccount(context, AccountReason.secondPath);
    if (allowed && context.mounted) context.push(AppRoutes.studyTopics);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final palette = ReaderPalette.of(context);
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
                style: AppFonts.inter(
                  fontSize: 16,
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
                // 40px tall to tap; the gap under the header is dropped so
                // the card moves by 2px only.
                minimumSize: const Size(0, 40),
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
        TodayLessonCard(
          summary: summary,
          mode: widget.mode,
          onStart: () => _start(context),
          onChooseNextPath: () => _chooseNextPath(context),
          onSeePath: () => _openPath(context),
        ),
        if (summary.isFinished) ...[
          const SizedBox(height: 12),
          NextPathsCard(
            key: const Key('home_what_next'),
            excludePathId: summary.pathId,
            onPathChanged: widget.onProgressMayHaveChanged,
          ),
        ],
      ],
    );
  }
}

/// Skeleton of the section (header, then one card for the strip and lesson)
/// while the path loads: the loaded section's height, so nothing jumps.
class _PathPlaceholder extends StatelessWidget {
  const _PathPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final bone = palette.hairline;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bone,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    BoxDecoration card() => BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.hairline),
        );
    return Semantics(
      label: context.tr(TranslationKeys.homeTodayLoadingPath),
      child: Column(
        key: const Key('home_path_placeholder'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: bar(160, 14),
          ),
          const SizedBox(height: 6),
          // One card: the strip, then eyebrow, title and button.
          Container(
            height: 192,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(double.infinity, 28),
                const SizedBox(height: 22),
                bar(110, 10),
                const SizedBox(height: 14),
                bar(200, 16),
                const Spacer(),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: bone,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
