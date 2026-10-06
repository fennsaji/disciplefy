import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// Today's lesson in the active path: eyebrow, a Quick/Full mode chip, the
/// lesson title and one "Start lesson N" button.
///
/// When the path has no next lesson it shows "You finished {path}" and a
/// "Choose your next path" button instead.
///
/// The card owns no state: [mode] is chosen (and persisted) by the caller,
/// which [onModeChanged] notifies when the user picks another mode.
class TodayLessonCard extends StatelessWidget {
  final ActivePathSummary summary;
  final StudyMode mode;
  final ValueChanged<StudyMode> onModeChanged;
  final VoidCallback onStart;
  final VoidCallback? onChooseNextPath;

  const TodayLessonCard({
    super.key,
    required this.summary,
    required this.mode,
    required this.onModeChanged,
    required this.onStart,
    this.onChooseNextPath,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final next = summary.next;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: next == null
          ? _finished(context, palette)
          : _lesson(context, palette, next),
    );
  }

  TextStyle? _titleStyle(BuildContext context, ReaderPalette palette) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: palette.text,
          );

  Widget _lesson(BuildContext context, ReaderPalette palette, NextLesson next) {
    final theme = Theme.of(context);
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: palette.gold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ModeChip(mode: mode, onChanged: onModeChanged),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          next.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _titleStyle(context, palette),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: palette.isDark ? palette.ctaFill : palette.gold,
              foregroundColor: palette.isDark ? palette.ctaInk : Colors.white,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              textStyle: theme.textTheme.labelLarge
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
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

  Widget _finished(BuildContext context, ReaderPalette palette) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr(TranslationKeys.homeTodayPathFinished,
              {'path': summary.displayTitle}),
          style: _titleStyle(context, palette),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: onChooseNextPath,
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
            child: Text(context.tr(TranslationKeys.homeTodayChooseNextPath)),
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

/// 32px outlined chip showing the current mode; opens a Quick/Full menu.
class _ModeChip extends StatefulWidget {
  final StudyMode mode;
  final ValueChanged<StudyMode> onChanged;

  const _ModeChip({required this.mode, required this.onChanged});

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  final _menuKey = GlobalKey<PopupMenuButtonState<StudyMode>>();

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final palette = ReaderPalette.of(context);
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: palette.text,
        );
    return PopupMenuButton<StudyMode>(
      key: _menuKey,
      initialValue: mode,
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
                  fontWeight: m == mode ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
      ],
      child: SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: () => _menuKey.currentState?.showButtonMenu(),
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.text,
            side: BorderSide(color: palette.outline),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 14, color: palette.gold),
              const SizedBox(width: 4),
              Text(_modeLabel(context, mode), style: labelStyle),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 16, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
