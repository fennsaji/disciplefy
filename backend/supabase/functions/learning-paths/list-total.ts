/**
 * The `total` of the flat learning-path list: how many paths match the whole
 * list, not just the returned page.
 */

export interface FlatListTotalInput {
  offset: number
  pageLength: number
  hasMore: boolean
  /** Active learning paths, or null when the count failed. */
  activeCount: number | null
  /** No search and enrolled paths included: every active path is listed. */
  unfiltered: boolean
}

/**
 * Exact on the last page (any filter). With more pages, the active-path
 * count when the list is unfiltered and the count agrees with the page;
 * otherwise null (unknown).
 */
export function flatListTotal(input: FlatListTotalInput): number | null {
  const seen = input.offset + input.pageLength
  if (!input.hasMore) return seen
  if (!input.unfiltered || input.activeCount === null) return null
  return input.activeCount > seen ? input.activeCount : null
}

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
type Client = any

/** Number of active learning paths (head request), or null on error. */
export async function loadActivePathCount(client: Client): Promise<number | null> {
  const { count, error } = await client
    .from('learning_paths')
    .select('id', { count: 'exact', head: true })
    .eq('is_active', true)
  if (error || typeof count !== 'number') return null
  return count
}
