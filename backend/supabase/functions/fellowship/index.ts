/**
 * fellowship  (merged)
 * Routes:
 *   GET    /fellowship                          → list my fellowships (auth required)
 *   GET    /fellowship?fellowship_id=UUID       → get single fellowship (auth optional)
 *   GET    /fellowship/discover                 → discover public fellowships (auth required)
 *   POST   /fellowship                          → create fellowship (auth required)
 *   POST   /fellowship/join                     → join public fellowship (auth required)
 *   POST   /fellowship/leave                    → leave fellowship (auth required)
 *   PATCH  /fellowship                          → update fellowship (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { pushMentorsOrQueue } from '../_shared/services/discipler-service.ts'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
/// How many active fellowships one non-admin account may own.
const MAX_FELLOWSHIPS_PER_USER = 5

const VALID_LANGUAGES = ['en', 'hi', 'ml'] as const
type Language = typeof VALID_LANGUAGES[number]

// ---------------------------------------------------------------------------
// List my fellowships  GET /fellowship  (no fellowship_id param)
// ---------------------------------------------------------------------------

async function handleListFellowships(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  const url = new URL(req.url)
  const langParam = url.searchParams.get('language') ?? 'en'
  const language = (VALID_LANGUAGES.includes(langParam as Language) ? langParam : 'en') as Language

  const db = services.supabaseServiceClient

  const { data: memberships, error: membershipsError } = await db
    .from('fellowship_members')
    .select(`
      role,
      joined_at,
      discipler_activity_push,
      fellowships (
        id,
        name,
        description,
        is_active,
        is_public,
        posting_permission,
        created_at,
        mentor_user_id,
        is_official,
        discipler_allowed,
        daily_post_allowed,
        discipler_reply_mode,
        discipler_reply_scope,
        discipler_reply_delay_min,
        discipler_react_enabled,
        daily_post_on,
        daily_post_frequency_days,
        daily_post_auto_advance
      )
    `)
    .eq('user_id', user.id)
    .eq('is_active', true)

  if (membershipsError) {
    console.error('[fellowship/list] Memberships query error:', membershipsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowships', 500)
  }

  const activeMemberships = (memberships || []).filter(
    (m: any) => m.fellowships && m.fellowships.is_active === true
  )

  const fellowshipIds = activeMemberships.map((m: any) => m.fellowships.id as string)

  const { data: mentorRows, error: mentorRowsError } = fellowshipIds.length > 0
    ? await db.from('fellowship_members').select('fellowship_id, user_id')
        .in('fellowship_id', fellowshipIds).eq('role', 'mentor').eq('is_active', true)
    : { data: [] as { fellowship_id: string; user_id: string }[], error: null }
  if (mentorRowsError) {
    console.error('[fellowship/list] Mentor rows query error:', mentorRowsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch mentors', 500)
  }

  const mentorUserIds = [...new Set((mentorRows ?? []).map((r: any) => r.user_id as string))]
  const mentorEntries = await Promise.all(
    mentorUserIds.map(async (userId: string): Promise<MentorEntry> => {
      try {
        const { data: userData } = await db.auth.admin.getUserById(userId)
        if (!userData?.user) return { userId, name: null, avatar: null }
        const u = userData.user
        const name: string | null =
          u.user_metadata?.full_name ?? u.user_metadata?.name ??
          u.user_metadata?.display_name ?? null
        const avatar: string | null = u.user_metadata?.avatar_url ?? null
        return { userId, name, avatar }
      } catch {
        return { userId, name: null, avatar: null }
      }
    })
  )

  const mentorInfoMap = new Map<string, { name: string | null; avatar: string | null }>()
  for (const entry of mentorEntries) mentorInfoMap.set(entry.userId, { name: entry.name, avatar: entry.avatar })

  const mentorsByFellowship = new Map<string, { userId: string; name: string | null; avatar: string | null }[]>()
  for (const row of (mentorRows ?? []) as { fellowship_id: string; user_id: string }[]) {
    const info = mentorInfoMap.get(row.user_id) ?? { name: null, avatar: null }
    const list = mentorsByFellowship.get(row.fellowship_id) ?? []
    list.push({ userId: row.user_id, name: info.name, avatar: info.avatar })
    mentorsByFellowship.set(row.fellowship_id, list)
  }

  const fellowships = await Promise.all(
    activeMemberships.map(async (membership: any) => {
      const fellowship = membership.fellowships as any
      const fellowshipId: string = fellowship.id

      const [countResult, studyResult] = await Promise.all([
        db.from('fellowship_members')
          .select('*', { count: 'exact', head: true })
          .eq('fellowship_id', fellowshipId)
          .eq('is_active', true),
        db.from('fellowship_study')
          .select('learning_path_id, current_guide_index, started_at, completed_at, learning_paths(id, title)')
          .eq('fellowship_id', fellowshipId)
          .is('completed_at', null)
          .order('started_at', { ascending: false })
          .maybeSingle()
      ])

      const { count: memberCount, error: countError } = countResult
      if (countError) {
        console.error('[fellowship/list] Member count error for', fellowshipId, ':', countError)
        throw new AppError('DATABASE_ERROR', 'Failed to fetch member count', 500)
      }

      const { data: study, error: studyError } = studyResult
      if (studyError) {
        console.error('[fellowship/list] Study query error for', fellowshipId, ':', studyError)
        throw new AppError('DATABASE_ERROR', 'Failed to fetch study info', 500)
      }

      return {
        id: fellowship.id,
        name: fellowship.name,
        description: fellowship.description,
        member_count: memberCount || 0,
        user_role: membership.role as 'mentor' | 'member',
        joined_at: membership.joined_at,
        created_at: fellowship.created_at,
        is_public: fellowship.is_public ?? false,
        posting_permission: fellowship.posting_permission ?? 'all_members',
        mentors: (mentorsByFellowship.get(fellowship.id) ?? []).map((m) => ({ user_id: m.userId, display_name: m.name, avatar_url: m.avatar })),
        mentor_name: (mentorsByFellowship.get(fellowship.id) ?? [])[0]?.name ?? null, // kept for older clients
        is_official: fellowship.is_official ?? false,
        discipler_allowed: fellowship.discipler_allowed ?? false,
        daily_post_allowed: fellowship.daily_post_allowed ?? false,
        discipler_reply_mode: fellowship.discipler_reply_mode ?? 'auto',
        discipler_reply_scope: fellowship.discipler_reply_scope ?? 'all',
        discipler_reply_delay_min: fellowship.discipler_reply_delay_min ?? 0,
        discipler_react_enabled: fellowship.discipler_react_enabled ?? true,
        daily_post_on: fellowship.daily_post_on ?? true,
        daily_post_frequency_days: fellowship.daily_post_frequency_days ?? 1,
        daily_post_auto_advance: fellowship.daily_post_auto_advance ?? true,
        my_discipler_activity_push: (membership as any).discipler_activity_push ?? true,
        current_study: study
          ? {
              learning_path_id: study.learning_path_id,
              learning_path_title: (study.learning_paths as any)?.title ?? null,
              current_guide_index: study.current_guide_index,
              started_at: study.started_at,
              completed_at: study.completed_at
            }
          : null
      }
    })
  )

  // Batch-fetch translations + topic counts for active studies
  const pathIds = [...new Set(
    fellowships
      .map(f => f.current_study?.learning_path_id)
      .filter((id): id is string => !!id)
  )]

  if (pathIds.length > 0) {
    const [translationsResult, topicsResult] = await Promise.all([
      language !== 'en'
        ? db.from('learning_path_translations')
            .select('learning_path_id, title')
            .in('learning_path_id', pathIds)
            .eq('lang_code', language)
        : Promise.resolve({ data: [] }),
      db.from('learning_path_topics')
        .select('learning_path_id')
        .in('learning_path_id', pathIds)
        .eq('is_active', true),
    ])

    const translationMap = new Map<string, string>()
    for (const t of (translationsResult.data ?? [])) {
      translationMap.set(t.learning_path_id, t.title)
    }

    const topicsCountMap = new Map<string, number>()
    for (const t of (topicsResult.data ?? [])) {
      topicsCountMap.set(t.learning_path_id, (topicsCountMap.get(t.learning_path_id) ?? 0) + 1)
    }

    for (const f of fellowships) {
      if (!f.current_study) continue
      const pathId = f.current_study.learning_path_id
      if (!pathId) continue
      const cs = f.current_study as any
      const translated = translationMap.get(pathId)
      if (translated) cs.learning_path_title = translated
      cs.total_guides = topicsCountMap.get(pathId) ?? null
    }
  }

  return new Response(
    JSON.stringify({ success: true, data: { fellowships } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Get single fellowship  GET /fellowship?fellowship_id=UUID
// ---------------------------------------------------------------------------

async function handleGetFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const langParam = url.searchParams.get('language') ?? 'en'
  const language = (VALID_LANGUAGES.includes(langParam as Language) ? langParam : 'en') as Language

  const db = services.supabaseServiceClient

  const { data: fellowship } = await db
    .from('fellowships')
    .select('*')
    .eq('id', fellowshipId)
    .maybeSingle()

  if (!fellowship) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)

  const { count: memberCount, error: countError } = await db
    .from('fellowship_members')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', fellowshipId)
    .eq('is_active', true)

  if (countError) console.error('[fellowship/get] Count query error:', countError)

  const { data: study } = await db
    .from('fellowship_study')
    .select(`current_guide_index, started_at, learning_paths (id, title)`)
    .eq('fellowship_id', fellowshipId)
    .is('completed_at', null)
    .maybeSingle()

  let learningPathTitle = (study?.learning_paths as any)?.title ?? null
  const learningPathId = (study?.learning_paths as any)?.id ?? null

  // Fetch translated title and topic count in parallel when a path is active
  let totalGuides: number | null = null
  await Promise.all([
    (async () => {
      if (study && language !== 'en' && learningPathId) {
        const { data: translation } = await db
          .from('learning_path_translations')
          .select('title')
          .eq('learning_path_id', learningPathId)
          .eq('lang_code', language)
          .maybeSingle()
        if (translation?.title) learningPathTitle = translation.title
      }
    })(),
    (async () => {
      if (learningPathId) {
        const { count } = await db
          .from('learning_path_topics')
          .select('*', { count: 'exact', head: true })
          .eq('learning_path_id', learningPathId)
          .eq('is_active', true)
        totalGuides = count ?? null
      }
    })(),
  ])

  let isMember = false
  let callerRole: string | null = null
  const authHeader = req.headers.get('Authorization')
  if (authHeader) {
    const { data: { user } } = await services.supabaseServiceClient.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (user) {
      const { data: membership } = await db
        .from('fellowship_members')
        .select('role')
        .eq('fellowship_id', fellowshipId)
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle()
      isMember = !!membership
      callerRole = membership?.role || null
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: fellowship.id,
        name: fellowship.name,
        description: fellowship.description,
        max_members: fellowship.max_members,
        posting_permission: fellowship.posting_permission,
        member_count: memberCount || 0,
        is_active: fellowship.is_active,
        active_study: study ? {
          learning_path_id: learningPathId,
          learning_path_title: learningPathTitle,
          current_guide_index: study.current_guide_index,
          started_at: study.started_at,
          total_guides: totalGuides,
        } : null,
        caller_is_member: isMember,
        caller_role: callerRole,
        created_at: fellowship.created_at
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Discover public fellowships  GET /fellowship/discover
// ---------------------------------------------------------------------------

interface FellowshipRow { id: string; name: string; description: string | null; language: string; max_members: number | null; created_at: string; mentor_user_id: string; is_official?: boolean; discipler_allowed?: boolean }
interface MentorEntry { userId: string; name: string | null; avatar: string | null }
interface MemberRow { fellowship_id: string }
interface StudyRow { fellowship_id: string; learning_paths: { title: string | null }[] | null }

const DEFAULT_LIMIT = 10
const MAX_LIMIT = 50

async function handleDiscoverFellowships(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  const url = new URL(req.url)
  const languageParam = url.searchParams.get('language')
  const rawCursor = url.searchParams.get('cursor') ?? null
  const [cursorTs, cursorId] = rawCursor ? rawCursor.split(':') : [null, null]
  const cursorParam = cursorTs ?? null
  const rawLimit = parseInt(url.searchParams.get('limit') || String(DEFAULT_LIMIT), 10)
  const limit = Number.isNaN(rawLimit) || rawLimit < 1 ? DEFAULT_LIMIT : Math.min(rawLimit, MAX_LIMIT)
  const rawSearch = url.searchParams.get('search')?.trim() || null
  const searchParam = rawSearch && rawSearch.length >= 2 && rawSearch.length <= 60
    ? rawSearch.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_')
    : null

  if (languageParam !== null && !VALID_LANGUAGES.includes(languageParam as Language)) {
    throw new AppError('VALIDATION_ERROR', `Invalid language. Must be one of: ${VALID_LANGUAGES.join(', ')}`, 400)
  }

  const language = languageParam as Language | null
  const db = services.supabaseServiceClient

  const { data: callerMemberships, error: callerMembershipsError } = await db
    .from('fellowship_members')
    .select('fellowship_id')
    .eq('user_id', user.id)
    .eq('is_active', true)

  if (callerMembershipsError) {
    console.error('[fellowship/discover] Caller memberships error:', callerMembershipsError)
    throw new AppError('DATABASE_ERROR', 'Failed to check memberships', 500)
  }

  const callerMemberIds = (callerMemberships ?? []).map(m => (m as MemberRow).fellowship_id)

  let fellowshipsQuery = db
    .from('fellowships')
    .select('id, name, description, language, max_members, created_at, mentor_user_id, is_official, discipler_allowed')
    .eq('is_public', true)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
    .order('id', { ascending: false })
    .limit(limit + 1)

  if (language !== null) fellowshipsQuery = fellowshipsQuery.eq('language', language)
  if (searchParam !== null) fellowshipsQuery = fellowshipsQuery.ilike('name', `%${searchParam}%`)
  if (callerMemberIds.length > 0) fellowshipsQuery = fellowshipsQuery.not('id', 'in', `(${callerMemberIds.join(',')})`)

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
    console.error('[fellowship/discover] Fellowships query error:', fellowshipsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowships', 500)
  }

  const hasMore = (fellowships?.length ?? 0) > limit
  const pageRows = hasMore
    ? (fellowships as FellowshipRow[]).slice(0, limit)
    : ((fellowships ?? []) as FellowshipRow[])
  const lastRow = pageRows[pageRows.length - 1]
  const nextCursor = hasMore ? `${lastRow.created_at}:${lastRow.id}` : null

  if (pageRows.length === 0) {
    return new Response(
      JSON.stringify({ success: true, data: { fellowships: [] }, pagination: { has_more: false, next_cursor: null } }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const ids = pageRows.map(f => f.id)
  const mentorIds = [...new Set(pageRows.map(f => f.mentor_user_id))]

  const [memberRowsResult, studyRowsResult, mentorEntries] = await Promise.all([
    db.from('fellowship_members').select('fellowship_id').in('fellowship_id', ids).eq('is_active', true),
    db.from('fellowship_study').select('fellowship_id, learning_paths(title)').in('fellowship_id', ids).is('completed_at', null).order('started_at', { ascending: false }),
    Promise.all(
      mentorIds.map(async (userId): Promise<MentorEntry> => {
        try {
          const { data: userData } = await db.auth.admin.getUserById(userId)
          if (!userData?.user) return { userId, name: null, avatar: null }
          const u = userData.user
          const name: string | null =
            u.user_metadata?.full_name ?? u.user_metadata?.name ??
            u.user_metadata?.display_name ?? null
          const avatar: string | null = u.user_metadata?.avatar_url ?? null
          return { userId, name, avatar }
        } catch {
          return { userId, name: null, avatar: null }
        }
      })
    ),
  ])

  const { data: memberRows, error: memberRowsError } = memberRowsResult
  if (memberRowsError) {
    console.error('[fellowship/discover] Bulk member rows error:', memberRowsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch member counts', 500)
  }

  const { data: studyRows, error: studyRowsError } = studyRowsResult
  if (studyRowsError) {
    console.error('[fellowship/discover] Bulk study query error:', studyRowsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch study info', 500)
  }

  const mentorNameMap = new Map<string, string | null>()
  for (const entry of mentorEntries) mentorNameMap.set(entry.userId, entry.name)

  const memberCountMap = new Map<string, number>()
  for (const row of (memberRows as MemberRow[] ?? [])) {
    const fid = row.fellowship_id
    memberCountMap.set(fid, (memberCountMap.get(fid) ?? 0) + 1)
  }

  const studyTitleMap = new Map<string, string | null>()
  for (const row of (studyRows as StudyRow[] ?? [])) {
    const fid = row.fellowship_id
    if (!studyTitleMap.has(fid)) {
      studyTitleMap.set(fid, row.learning_paths?.[0]?.title ?? null)
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
    mentor_name: mentorNameMap.get(f.mentor_user_id) ?? null,
    is_official: f.is_official ?? false,
    discipler_allowed: f.discipler_allowed ?? false,
  }))

  return new Response(
    JSON.stringify({ success: true, data: { fellowships: discoverable }, pagination: { has_more: hasMore, next_cursor: nextCursor } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Create fellowship  POST /fellowship
// ---------------------------------------------------------------------------

async function handleCreateFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: {
    name: string; description?: string; max_members?: number | null; is_public?: boolean; language?: string; posting_permission?: string
    is_official?: boolean; discipler_allowed?: boolean; daily_post_allowed?: boolean
  }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }

  if (!body.name || typeof body.name !== 'string') throw new AppError('VALIDATION_ERROR', 'name is required', 400)
  const name = body.name.trim()
  if (name.length < 3 || name.length > 60) throw new AppError('VALIDATION_ERROR', 'name must be 3–60 characters', 400)
  // max_members: a number 2..50, or null = unlimited (app-admin only — checked below).
  if (body.max_members !== undefined && body.max_members !== null) {
    if (typeof body.max_members !== 'number' || !Number.isInteger(body.max_members) || body.max_members < 2 || body.max_members > 50) {
      throw new AppError('VALIDATION_ERROR', 'max_members must be an integer between 2 and 50 (or null for unlimited)', 400)
    }
  }
  const postingPermission = body.posting_permission ?? 'all_members'
  if (postingPermission !== 'all_members' && postingPermission !== 'mentor_only') {
    throw new AppError('VALIDATION_ERROR', "posting_permission must be 'all_members' or 'mentor_only'", 400)
  }
  if (body.description && body.description.trim().length > 500) {
    throw new AppError('VALIDATION_ERROR', 'description must be 500 characters or fewer', 400)
  }

  const language = body.language ?? 'en'
  if (!VALID_LANGUAGES.includes(language as Language)) {
    throw new AppError('VALIDATION_ERROR', 'language must be en, hi, or ml', 400)
  }

  const db = services.supabaseServiceClient

  // Permission check: admin, existing mentor, or plus/premium subscriber
  const [planResult, mentorResult, profileResult] = await Promise.all([
    db.rpc('get_user_plan_with_subscription', { p_user_id: user.id }),
    db.from('fellowship_members').select('id', { count: 'exact', head: true }).eq('user_id', user.id).eq('role', 'mentor'),
    db.from('user_profiles').select('is_admin').eq('id', user.id).single(),
  ])

  const userPlan: string = planResult.data ?? 'free'
  const isMentor = (mentorResult.count ?? 0) > 0
  const isAdmin = profileResult.data?.is_admin === true
  // Admins resolve to 'premium' via get_user_plan_with_subscription, so no separate admin check needed
  const isPaidEligible = userPlan === 'plus' || userPlan === 'premium'

  if (!isMentor && !isPaidEligible) {
    throw new AppError('PERMISSION_DENIED', 'A Plus or Premium subscription is required to create a fellowship', 403)
  }

  // Cap what one person can own. Creation used to be unbounded: mentoring a
  // single group granted it, and an existing mentor can promote anyone to
  // co-mentor, so the grant spread without an admin ever being involved.
  //
  // Counted by ownership (`mentor_user_id`), not by mentor membership — being
  // made a co-mentor of someone else's group should not consume, or unlock,
  // your own allowance. Admins are exempt.
  if (!isAdmin) {
    const { count: ownedCount, error: ownedError } = await db
      .from('fellowships')
      .select('id', { count: 'exact', head: true })
      .eq('mentor_user_id', user.id)
      .eq('is_active', true)

    if (ownedError) {
      console.error('[fellowship/create] Owned-count error:', ownedError)
      throw new AppError('DATABASE_ERROR', 'Failed to check fellowship limit', 500)
    }
    if ((ownedCount ?? 0) >= MAX_FELLOWSHIPS_PER_USER) {
      throw new AppError(
        'LIMIT_EXCEEDED',
        `You can create up to ${MAX_FELLOWSHIPS_PER_USER} fellowships. Archive one to make room for another.`,
        409,
      )
    }
  }

  const { count: nameCount, error: nameCheckError } = await db
    .from('fellowships')
    .select('*', { count: 'exact', head: true })
    .ilike('name', name)
    .eq('is_active', true)

  if (nameCheckError) {
    console.error('[fellowship/create] Name check error:', nameCheckError)
    throw new AppError('DATABASE_ERROR', 'Failed to check name availability', 500)
  }
  if ((nameCount || 0) > 0) throw new AppError('CONFLICT', 'A fellowship with this name already exists', 409)

  if (body.is_public === true && !isAdmin) {
    throw new AppError('PERMISSION_DENIED', 'Only admins can create public fellowships', 403)
  }
  if (body.max_members === null && !isAdmin) {
    throw new AppError('PERMISSION_DENIED', 'Only admins can create unlimited-size fellowships', 403)
  }

  const wantsOfficial = body.is_official === true
  const wantsDiscipler = body.discipler_allowed === true
  const wantsDaily = body.daily_post_allowed === true
  if ((wantsOfficial || wantsDiscipler || wantsDaily) && !isAdmin) {
    throw new AppError('PERMISSION_DENIED', 'Only admins can set official or Discipler flags', 403)
  }

  const { data: fellowship, error: createError } = await db
    .from('fellowships')
    .insert({
      name,
      description: body.description?.trim() || null,
      mentor_user_id: user.id,
      // null = unlimited (admin-gated above); undefined → default 12
      max_members: body.max_members === undefined ? 12 : body.max_members,
      is_public: body.is_public ?? false,
      language,
      posting_permission: postingPermission,
      is_official: wantsOfficial, discipler_allowed: wantsDiscipler, daily_post_allowed: wantsDaily,
    })
    .select()
    .single()

  if (createError) {
    console.error('[fellowship/create] DB error:', createError)
    throw new AppError('DATABASE_ERROR', 'Failed to create fellowship', 500)
  }

  const { error: memberError } = await db.from('fellowship_members').insert({
    fellowship_id: fellowship.id,
    user_id: user.id,
    role: 'mentor'
  })

  if (memberError) {
    console.error('[fellowship/create] Member insert error:', memberError)
    const { error: cleanupError } = await db.from('fellowships').delete().eq('id', fellowship.id)
    if (cleanupError) console.error('[fellowship/create] Cleanup failed — orphaned fellowship:', fellowship.id, cleanupError)
    throw new AppError('DATABASE_ERROR', 'Failed to initialize fellowship membership', 500)
  }

  // Every fellowship gets a default study path (non-fatal — a fellowship without one just
  // shows no active study until a mentor sets one via fellowship-study).
  const { data: defaultPathId, error: defaultPathError } = await db.rpc('default_learning_path_id')
  if (defaultPathError) {
    console.error('[fellowship] default study insert failed', { fellowshipId: fellowship.id, error: defaultPathError })
  } else if (defaultPathId) {
    const { error: studyError } = await db.from('fellowship_study').insert({
      fellowship_id: fellowship.id,
      learning_path_id: defaultPathId,
      current_guide_index: 0
    })
    if (studyError) {
      console.error('[fellowship] default study insert failed', { fellowshipId: fellowship.id, error: studyError })
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: fellowship.id,
        name: fellowship.name,
        description: fellowship.description,
        max_members: fellowship.max_members,
        is_public: fellowship.is_public,
        language: fellowship.language,
        posting_permission: fellowship.posting_permission,
        mentor_user_id: fellowship.mentor_user_id,
        created_at: fellowship.created_at
      },
      message: 'Fellowship created successfully'
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Join public fellowship  POST /fellowship/join
// ---------------------------------------------------------------------------

async function handleJoinPublicFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string }
  try {
    body = await req.json() as { fellowship_id: string }
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!UUID_RE.test(body.fellowship_id)) throw new AppError('VALIDATION_ERROR', 'fellowship_id must be a valid UUID', 400)

  const db = services.supabaseServiceClient

  const { data: fellowship, error: fellowshipError } = await db
    .from('fellowships')
    .select('id, name, is_active, is_public, max_members, mentor_user_id')
    .eq('id', body.fellowship_id)
    .maybeSingle()

  if (fellowshipError) {
    console.error('[fellowship/join] Fellowship fetch error:', fellowshipError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowship', 500)
  }
  if (!fellowship) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)
  if (!fellowship.is_active) throw new AppError('FORBIDDEN', 'Fellowship is not active', 403)
  if (!fellowship.is_public) throw new AppError('FORBIDDEN', 'Fellowship is not open to public joining', 403)

  const { data: existing, error: existingError } = await db
    .from('fellowship_members')
    .select('id, is_active')
    .eq('fellowship_id', fellowship.id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (existingError) {
    console.error('[fellowship/join] Existing member check error:', existingError)
    throw new AppError('DATABASE_ERROR', 'Failed to check membership status', 500)
  }
  if (existing?.is_active) throw new AppError('CONFLICT', 'You are already a member of this fellowship', 409)

  const { count: memberCount, error: countError } = await db
    .from('fellowship_members')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', fellowship.id)
    .eq('is_active', true)

  if (countError) {
    console.error('[fellowship/join] Count error:', countError)
    throw new AppError('DATABASE_ERROR', 'Failed to check member capacity', 500)
  }
  if (fellowship.max_members !== null && (memberCount || 0) >= fellowship.max_members) throw new AppError('VALIDATION_ERROR', 'Fellowship is full', 400)

  if (existing) {
    const { error: updateError } = await db.from('fellowship_members')
      .update({ is_active: true, role: 'member' }).eq('id', existing.id)
    if (updateError) {
      console.error('[fellowship/join] Member reactivation error:', updateError)
      throw new AppError('DATABASE_ERROR', 'Failed to join fellowship', 500)
    }
  } else {
    const { error: insertError } = await db.from('fellowship_members').insert({
      fellowship_id: fellowship.id,
      user_id: user.id,
      role: 'member',
      is_active: true
    })
    if (insertError) {
      console.error('[fellowship/join] Member insert error:', insertError)
      throw new AppError('DATABASE_ERROR', 'Failed to join fellowship', 500)
    }
  }

  let displayName = 'A new member'
  try {
    const { data: userData } = await db.auth.admin.getUserById(user.id)
    if (userData?.user) {
      const u = userData.user
      displayName = u.user_metadata?.full_name ?? u.user_metadata?.name ??
        u.user_metadata?.display_name ?? 'A new member'
    }
  } catch { /* non-fatal */ }

  const joinPush = pushMentorsOrQueue(db, fellowship.id,
    { title: `👋 ${displayName} joined the fellowship`, body: `${displayName} joined ${fellowship.name}` },
    { type: 'fellowship_member_joined', fellowship_id: fellowship.id, user_id: user.id },
    { kind: 'fellowship_member_joined', excludeUserId: user.id })
  if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(joinPush)

  // Fire-and-forget: notify new member of upcoming meetings (non-blocking)
  const invitePromise = fetch(
    `${Deno.env.get('SUPABASE_URL')}/functions/v1/fellowship-meetings/invite-member`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ fellowshipId: fellowship.id, memberId: user.id }),
    }
  ).catch((err: unknown) =>
    console.error('[fellowship/join] invite-member fire-and-forget failed:', err)
  )
  if (typeof EdgeRuntime !== 'undefined') {
    EdgeRuntime.waitUntil(invitePromise)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: { fellowship_id: fellowship.id, fellowship_name: fellowship.name },
      message: 'Joined fellowship successfully'
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Leave fellowship  POST /fellowship/leave
// ---------------------------------------------------------------------------

async function handleLeaveFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: membership, error: memberError } = await db
    .from('fellowship_members')
    .select('role, is_active')
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (memberError) {
    console.error('[fellowship/leave] Membership fetch error:', memberError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!membership?.is_active) throw new AppError('VALIDATION_ERROR', 'You are not a member of this fellowship', 400)

  if (membership.role === 'mentor') {
    const { count: mentorCount, error: countError } = await db
      .from('fellowship_members')
      .select('*', { count: 'exact', head: true })
      .eq('fellowship_id', body.fellowship_id)
      .eq('role', 'mentor')
      .eq('is_active', true)
      .neq('user_id', user.id)

    if (countError) {
      console.error('[fellowship/leave] Mentor count error:', countError)
      throw new AppError('DATABASE_ERROR', 'Failed to check mentor status', 500)
    }
    if ((mentorCount || 0) === 0) throw new AppError('VALIDATION_ERROR', 'Transfer mentor role before leaving', 400)
  }

  const { error } = await db
    .from('fellowship_members')
    .update({ is_active: false })
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', user.id)

  if (error) {
    console.error('[fellowship/leave] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to leave fellowship', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'You have left the fellowship' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Update fellowship  PATCH /fellowship
// ---------------------------------------------------------------------------

async function handleDeleteFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship/delete] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { error } = await db
    .from('fellowships')
    .delete()
    .eq('id', body.fellowship_id)

  if (error) {
    console.error('[fellowship/delete] Delete error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to delete fellowship', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Fellowship deleted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

async function handleUpdateFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: {
    fellowship_id: string; name?: string; description?: string; max_members?: number | null; posting_permission?: string
    is_official?: boolean; discipler_allowed?: boolean; daily_post_allowed?: boolean
    discipler_reply_mode?: string; discipler_reply_scope?: string; discipler_reply_delay_min?: number
    discipler_react_enabled?: boolean; daily_post_on?: boolean; discipler_activity_push?: boolean
    daily_post_frequency_days?: number; daily_post_auto_advance?: boolean
  }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship/update] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() }

  if (body.name !== undefined) {
    const name = body.name.trim()
    if (name.length < 3 || name.length > 60) throw new AppError('VALIDATION_ERROR', 'name must be 3–60 characters', 400)

    const { count: nameCount, error: nameCheckError } = await db
      .from('fellowships')
      .select('*', { count: 'exact', head: true })
      .ilike('name', name)
      .eq('is_active', true)
      .neq('id', body.fellowship_id)

    if (nameCheckError) {
      console.error('[fellowship/update] Name check error:', nameCheckError)
      throw new AppError('DATABASE_ERROR', 'Failed to check name availability', 500)
    }
    if ((nameCount || 0) > 0) throw new AppError('CONFLICT', 'A fellowship with this name already exists', 409)
    updates.name = name
  }
  if (body.description !== undefined) {
    const desc = body.description.trim()
    if (desc.length > 500) throw new AppError('VALIDATION_ERROR', 'description must be 500 characters or fewer', 400)
    updates.description = desc || null
  }
  if (body.max_members !== undefined) {
    if (body.max_members === null) {
      // Unlimited — app-admin only (mentor alone is not enough).
      const { data: profile } = await db.from('user_profiles').select('is_admin').eq('id', user.id).single()
      if (profile?.is_admin !== true) {
        throw new AppError('PERMISSION_DENIED', 'Only admins can set unlimited members', 403)
      }
      updates.max_members = null
    } else if (typeof body.max_members !== 'number' || !Number.isInteger(body.max_members) || body.max_members < 2 || body.max_members > 50) {
      throw new AppError('VALIDATION_ERROR', 'max_members must be an integer between 2 and 50 (or null for unlimited)', 400)
    } else {
      updates.max_members = body.max_members
    }
  }
  if (body.posting_permission !== undefined) {
    if (body.posting_permission !== 'all_members' && body.posting_permission !== 'mentor_only') {
      throw new AppError('VALIDATION_ERROR', "posting_permission must be 'all_members' or 'mentor_only'", 400)
    }
    updates.posting_permission = body.posting_permission
  }

  const adminFlagKeys = ['is_official', 'discipler_allowed', 'daily_post_allowed'] as const
  if (adminFlagKeys.some((k) => body[k] !== undefined)) {
    const { data: profile } = await db.from('user_profiles').select('is_admin').eq('id', user.id).single()
    if (profile?.is_admin !== true) throw new AppError('PERMISSION_DENIED', 'Only admins can change official or Discipler flags', 403)

    const { data: currentRow, error: currentRowError } = await db
      .from('fellowships')
      .select('id')
      .eq('id', body.fellowship_id)
      .single()
    if (currentRowError || !currentRow) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)

    for (const k of adminFlagKeys) if (typeof body[k] === 'boolean') updates[k] = body[k]

    // Discipler and the daily post are independent of the official badge: an
    // admin may switch them on for any fellowship. "Official" only marks a
    // group as run by Disciplefy.
  }
  if (body.discipler_reply_mode !== undefined) {
    if (!['off', 'auto', 'review'].includes(body.discipler_reply_mode)) throw new AppError('VALIDATION_ERROR', "discipler_reply_mode must be 'off', 'auto' or 'review'", 400)
    updates.discipler_reply_mode = body.discipler_reply_mode
  }
  if (body.discipler_reply_scope !== undefined) {
    if (!['all', 'lessons_only'].includes(body.discipler_reply_scope)) throw new AppError('VALIDATION_ERROR', "discipler_reply_scope must be 'all' or 'lessons_only'", 400)
    updates.discipler_reply_scope = body.discipler_reply_scope
  }
  if (body.discipler_reply_delay_min !== undefined) {
    if (![0, 30, 120, 720].includes(body.discipler_reply_delay_min)) throw new AppError('VALIDATION_ERROR', 'discipler_reply_delay_min must be 0, 30, 120 or 720', 400)
    updates.discipler_reply_delay_min = body.discipler_reply_delay_min
  }
  if (typeof body.discipler_react_enabled === 'boolean') updates.discipler_react_enabled = body.discipler_react_enabled
  if (typeof body.daily_post_on === 'boolean') updates.daily_post_on = body.daily_post_on
  if (body.daily_post_frequency_days !== undefined) {
    if (![1, 2, 7].includes(body.daily_post_frequency_days)) throw new AppError('VALIDATION_ERROR', 'daily_post_frequency_days must be 1, 2 or 7', 400)
    updates.daily_post_frequency_days = body.daily_post_frequency_days
  }
  if (typeof body.daily_post_auto_advance === 'boolean') updates.daily_post_auto_advance = body.daily_post_auto_advance
  if (typeof body.discipler_activity_push === 'boolean') {
    await db.from('fellowship_members').update({ discipler_activity_push: body.discipler_activity_push })
      .eq('fellowship_id', body.fellowship_id).eq('user_id', user.id)
  }

  const hasUpdate = Object.keys(updates).some(k => k !== 'updated_at') || typeof body.discipler_activity_push === 'boolean'
  if (!hasUpdate) throw new AppError('VALIDATION_ERROR', 'No valid fields provided to update', 400)

  const reload = async () => {
    const { data, error } = await db.from('fellowships').select('*').eq('id', body.fellowship_id).single()
    if (error) {
      console.error('[fellowship/update] Reload error:', error)
      throw new AppError('DATABASE_ERROR', 'Failed to load updated fellowship', 500)
    }
    return data
  }

  if (Object.keys(updates).length === 1) return ok(fellowshipSettingsPayload(await reload()))

  const { data: fellowship, error } = await db
    .from('fellowships')
    .update(updates)
    .eq('id', body.fellowship_id)
    .select()
    .single()

  if (error) {
    console.error('[fellowship/update] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to update fellowship', 500)
  }

  return ok(fellowshipSettingsPayload(fellowship))
}

function ok(data: unknown): Response {
  return new Response(JSON.stringify({ success: true, data }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

function fellowshipSettingsPayload(fellowship: any) {
  return {
    id: fellowship.id,
    name: fellowship.name,
    description: fellowship.description,
    max_members: fellowship.max_members,
    posting_permission: fellowship.posting_permission,
    is_official: fellowship.is_official ?? false,
    discipler_allowed: fellowship.discipler_allowed ?? false,
    daily_post_allowed: fellowship.daily_post_allowed ?? false,
    discipler_reply_mode: fellowship.discipler_reply_mode ?? 'auto',
    discipler_reply_scope: fellowship.discipler_reply_scope ?? 'all',
    discipler_reply_delay_min: fellowship.discipler_reply_delay_min ?? 0,
    discipler_react_enabled: fellowship.discipler_react_enabled ?? true,
    daily_post_on: fellowship.daily_post_on ?? true,
    daily_post_frequency_days: fellowship.daily_post_frequency_days ?? 1,
    daily_post_auto_advance: fellowship.daily_post_auto_advance ?? true,
    updated_at: fellowship.updated_at,
  }
}

// ---------------------------------------------------------------------------
// Discipler activity list  GET /fellowship/discipler-activity
// ---------------------------------------------------------------------------

async function handleDisciplerActivity(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(authHeader.replace('Bearer ', ''))
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId || !UUID_RE.test(fellowshipId)) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  const kind = url.searchParams.get('kind')
  const cursor = url.searchParams.get('cursor')
  const limit = Math.min(Math.max(parseInt(url.searchParams.get('limit') || '30', 10) || 30, 1), 100)
  const db = services.supabaseServiceClient
  const { data: isMentor } = await db.rpc('is_fellowship_mentor', { p_fellowship_id: fellowshipId, p_user_id: user.id })
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  let q = db.from('discipler_activity')
    .select('id, kind, post_id, comment_id, reaction, language, summary, reviewed_by, reviewed_at, created_at, fellowship_posts(content, author_user_id, post_type, topic_title), fellowship_comments(content, is_pending_review, is_deleted)')
    .eq('fellowship_id', fellowshipId).order('created_at', { ascending: false }).limit(limit + 1)
  if (kind && ['reply', 'react', 'draft', 'daily_post'].includes(kind)) q = q.eq('kind', kind)
  if (cursor) q = q.lt('created_at', cursor)
  const { data, error } = await q
  if (error) { console.error('[fellowship/discipler-activity] query error:', error); throw new AppError('DATABASE_ERROR', 'Failed to load activity', 500) }
  const rows = data ?? []
  const hasMore = rows.length > limit
  const page = hasMore ? rows.slice(0, limit) : rows
  return new Response(JSON.stringify({
    success: true,
    data: page.map((r: any) => ({
      id: r.id, kind: r.kind, post_id: r.post_id, comment_id: r.comment_id, reaction: r.reaction, language: r.language,
      summary: r.summary, reviewed_at: r.reviewed_at, created_at: r.created_at,
      post: r.fellowship_posts ? { content: r.fellowship_posts.content, post_type: r.fellowship_posts.post_type, topic_title: r.fellowship_posts.topic_title } : null,
      comment: r.fellowship_comments ? { content: r.fellowship_comments.content, is_pending_review: r.fellowship_comments.is_pending_review, is_deleted: r.fellowship_comments.is_deleted } : null,
    })),
    pagination: { has_more: hasMore, next_cursor: hasMore ? page[page.length - 1].created_at : null },
  }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const pathname = new URL(req.url).pathname

  // Sub-routes (POST)
  if (req.method === 'POST') {
    if (pathname.endsWith('/join'))  return handleJoinPublicFellowship(req, services)
    if (pathname.endsWith('/leave')) return handleLeaveFellowship(req, services)
    return handleCreateFellowship(req, services)
  }

  // PATCH → update
  if (req.method === 'PATCH') return handleUpdateFellowship(req, services)
  if (req.method === 'DELETE') return handleDeleteFellowship(req, services)

  // GET routes
  if (req.method === 'GET') {
    if (pathname.endsWith('/discover')) return handleDiscoverFellowships(req, services)
    if (pathname.endsWith('/discipler-activity')) return handleDisciplerActivity(req, services)
    const fellowshipId = new URL(req.url).searchParams.get('fellowship_id')
    if (fellowshipId) return handleGetFellowship(req, services)
    return handleListFellowships(req, services)
  }

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleFellowship, {
  allowedMethods: ['GET', 'POST', 'PATCH', 'DELETE'],
  enableAnalytics: true,
  timeout: 15000,
})
