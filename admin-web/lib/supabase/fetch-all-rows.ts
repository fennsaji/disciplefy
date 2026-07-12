import type { PostgrestError } from '@supabase/supabase-js'

const PAGE_SIZE = 1000
const MAX_PAGES = 100 // safety cap: 100k rows

/**
 * Fetch ALL rows past PostgREST's silent 1000-row response cap by paging with
 * `.range()`. `buildQuery` must build a FRESH query for each page (Supabase
 * query builders are single-use) and should include a deterministic
 * `.order()` so pages don't overlap or skip rows.
 */
export async function fetchAllRows<T>(
  buildQuery: (
    from: number,
    to: number
  ) => PromiseLike<{ data: T[] | null; error: PostgrestError | null }>
): Promise<{ data: T[]; error: PostgrestError | null }> {
  const rows: T[] = []
  for (let page = 0; page < MAX_PAGES; page++) {
    const from = page * PAGE_SIZE
    const { data, error } = await buildQuery(from, from + PAGE_SIZE - 1)
    if (error) return { data: rows, error }
    rows.push(...(data || []))
    if (!data || data.length < PAGE_SIZE) break
  }
  return { data: rows, error: null }
}
