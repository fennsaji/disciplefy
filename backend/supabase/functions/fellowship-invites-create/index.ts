/**
 * fellowship-invites-create
 * Mentor generates a 7-day invite link (max 10 active per fellowship).
 * POST /fellowship-invites-create
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleCreateInvite(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

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

  const db = services.supabaseServiceClient

  // Check mentor
  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-invites-create] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  // Check active invite count (max 10)
  const { count, error: countError } = await db
    .from('fellowship_invites')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', body.fellowship_id)
    .eq('is_revoked', false)
    .is('used_at', null)
    .gt('expires_at', new Date().toISOString())

  if (countError) {
    console.error('[fellowship-invites-create] Count error:', countError)
    throw new AppError('DATABASE_ERROR', 'Failed to check invite limit', 500)
  }

  if ((count || 0) >= 10) {
    throw new AppError('VALIDATION_ERROR', 'Maximum 10 active invite links. Revoke some first.', 400)
  }

  // Create invite
  const { data: invite, error } = await db
    .from('fellowship_invites')
    .insert({ fellowship_id: body.fellowship_id, created_by: user.id })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-invites-create] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to create invite', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: invite.id,
        token: invite.token,
        expires_at: invite.expires_at,
        join_url: `disciplefy://fellowship/join?token=${invite.token}`
      }
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleCreateInvite, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
