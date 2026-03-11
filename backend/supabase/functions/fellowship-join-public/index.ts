/**
 * fellowship-join-public
 * Joins a public fellowship directly without an invite token.
 * POST /fellowship-join-public
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

async function handleJoinPublicFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  // 1. Validate auth
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  // 2. Parse + validate body
  let body: { fellowship_id: string }
  try {
    body = await req.json() as { fellowship_id: string }
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!UUID_REGEX.test(body.fellowship_id)) throw new AppError('VALIDATION_ERROR', 'fellowship_id must be a valid UUID', 400)

  const db = services.supabaseServiceClient

  // 3. Fetch fellowship
  const { data: fellowship, error: fellowshipError } = await db
    .from('fellowships')
    .select('id, name, is_active, is_public, max_members')
    .eq('id', body.fellowship_id)
    .maybeSingle()

  if (fellowshipError) {
    console.error('[fellowship-join-public] Fellowship fetch error:', fellowshipError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowship', 500)
  }
  if (!fellowship) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)
  if (!fellowship.is_active) throw new AppError('FORBIDDEN', 'Fellowship is not active', 403)
  if (!fellowship.is_public) throw new AppError('FORBIDDEN', 'Fellowship is not open to public joining', 403)

  // 4. Check existing membership
  const { data: existing, error: existingError } = await db
    .from('fellowship_members')
    .select('id, is_active')
    .eq('fellowship_id', fellowship.id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (existingError) {
    console.error('[fellowship-join-public] Existing member check error:', existingError)
    throw new AppError('DATABASE_ERROR', 'Failed to check membership status', 500)
  }

  if (existing?.is_active) {
    throw new AppError('CONFLICT', 'You are already a member of this fellowship', 409)
  }

  // 5. Count active members and check capacity.
  // Note: the count query and the insert below are not atomic. A concurrent
  // join could push the count past max_members between these two operations.
  // This is an accepted limitation matching all other join functions in this
  // codebase; a DB-level constraint or advisory lock would be needed to fully
  // prevent it. In practice admin-curated public fellowships keep small caps.
  const { count: memberCount, error: countError } = await db
    .from('fellowship_members')
    .select('*', { count: 'exact', head: true })
    .eq('fellowship_id', fellowship.id)
    .eq('is_active', true)

  if (countError) {
    console.error('[fellowship-join-public] Count error:', countError)
    throw new AppError('DATABASE_ERROR', 'Failed to check member capacity', 500)
  }

  if ((memberCount || 0) >= fellowship.max_members) {
    throw new AppError('VALIDATION_ERROR', 'Fellowship is full', 400)
  }

  // 6. Add or reactivate membership
  if (existing) {
    // Reactivate previously inactive member
    const { error: updateError } = await db
      .from('fellowship_members')
      .update({ is_active: true, role: 'member' })
      .eq('id', existing.id)

    if (updateError) {
      console.error('[fellowship-join-public] Member reactivation error:', updateError)
      throw new AppError('DATABASE_ERROR', 'Failed to join fellowship', 500)
    }
  } else {
    // Insert new member row
    const { error: insertError } = await db
      .from('fellowship_members')
      .insert({
        fellowship_id: fellowship.id,
        user_id: user.id,
        role: 'member',
        is_active: true
      })

    if (insertError) {
      console.error('[fellowship-join-public] Member insert error:', insertError)
      throw new AppError('DATABASE_ERROR', 'Failed to join fellowship', 500)
    }
  }

  // 7. Get caller's display name from auth user_metadata (user_profiles has no display_name column).
  let displayName = 'A new member'
  try {
    const { data: userData } = await db.auth.admin.getUserById(user.id)
    if (userData?.user) {
      const u = userData.user
      displayName =
        u.user_metadata?.full_name ??
        u.user_metadata?.name ??
        u.user_metadata?.display_name ??
        'A new member'
    }
  } catch {
    // Non-fatal — fall back to generic name
  }

  // 8. Insert system post (non-fatal)
  const { error: postError } = await db
    .from('fellowship_posts')
    .insert({
      fellowship_id: fellowship.id,
      author_user_id: user.id,
      content: `${displayName} has joined the fellowship`,
      post_type: 'system'
    })

  if (postError) {
    console.warn('[fellowship-join-public] Failed to create system post — non-fatal:', postError)
  }

  // 9. Return success
  return new Response(
    JSON.stringify({
      success: true,
      data: { fellowship_id: fellowship.id, fellowship_name: fellowship.name },
      message: 'Joined fellowship successfully'
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleJoinPublicFellowship, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
