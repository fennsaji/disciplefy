/**
 * fellowship-invites-list
 * Lists active invite links for a fellowship.
 * GET /fellowship-invites-list?fellowship_id=UUID
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleListInvites(req: Request, services: ServiceContainer): Promise<Response> {
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

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: fellowshipId,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-invites-list] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: invites, error } = await db
    .from('fellowship_invites')
    .select('id, token, expires_at, used_at, created_at')
    .eq('fellowship_id', fellowshipId)
    .eq('is_revoked', false)
    .is('used_at', null)
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[fellowship-invites-list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch invites', 500)
  }

  const invitesWithUrl = invites.map((inv: any) => ({
    ...inv,
    join_url: `disciplefy://fellowship/join?token=${inv.token}`
  }))

  return new Response(
    JSON.stringify({ success: true, data: invitesWithUrl }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleListInvites, {
  allowedMethods: ['GET'],
  enableAnalytics: false,
  timeout: 10000
})
