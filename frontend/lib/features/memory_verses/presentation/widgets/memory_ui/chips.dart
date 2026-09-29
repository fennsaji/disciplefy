import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/style.dart';

/// Stadium filter chip: raised fill; selected = CTA fill/ink (white + indigo
/// ink on dark, indigo + white on light).
class MemoryChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const MemoryChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final fill = selected ? palette.ctaFill : palette.raised;
    final ink = selected ? palette.ctaInk : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: fill,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? Colors.transparent : palette.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of [MemoryChoiceChip]s with page gutters.
class MemoryChipBar extends StatelessWidget {
  final List<Widget> chips;
  final EdgeInsetsGeometry padding;

  const MemoryChipBar({
    super.key,
    required this.chips,
    this.padding = const EdgeInsets.symmetric(horizontal: kMemoryGutter),
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      );
}

/// One option of an [MemorySegmentedControl].
@immutable
class MemorySegment<T> {
  final T value;
  final String label;

  const MemorySegment({required this.value, required this.label});
}

/// Rounded segmented control ("Weekly / Monthly / All time",
/// "Word by word / Phrase by phrase", "Easy / Medium / Hard").
class MemorySegmentedControl<T> extends StatelessWidget {
  final List<MemorySegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  const MemorySegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final selectedFill = palette.isDark ? palette.page : palette.card;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment.value == selected,
                child: Material(
                  color: segment.value == selected
                      ? selectedFill
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(segment.value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: Center(
                          // Wraps to a second line rather than truncating.
                          child: Text(
                            segment.label,
                            textAlign: TextAlign.center,
                            style: AppFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: segment.value == selected
                                  ? palette.text
                                  : palette.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Visual state of an [MemoryTokenChip].
enum MemoryTokenState {
  /// Card fill + hairline, normal text (word bank / available phrase).
  idle,

  /// Indigo fill, white text (placed / selected word).
  selected,

  /// Green tint + border (checked correct).
  correct,

  /// Red tint + border (checked wrong).
  wrong,

  /// Accent-outlined empty or editable slot (cloze blank).
  blank,

  /// Empty raised placeholder (next slot in the answer).
  placeholder,

  /// Already used / not tappable: dimmed.
  disabled,
}

/// A word or phrase token used by practice modes (word bank, scramble,
/// cloze blanks, first-letter hints). Wraps long Hindi/Malayalam text.
class MemoryTokenChip extends StatelessWidget {
  final String label;
  final MemoryTokenState state;
  final VoidCallback? onTap;

  /// Optional leading widget (e.g. a drag-handle icon for phrase rows).
  final Widget? leading;

  /// Stretch to the full available width (phrase rows).
  final bool expand;

  /// Minimum width, mostly for [MemoryTokenState.placeholder] / blanks.
  final double minWidth;
  final double radius;
  final double fontSize;

  const MemoryTokenChip({
    super.key,
    required this.label,
    this.state = MemoryTokenState.idle,
    this.onTap,
    this.leading,
    this.expand = false,
    this.minWidth = 0,
    this.radius = 14,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final alpha = palette.isDark ? 0.14 : 0.10;
    Color fill;
    Color border;
    Color ink;
    double borderWidth = 1;
    switch (state) {
      case MemoryTokenState.idle:
        fill = palette.card;
        border = palette.hairline;
        ink = palette.text;
      case MemoryTokenState.selected:
        fill = ReaderPalette.selectedFill;
        border = ReaderPalette.selectedFill;
        ink = Colors.white;
      case MemoryTokenState.correct:
        fill = AppColors.success.withValues(alpha: alpha);
        border = context.appSuccess;
        ink = context.appSuccess;
        borderWidth = 1.5;
      case MemoryTokenState.wrong:
        fill = AppColors.error.withValues(alpha: alpha);
        border = context.appError;
        ink = context.appError;
        borderWidth = 1.5;
      case MemoryTokenState.blank:
        fill = Colors.transparent;
        border = palette.accentIcon;
        ink = palette.text;
        borderWidth = 1.5;
      case MemoryTokenState.placeholder:
        fill = palette.raised;
        border = Colors.transparent;
        ink = palette.dim;
      case MemoryTokenState.disabled:
        fill = palette.card;
        border = palette.hairline;
        ink = palette.dim;
    }
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border, width: borderWidth),
    );
    final text = Text(
      label,
      softWrap: true,
      style: AppFonts.inter(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: ink,
        height: 1.3,
      ),
    );
    final chip = Material(
      color: fill,
      shape: shape,
      child: InkWell(
        onTap: state == MemoryTokenState.disabled ? null : onTap,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 44, minWidth: minWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                if (expand) Expanded(child: text) else Flexible(child: text),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: state == MemoryTokenState.selected,
      child: chip,
    );
  }
}

/// Dashed outlined drop target ("Drop here").
class MemoryDropZone extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  /// Highlight while a draggable hovers over it.
  final bool active;
  final double minHeight;
  final double radius;

  const MemoryDropZone({
    super.key,
    required this.label,
    this.onTap,
    this.active = false,
    this.minHeight = 48,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final color = active ? palette.accentIcon : palette.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: color,
          radius: radius,
          strokeWidth: active ? 1.5 : 1,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 14,
                  color: active ? palette.accentIcon : palette.dim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

/// Horizontal step indicator ("✓ Read · 2 Speak · 3 Results").
class MemoryStepIndicator extends StatelessWidget {
  final List<String> steps;

  /// Zero-based index of the current step; earlier steps show a check.
  final int currentIndex;

  const MemoryStepIndicator({
    super.key,
    required this.steps,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < currentIndex
                        ? AppColors.success
                        : i == currentIndex
                            ? ReaderPalette.selectedFill
                            : palette.raised,
                  ),
                  child: i < currentIndex
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: i == currentIndex
                                ? Colors.white
                                : palette.muted,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    steps[i],
                    style: AppFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: i == currentIndex ? palette.text : palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
