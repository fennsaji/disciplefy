/**
 * fellowship-comments-list
 * Lists all comments for a post (no pagination for MVP).
 * GET /fellowship-comments-list?post_id=UUID
 * Auth: Required (member only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleListComments(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  const url = new URL(req.url)
  const postId = url.searchParams.get('post_id')
  if (!postId) throw new AppError('VALIDATION_ERROR', 'post_id is required', 400)

  const db = services.supabaseServiceClient

  // Fetch post for fellowship_id (also validates post exists)
  const { data: post, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id')
    .eq('id', postId)
    .eq('is_deleted', false)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-comments-list] Post fetch error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch post', 500)
  }
  if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)

  // Member check
  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: post.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-comments-list] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const { data: comments, error } = await db
    .from('fellowship_comments')
    .select('id, post_id, content, author_user_id, is_deleted, created_at')
    .eq('post_id', postId)
    .eq('is_deleted', false)
    .order('created_at', { ascending: true })

  if (error) {
    console.error('[fellowship-comments-list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch comments', 500)
  }

  const rows = comments ?? []

  // Enrich each comment with author display name and avatar
  const uniqueAuthorIds = [...new Set(rows.map((c: { author_user_id: string }) => c.author_user_id))]
  const authorEntries = await Promise.all(
    uniqueAuthorIds.map(async (userId: string) => {
      try {
        const { data: userData, error: userError } =
          await services.supabaseServiceClient.auth.admin.getUserById(userId)
        if (userError || !userData?.user) {
          return { userId, displayName: 'Unknown Member', avatarUrl: null }
        }
        const u = userData.user
        const displayName: string =
          u.user_metadata?.full_name ??
          u.user_metadata?.name ??
          u.user_metadata?.display_name ??
          u.email ??
          'Unknown Member'
        const avatarUrl: string | null = u.user_metadata?.avatar_url ?? null
        return { userId, displayName, avatarUrl }
      } catch {
        return { userId, displayName: 'Unknown Member', avatarUrl: null }
      }
    })
  )

  const authorMap = new Map(
    authorEntries.map((e: { userId: string; displayName: string; avatarUrl: string | null }) =>
      [e.userId, e]
    )
  )

  const enrichedComments = rows.map((c: {
    id: string
    post_id: string
    content: string
    author_user_id: string
    is_deleted: boolean
    created_at: string
  }) => {
    const author = authorMap.get(c.author_user_id)
    return {
      id: c.id,
      post_id: c.post_id,
      content: c.content,
      author_user_id: c.author_user_id,
      is_deleted: c.is_deleted,
      created_at: c.created_at,
      author_display_name: author?.displayName ?? 'Unknown Member',
      author_avatar_url: author?.avatarUrl ?? null
    }
  })

  return new Response(
    JSON.stringify({ success: true, data: enrichedComments }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleListComments, {
  allowedMethods: ['GET'],
  enableAnalytics: false,
  timeout: 10000
})
