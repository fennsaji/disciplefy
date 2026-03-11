/**
 * fellowship-leave
 * Member leaves fellowship. Blocks if caller is the sole mentor.
 * POST /fellowship-leave
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleLeaveFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

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

  // Fetch caller's membership
  const { data: membership, error: memberError } = await db
    .from('fellowship_members')
    .select('role, is_active')
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (memberError) {
    console.error('[fellowship-leave] Membership fetch error:', memberError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!membership?.is_active) throw new AppError('VALIDATION_ERROR', 'You are not a member of this fellowship', 400)

  // If mentor, check if sole mentor
  if (membership.role === 'mentor') {
    const { count: mentorCount, error: countError } = await db
      .from('fellowship_members')
      .select('*', { count: 'exact', head: true })
      .eq('fellowship_id', body.fellowship_id)
      .eq('role', 'mentor')
      .eq('is_active', true)
      .neq('user_id', user.id)

    if (countError) {
      console.error('[fellowship-leave] Mentor count error:', countError)
      throw new AppError('DATABASE_ERROR', 'Failed to check mentor status', 500)
    }
    if ((mentorCount || 0) === 0) {
      throw new AppError('VALIDATION_ERROR', 'Transfer mentor role before leaving', 400)
    }
  }

  const { error } = await db
    .from('fellowship_members')
    .update({ is_active: false })
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', user.id)

  if (error) {
    console.error('[fellowship-leave] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to leave fellowship', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'You have left the fellowship' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleLeaveFellowship, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
