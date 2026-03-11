/**
 * fellowship-invites-revoke
 * Mentor revokes an invite link.
 * POST /fellowship-invites-revoke
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleRevokeInvite(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { invite_id: string; fellowship_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.invite_id) throw new AppError('VALIDATION_ERROR', 'invite_id is required', 400)
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-invites-revoke] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: updatedRows, error } = await db
    .from('fellowship_invites')
    .update({ is_revoked: true })
    .eq('id', body.invite_id)
    .eq('fellowship_id', body.fellowship_id)
    .select()

  if (error) {
    console.error('[fellowship-invites-revoke] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to revoke invite', 500)
  }
  if (!updatedRows || updatedRows.length === 0) {
    throw new AppError('NOT_FOUND', 'Invite not found or does not belong to this fellowship', 404)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Invite link revoked' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleRevokeInvite, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
