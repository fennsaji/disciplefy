/**
 * fellowship-invites  (merged)
 * Routes:
 *   GET    /fellowship-invites?fellowship_id=UUID  → list active invites (mentor)
 *   POST   /fellowship-invites                      → create invite (mentor)
 *   POST   /fellowship-invites/join                 → join via token (any auth user)
 *   POST   /fellowship-invites/revoke               → revoke invite (mentor)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

// ---------------------------------------------------------------------------
// List invites  GET /fellowship-invites?fellowship_id=UUID
// ---------------------------------------------------------------------------

async function handleListInvites(req: Request, services: ServiceContainer): Promise<Response> {
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
    console.error('[fellowship-invites/list] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  // Fire-and-forget: mark expired codes as revoked for this fellowship
  void Promise.resolve(
    db.from('fellowship_invites')
      .update({ is_revoked: true })
      .eq('fellowship_id', fellowshipId)
      .eq('is_revoked', false)
      .is('used_at', null)
      .lt('expires_at', new Date().toISOString())
  ).catch(() => {})

  const { data: invites, error } = await db
    .from('fellowship_invites')
    .select('id, token, expires_at, used_at, created_at')
    .eq('fellowship_id', fellowshipId)
    .eq('is_revoked', false)
    .is('used_at', null)
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[fellowship-invites/list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch invites', 500)
  }

  const invitesWithUrl = invites.map((inv: any) => ({
    ...inv,
    join_url: `https://app.disciplefy.in/fellowship/join/${inv.token}`
  }))

  return new Response(
    JSON.stringify({ success: true, data: invitesWithUrl }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Create invite  POST /fellowship-invites
// ---------------------------------------------------------------------------

async function handleCreateInvite(req: Request, services: ServiceContainer): Promise<Response> {
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

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-invites/create] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { count, error: countError } = await db
    .from('fellowship_invites')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', body.fellowship_id)
    .eq('is_revoked', false)
    .is('used_at', null)
    .gt('expires_at', new Date().toISOString())

  if (countError) {
    console.error('[fellowship-invites/create] Count error:', countError)
    throw new AppError('DATABASE_ERROR', 'Failed to check invite limit', 500)
  }

  if ((count || 0) >= 10) {
    throw new AppError('VALIDATION_ERROR', 'Maximum 10 active invite links. Revoke some first.', 400)
  }

  const { data: invite, error } = await db
    .from('fellowship_invites')
    .insert({ fellowship_id: body.fellowship_id, created_by: user.id })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-invites/create] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to create invite', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: invite.id,
        token: invite.token,
        expires_at: invite.expires_at,
        join_url: `https://app.disciplefy.in/fellowship/join/${invite.token}`
      }
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Join via token  POST /fellowship-invites/join
// ---------------------------------------------------------------------------

async function handleJoinFellowship(req: Request, services: ServiceContainer): Promise<Response> {
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

  const { data: invite } = await db
    .from('fellowship_invites')
    .select('*, fellowships(id, name, max_members)')
    .eq('token', body.token)
    .eq('is_revoked', false)
    .is('used_at', null)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle()

  if (!invite) throw new AppError('NOT_FOUND', 'Invite link is invalid or expired', 404)

  const fellowship = invite.fellowships as any
  if (!fellowship) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)

  const { data: existing } = await db
    .from('fellowship_members')
    .select('id, is_active')
    .eq('fellowship_id', fellowship.id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (existing?.is_active) {
    throw new AppError('VALIDATION_ERROR', 'You are already a member of this fellowship', 400)
  }

  const { count: memberCount, error: countError } = await db
    .from('fellowship_members')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', fellowship.id)
    .eq('is_active', true)

  if (countError) {
    console.error('[fellowship-invites/join] Count error:', countError)
    throw new AppError('DATABASE_ERROR', 'Failed to check member capacity', 500)
  }

  if ((memberCount || 0) >= fellowship.max_members) {
    throw new AppError('VALIDATION_ERROR', 'Fellowship is full', 400)
  }

  const { error: memberError } = await db
    .from('fellowship_members')
    .upsert({
      fellowship_id: fellowship.id,
      user_id: user.id,
      role: 'member',
      is_active: true
    }, { onConflict: 'fellowship_id,user_id' })

  if (memberError) {
    console.error('[fellowship-invites/join] Member upsert error:', memberError)
    throw new AppError('DATABASE_ERROR', 'Failed to join fellowship', 500)
  }

  const { error: markUsedError } = await db
    .from('fellowship_invites')
    .update({ used_at: new Date().toISOString(), used_by: user.id })
    .eq('id', invite.id)
  if (markUsedError) {
    console.error('[fellowship-invites/join] Failed to mark invite used — token may be reusable:', invite.id, markUsedError)
  }

  // Fire-and-forget: notify new member of upcoming meetings (non-blocking)
  const invitePromise = fetch(
    `${Deno.env.get('SUPABASE_URL')}/functions/v1/fellowship-meetings/invite-member`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ fellowshipId: fellowship.id, memberId: user.id }),
    }
  ).catch((err: unknown) =>
    console.error('[fellowship-invites/join] invite-member fire-and-forget failed:', err)
  )
  if (typeof EdgeRuntime !== 'undefined') {
    EdgeRuntime.waitUntil(invitePromise)
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

// ---------------------------------------------------------------------------
// Revoke invite  POST /fellowship-invites/revoke
// ---------------------------------------------------------------------------

async function handleRevokeInvite(req: Request, services: ServiceContainer): Promise<Response> {
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
    console.error('[fellowship-invites/revoke] RPC error:', rpcError)
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
    console.error('[fellowship-invites/revoke] Update error:', error)
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

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleInvites(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const pathname = new URL(req.url).pathname

  if (req.method === 'GET') {
    return handleListInvites(req, services)
  }

  if (req.method === 'POST') {
    if (pathname.endsWith('/join')) return handleJoinFellowship(req, services)
    if (pathname.endsWith('/revoke')) return handleRevokeInvite(req, services)
    return handleCreateInvite(req, services)
  }

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleInvites, {
  allowedMethods: ['GET', 'POST'],
  enableAnalytics: true,
  timeout: 10000,
})
