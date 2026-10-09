import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scroll-driven "sections read so far" for the study guide header.
///
/// [StudyGuideBody] attaches [keyFor] to each rendered section and reports how
/// many it rendered through [total]; the screen calls [update] on scroll. A
/// section counts as read once its top has scrolled above the threshold line.
/// The count only grows — scrolling back up does not empty segments — and
/// [markComplete] fills them all.
class StudyReadingTracker extends ChangeNotifier {
  final Map<int, GlobalKey> _keys = {};
  int _readCount = 0;

  /// Sections the body is currently rendering (including loading shimmers).
  /// Set by the body while building; does not notify, because the header
  /// reads it in the same build.
  int total = 0;
  bool _isComplete = false;

  /// Sections counted as read, capped at [total]; all of them once complete.
  int get readCount => _isComplete ? total : math.min(_readCount, total);

  bool get isComplete => _isComplete;

  /// Key for the section with spec index [index] (0–6).
  GlobalKey keyFor(int index) => _keys.putIfAbsent(
        index,
        () => GlobalKey(debugLabel: 'study_section_$index'),
      );

  /// Starts from progress remembered from an earlier visit.
  void seed(int count) {
    if (count <= _readCount) return;
    _readCount = count;
    notifyListeners();
  }

  /// Spec indices of the rendered sections, top to bottom. Set by the body
  /// while building, like [total].
  List<int> sectionOrder = const [];

  /// Recounts read sections. [thresholdY] is a global y coordinate (from the
  /// top of the screen); a section whose top is above it counts as read, and
  /// so does every section before it — the body builds sections lazily, so
  /// those may no longer be laid out. [atBottom] counts every section.
  void update({required double thresholdY, bool atBottom = false}) {
    var count = 0;
    if (atBottom) {
      count = total;
    } else {
      final order = sectionOrder.isNotEmpty
          ? sectionOrder
          : (_keys.keys.toList()..sort());
      for (var position = 0; position < order.length; position++) {
        final box = _keys[order[position]]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        if (box.localToGlobal(Offset.zero).dy < thresholdY) {
          count = position + 1;
        }
      }
    }
    if (count > _readCount) {
      _readCount = count;
      notifyListeners();
    }
  }

  void markComplete() {
    if (_isComplete) return;
    _isComplete = true;
    notifyListeners();
  }
}
