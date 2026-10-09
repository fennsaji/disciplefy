import 'package:flutter/material.dart';

import '../../../../../core/extensions/translation_extension.dart';
import '../../../../../core/i18n/translation_keys.dart';
import '../../../../../core/theme/reader_palette.dart';

/// How a path's progress is drawn: one dot per lesson up to 10, a segmented
/// bar for 11-20, a smooth bar with milestone ticks beyond that.
enum StripTier { dots, segments, smooth }

StripTier stripTierFor(int total) {
  if (total <= 10) return StripTier.dots;
  if (total <= 20) return StripTier.segments;
  return StripTier.smooth;
}

/// Progress through the active path: the top of [TodayLessonCard], drawn
/// without a frame of its own and tappable as one area (at least 40px tall).
///
/// [current] is the next lesson number, or [total] when the path is finished.
/// The current lesson is marked by its dot or knob alone: the lesson card's
/// "TODAY · LESSON N" eyebrow below says which day it is.
///
/// With [lessonLabel] ("Lesson 4 of 16"), the bar and segment tiers end in a
/// caption row: the label, [toGoLabel] (smooth bar only) and a chevron. Dots
/// need no caption.
class PathProgressStrip extends StatelessWidget {
  final int total;
  final int completed;
  final int current;
  final List<int> milestones;
  final VoidCallback? onTap;
  final String? lessonLabel;
  final String? toGoLabel;

  const PathProgressStrip({
    super.key,
    required this.total,
    required this.completed,
    required this.current,
    this.milestones = const [],
    this.onTap,
    this.lessonLabel,
    this.toGoLabel,
  });

  static const double _doneSize = 24;
  static const double _currentSize = 28;
  static const double _futureSize = 18;

  /// The strip's tap area is never shorter than this.
  static const double minTapHeight = 40;

  // Normalised inputs: callers may pass out-of-range values.
  int get _total => total < 0 ? 0 : total;
  int get _completed => completed.clamp(0, _total);
  int get _current => _total == 0 ? 0 : current.clamp(1, _total);
  bool get _finished => _total > 0 && _completed >= _total;
  List<int> get _milestones => {
        for (final m in milestones)
          if (m >= 1 && m <= _total) m
      }.toList();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final tier = stripTierFor(_total);
    final caption = tier != StripTier.dots && lessonLabel != null;

    final Widget strip;
    switch (tier) {
      case StripTier.dots:
        strip = _dots(palette);
      case StripTier.segments:
        strip = _segments(palette);
      case StripTier.smooth:
        strip = _smooth(palette);
    }

    return Semantics(
      button: onTap != null,
      label: context.tr(TranslationKeys.homeTodayStripSemantics,
          {'done': _completed, 'total': _total}),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('path_progress_strip'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minTapHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  strip,
                  if (caption)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child:
                          _caption(palette, showToGo: tier == StripTier.smooth),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Lesson 4 of 16 ... 17 to go >".
  Widget _caption(ReaderPalette palette, {required bool showToGo}) {
    final toGo = toGoLabel;
    return Row(
      key: const Key('strip_caption'),
      children: [
        Flexible(
          child: Text(
            lessonLabel!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
        ),
        const Spacer(),
        if (showToGo && toGo != null) ...[
          const SizedBox(width: 8),
          Text(
            toGo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: palette.muted,
            ),
          ),
        ],
        const SizedBox(width: 5),
        Icon(Icons.chevron_right_rounded, size: 14, color: palette.muted),
      ],
    );
  }

  Widget _dots(ReaderPalette palette) {
    // The connector between lesson n-1 and n is gold once n is reached.
    Widget connector(int toLesson) => Expanded(
          child: toLesson < 2 || toLesson > _total
              ? const SizedBox.shrink()
              : Container(
                  height: 2,
                  color: (toLesson <= _completed || toLesson == _current)
                      ? palette.gold
                      : palette.outline,
                ),
        );

    Widget dot(int n, double scale) {
      final done = n <= _completed;
      final isCurrent = n == _current && !done;
      final size = scale *
          (isCurrent
              ? _currentSize
              : done
                  ? _doneSize
                  : _futureSize);
      return Container(
        key: Key('strip_dot_$n'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (done || isCurrent) ? palette.selectedFill : null,
          border: isCurrent
              ? Border.all(color: palette.gold.withValues(alpha: 0.33))
              : done
                  ? null
                  : Border.all(color: palette.outline),
        ),
        // Ink on the selected gold fill: 7.6:1 light, 8.9:1 dark (white on
        // the deep light gold was 4.8:1).
        child: done
            ? Icon(Icons.check_rounded, size: 12, color: palette.onSelected)
            : isCurrent
                ? Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.onSelected,
                      height: 1,
                    ),
                  )
                : null,
      );
    }

    // Ten lessons on a small phone leave under 28px a slot: the dots
    // shrink together rather than overflow.
    return LayoutBuilder(builder: (context, box) {
      final slot = _total == 0 ? _currentSize : box.maxWidth / _total;
      final scale = slot >= _currentSize + 2 ? 1.0 : (slot - 2) / _currentSize;
      return SizedBox(
        height: _currentSize,
        child: Row(
          children: [
            for (var n = 1; n <= _total; n++)
              Expanded(
                child: Row(
                  children: [connector(n), dot(n, scale), connector(n + 1)],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _segments(ReaderPalette palette) {
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          for (var n = 1; n <= _total; n++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: n == 1 ? 0 : 3),
                child: Container(
                  key: Key('strip_segment_$n'),
                  height: n == _current ? 10 : 6,
                  decoration: BoxDecoration(
                    color: (n <= _completed || n == _current)
                        ? palette.gold
                        : palette.hairline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _smooth(ReaderPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final safeTotal = _total < 1 ? 1 : _total;
        double at(num lesson) => width * (lesson - 0.5) / safeTotal;
        // The fill reaches the current lesson's knob; a finished path is full.
        final reached =
            _finished ? width : at(_current.clamp(1, safeTotal)).toDouble();
        return SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: palette.hairline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                height: 6,
                width: reached.clamp(0.0, width),
                decoration: BoxDecoration(
                  color: palette.gold,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              for (final m in _milestones)
                Positioned(
                  left: at(m) - 1,
                  child: Container(
                    key: Key('strip_tick_$m'),
                    width: 2,
                    height: 12,
                    decoration: BoxDecoration(
                      // Passed milestones turn gold with the fill.
                      color: m <= _current ? palette.gold : palette.dim,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              if (!_finished)
                Positioned(
                  left: at(_current.clamp(1, safeTotal)) - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.gold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
