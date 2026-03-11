/**
 * fellowship-members-unmute
 * Mentor unmutes a member.
 * POST /fellowship-members-unmute
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleUnmuteMember(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; user_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.user_id) throw new AppError('VALIDATION_ERROR', 'user_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-members-unmute] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { error } = await db
    .from('fellowship_mutes')
    .delete()
    .eq('fellowship_id', body.fellowship_id)
    .eq('muted_user_id', body.user_id)

  if (error) {
    console.error('[fellowship-members-unmute] Delete error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to unmute member', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Member unmuted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleUnmuteMember, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
