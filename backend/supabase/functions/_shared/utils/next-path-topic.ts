// backend/supabase/functions/_shared/utils/next-path-topic.ts
/**
 * Picks the lesson a "Continue Your Study" push should name.
 *
 * The push used to trust `user_learning_path_progress.current_topic_position`
 * and `completed_at` alone. Those are only maintained by the topic-completion
 * trigger, which updates paths the user is enrolled in *at that moment*. A path
 * enrolled after its lessons were finished (the "Review" button on a finished
 * path auto-enrols, as does starting a lesson or a fellowship study) got a
 * fresh row: cursor 0, completed_at NULL. The push then said "Pick up where you
 * left off: Romans 1" to someone who had finished all 16 lessons.
 *
 * The rule here is read from the lessons themselves: a lesson is done when any
 * completion record exists for it, and a path with no unfinished lesson is
 * skipped, whatever its stored row says.
 */

/** An enrolled, not-marked-complete path, most recently active first. */
export interface ActivePathRow {
  readonly learning_path_id: string;
  readonly current_topic_position: number | null;
}

/** A visible lesson (active link + active topic) of a path. */
export interface PathTopicRow {
  readonly learning_path_id: string;
  readonly topic_id: string;
  readonly position: number;
  readonly title: string;
  readonly description: string;
  readonly category: string;
}

/**
 * The first unfinished lesson of a path, in path order, or null when every
 * visible lesson is done (or the path has none).
 *
 * `fromPosition` keeps the user's place: the first unfinished lesson at or
 * after it wins, so a user who skipped ahead is not dragged back. When nothing
 * after it is left, the earliest unfinished lesson is returned instead.
 */
export function firstUnfinishedTopic(
  topics: readonly PathTopicRow[],
  completedTopicIds: ReadonlySet<string>,
  fromPosition = 0,
): PathTopicRow | null {
  const unfinished = topics
    .filter((t) => !completedTopicIds.has(t.topic_id))
    .sort((a, b) => a.position - b.position);
  if (unfinished.length === 0) return null;
  return unfinished.find((t) => t.position >= fromPosition) ?? unfinished[0];
}

/** Whether every visible lesson of a path is done. A path with no lessons is not "finished". */
export function isPathFinished(
  topics: readonly PathTopicRow[],
  completedTopicIds: ReadonlySet<string>,
): boolean {
  return topics.length > 0 && topics.every((t) => completedTopicIds.has(t.topic_id));
}

/**
 * Walks the active paths (most recent first) and returns the first unfinished
 * lesson found. Finished paths — and paths with no visible lessons — are
 * skipped, so a finished path hands over to the next enrolled one. Null means
 * there is no genuinely unfinished enrolled work.
 */
export function pickContinueLearningTopic(
  activePaths: readonly ActivePathRow[],
  topics: readonly PathTopicRow[],
  completedTopicIds: ReadonlySet<string>,
): PathTopicRow | null {
  for (const path of activePaths) {
    const pathTopics = topics.filter((t) => t.learning_path_id === path.learning_path_id);
    const next = firstUnfinishedTopic(
      pathTopics,
      completedTopicIds,
      path.current_topic_position ?? 0,
    );
    if (next) return next;
  }
  return null;
}
