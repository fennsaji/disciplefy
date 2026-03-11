/**
 * fellowship-members-remove
 * Mentor removes (kicks) a member from the fellowship.
 * POST /fellowship-members-remove
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleRemoveMember(req: Request, services: ServiceContainer): Promise<Response> {
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
  if (body.user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot remove yourself — use leave fellowship instead', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-members-remove] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: targetMember, error: targetMemberError } = await db
    .from('fellowship_members')
    .select('user_id, role')
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', body.user_id)
    .eq('is_active', true)
    .maybeSingle()

  if (targetMemberError) {
    console.error('[fellowship-members-remove] Error checking target membership:', targetMemberError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify target membership', 500)
  }
  if (!targetMember) {
    throw new AppError('NOT_FOUND', 'Target user is not an active member of this fellowship', 404)
  }
  if ((targetMember as any).role === 'mentor') {
    throw new AppError('VALIDATION_ERROR', 'Cannot remove the mentor — transfer mentor role first', 400)
  }

  const { error } = await db
    .from('fellowship_members')
    .update({ is_active: false, left_at: new Date().toISOString() })
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', body.user_id)

  if (error) {
    console.error('[fellowship-members-remove] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to remove member', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Member removed' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleRemoveMember, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
