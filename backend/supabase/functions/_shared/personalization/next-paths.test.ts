// Run with: deno test -A next-paths.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  type CatalogPath,
  clearNextPathCaches,
  GROWTH_GOALS,
  growthGoalOrNull,
  lastFinishedPathId,
  legacyPathReason,
  legacyTopicReason,
  loadNextPaths,
  type NextPathInputs,
  rankNextPaths,
} from './next-paths.ts'

const path = (slug: string, extra: Partial<CatalogPath> = {}): CatalogPath => ({
  id: `id-${slug}`,
  slug,
  is_featured: false,
  guest_accessible: false,
  display_order: 100,
  ...extra,
})

/** A small catalogue: two guest paths, two featured, three others. */
const catalog: CatalogPath[] = [
  path('new-believer-essentials', { is_featured: true, guest_accessible: true, display_order: 1 }),
  path('rooted-in-christ', { is_featured: true, display_order: 2 }),
  path('gospel-of-mark', { guest_accessible: true, display_order: 6 }),
  path('gospel-of-john', { display_order: 11 }),
  path('gospel-of-luke', { display_order: 34 }),
  path('jesus-parables', { display_order: 28 }),
  path('faith-and-reason', { is_featured: true, display_order: 39 }),
]

const inputs = (over: Partial<NextPathInputs> = {}): NextPathInputs => ({
  catalog,
  activePathIds: [],
  goalSlugs: [],
  finishedIds: new Set(),
  enrolledIds: new Set(),
  isGuest: false,
  ...over,
})

const slugs = (ps: { slug: string }[]) => ps.map((p) => p.slug)

Deno.test('no goal, nothing started: featured paths, default first, then the rest of the catalogue', () => {
  const ranked = rankNextPaths(inputs())
  assertEquals(slugs(ranked).slice(0, 3), ['new-believer-essentials', 'rooted-in-christ', 'faith-and-reason'])
  assertEquals(ranked.slice(0, 3).map((p) => p.reason), ['featured', 'featured', 'featured'])
  assertEquals(ranked[3], { pathId: 'id-gospel-of-mark', slug: 'gospel-of-mark', reason: 'catalog' })
  assertEquals(ranked.length, catalog.length)
})

Deno.test('goal list order comes before featured', () => {
  const ranked = rankNextPaths(inputs({ goalSlugs: ['gospel-of-mark', 'gospel-of-john', 'gospel-of-luke'] }))
  assertEquals(slugs(ranked).slice(0, 4), ['gospel-of-mark', 'gospel-of-john', 'gospel-of-luke', 'new-believer-essentials'])
  assertEquals(ranked[0].reason, 'goal')
  assertEquals(ranked[3].reason, 'featured')
})

Deno.test('the unfinished enrolled path comes first, then the goal list', () => {
  const ranked = rankNextPaths(inputs({
    activePathIds: ['id-jesus-parables'],
    enrolledIds: new Set(['id-jesus-parables']),
    goalSlugs: ['gospel-of-mark', 'jesus-parables', 'gospel-of-john'],
  }))
  assertEquals(slugs(ranked).slice(0, 3), ['jesus-parables', 'gospel-of-mark', 'gospel-of-john'])
  assertEquals(ranked[0].reason, 'active')
})

Deno.test('finished paths are skipped everywhere, enrolled ones only in the goal and featured lists', () => {
  const ranked = rankNextPaths(inputs({
    activePathIds: ['id-gospel-of-john', 'id-gospel-of-mark'],
    enrolledIds: new Set(['id-gospel-of-john', 'id-gospel-of-mark', 'id-rooted-in-christ']),
    finishedIds: new Set(['id-gospel-of-mark', 'id-new-believer-essentials']),
    goalSlugs: ['gospel-of-mark', 'gospel-of-john', 'gospel-of-luke'],
  }))
  // Mark is finished (its stored row lags): never listed. John is active.
  // Rooted is enrolled but not active (e.g. reset), so not suggested again.
  assertEquals(slugs(ranked), ['gospel-of-john', 'gospel-of-luke', 'faith-and-reason', 'jesus-parables'])
  assertEquals(ranked.map((p) => p.reason), ['active', 'goal', 'featured', 'catalog'])
})

Deno.test('a guest only gets guest-accessible paths', () => {
  const ranked = rankNextPaths(inputs({
    isGuest: true,
    goalSlugs: ['gospel-of-mark', 'gospel-of-john', 'new-believer-essentials'],
  }))
  assertEquals(slugs(ranked), ['gospel-of-mark', 'new-believer-essentials'])
})

Deno.test('a guest who finished every guest path gets nothing', () => {
  const ranked = rankNextPaths(inputs({
    isGuest: true,
    finishedIds: new Set(['id-gospel-of-mark', 'id-new-believer-essentials']),
  }))
  assertEquals(ranked, [])
})

Deno.test('goal slugs that are not in the active catalogue are ignored', () => {
  const ranked = rankNextPaths(inputs({ goalSlugs: ['retired-path', 'gospel-of-luke'] }))
  assertEquals(ranked[0], { pathId: 'id-gospel-of-luke', slug: 'gospel-of-luke', reason: 'goal' })
})

Deno.test('limit cuts the list', () => {
  assertEquals(rankNextPaths(inputs(), 2).length, 2)
})

Deno.test('every active path is reachable: an exhausted goal list falls through to the whole catalogue', () => {
  const ranked = rankNextPaths(inputs({ goalSlugs: ['gospel-of-mark'] }))
  assertEquals(new Set(slugs(ranked)), new Set(slugs(catalog)))
  assertEquals(ranked.length, catalog.length)
})

Deno.test('last finished path: the latest enrolled path when it is finished and nothing is active', () => {
  const rows = [
    { learning_path_id: 'b', completed_at: '2026-10-09T00:00:00Z', enrolled_at: 'x' },
    { learning_path_id: 'a', completed_at: '2026-10-01T00:00:00Z', enrolled_at: 'x' },
  ]
  assertEquals(lastFinishedPathId(rows, new Set(['a', 'b']), []), 'b')
  // Finished by lessons while the stored row still reads unfinished.
  assertEquals(lastFinishedPathId([{ learning_path_id: 'c', completed_at: null, enrolled_at: 'x' }], new Set(['c']), []), 'c')
  // Another path is still active: no "What next?".
  assertEquals(lastFinishedPathId(rows, new Set(['a', 'b']), ['d']), null)
  // The latest path is not finished.
  assertEquals(lastFinishedPathId([{ learning_path_id: 'e', completed_at: null, enrolled_at: 'x' }], new Set(), []), null)
  assertEquals(lastFinishedPathId([], new Set(), []), null)
})

Deno.test('legacy reasons keep the values older apps parse', () => {
  assertEquals(legacyPathReason('active'), 'active')
  assertEquals(legacyPathReason('goal'), 'personalized')
  assertEquals(legacyPathReason('featured'), 'featured')
  assertEquals(legacyPathReason('catalog'), 'featured')
  assertEquals(legacyTopicReason('goal'), 'personalized')
  assertEquals(legacyTopicReason('catalog'), 'default')
  assertEquals(legacyTopicReason('active'), 'active')
})

Deno.test('growth goal values', () => {
  assertEquals(GROWTH_GOALS.length, 6)
  assertEquals(growthGoalOrNull('read_gospel'), 'read_gospel')
  assertEquals(growthGoalOrNull('readGospel'), null)
  assertEquals(growthGoalOrNull(null), null)
})

// ---------------------------------------------------------------------------
// Loader
// ---------------------------------------------------------------------------

type Row = Record<string, unknown>

// deno-lint-ignore no-explicit-any
function fakeClient(tables: Record<string, Row[]>, finished: string[] = []): any {
  const query = (table: string) => {
    let rows = [...(tables[table] ?? [])]
    let single = false
    const q: Record<string, unknown> = {
      select: () => q,
      eq: (col: string, v: unknown) => { rows = rows.filter((r) => r[col] === v); return q },
      order: () => q,
      limit: () => q,
      maybeSingle: () => { single = true; return q },
      then: (resolve: (v: unknown) => void) =>
        resolve(single ? { data: rows[0] ?? null, error: null } : { data: rows, error: null }),
    }
    return q
  }
  return {
    from: query,
    rpc: () => Promise.resolve({ data: finished.map((id) => ({ learning_path_id: id })), error: null }),
  }
}

const tables = (): Record<string, Row[]> => ({
  learning_paths: catalog.map((p) => ({ ...p, is_active: true })),
  growth_goal_paths: [
    { goal: 'read_gospel', path_slug: 'gospel-of-john', position: 2 },
    { goal: 'read_gospel', path_slug: 'gospel-of-mark', position: 1 },
    { goal: 'read_gospel', path_slug: 'gospel-of-luke', position: 3 },
    { goal: 'new_to_faith', path_slug: 'new-believer-essentials', position: 1 },
  ],
  user_growth_goals: [{ user_id: 'u', goal: 'read_gospel' }],
  user_learning_path_progress: [
    { user_id: 'u', learning_path_id: 'id-gospel-of-mark', completed_at: '2026-10-09T00:00:00Z', enrolled_at: 'x' },
  ],
})

Deno.test('loader: goal list from the table in position order, finished skipped, last finished reported', async () => {
  clearNextPathCaches()
  const result = await loadNextPaths(fakeClient(tables(), ['id-gospel-of-mark']), { userId: 'u', isGuest: false, limit: 3 })
  assertEquals(result.goal, 'read_gospel')
  assertEquals(slugs(result.paths), ['gospel-of-john', 'gospel-of-luke', 'new-believer-essentials'])
  assertEquals(result.lastFinishedPathId, 'id-gospel-of-mark')
})

Deno.test('loader: no user means featured paths only', async () => {
  clearNextPathCaches()
  const result = await loadNextPaths(fakeClient(tables()), { userId: null, isGuest: false, limit: 2 })
  assertEquals(result.goal, null)
  assertEquals(slugs(result.paths), ['new-believer-essentials', 'rooted-in-christ'])
  assertEquals(result.lastFinishedPathId, null)
})

Deno.test('loader: a guest with a goal gets guest paths only', async () => {
  clearNextPathCaches()
  const t = tables()
  t.user_learning_path_progress = []
  const result = await loadNextPaths(fakeClient(t), { userId: 'u', isGuest: true })
  assertEquals(slugs(result.paths), ['gospel-of-mark', 'new-believer-essentials'])
})
