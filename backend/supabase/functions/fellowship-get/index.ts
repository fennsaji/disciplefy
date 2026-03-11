/**
 * fellowship-get
 * Returns fellowship details + member count + active study.
 * GET /fellowship-get?fellowship_id=UUID
 * Auth: Optional (non-members see limited info)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleGetFellowship(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const db = services.supabaseServiceClient

  // Fetch fellowship
  const { data: fellowship } = await db
    .from('fellowships')
    .select('*')
    .eq('id', fellowshipId)
    .maybeSingle()

  if (!fellowship) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)

  // Member count
  const { count: memberCount, error: countError } = await db
    .from('fellowship_members')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', fellowshipId)
    .eq('is_active', true)

  if (countError) {
    console.error('[fellowship-get] Count query error:', countError)
  }

  // Active study (optional)
  const { data: study } = await db
    .from('fellowship_study')
    .select(`
      current_guide_index,
      started_at,
      learning_paths (id, title)
    `)
    .eq('fellowship_id', fellowshipId)
    .is('completed_at', null)
    .maybeSingle()

  // Check if caller is member (optional auth)
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
        member_count: memberCount || 0,
        is_active: fellowship.is_active,
        active_study: study ? {
          learning_path_id: (study.learning_paths as any)?.id,
          learning_path_title: (study.learning_paths as any)?.title,
          current_guide_index: study.current_guide_index,
          started_at: study.started_at
        } : null,
        caller_is_member: isMember,
        caller_role: callerRole,
        created_at: fellowship.created_at
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleGetFellowship, {
  allowedMethods: ['GET'],
  enableAnalytics: false,
  timeout: 10000
})
