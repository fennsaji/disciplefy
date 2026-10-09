import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/save_progress_block.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

/// What "Lesson complete" adds for a guest.
enum GuestNudge {
  none,

  /// Lesson 1 of the first run: the full sign-up block with "Not now".
  signUpBlock,

  /// Lessons 3 and 6: the dismissible "Keep these days safe" card.
  keepProgressCard,

  /// Last lesson of the path: sign-up block plus the next paths.
  pathFinished,
}

/// Picks the nudge for a finished lesson. Only guests get one.
GuestNudge guestNudgeFor({
  required bool isGuest,
  required int lessonNumber,
  required bool isLastLesson,
  required bool firstRun,
}) {
  if (!isGuest) return GuestNudge.none;
  if (isLastLesson) return GuestNudge.pathFinished;
  if (firstRun && lessonNumber == 1) return GuestNudge.signUpBlock;
  if (lessonNumber == 3 || lessonNumber == 6) {
    return GuestNudge.keepProgressCard;
  }
  return GuestNudge.none;
}

/// Remembers which "Keep these days safe" cards the guest closed, in Hive
/// `app_settings['guest_nudge_dismissed_<lesson>']`.
class GuestNudgeDismissals {
  GuestNudgeDismissals._();

  static const String _boxName = 'app_settings';

  /// Replaces the Hive box in tests.
  @visibleForTesting
  static Box<dynamic>? debugBox;

  static String keyFor(int lesson) => 'guest_nudge_dismissed_$lesson';

  static Box<dynamic>? get _box =>
      debugBox ?? (Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null);

  static bool isDismissed(int lesson) {
    try {
      return _box?.get(keyFor(lesson), defaultValue: false) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> dismiss(int lesson) async {
    try {
      await _box?.put(keyFor(lesson), true);
    } catch (e) {
      Logger.warning('Could not store the nudge dismissal',
          tag: 'GUEST', context: {'error': e.runtimeType.toString()});
    }
  }
}

/// Up to [max] guest-accessible paths other than [currentPathId] that the
/// guest has not finished. Pages the path list (20 per page, at most 4
/// pages, as the goal screen does). Never throws: an error gives what was
/// found so far.
Future<List<LearningPath>> loadNextGuestPaths(
  LearningPathsRepository repository, {
  required String language,
  required String currentPathId,
  int max = 2,
}) async {
  final found = <LearningPath>[];
  var offset = 0;
  for (var page = 0; page < 4 && found.length < max; page++) {
    final result = await repository.getLearningPaths(
      language: language,
      offset: offset,
      limit: 20,
    );
    final listed = result.fold((_) => null, (r) => r);
    if (listed == null) break;
    for (final path in listed.paths) {
      if (path.guestAccessible &&
          path.id != currentPathId &&
          !path.isCompleted &&
          found.length < max) {
        found.add(path);
      }
    }
    offset += listed.paths.length;
    if (!listed.hasMore || listed.paths.isEmpty) break;
  }
  return found;
}

/// The guest's section on "Lesson complete" (see [guestNudgeFor]). Renders
/// nothing for a full account or when guest mode is off.
class GuestLessonNudge extends StatefulWidget {
  final String pathId;
  final int lessonNumber;
  final bool isLastLesson;
  final bool firstRun;
  final String language;

  const GuestLessonNudge({
    super.key,
    required this.pathId,
    required this.lessonNumber,
    required this.isLastLesson,
    required this.firstRun,
    required this.language,
  });

  @override
  State<GuestLessonNudge> createState() => _GuestLessonNudgeState();
}

class _GuestLessonNudgeState extends State<GuestLessonNudge> {
  late GuestNudge _nudge;
  bool _hidden = false;
  List<LearningPath> _nextPaths = const [];

  @override
  void initState() {
    super.initState();
    _nudge = guestNudgeFor(
      isGuest: AccountGate.isActive,
      lessonNumber: widget.lessonNumber,
      isLastLesson: widget.isLastLesson,
      firstRun: widget.firstRun,
    );
    if (_nudge == GuestNudge.keepProgressCard &&
        GuestNudgeDismissals.isDismissed(widget.lessonNumber)) {
      _hidden = true;
    }
    if (_nudge == GuestNudge.pathFinished &&
        sl.isRegistered<LearningPathsRepository>()) {
      loadNextGuestPaths(
        sl<LearningPathsRepository>(),
        language: widget.language,
        currentPathId: widget.pathId,
      ).then((paths) {
        if (mounted) setState(() => _nextPaths = paths);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    switch (_nudge) {
      case GuestNudge.none:
        return const SizedBox.shrink();
      case GuestNudge.signUpBlock:
        return SaveProgressBlock(
          onNotNow: () => setState(() => _hidden = true),
        );
      case GuestNudge.keepProgressCard:
        return KeepProgressCard(
          days: widget.lessonNumber,
          onTap: () =>
              AccountNeededSheet.show(context, AccountReason.saveProgress),
          onDismiss: () {
            setState(() => _hidden = true);
            GuestNudgeDismissals.dismiss(widget.lessonNumber);
          },
        );
      case GuestNudge.pathFinished:
        return SaveProgressBlock(
          titleKey: TranslationKeys.accountPathFinishedTitle,
          nextPaths: _nextPaths,
        );
    }
  }
}
