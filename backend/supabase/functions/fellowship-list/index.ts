/**
 * fellowship-list
 * Returns all fellowships the authenticated user belongs to,
 * enriched with member count and current study info.
 * GET /fellowship-list
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleListFellowships(
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

  const db = services.supabaseServiceClient

  // Fetch all active memberships for this user, joining fellowship rows
  const { data: memberships, error: membershipsError } = await db
    .from('fellowship_members')
    .select(`
      role,
      joined_at,
      fellowships (
        id,
        name,
        description,
        is_active,
        is_public,
        created_at,
        mentor_user_id
      )
    `)
    .eq('user_id', user.id)
    .eq('is_active', true)

  if (membershipsError) {
    console.error('[fellowship-list] Memberships query error:', membershipsError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowships', 500)
  }

  // Filter out memberships where the fellowship itself is inactive
  const activeMemberships = (memberships || []).filter(
    (m: any) => m.fellowships && m.fellowships.is_active === true
  )

  // Batch-fetch mentor display names via auth admin API (deduplicated mentor IDs)
  const mentorIds = [...new Set(
    activeMemberships
      .map((m: any) => m.fellowships?.mentor_user_id as string | undefined)
      .filter((id): id is string => !!id)
  )]

  const mentorEntries = await Promise.all(
    mentorIds.map(async (userId: string) => {
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
  )

  const mentorNameMap = new Map<string, string | null>()
  for (const entry of mentorEntries) {
    mentorNameMap.set(entry.userId, entry.name)
  }

  // Enrich each fellowship in parallel: member count + current study
  const fellowships = await Promise.all(
    activeMemberships.map(async (membership: any) => {
      const fellowship = membership.fellowships as any
      const fellowshipId: string = fellowship.id

      const [countResult, studyResult] = await Promise.all([
        // Member count: active members only
        db
          .from('fellowship_members')
          .select('*', { count: 'exact', head: true })
          .eq('fellowship_id', fellowshipId)
          .eq('is_active', true),

        // Current study (most recent incomplete) — join learning_paths for title
        db
          .from('fellowship_study')
          .select('learning_path_id, current_guide_index, started_at, completed_at, learning_paths(title)')
          .eq('fellowship_id', fellowshipId)
          .is('completed_at', null)
          .order('started_at', { ascending: false })
          .maybeSingle()
      ])

      const { count: memberCount, error: countError } = countResult
      if (countError) {
        console.error('[fellowship-list] Member count error for', fellowshipId, ':', countError)
        throw new AppError('DATABASE_ERROR', 'Failed to fetch member count', 500)
      }

      const { data: study, error: studyError } = studyResult
      if (studyError) {
        console.error('[fellowship-list] Study query error for', fellowshipId, ':', studyError)
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
        mentor_name: mentorNameMap.get(fellowship.mentor_user_id) ?? null,
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

  return new Response(
    JSON.stringify({
      success: true,
      data: { fellowships }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleListFellowships, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 15000
})
