/**
 * fellowship-blocks
 * Routes:
 *   POST   /fellowship-blocks  → block a user (global, mutual)
 *   DELETE /fellowship-blocks  → unblock a user
 *   GET    /fellowship-blocks  → list users the caller has blocked
 *
 * Blocks are global (not scoped to a fellowship) and mutual: neither party
 * sees the other's posts or comments anywhere. See
 * docs/superpowers/specs/2026-08-10-block-user-community-design.md
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

interface BlockedUserResponse {
  user_id: string
  display_name: string
  avatar_url: string | null
  blocked_at: string
}

/** Resolves the caller from the Authorization header or throws. */
async function requireUser(req: Request, services: ServiceContainer) {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (error || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  return user
}

// ---------------------------------------------------------------------------
// Block  POST /fellowship-blocks
// ---------------------------------------------------------------------------

async function handleBlock(req: Request, services: ServiceContainer): Promise<Response> {
  const user = await requireUser(req, services)

  let body: {
    blocked_user_id: string
    fellowship_id?: string
    content_type?: string
    content_id?: string
  }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }

  if (!body.blocked_user_id) throw new AppError('VALIDATION_ERROR', 'blocked_user_id is required', 400)
  if (!UUID_RE.test(body.blocked_user_id)) throw new AppError('VALIDATION_ERROR', 'blocked_user_id must be a valid UUID', 400)
  if (body.blocked_user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot block yourself', 400)

  // Empty string is treated as "not provided" for these optional fields —
  // normalize before validating so '' never reaches the truthy checks below
  // (a bare `body.x &&` guard lets '' slip past `.includes`/UUID checks and
  // through the `?? null` into the RPC as a non-null empty string, which
  // satisfies block_user()'s `IS NOT NULL` guard and trips the
  // fellowship_reports CHECK constraint, rolling back the whole block).
  const contentType = body.content_type === '' ? undefined : body.content_type
  const contentId = body.content_id === '' ? undefined : body.content_id
  const fellowshipId = body.fellowship_id === '' ? undefined : body.fellowship_id

  if (contentType !== undefined && !['post', 'comment'].includes(contentType)) {
    throw new AppError('VALIDATION_ERROR', "content_type must be 'post' or 'comment'", 400)
  }
  if (contentId !== undefined && !UUID_RE.test(contentId)) {
    throw new AppError('VALIDATION_ERROR', 'content_id must be a valid UUID', 400)
  }
  if (fellowshipId !== undefined && !UUID_RE.test(fellowshipId)) {
    throw new AppError('VALIDATION_ERROR', 'fellowship_id must be a valid UUID', 400)
  }

  const db = services.supabaseServiceClient

  const { data: created, error } = await db.rpc('block_user', {
    p_blocker_id: user.id,
    p_blocked_id: body.blocked_user_id,
    p_fellowship_id: fellowshipId ?? null,
    p_content_type: contentType ?? null,
    p_content_id: contentId ?? null,
    p_reason: null
  })

  if (error) {
    console.error('[fellowship-blocks/block] RPC error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to block user', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: created ? 'User blocked' : 'User is already blocked' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Unblock  DELETE /fellowship-blocks
// ---------------------------------------------------------------------------

async function handleUnblock(req: Request, services: ServiceContainer): Promise<Response> {
  const user = await requireUser(req, services)

  let body: { blocked_user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.blocked_user_id) throw new AppError('VALIDATION_ERROR', 'blocked_user_id is required', 400)
  if (!UUID_RE.test(body.blocked_user_id)) throw new AppError('VALIDATION_ERROR', 'blocked_user_id must be a valid UUID', 400)

  const { error } = await services.supabaseServiceClient
    .from('user_blocks')
    .delete()
    .eq('blocker_id', user.id)
    .eq('blocked_id', body.blocked_user_id)

  if (error) {
    console.error('[fellowship-blocks/unblock] Delete error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to unblock user', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'User unblocked' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// List  GET /fellowship-blocks
// ---------------------------------------------------------------------------

async function handleList(req: Request, services: ServiceContainer): Promise<Response> {
  const user = await requireUser(req, services)
  const db = services.supabaseServiceClient

  // Only outbound blocks: a user manages the blocks they made, and must not
  // learn who blocked them.
  const { data: rows, error } = await db
    .from('user_blocks')
    .select('blocked_id, created_at')
    .eq('blocker_id', user.id)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[fellowship-blocks/list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch blocked users', 500)
  }

  const blockRows = (rows ?? []) as { blocked_id: string; created_at: string }[]

  const blocked: BlockedUserResponse[] = await Promise.all(
    blockRows.map(async (row) => {
      try {
        const { data: userData, error: userError } =
          await db.auth.admin.getUserById(row.blocked_id)
        if (userError || !userData?.user) {
          return { user_id: row.blocked_id, display_name: 'Unknown Member', avatar_url: null, blocked_at: row.created_at }
        }
        const u = userData.user
        const displayName: string =
          u.user_metadata?.full_name ?? u.user_metadata?.name ??
          u.user_metadata?.display_name ?? u.email ?? 'Unknown Member'
        return {
          user_id: row.blocked_id,
          display_name: displayName,
          avatar_url: (u.user_metadata?.avatar_url ?? null) as string | null,
          blocked_at: row.created_at
        }
      } catch {
        return { user_id: row.blocked_id, display_name: 'Unknown Member', avatar_url: null, blocked_at: row.created_at }
      }
    })
  )

  return new Response(
    JSON.stringify({ success: true, data: blocked }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleBlocks(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  if (req.method === 'GET') return handleList(req, services)
  if (req.method === 'POST') return handleBlock(req, services)
  if (req.method === 'DELETE') return handleUnblock(req, services)

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleBlocks, {
  allowedMethods: ['GET', 'POST', 'DELETE'],
  enableAnalytics: true,
  timeout: 15000,
})
