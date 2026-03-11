/**
 * fellowship-invites-join
 * Validates invite token and adds user as member.
 * POST /fellowship-invites-join
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleJoinFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { token: string }
  try {
    body = await req.json() as { token: string }
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.token) throw new AppError('VALIDATION_ERROR', 'token is required', 400)

  const db = services.supabaseServiceClient

  // Validate invite
  const { data: invite } = await db
    .from('fellowship_invites')
    .select('*, fellowships(id, name, max_members)')
    .eq('token', body.token)
    .eq('is_revoked', false)
    .is('used_at', null)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle()

  if (!invite) {
    throw new AppError('NOT_FOUND', 'Invite link is invalid or expired', 404)
  }

  const fellowship = invite.fellowships as any
  if (!fellowship) {
    throw new AppError('NOT_FOUND', 'Fellowship not found', 404)
  }

  // Check already a member
  const { data: existing } = await db
    .from('fellowship_members')
    .select('id, is_active')
    .eq('fellowship_id', fellowship.id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (existing?.is_active) {
    throw new AppError('VALIDATION_ERROR', 'You are already a member of this fellowship', 400)
  }

  // Check member cap
  const { count: memberCount, error: countError } = await db
    .from('fellowship_members')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', fellowship.id)
    .eq('is_active', true)

  if (countError) {
    console.error('[fellowship-invites-join] Count error:', countError)
    throw new AppError('DATABASE_ERROR', 'Failed to check member capacity', 500)
  }

  if ((memberCount || 0) >= fellowship.max_members) {
    throw new AppError('VALIDATION_ERROR', 'Fellowship is full', 400)
  }

  // Add member (upsert in case they had left before)
  const { error: memberError } = await db
    .from('fellowship_members')
    .upsert({
      fellowship_id: fellowship.id,
      user_id: user.id,
      role: 'member',
      is_active: true
    }, { onConflict: 'fellowship_id,user_id' })

  if (memberError) {
    console.error('[fellowship-invites-join] Member upsert error:', memberError)
    throw new AppError('DATABASE_ERROR', 'Failed to join fellowship', 500)
  }

  // Mark invite as used
  const { error: markUsedError } = await db
    .from('fellowship_invites')
    .update({ used_at: new Date().toISOString(), used_by: user.id })
    .eq('id', invite.id)
  if (markUsedError) {
    console.error('[fellowship-invites-join] Failed to mark invite used — token may be reusable:', invite.id, markUsedError)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: { fellowship_id: fellowship.id, fellowship_name: fellowship.name },
      message: `Welcome to ${fellowship.name}!`
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleJoinFellowship, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
