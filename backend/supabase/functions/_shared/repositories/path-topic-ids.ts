import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

let cache: { ids: Set<string>; at: number } | null = null
const TTL_MS = 5 * 60 * 1000

/** Topic ids that belong to a learning path (cached for 5 minutes). */
export async function loadPathTopicIds(client: SupabaseClient): Promise<Set<string>> {
  if (cache && Date.now() - cache.at < TTL_MS) return cache.ids
  const { data, error } = await client.from('learning_path_topics').select('topic_id')
  if (error) throw new Error(`learning_path_topics: ${error.message}`)
  cache = { ids: new Set((data ?? []).map((r: { topic_id: string }) => r.topic_id)), at: Date.now() }
  return cache.ids
}

/** Drops guides generated from a learning-path lesson; keeps everything else. */
export function excludePathLessons<T extends { study_guides: { topic_id: string | null } | null }>(
  rows: T[], pathTopicIds: Set<string>): T[] {
  return rows.filter(r => !r.study_guides?.topic_id || !pathTopicIds.has(r.study_guides.topic_id))
}
