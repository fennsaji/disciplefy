import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

let cache: { ids: Set<string>; at: number } | null = null
const TTL_MS = 5 * 60 * 1000

/** Test hook: clears the module cache. */
export function resetPathTopicIdsCache(): void {
  cache = null
}

/**
 * Topic ids that belong to a learning path (cached for 5 minutes).
 * On query failure returns an empty set (unfiltered but working) and does
 * not cache it, so the next request retries.
 */
export async function loadPathTopicIds(
  client: SupabaseClient,
  now: () => number = Date.now
): Promise<Set<string>> {
  if (cache && now() - cache.at < TTL_MS) return cache.ids
  try {
    const { data, error } = await client.from('learning_path_topics').select('topic_id')
    if (error) throw new Error(error.message)
    cache = { ids: new Set((data ?? []).map((r: { topic_id: string }) => r.topic_id)), at: now() }
    return cache.ids
  } catch (e) {
    // Metadata only; never fail the guides endpoint over this filter.
    console.warn('[path-topic-ids] learning_path_topics load failed', {
      reason: e instanceof Error ? e.name : 'unknown'
    })
    return new Set()
  }
}

/**
 * Drops guides generated from a learning-path lesson; keeps everything else.
 * Approximation: topic_id marks the topic, not who generated it, so a typed
 * study of a recommended topic that is also a path lesson shares the cached
 * study_guides row and is filtered too.
 */
export function excludePathLessons<T extends { study_guides: { topic_id: string | null } | null }>(
  rows: T[], pathTopicIds: Set<string>): T[] {
  return rows.filter(r => !r.study_guides?.topic_id || !pathTopicIds.has(r.study_guides.topic_id))
}
