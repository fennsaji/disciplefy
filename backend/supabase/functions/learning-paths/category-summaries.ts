/**
 * Every learning-path category with its active-path count, without loading
 * the paths (All paths shows a chip per category before any path is listed).
 */

export interface CategorySummary {
  name: string
  total_paths: number
}

/** More categories than will ever exist, so one read lists them all. */
export const CATEGORY_SUMMARY_LIMIT = 500

/**
 * Rows of `get_learning_path_categories` as summaries, in the given
 * (priority) order. Blank names, empty categories and repeats are dropped.
 */
export function toCategorySummaries(rows: Array<Record<string, unknown>> | null | undefined): CategorySummary[] {
  const seen = new Set<string>()
  const summaries: CategorySummary[] = []
  for (const row of rows ?? []) {
    const name = typeof row.category === 'string' ? row.category.trim() : ''
    const total = Number(row.total_paths)
    if (!name || !Number.isFinite(total) || total <= 0 || seen.has(name)) continue
    seen.add(name)
    summaries.push({ name, total_paths: total })
  }
  return summaries
}

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
type Client = any

/** Every category for [userId] (null for guests), or null when the read failed. */
export async function loadCategorySummaries(client: Client, userId: string | null): Promise<CategorySummary[] | null> {
  const { data, error } = await client.rpc('get_learning_path_categories', {
    p_user_id: userId,
    p_limit: CATEGORY_SUMMARY_LIMIT,
    p_offset: 0,
  })
  if (error) return null
  return toCategorySummaries(data)
}
