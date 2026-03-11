/**
 * fellowship-meetings-list
 * Returns upcoming (non-cancelled) meetings for a fellowship, ordered soonest first.
 * GET /fellowship-meetings-list?fellowship_id=UUID&limit=20
 * Auth: Required (any member)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleListMeetings(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const rawLimit = parseInt(url.searchParams.get('limit') || '20', 10)
  const limit = Number.isNaN(rawLimit) || rawLimit < 1 ? 20 : Math.min(rawLimit, 50)

  const db = services.supabaseServiceClient

  // Member check
  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: fellowshipId,
    p_user_id: user.id,
  })
  if (rpcError) throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const now = new Date().toISOString()

  const { data: meetings, error } = await db
    .from('fellowship_meetings')
    .select('id, fellowship_id, created_by, title, description, starts_at, ends_at, recurrence, meet_link, created_at')
    .eq('fellowship_id', fellowshipId)
    .eq('is_cancelled', false)
    .gte('starts_at', now)
    .order('starts_at', { ascending: true })
    .limit(limit)

  if (error) {
    console.error('[fellowship-meetings-list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch meetings', 500)
  }

  return new Response(
    JSON.stringify({ success: true, data: meetings ?? [] }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleListMeetings, {
  allowedMethods: ['GET'],
  enableAnalytics: false,
  timeout: 10000,
})
