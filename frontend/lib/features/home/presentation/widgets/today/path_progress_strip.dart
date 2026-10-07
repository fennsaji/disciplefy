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

/// Progress through the active path, inside a tappable card.
///
/// [current] is the next lesson number, or [total] when the path is finished.
class PathProgressStrip extends StatelessWidget {
  final int total;
  final int completed;
  final int current;
  final List<int> milestones;
  final VoidCallback? onTap;

  const PathProgressStrip({
    super.key,
    required this.total,
    required this.completed,
    required this.current,
    this.milestones = const [],
    this.onTap,
  });

  static const double _dotSize = 22;

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
    final safeTotal = _total < 1 ? 1 : _total;
    final slot = (_current.clamp(1, safeTotal) - 0.5) / safeTotal;

    final Widget strip;
    switch (stripTierFor(_total)) {
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
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                strip,
                // Nothing is "today" on a finished path.
                if (!_finished) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment(slot * 2 - 1, 0),
                    child: Text(
                      context.tr(TranslationKeys.homeTodayLabel),
                      key: const Key('strip_today'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.gold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
                      : palette.hairline,
                ),
        );

    Widget dot(int n) {
      final done = n <= _completed;
      final isCurrent = n == _current;
      return Container(
        key: Key('strip_dot_$n'),
        width: _dotSize,
        height: _dotSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (done || isCurrent) ? palette.selectedFill : null,
          border: (done || isCurrent)
              ? null
              : Border.all(color: palette.hairline, width: 1.5),
        ),
        // Ink on the selected gold fill: 7.6:1 light, 8.9:1 dark (white on
        // the deep light gold was 4.8:1).
        child: done
            ? Icon(Icons.check_rounded, size: 14, color: palette.onSelected)
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

    return Row(
      children: [
        for (var n = 1; n <= _total; n++)
          Expanded(
            child: Row(
              children: [connector(n), dot(n), connector(n + 1)],
            ),
          ),
      ],
    );
  }

  Widget _segments(ReaderPalette palette) {
    return SizedBox(
      height: 9,
      child: Row(
        children: [
          for (var n = 1; n <= _total; n++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: n == 1 ? 0 : 3),
                child: Container(
                  key: Key('strip_segment_$n'),
                  height: n == _current ? 9 : 6,
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
                width: width * (_completed / safeTotal).clamp(0.0, 1.0),
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
                    height: 10,
                    color: palette.outline,
                  ),
                ),
              Positioned(
                left: at(_current.clamp(1, safeTotal)) - 5,
                child: Container(
                  width: 10,
                  height: 10,
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
