import 'package:flutter/widgets.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';

/// A group's progress on its learning path — the one definition every card
/// uses (fellowship home, community list, lessons tab), so they never
/// disagree.
///
/// Lessons done are the lessons before the group's current one; the path
/// counts as fully done only once the group has finished it together (being
/// on the last lesson is not finishing it).
class GroupStudyProgress {
  /// Lessons the group has finished together.
  final int done;

  /// The path's lesson count, or null when unknown / the path has none.
  final int? total;

  /// Whether the group has finished the path.
  final bool finished;

  const GroupStudyProgress._(this.done, this.total, this.finished);

  factory GroupStudyProgress.of({
    required int currentGuideIndex,
    int? totalGuides,
    bool completed = false,
  }) {
    final total = (totalGuides != null && totalGuides > 0) ? totalGuides : null;
    final index = currentGuideIndex < 0 ? 0 : currentGuideIndex;
    final done = total == null
        ? (completed ? 0 : index)
        : completed
            ? total
            : index.clamp(0, total);
    return GroupStudyProgress._(done, total, completed);
  }

  bool get hasTotal => total != null;

  /// 0–1 for a progress bar, or null when the length is unknown.
  double? get fraction => total == null ? null : done / total!;

  /// "2 of 8 done" (localized), or null when the length is unknown.
  String? doneLabel(BuildContext context) => total == null
      ? null
      : context.tr(TranslationKeys.communityLessonsGroupDone,
          {'done': done, 'total': total});

  /// "Finished all 8 lessons together" (localized), or null.
  String? finishedLabel(BuildContext context) => !finished || total == null
      ? null
      : context
          .tr(TranslationKeys.communityLessonsGroupFinished, {'total': total});
}
