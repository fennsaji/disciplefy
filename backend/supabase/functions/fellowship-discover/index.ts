/**
 * fellowship-discover
 * Returns public, active fellowships that the authenticated user has not yet joined.
 * Optionally filtered by language. Cursor-based pagination (newest first).
 * GET /fellowship-discover?language=en&limit=10&cursor=ISO_TIMESTAMP
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

const VALID_LANGUAGES = ['en', 'hi', 'ml'] as const
const DEFAULT_LIMIT = 10
const MAX_LIMIT = 50

type Language = typeof VALID_LANGUAGES[number]

interface FellowshipRow {
  id: string
  name: string
  description: string | null
  language: string
  max_members: number
  created_at: string
  mentor_user_id: string
}

interface MentorEntry {
  userId: string
  name: string | null
}

interface MemberRow {
  fellowship_id: string
}

interface StudyRow {
  fellowship_id: string
  learning_paths: { title: string | null } | null
}

async function handleDiscoverFellowships(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  await checkMaintenanceMode(req, services)

  // Auth check — must come before any DB query
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  // Parse query params
  const url = new URL(req.url)
  const languageParam = url.searchParams.get('language')
  // Composite cursor: "ISO_TIMESTAMP:uuid" — prevents duplicate/skipped rows
  // when two fellowships share the same created_at millisecond timestamp.
  const rawCursor = url.searchParams.get('cursor') ?? null
  const [cursorTs, cursorId] = rawCursor ? rawCursor.split(':') : [null, null]
  const cursorParam = cursorTs ?? null
  const rawLimit = parseInt(url.searchParams.get('limit') || String(DEFAULT_LIMIT), 10)
  const limit = Number.isNaN(rawLimit) || rawLimit < 1 ? DEFAULT_LIMIT : Math.min(rawLimit, MAX_LIMIT)
  const rawSearch = url.searchParams.get('search')?.trim() || null
  // Require 2–60 chars and escape LIKE wildcards to prevent pattern injection / DoS.
  const searchParam = rawSearch && rawSearch.length >= 2 && rawSearch.length <= 60
    ? rawSearch.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_')
    : null

  if (languageParam !== null && !VALID_LANGUAGES.includes(languageParam as Language)) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Invalid language. Must be one of: ${VALID_LANGUAGES.join(', ')}`,
      400
    )
  }

  const language = languageParam as Language | null

  // We intentionally use the service client (bypassing RLS) here because this
  // endpoint applies its own filtering logic: public + active + exclude caller.
  // Using the anon/user client would rely on RLS which is intentionally more
  // restrictive for member-only rows; using the service client lets us do one
  // clean query and filter in application code.
  const db = services.supabaseServiceClient

  // Pre-query: Fetch all fellowship IDs the caller is already an active member of.
  // We exclude these at the DB level so cursor-based pagination is accurate.
  const { data: callerMemberships, error: callerMembershipsError } = await db
    .from('fellowship_members')
    .select('fellowship_id')
    .eq('user_id', user.id)
    .eq('is_active', true)

  if (callerMembershipsError) {
    console.error('[fellowship-discover] Caller memberships error:', callerMembershipsError)
    throw new AppError('DATABASE_ERROR', 'Failed to check memberships', 500)
  }

  const callerMemberIds = (callerMemberships ?? []).map(
    m => (m as MemberRow).fellowship_id
  )

  // Query 1: Public active fellowships, cursor-paginated, caller-excluded at DB level.
  // Fetch limit+1 rows to detect whether a next page exists.
  // Order by (created_at DESC, id DESC) for a stable composite cursor.
  // Using created_at alone would skip or duplicate rows created at the same millisecond.
  let fellowshipsQuery = db
    .from('fellowships')
    .select('id, name, description, language, max_members, created_at, mentor_user_id')
    .eq('is_public', true)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
    .order('id', { ascending: false })
    .limit(limit + 1)

  if (language !== null) {
    fellowshipsQuery = fellowshipsQuery.eq('language', language)
  }

  if (searchParam !== null) {
    fellowshipsQuery = fellowshipsQuery.ilike('name', `%${searchParam}%`)
  }

  if (callerMemberIds.length > 0) {
    fellowshipsQuery = fellowshipsQuery.not('id', 'in', `(${callerMemberIds.join(',')})`)
  }

  // Composite cursor: skip rows older than the cursor timestamp, or with the
  // same timestamp but a lexicographically smaller UUID.
  if (cursorParam !== null) {
    if (cursorId) {
      fellowshipsQuery = fellowshipsQuery.or(
        `created_at.lt.${cursorParam},and(created_at.eq.${cursorParam},id.lt.${cursorId})`
      )
    } else {
      fellowshipsQuery = fellowshipsQuery.lt('created_at', cursorParam)
    }
  }

  const { data: fellowships, error: fellowshipsError } = await fellowshipsQuery

  if (fellowshipsError) {
    console.error('[fellowship-discover] Fellowships query error:', fellowshipsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowships', 500)
  }

  // Determine pagination before trimming
  const hasMore = (fellowships?.length ?? 0) > limit
  const pageRows = hasMore
    ? (fellowships as FellowshipRow[]).slice(0, limit)
    : ((fellowships ?? []) as FellowshipRow[])
  const lastRow = pageRows[pageRows.length - 1]
  const nextCursor = hasMore ? `${lastRow.created_at}:${lastRow.id}` : null

  if (pageRows.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        data: { fellowships: [] },
        pagination: { has_more: false, next_cursor: null }
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const ids = pageRows.map(f => f.id)
  const mentorIds = [...new Set(pageRows.map(f => f.mentor_user_id))]

  // Queries 2–4: Bulk enrichment — 2 DB queries + N auth admin lookups (N = unique mentors)
  const [memberRowsResult, studyRowsResult, mentorEntries] = await Promise.all([
    // Query 2: All active member rows for page fellowship IDs — count in memory
    db
      .from('fellowship_members')
      .select('fellowship_id')
      .in('fellowship_id', ids)
      .eq('is_active', true),

    // Query 3: Active study rows for page fellowship IDs with joined learning path title
    db
      .from('fellowship_study')
      .select('fellowship_id, learning_paths(title)')
      .in('fellowship_id', ids)
      .is('completed_at', null)
      .order('started_at', { ascending: false }),

    // Query 4: Mentor display names via auth admin API — same source as fellowship-posts-list.
    // user_profiles has no display_name column; names live in auth user_metadata.
    Promise.all(
      mentorIds.map(async (userId): Promise<MentorEntry> => {
        try {
          const { data: userData } = await db.auth.admin.getUserById(userId)
          if (!userData?.user) return { userId, name: null }
          const u = userData.user
          const name: string | null =
            u.user_metadata?.full_name ??
            u.user_metadata?.name ??
            u.user_metadata?.display_name ??
            null
          return { userId, name }
        } catch {
          return { userId, name: null }
        }
      })
    ),
  ])

  const { data: memberRows, error: memberRowsError } = memberRowsResult
  if (memberRowsError) {
    console.error('[fellowship-discover] Bulk member rows error:', memberRowsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch member counts', 500)
  }

  const { data: studyRows, error: studyRowsError } = studyRowsResult
  if (studyRowsError) {
    console.error('[fellowship-discover] Bulk study query error:', studyRowsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch study info', 500)
  }

  // Build mentor name map: user_id → display name
  const mentorNameMap = new Map<string, string | null>()
  for (const entry of mentorEntries) {
    mentorNameMap.set(entry.userId, entry.name)
  }

  // Build member count map: fellowship_id → count
  const memberCountMap = new Map<string, number>()
  for (const row of (memberRows as MemberRow[] ?? [])) {
    const fid = row.fellowship_id
    memberCountMap.set(fid, (memberCountMap.get(fid) ?? 0) + 1)
  }

  // Build study title map: fellowship_id → title of most-recently-started active study
  // The query is ordered by started_at DESC so the first row per fellowship is the latest.
  const studyTitleMap = new Map<string, string | null>()
  for (const row of (studyRows as StudyRow[] ?? [])) {
    const fid = row.fellowship_id
    if (!studyTitleMap.has(fid)) {
      const title: string | null = row.learning_paths?.title ?? null
      studyTitleMap.set(fid, title)
    }
  }

  const discoverable = pageRows.map(f => ({
    id: f.id,
    name: f.name,
    description: f.description,
    language: f.language,
    member_count: memberCountMap.get(f.id) ?? 0,
    max_members: f.max_members,
    current_study_title: studyTitleMap.get(f.id) ?? null,
    mentor_name: mentorNameMap.get(f.mentor_user_id) ?? null
  }))

  return new Response(
    JSON.stringify({
      success: true,
      data: { fellowships: discoverable },
      pagination: { has_more: hasMore, next_cursor: nextCursor }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleDiscoverFellowships, {
  allowedMethods: ['GET'],
  enableAnalytics: false,
  timeout: 15000
})
