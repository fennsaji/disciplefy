/**
 * fellowship-members-list
 * Returns all active members of a fellowship, ordered by role then join date.
 * GET /fellowship-members-list?fellowship_id=UUID
 * Auth: Required (caller must be an active member)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/**
 * Shape of each member in the response.
 */
interface MemberResponse {
  user_id: string
  role: 'mentor' | 'member'
  joined_at: string
  is_muted: boolean
  display_name: string
  avatar_url: string | null
  topics_completed: number | null
}

/**
 * Row returned from the fellowship_members query.
 */
interface FellowshipMemberRow {
  user_id: string
  role: 'mentor' | 'member'
  joined_at: string
}

async function handleListFellowshipMembers(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  await checkMaintenanceMode(req, services)

  // 1. Extract and validate auth token
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)

  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  // 2. Validate fellowship_id query param
  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!UUID_RE.test(fellowshipId)) throw new AppError('VALIDATION_ERROR', 'fellowship_id must be a valid UUID', 400)

  const db = services.supabaseServiceClient

  // 3. Check caller is an active member via is_fellowship_member RPC
  const { data: isMember, error: rpcError } = await db.rpc(
    'is_fellowship_member',
    { p_fellowship_id: fellowshipId, p_user_id: user.id }
  )
  if (rpcError) throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'You are not a member of this fellowship', 403)

  // 4. Fetch active members + muted user IDs + active study in parallel
  //    is_muted lives in fellowship_mutes, not fellowship_members — derive it via join.
  //    Role ordering: 'member' > 'mentor' alphabetically so we sort in application code.
  const [membersResult, mutesResult, studyResult] = await Promise.all([
    db
      .from('fellowship_members')
      .select('user_id, role, joined_at')
      .eq('fellowship_id', fellowshipId)
      .eq('is_active', true)
      .order('joined_at', { ascending: true }),

    db
      .from('fellowship_mutes')
      .select('muted_user_id')
      .eq('fellowship_id', fellowshipId),

    db
      .from('fellowship_study')
      .select('learning_path_id, current_guide_index')
      .eq('fellowship_id', fellowshipId)
      .maybeSingle()
  ])

  if (membersResult.error) {
    console.error('[fellowship-members-list] Members query error:', membersResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowship members', 500)
  }
  if (mutesResult.error) {
    console.error('[fellowship-members-list] Mutes query error:', mutesResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch mute list', 500)
  }

  const memberRows = (membersResult.data ?? []) as FellowshipMemberRow[]
  const mutedUserIds = new Set((mutesResult.data ?? []).map((r: { muted_user_id: string }) => r.muted_user_id))

  // Build a map of userId -> topics_completed from user_learning_path_progress
  const activeLearningPathId = studyResult.data?.learning_path_id ?? null
  // current_guide_index is the index of the *current* guide being studied.
  // All guides before it have been completed by the fellowship advancing past them.
  const currentGuideIndex: number = studyResult.data?.current_guide_index ?? 0
  const progressByUserId = new Map<string, number>()

  if (activeLearningPathId && memberRows.length > 0) {
    const memberUserIds = memberRows.map((r) => r.user_id)
    const { data: progressRows } = await db
      .from('user_learning_path_progress')
      .select('user_id, topics_completed')
      .eq('learning_path_id', activeLearningPathId)
      .in('user_id', memberUserIds)

    for (const row of progressRows ?? []) {
      progressByUserId.set(row.user_id, row.topics_completed ?? 0)
    }
  }

  // Sort: mentors first, then by joined_at ascending
  memberRows.sort((a, b) => {
    const rolePriority = (role: string) => (role === 'mentor' ? 0 : 1)
    const roleDiff = rolePriority(a.role) - rolePriority(b.role)
    if (roleDiff !== 0) return roleDiff
    return new Date(a.joined_at).getTime() - new Date(b.joined_at).getTime()
  })

  // 5. Enrich each member with display_name and avatar_url via admin.getUserById
  const members: MemberResponse[] = await Promise.all(
    memberRows.map(async (row): Promise<MemberResponse> => {
      const is_muted = mutedUserIds.has(row.user_id)

      const personallyCompleted = progressByUserId.has(row.user_id)
        ? progressByUserId.get(row.user_id)!
        : (activeLearningPathId ? 0 : null)
      // Fellowship advancing past a guide means all members have completed it.
      // Effective completed = max(personally completed, current_guide_index).
      const topics_completed = personallyCompleted !== null
        ? Math.max(personallyCompleted, currentGuideIndex)
        : null

      try {
        const { data: userData, error: userError } =
          await services.supabaseServiceClient.auth.admin.getUserById(row.user_id)

        if (userError || !userData?.user) {
          console.error(
            '[fellowship-members-list] getUserById error for user:',
            row.user_id,
            userError
          )
          return {
            user_id: row.user_id,
            role: row.role,
            joined_at: row.joined_at,
            is_muted,
            display_name: 'Unknown Member',
            avatar_url: null,
            topics_completed
          }
        }

        const u = userData.user
        const display_name: string =
          u.user_metadata?.full_name ??
          u.user_metadata?.name ??
          u.user_metadata?.display_name ??
          u.email ??
          'Unknown Member'
        const avatar_url: string | null = u.user_metadata?.avatar_url ?? null

        return {
          user_id: row.user_id,
          role: row.role,
          joined_at: row.joined_at,
          is_muted,
          display_name,
          avatar_url,
          topics_completed
        }
      } catch (err) {
        // Best-effort: don't let a single user lookup failure abort the whole list
        console.error(
          '[fellowship-members-list] Unexpected error fetching user:',
          row.user_id,
          err
        )
        return {
          user_id: row.user_id,
          role: row.role,
          joined_at: row.joined_at,
          is_muted,
          display_name: 'Unknown Member',
          avatar_url: null,
          topics_completed
        }
      }
    })
  )

  // 6. Return success response
  return new Response(
    JSON.stringify({ success: true, data: { members } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleListFellowshipMembers, {
  allowedMethods: ['GET'],
  enableAnalytics: false,
  timeout: 15000
})
