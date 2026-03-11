/**
 * fellowship-members-mute
 * Mentor mutes a member (hides their content from feed).
 * POST /fellowship-members-mute
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleMuteMember(req: Request, services: ServiceContainer): Promise<Response> {
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
  if (body.user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot mute yourself', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-members-mute] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: targetMember, error: targetMemberError } = await services.supabaseServiceClient
    .from('fellowship_members')
    .select('user_id, role')
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', body.user_id)
    .eq('is_active', true)
    .maybeSingle()

  if (targetMemberError) {
    console.error('[fellowship-members-mute] Error checking target membership:', targetMemberError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify target membership', 500)
  }
  if (!targetMember) {
    throw new AppError('NOT_FOUND', 'Target user is not an active member of this fellowship', 404)
  }
  if ((targetMember as any).role === 'mentor') {
    throw new AppError('VALIDATION_ERROR', 'Cannot mute a mentor', 400)
  }

  const { error } = await db
    .from('fellowship_mutes')
    .insert({
      fellowship_id: body.fellowship_id,
      muted_user_id: body.user_id,
      muted_by: user.id
    })

  if (error) {
    if (error.code === '23505') {
      // Already muted — idempotent, return success
      return new Response(
        JSON.stringify({ success: true, message: 'Member is already muted' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }
    console.error('[fellowship-members-mute] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to mute member', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Member muted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleMuteMember, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
