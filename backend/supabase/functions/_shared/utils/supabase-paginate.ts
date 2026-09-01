// ============================================================================
// Supabase Pagination Helper
// ============================================================================
// PostgREST caps a single select at 1000 rows by default and returns the
// truncated page without any error. For notification fan-out that silently
// drops every user past the first page, so any full-table scan the schedulers
// depend on must page explicitly.

/** PostgREST's default maximum rows per response. */
const PAGE_SIZE = 1000

/** Hard stop so a mis-built query can never spin forever. */
const MAX_PAGES = 100

/**
 * Reads every row of a query by paging through it with `.range()`.
 *
 * @param buildQuery - Builds the query for one page. Must apply the same
 *   filters and ordering on every call; only the range differs.
 * @returns Every row across all pages
 */
export async function fetchAllRows<T>(
  buildQuery: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: { message: string } | null }>
): Promise<T[]> {
  const rows: T[] = []

  for (let page = 0; page < MAX_PAGES; page++) {
    const from = page * PAGE_SIZE
    const { data, error } = await buildQuery(from, from + PAGE_SIZE - 1)

    if (error) {
      throw new Error(error.message)
    }

    const batch = data || []
    rows.push(...batch)

    if (batch.length < PAGE_SIZE) {
      return rows
    }
  }

  console.warn(`[Paginate] Hit MAX_PAGES (${MAX_PAGES}); results may be truncated`)
  return rows
}
