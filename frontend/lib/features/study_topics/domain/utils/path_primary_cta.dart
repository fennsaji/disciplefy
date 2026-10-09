import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

enum PathCtaKind { enrollAndStart, start, resume, review }

/// What the learning-path detail page's primary button does.
class PathCta {
  final PathCtaKind kind;
  final LearningPathTopic topic;

  /// 1-based lesson number of [topic] within the path.
  final int lessonNumber;

  const PathCta(this.kind, this.topic, this.lessonNumber);
}

/// Null when the path has no topics. A fully completed path reviews lesson 1;
/// it never points at a lesson beyond the last one.
PathCta? pathPrimaryCta(LearningPathDetail path) {
  final ordered = [...path.topics]
    ..sort((a, b) => a.position.compareTo(b.position));
  if (ordered.isEmpty) return null;
  if (!path.isEnrolled) {
    return PathCta(PathCtaKind.enrollAndStart, ordered.first, 1);
  }
  final i = ordered.indexWhere((t) => !t.isCompleted);
  if (i < 0) return PathCta(PathCtaKind.review, ordered.first, 1);
  final started = ordered.any((t) => t.isCompleted || t.isInProgress);
  return PathCta(
      started ? PathCtaKind.resume : PathCtaKind.start, ordered[i], i + 1);
}
