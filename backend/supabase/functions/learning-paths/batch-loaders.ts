/**
 * Batched per-user lookups for a set of learning paths.
 *
 * The recommended-path handler used to ask, per candidate path, for its
 * translation, whether the user is enrolled and how many of its topics the
 * user has completed — several round trips per candidate, one after another.
 * These helpers answer the same questions for every candidate at once.
 */

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
type Client = any;

/**
 * Distinct completed topics per path for one user, in two queries.
 *
 * Returns null when either query fails, so the caller can fall back to its
 * per-path lookup rather than treat a failed read as "nothing completed".
 */
export async function loadCompletedTopicCounts(
  client: Client,
  pathIds: string[],
  userId: string,
): Promise<Map<string, number> | null> {
  const ids = [...new Set(pathIds.filter(Boolean))];
  const counts = new Map<string, number>();
  if (ids.length === 0) return counts;

  const { data: pathTopics, error: topicsError } = await client
    .from('learning_path_topics')
    .select('learning_path_id, topic_id')
    .in('learning_path_id', ids)
    .eq('is_active', true);
  if (topicsError) return null;

  const rows = (pathTopics ?? []) as Array<{ learning_path_id: string; topic_id: string }>;
  const topicIds = [...new Set(rows.map((r) => r.topic_id))];
  let completed: Array<{ topic_id: string }> = [];
  if (topicIds.length > 0) {
    const { data, error } = await client
      .from('user_topic_progress')
      .select('topic_id')
      .eq('user_id', userId)
      .in('topic_id', topicIds)
      .not('completed_at', 'is', null);
    if (error) return null;
    completed = (data ?? []) as Array<{ topic_id: string }>;
  }

  return countCompletedPerPath(ids, rows, completed);
}

/** Pure counting step of loadCompletedTopicCounts, exported for tests. */
export function countCompletedPerPath(
  pathIds: string[],
  pathTopics: Array<{ learning_path_id: string; topic_id: string }>,
  completed: Array<{ topic_id: string }>,
): Map<string, number> {
  const done = new Set(completed.map((r) => r.topic_id));
  const perPath = new Map<string, Set<string>>();
  for (const id of pathIds) perPath.set(id, new Set());
  for (const row of pathTopics) {
    if (done.has(row.topic_id)) perPath.get(row.learning_path_id)?.add(row.topic_id);
  }
  const counts = new Map<string, number>();
  for (const [id, topics] of perPath) counts.set(id, topics.size);
  return counts;
}

/**
 * Ids of the given paths the user has a progress row for (enrolled), in one
 * query. Null on error, so the caller can fall back to per-path lookups.
 */
export async function loadEnrolledPathIds(
  client: Client,
  pathIds: string[],
  userId: string,
): Promise<Set<string> | null> {
  const ids = [...new Set(pathIds.filter(Boolean))];
  if (ids.length === 0) return new Set();
  const { data, error } = await client
    .from('user_learning_path_progress')
    .select('learning_path_id')
    .eq('user_id', userId)
    .in('learning_path_id', ids);
  if (error) return null;
  return new Set(((data ?? []) as Array<{ learning_path_id: string }>).map((r) => r.learning_path_id));
}

export type PathTranslationRow = {
  title: string | null;
  description: string | null;
  /** Optional localized display name (<= 28 chars); null means none. */
  short_title?: string | null;
};
export type PathTranslation = PathTranslationRow | null;

type TranslationQueryRow = PathTranslationRow & { learning_path_id: string };

/**
 * Translations for many paths in one query. Paths with exactly one row map to
 * it; paths with none (or, as `.single()` treated them, more than one) map to
 * null. Returns null on a query error so nothing is remembered.
 */
export async function loadPathTranslations(
  client: Client,
  pathIds: string[],
  language: string,
): Promise<Map<string, PathTranslation> | null> {
  const ids = [...new Set(pathIds.filter(Boolean))];
  if (ids.length === 0) return new Map();
  const { data, error } = await client
    .from('learning_path_translations')
    .select('learning_path_id, title, description, short_title')
    .in('learning_path_id', ids)
    .eq('lang_code', language);
  if (error) return null;
  return groupPathTranslations(ids, (data ?? []) as TranslationQueryRow[]);
}

/** Pure grouping step of loadPathTranslations, exported for tests. */
export function groupPathTranslations(
  pathIds: string[],
  rows: TranslationQueryRow[],
): Map<string, PathTranslation> {
  const seen = new Map<string, number>();
  for (const row of rows) seen.set(row.learning_path_id, (seen.get(row.learning_path_id) ?? 0) + 1);
  const result = new Map<string, PathTranslation>();
  for (const id of pathIds) result.set(id, null);
  for (const row of rows) {
    if (seen.get(row.learning_path_id) === 1) {
      result.set(row.learning_path_id, {
        title: row.title,
        description: row.description,
        short_title: row.short_title ?? null,
      });
    }
  }
  return result;
}

/**
 * The short display title for a path in [language].
 *
 * English reads the path's own short_title. Elsewhere a translation's short
 * title wins; a translated title without one has none (the English short title
 * must not sit under a translated header). Only when there is no translated
 * title, and the response falls back to the English title, does the English
 * short title come along with it. Blank values read as none.
 *
 * [translation] is undefined when it was not looked up (English).
 */
export function resolveShortTitle(
  language: string,
  baseShortTitle: string | null | undefined,
  translation: PathTranslation | undefined,
): string | null {
  const clean = (v: string | null | undefined) => (v && v.trim() ? v.trim() : null);
  if (language === 'en' || !translation || !clean(translation.title)) return clean(baseShortTitle);
  return clean(translation.short_title);
}

/**
 * A path's progress for the user: completed visible topics over visible
 * topics, or 100 once the path itself is marked completed.
 */
export function pathProgressPercentage(
  topicsCompleted: number,
  topicsCount: number,
  pathId: string,
  completedPathIds: Set<string>,
): number {
  if (completedPathIds.has(pathId)) return 100;
  if (topicsCount <= 0) return 0;
  return Math.min(100, Math.round((topicsCompleted * 100) / topicsCount));
}

/**
 * 1-based number of each path's first unfinished visible lesson for one
 * user, from the lesson rows; null when every lesson is done (or the path has
 * none). Lets list rows say "Lesson N of M" without assuming lessons were
 * finished in order ("completed + 1" named lesson 3 when 1 and 3 were done).
 *
 * Null map on a failed read, so callers just omit the field.
 */
export async function loadNextLessonNumbers(
  client: Client,
  pathIds: string[],
  userId: string,
): Promise<Map<string, number | null> | null> {
  const ids = [...new Set(pathIds.filter(Boolean))];
  if (ids.length === 0) return new Map();

  const { data: pathTopics, error: topicsError } = await client
    .from('learning_path_topics')
    .select('learning_path_id, topic_id, position, recommended_topics!inner(is_active)')
    .in('learning_path_id', ids)
    .eq('is_active', true)
    .eq('recommended_topics.is_active', true);
  if (topicsError) return null;

  const rows = (pathTopics ?? []) as Array<{ learning_path_id: string; topic_id: string; position: number }>;
  const topicIds = [...new Set(rows.map((r) => r.topic_id))];
  let completed: Array<{ topic_id: string }> = [];
  if (topicIds.length > 0) {
    const { data, error } = await client
      .from('user_topic_progress')
      .select('topic_id')
      .eq('user_id', userId)
      .in('topic_id', topicIds)
      .not('completed_at', 'is', null);
    if (error) return null;
    completed = (data ?? []) as Array<{ topic_id: string }>;
  }

  return nextLessonNumberPerPath(ids, rows, completed);
}

/** Pure step of loadNextLessonNumbers, exported for tests. */
export function nextLessonNumberPerPath(
  pathIds: string[],
  pathTopics: Array<{ learning_path_id: string; topic_id: string; position: number }>,
  completed: Array<{ topic_id: string }>,
): Map<string, number | null> {
  const done = new Set(completed.map((r) => r.topic_id));
  const out = new Map<string, number | null>();
  for (const id of pathIds) {
    const lessons = pathTopics
      .filter((t) => t.learning_path_id === id)
      .sort((a, b) => a.position - b.position);
    const i = lessons.findIndex((t) => !done.has(t.topic_id));
    out.set(id, i < 0 ? null : i + 1);
  }
  return out;
}
