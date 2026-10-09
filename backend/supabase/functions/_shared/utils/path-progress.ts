// backend/supabase/functions/_shared/utils/path-progress.ts
/**
 * How many in-progress paths the recommendation looks at before giving up on
 * the "active" priority. More than one, because the newest row is often a study
 * the user has just finished.
 */
export const ACTIVE_PATH_CANDIDATES = 5;

/**
 * Paths this user has finished, by id.
 *
 * Reads get_finished_path_ids (stored completion OR all visible lessons done);
 * falls back to the stored completion alone if the RPC is not deployed yet.
 *
 * Completion lives in two places: per-topic rows in `user_topic_progress`, and
 * `user_learning_path_progress.completed_at` — which is what a path finished
 * through a fellowship, or before per-topic rows were written, leaves behind.
 * Reading only the first made a finished path report 25% and get recommended
 * again, which is the whole reason For You kept resurfacing completed studies.
 *
 * The SQL listing already floors its computed value with the same rule (see
 * migration 20260908000001); this is that rule for the endpoints that compute
 * progress in TypeScript instead.
 */
export async function getCompletedPathIds(
  // deno-lint-ignore no-explicit-any
  supabaseClient: any,
  userId: string,
): Promise<Set<string>> {
  // Stored completion OR every visible lesson done (migration 20261009020000).
  // A path finished lesson by lesson whose stored row never caught up -- or
  // that was never enrolled -- is finished too, and must not be recommended.
  const { data: finished, error: rpcError } = await supabaseClient
    .rpc('get_finished_path_ids', { p_user_id: userId });
  if (!rpcError) {
    return new Set((finished || []).map((r: { learning_path_id: string }) => r.learning_path_id));
  }
  console.warn('[LEARNING_PATHS] get_finished_path_ids unavailable, using stored completion only:', rpcError.message);

  const { data, error } = await supabaseClient
    .from('user_learning_path_progress')
    .select('learning_path_id')
    .eq('user_id', userId)
    .not('completed_at', 'is', null);

  if (error) {
    console.error('[LEARNING_PATHS] Failed to load completed paths:', error);
    return new Set();
  }
  return new Set((data || []).map((r: { learning_path_id: string }) => r.learning_path_id));
}

/**
 * Progress for a path, with a stored completion flooring the computed value.
 * Whichever source says "finished" wins; a partly-done path keeps its real number.
 */
export function effectiveProgress(computed: number, pathId: string, completedIds: Set<string>): number {
  return completedIds.has(pathId) ? 100 : computed;
}

