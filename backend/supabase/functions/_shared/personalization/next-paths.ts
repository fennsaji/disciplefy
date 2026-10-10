/**
 * The one "what next" engine: which learning paths to suggest to a user, in
 * order. Used by learning-paths (`recommended`, `recommended_paths`),
 * topics-for-you and the recommended-lesson notification.
 *
 * Order (owner decision 2026-10-10):
 *   1. active   - enrolled paths not yet finished, latest activity first
 *   2. goal     - the user's growth goal list (growth_goal_paths), in order
 *   3. featured - featured paths, the default path first
 *   4. catalog  - every other active path by display order
 * Finished paths (get_finished_path_ids: stored completion or every visible
 * lesson done) are never suggested; enrolled paths only as "active". A guest
 * only ever gets guest-accessible paths.
 *
 * Language does not change the order; callers localise titles.
 */

import { getCompletedPathIds } from '../utils/path-progress.ts'
import { TtlCache } from '../utils/ttl-cache.ts'

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
type Client = any

export const GROWTH_GOALS = [
  'new_to_faith',
  'fresh_start',
  'walk_with_god',
  'hope_hard_times',
  'read_gospel',
  'understand_gospel',
] as const

export type GrowthGoal = typeof GROWTH_GOALS[number]

export function growthGoalOrNull(value: unknown): GrowthGoal | null {
  return typeof value === 'string' && (GROWTH_GOALS as readonly string[]).includes(value)
    ? value as GrowthGoal
    : null
}

/** Path offered when nothing else is known (also the first featured path). */
export const DEFAULT_PATH_SLUG = 'new-believer-essentials'

export type NextPathReason = 'active' | 'goal' | 'featured' | 'catalog'

export interface CatalogPath {
  id: string
  slug: string
  is_featured: boolean | null
  guest_accessible: boolean | null
  display_order: number | null
}

export interface NextPath {
  pathId: string
  slug: string
  reason: NextPathReason
}

export interface NextPathInputs {
  /** Active paths only. */
  catalog: CatalogPath[]
  /** Enrolled, not stored as completed, latest activity first. */
  activePathIds: string[]
  /** The goal's path slugs in order; empty without a goal. */
  goalSlugs: string[]
  finishedIds: Set<string>
  enrolledIds: Set<string>
  isGuest: boolean
  defaultSlug?: string
}

/** The ranked suggestions. Pure. */
export function rankNextPaths(inputs: NextPathInputs, limit = Number.POSITIVE_INFINITY): NextPath[] {
  const allowed = inputs.isGuest
    ? inputs.catalog.filter((p) => p.guest_accessible === true)
    : inputs.catalog
  const byId = new Map(allowed.map((p) => [p.id, p]))
  const bySlug = new Map(allowed.map((p) => [p.slug, p]))
  const out: NextPath[] = []
  const seen = new Set<string>()

  const add = (p: CatalogPath | undefined, reason: NextPathReason, allowEnrolled = false) => {
    if (!p || seen.has(p.id) || inputs.finishedIds.has(p.id)) return
    if (!allowEnrolled && inputs.enrolledIds.has(p.id)) return
    seen.add(p.id)
    out.push({ pathId: p.id, slug: p.slug, reason })
  }

  for (const id of inputs.activePathIds) add(byId.get(id), 'active', true)
  for (const slug of inputs.goalSlugs) add(bySlug.get(slug), 'goal')

  const byOrder = [...allowed].sort((a, b) =>
    (a.display_order ?? Number.MAX_SAFE_INTEGER) - (b.display_order ?? Number.MAX_SAFE_INTEGER) ||
    a.slug.localeCompare(b.slug)
  )
  add(bySlug.get(inputs.defaultSlug ?? DEFAULT_PATH_SLUG), 'featured')
  for (const p of byOrder) if (p.is_featured === true) add(p, 'featured')
  for (const p of byOrder) add(p, 'catalog')

  return out.slice(0, limit)
}

/**
 * The path a "What next?" card is about: the most recently active enrolled
 * path, when it is finished and no other path is still active. Null otherwise.
 * [rows] are the user's progress rows, latest activity first.
 */
export function lastFinishedPathId(
  rows: { learning_path_id: string; completed_at: string | null; enrolled_at?: string | null }[],
  finishedIds: Set<string>,
  activePathIds: string[],
): string | null {
  if (activePathIds.length > 0) return null
  const latest = rows.find((r) => r.enrolled_at !== null)
  if (!latest) return null
  return latest.completed_at !== null || finishedIds.has(latest.learning_path_id)
    ? latest.learning_path_id
    : null
}

/** Reason values the learning-paths responses always used (older apps parse them). */
export function legacyPathReason(reason: NextPathReason): 'active' | 'personalized' | 'featured' {
  if (reason === 'active') return 'active'
  return reason === 'goal' ? 'personalized' : 'featured'
}

/** Reason values topics-for-you always used for its suggested path. */
export function legacyTopicReason(reason: NextPathReason): 'active' | 'personalized' | 'default' {
  if (reason === 'active') return 'active'
  return reason === 'goal' ? 'personalized' : 'default'
}

// ---------------------------------------------------------------------------
// Loader
// ---------------------------------------------------------------------------

const CATALOG_TTL_MS = 10 * 60 * 1000
const catalogCache = new TtlCache<CatalogPath[]>(CATALOG_TTL_MS, 1)
const goalListCache = new TtlCache<Map<string, string[]>>(CATALOG_TTL_MS, 1)

/** For tests: forget the cached catalogue and goal lists. */
export function clearNextPathCaches(): void {
  catalogCache.clear()
  goalListCache.clear()
}

async function loadCatalog(client: Client): Promise<CatalogPath[]> {
  const cached = catalogCache.get('all')
  if (cached) return cached
  const { data, error } = await client
    .from('learning_paths')
    .select('id, slug, is_featured, guest_accessible, display_order')
    .eq('is_active', true)
  if (error) {
    console.error('[NEXT_PATHS] catalogue read failed:', error.message)
    return []
  }
  const rows = (data ?? []) as CatalogPath[]
  catalogCache.set('all', rows)
  return rows
}

async function loadGoalLists(client: Client): Promise<Map<string, string[]>> {
  const cached = goalListCache.get('all')
  if (cached) return cached
  const { data, error } = await client
    .from('growth_goal_paths')
    .select('goal, path_slug, position')
  if (error) {
    console.error('[NEXT_PATHS] goal lists read failed:', error.message)
    return new Map()
  }
  const rows = ((data ?? []) as { goal: string; path_slug: string; position: number }[])
    .sort((a, b) => a.position - b.position || a.path_slug.localeCompare(b.path_slug))
  const lists = new Map<string, string[]>()
  for (const r of rows) {
    const list = lists.get(r.goal) ?? []
    list.push(r.path_slug)
    lists.set(r.goal, list)
  }
  goalListCache.set('all', lists)
  return lists
}

/** The user's stored growth goal, or null (none, or a failed read). */
export async function loadGrowthGoal(client: Client, userId: string): Promise<GrowthGoal | null> {
  const { data, error } = await client
    .from('user_growth_goals')
    .select('goal')
    .eq('user_id', userId)
    .maybeSingle()
  if (error) {
    console.error('[NEXT_PATHS] goal read failed:', error.message)
    return null
  }
  return growthGoalOrNull(data?.goal)
}

interface ProgressRow {
  learning_path_id: string
  completed_at: string | null
  enrolled_at: string | null
}

async function loadProgressRows(client: Client, userId: string): Promise<ProgressRow[]> {
  const { data, error } = await client
    .from('user_learning_path_progress')
    .select('learning_path_id, completed_at, enrolled_at')
    .eq('user_id', userId)
    .order('last_activity_at', { ascending: false, nullsFirst: false })
    .limit(200)
  if (error) {
    console.error('[NEXT_PATHS] progress read failed:', error.message)
    return []
  }
  return (data ?? []) as ProgressRow[]
}

export interface NextPathsResult {
  paths: NextPath[]
  goal: GrowthGoal | null
  /** See [lastFinishedPathId]. */
  lastFinishedPathId: string | null
  /** Finished path ids (callers use them for progress). */
  finishedIds: Set<string>
  /** Path ids with an enrolment. */
  enrolledIds: Set<string>
}

/**
 * Loads everything the engine needs and ranks. Never throws: a failed read
 * leaves that input empty (the list degrades to featured paths).
 * [userId] null = nobody signed in (featured and catalogue only).
 */
export async function loadNextPaths(
  client: Client,
  opts: { userId: string | null; isGuest: boolean; limit?: number },
): Promise<NextPathsResult> {
  const { userId, isGuest } = opts
  const [catalog, goalLists, goal, rows, finishedIds] = await Promise.all([
    loadCatalog(client),
    loadGoalLists(client),
    userId ? loadGrowthGoal(client, userId) : Promise.resolve(null),
    userId ? loadProgressRows(client, userId) : Promise.resolve([] as ProgressRow[]),
    userId
      ? getCompletedPathIds(client, userId).catch(() => new Set<string>())
      : Promise.resolve(new Set<string>()),
  ])

  const activeIds = new Set(catalog.map((p) => p.id))
  const enrolled = rows.filter((r) => r.enrolled_at !== null && activeIds.has(r.learning_path_id))
  const enrolledIds = new Set(enrolled.map((r) => r.learning_path_id))
  const activePathIds = enrolled
    .filter((r) => r.completed_at === null && !finishedIds.has(r.learning_path_id))
    .map((r) => r.learning_path_id)

  const paths = rankNextPaths({
    catalog,
    activePathIds,
    goalSlugs: goal ? goalLists.get(goal) ?? [] : [],
    finishedIds,
    enrolledIds,
    isGuest,
  }, opts.limit)

  return {
    paths,
    goal,
    lastFinishedPathId: lastFinishedPathId(enrolled, finishedIds, activePathIds),
    finishedIds,
    enrolledIds,
  }
}
