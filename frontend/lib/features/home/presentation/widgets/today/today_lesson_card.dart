import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// Today's lesson in the active path: eyebrow, a Quick/Full mode chip, the
/// lesson title and one "Start lesson N" button.
///
/// When the path is finished it shows "You finished {path}" and a
/// "Choose your next path" button instead. When the next lesson is missing
/// but the path is not finished (partial data), it shows the path title and
/// a "See path" button.
///
/// The card owns no state: [mode] is chosen (and persisted) by the caller,
/// which [onModeChanged] notifies when the user picks another mode.
class TodayLessonCard extends StatelessWidget {
  final ActivePathSummary summary;
  final StudyMode mode;
  final ValueChanged<StudyMode> onModeChanged;
  final VoidCallback onStart;
  final VoidCallback? onChooseNextPath;

  /// Opens the path page (the fallback when no next lesson is known).
  final VoidCallback? onSeePath;

  const TodayLessonCard({
    super.key,
    required this.summary,
    required this.mode,
    required this.onModeChanged,
    required this.onStart,
    this.onChooseNextPath,
    this.onSeePath,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final next = summary.next;
    return Container(
      width: double.infinity,
      padding: next != null
          ? const EdgeInsets.fromLTRB(16, 16 - _ModeChip.slack, 16, 16)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        // A soft gold edge marks today's lesson as the one thing to do.
        border: Border.all(color: palette.gold.withValues(alpha: 0.33)),
      ),
      child: next != null
          ? _lesson(context, palette, next)
          : summary.isFinished
              ? _finished(context, palette)
              : _seePath(context, palette),
    );
  }

  TextStyle? _titleStyle(BuildContext context, ReaderPalette palette) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: palette.text,
          );

  Widget _lesson(BuildContext context, ReaderPalette palette, NextLesson next) {
    final theme = Theme.of(context);
    // The mode chip is drawn 26px tall inside a 40px tap row: the 7px above
    // and below it come out of the card's top padding and the next gap.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr(
                    TranslationKeys.homeTodayLessonEyebrow, {'n': next.number}),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: palette.gold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ModeChip(mode: mode, onChanged: onModeChanged),
          ],
        ),
        const SizedBox(height: 10 - _ModeChip.slack),
        Text(
          next.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _titleStyle(context, palette),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: palette.isDark ? palette.ctaFill : palette.text,
              foregroundColor: palette.isDark ? palette.ctaInk : Colors.white,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              textStyle: theme.textTheme.labelLarge
                  ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: Text(
              context
                  .tr(TranslationKeys.homeTodayStartLesson, {'n': next.number}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _finished(BuildContext context, ReaderPalette palette) =>
      _titleAndButton(
        context,
        palette,
        title: context.tr(TranslationKeys.homeTodayPathFinished,
            {'path': summary.displayTitle}),
        label: context.tr(TranslationKeys.homeTodayChooseNextPath),
        onPressed: onChooseNextPath,
      );

  Widget _seePath(BuildContext context, ReaderPalette palette) =>
      _titleAndButton(
        context,
        palette,
        title: summary.displayTitle,
        label: context.tr(TranslationKeys.homeTodaySeePath),
        onPressed: onSeePath,
      );

  Widget _titleAndButton(
    BuildContext context,
    ReaderPalette palette, {
    required String title,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: _titleStyle(context, palette)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.outline),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              textStyle: theme.textTheme.labelLarge
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}

String _modeLabel(BuildContext context, StudyMode mode) => context.tr(
      mode == StudyMode.quick
          ? TranslationKeys.homeTodayModeQuick
          : TranslationKeys.homeTodayModeStandard,
      {'min': mode.durationMinutes},
    );

/// A 26px outlined chip showing the current mode, in a 40px tap area; opens
/// a Quick/Full menu.
class _ModeChip extends StatefulWidget {
  final StudyMode mode;
  final ValueChanged<StudyMode> onChanged;

  const _ModeChip({required this.mode, required this.onChanged});

  /// Drawn height and the transparent tap margin above and below it.
  static const double height = 26;
  static const double slack = 7;

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  final _menuKey = GlobalKey<PopupMenuButtonState<StudyMode>>();

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final palette = ReaderPalette.of(context);
    // The design's warm grey, a shade darker on light so the label clears
    // the 5.5:1 chip floor (6.2:1 on white; the muted grey is 5.4:1).
    final ink = palette.isDark
        ? palette.muted
        : ReaderPalette.ink.withValues(alpha: 0.68);
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ink,
        );
    return PopupMenuButton<StudyMode>(
      key: _menuKey,
      initialValue: mode,
      // The chip shows its own label; no "Show menu" hover tip over it.
      tooltip: '',
      onSelected: (selected) {
        if (selected != widget.mode) widget.onChanged(selected);
      },
      color: palette.raised,
      itemBuilder: (context) => [
        for (final m in const [StudyMode.quick, StudyMode.standard])
          PopupMenuItem<StudyMode>(
            value: m,
            height: 40,
            child: Text(_modeLabel(context, m),
                style: labelStyle?.copyWith(
                  fontSize: 14,
                  color: palette.text,
                  fontWeight: m == mode ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _ModeChip.slack),
        child: Container(
          key: const Key('today_mode_chip'),
          height: _ModeChip.height,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_ModeChip.height / 2),
            border: Border.all(color: palette.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 12, color: ink),
              const SizedBox(width: 4),
              Text(_modeLabel(context, mode), style: labelStyle),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 14, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}
