import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/path_progress_strip.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';

/// The active path's one card on Home and Topics: its progress strip on top
/// (tapping it opens the path), then today's lesson: eyebrow, a Quick/Full
/// mode chip, the lesson title and one "Start lesson N" button.
///
/// When the path is finished the strip is all checked and the card shows
/// "You finished {path}" and a "Choose your next path" button instead. When
/// the next lesson is missing but the path is not finished (partial data),
/// it shows the path title and a "See path" button.
///
/// The card owns no state: [mode] is worked out by the caller and shown as
/// a label; it is changed in the study mode setting, not on the card.
class TodayLessonCard extends StatelessWidget {
  final ActivePathSummary summary;
  final StudyMode mode;
  final VoidCallback onStart;
  final VoidCallback? onChooseNextPath;

  /// Opens the path page: from the strip, and as the fallback button when
  /// no next lesson is known.
  final VoidCallback? onSeePath;

  const TodayLessonCard({
    super.key,
    required this.summary,
    required this.mode,
    required this.onStart,
    this.onChooseNextPath,
    this.onSeePath,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final next = summary.next;
    final total = summary.lessonTotal;
    final remaining = (total - summary.lessonsCompleted).clamp(0, total);
    return Container(
      key: const Key('today_path_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        // A soft gold edge marks today's lesson as the one thing to do.
        border: Border.all(color: palette.gold.withValues(alpha: 0.33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PathProgressStrip(
            total: total,
            completed: summary.lessonsCompleted,
            current: summary.currentLessonNumber,
            milestones: summary.milestoneNumbers,
            onTap: onSeePath,
            // Long paths say where you are under the bar; dots show it.
            lessonLabel: next == null
                ? null
                : context.tr(TranslationKeys.homeTodayLessonOf,
                    {'n': next.number, 'm': total}),
            toGoLabel: remaining > 0
                ? context.tr(TranslationKeys.homeTodayToGo, {'k': remaining})
                : null,
          ),
          // The mode chip's 7px tap margin adds to the gap above the eyebrow.
          SizedBox(height: next != null ? 4 : 10),
          if (next != null)
            _lesson(context, palette, next)
          else if (summary.isFinished)
            _finished(context, palette)
          else
            _seePath(context, palette),
        ],
      ),
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
    // and below it come out of the gap under the strip and the next gap.
    final eyebrow =
        context.tr(TranslationKeys.homeTodayLessonEyebrow, {'n': next.number});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EyebrowRow(
          eyebrow: eyebrow,
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            // Wide tracking only suits Latin caps; Devanagari and
            // Malayalam need the room to stay on one line.
            letterSpacing:
                RegExp(r'^[\x00-\x7F·]*$').hasMatch(eyebrow) ? 1.6 : 0.3,
            color: palette.gold,
          ),
          chipWidth: _ModeChip.widthFor(context, mode),
          chip: _ModeChip(mode: mode),
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

/// "Quick Read · 3 min" / "Standard · 8 min"; a deeper saved depth is named
/// as itself (e.g. "Deep Dive · 12 min"), never as Standard.
String _modeLabel(BuildContext context, StudyMode mode) => switch (mode) {
      StudyMode.quick => context.tr(
          TranslationKeys.homeTodayModeQuick, {'min': mode.durationMinutes}),
      StudyMode.standard => context.tr(
          TranslationKeys.homeTodayModeStandard, {'min': mode.durationMinutes}),
      _ =>
        '${mode.localizedShortName(context)} · ${mode.localizedShortDuration(context)}',
    };

/// The "TODAY · LESSON N" eyebrow with the mode chip at the row's end.
///
/// The eyebrow never wraps: when the eyebrow and the chip do not both fit on
/// one line (narrow phones, large text), the chip moves under the eyebrow,
/// whole; an eyebrow wider than the card on its own is scaled down.
class _EyebrowRow extends StatelessWidget {
  static const double _gap = 8;

  final String eyebrow;
  final TextStyle? style;
  final double chipWidth;
  final Widget chip;

  const _EyebrowRow({
    required this.eyebrow,
    required this.style,
    required this.chipWidth,
    required this.chip,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(eyebrow, style: style, maxLines: 1, softWrap: false);
    return LayoutBuilder(builder: (context, constraints) {
      final eyebrowWidth = _textWidth(context, eyebrow, style);
      if (eyebrowWidth + _gap + chipWidth <= constraints.maxWidth) {
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: _gap),
            chip,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The chip's tap margin keeps the eyebrow clear of the strip.
          const SizedBox(height: _ModeChip.slack),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: label,
          ),
          chip,
        ],
      );
    });
  }
}

/// Width of [text] on one line in [style], at the current text scale.
double _textWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width.ceilToDouble();
}

/// A 26px outlined chip showing the current mode, in a 40px tap area; opens
/// a Quick/Full menu.
class _ModeChip extends StatefulWidget {
  final StudyMode mode;

  const _ModeChip({required this.mode});

  /// Drawn height and the transparent tap margin above and below it.
  static const double height = 26;
  static const double slack = 7;

  /// Horizontal padding, border and the icon with its gap.
  static const double _chrome = 9 * 2 + 1 * 2 + 12 + 4;

  static TextStyle? labelStyle(BuildContext context, Color ink) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ink,
          );

  /// The drawn chip's width for [mode] at the current text scale.
  static double widthFor(BuildContext context, StudyMode mode) =>
      _chrome +
      _textWidth(context, _modeLabel(context, mode),
          labelStyle(context, const Color(0xFF000000)));

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final palette = ReaderPalette.of(context);
    // The design's warm grey, a shade darker on light so the label clears
    // the 5.5:1 chip floor (6.2:1 on white; the muted grey is 5.4:1).
    final ink = palette.isDark
        ? palette.muted
        : ReaderPalette.ink.withValues(alpha: 0.68);
    final labelStyle = _ModeChip.labelStyle(context, ink);
    // A label, not a picker: only Standard is free on a path lesson, so the
    // mode is changed in the study mode setting, not with one tap here.
    return Padding(
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
          ],
        ),
      ),
    );
  }
}
