/**
 * fellowship-comments  (merged)
 * Routes:
 *   GET    /fellowship-comments?post_id=UUID  → list comments for a post (member)
 *   POST   /fellowship-comments               → create comment (member)
 *   DELETE /fellowship-comments               → soft-delete comment (author or mentor)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

// ---------------------------------------------------------------------------
// List comments  GET /fellowship-comments?post_id=UUID
// ---------------------------------------------------------------------------

async function handleListComments(req: Request, services: ServiceContainer): Promise<Response> {
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

  const { data: post, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id')
    .eq('id', postId)
    .eq('is_deleted', false)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-comments/list] Post fetch error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch post', 500)
  }
  if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: post.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-comments/list] RPC error:', rpcError)
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
    console.error('[fellowship-comments/list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch comments', 500)
  }

  const rows = comments ?? []
  const uniqueAuthorIds = [...new Set(rows.map((c: { author_user_id: string }) => c.author_user_id))]
  const authorEntries = await Promise.all(
    uniqueAuthorIds.map(async (userId: string) => {
      try {
        const { data: userData, error: userError } =
          await services.supabaseServiceClient.auth.admin.getUserById(userId)
        if (userError || !userData?.user) return { userId, displayName: 'Unknown Member', avatarUrl: null }
        const u = userData.user
        const displayName: string =
          u.user_metadata?.full_name ?? u.user_metadata?.name ??
          u.user_metadata?.display_name ?? u.email ?? 'Unknown Member'
        const avatarUrl: string | null = u.user_metadata?.avatar_url ?? null
        return { userId, displayName, avatarUrl }
      } catch {
        return { userId, displayName: 'Unknown Member', avatarUrl: null }
      }
    })
  )

  const authorMap = new Map(
    authorEntries.map((e: { userId: string; displayName: string; avatarUrl: string | null }) => [e.userId, e])
  )

  const enrichedComments = rows.map((c: any) => {
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

// ---------------------------------------------------------------------------
// Create comment  POST /fellowship-comments
// ---------------------------------------------------------------------------

async function handleCreateComment(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { post_id: string; content: string }
  try {
    body = await req.json() as { post_id: string; content: string }
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.post_id) throw new AppError('VALIDATION_ERROR', 'post_id is required', 400)
  const trimmedContent = body.content?.trim() || ''
  if (!trimmedContent) throw new AppError('VALIDATION_ERROR', 'content is required', 400)
  if (trimmedContent.length > 1000) throw new AppError('VALIDATION_ERROR', 'content exceeds 1000 characters', 400)

  const db = services.supabaseServiceClient

  const { data: post, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id, author_user_id')
    .eq('id', body.post_id)
    .eq('is_deleted', false)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-comments/create] Post fetch error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch post', 500)
  }
  if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: post.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-comments/create] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const { data: comment, error } = await db
    .from('fellowship_comments')
    .insert({
      post_id: body.post_id,
      fellowship_id: post.fellowship_id,
      author_user_id: user.id,
      content: trimmedContent
    })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-comments/create] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to create comment', 500)
  }

  const [authorResult] = await Promise.all([
    services.supabaseServiceClient.auth.admin.getUserById(user.id),
    post.author_user_id !== user.id
      ? db.from('fellowship_notification_queue').insert({
          fellowship_id: post.fellowship_id,
          recipient_user_id: post.author_user_id,
          notification_type: 'new_comment',
          payload: { post_id: body.post_id, comment_id: comment.id }
        }).then(({ error: notifError }) => {
          if (notifError) console.error('[fellowship-comments/create] Notification error:', notifError)
        })
      : Promise.resolve()
  ])

  const authorUser = authorResult.data?.user
  const authorDisplayName: string =
    authorUser?.user_metadata?.full_name ?? authorUser?.user_metadata?.name ??
    authorUser?.user_metadata?.display_name ?? authorUser?.email ?? 'Unknown Member'
  const authorAvatarUrl: string | null = authorUser?.user_metadata?.avatar_url ?? null

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: comment.id,
        post_id: comment.post_id,
        content: comment.content,
        author_user_id: comment.author_user_id,
        is_deleted: comment.is_deleted ?? false,
        created_at: comment.created_at,
        author_display_name: authorDisplayName,
        author_avatar_url: authorAvatarUrl
      }
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Delete comment  DELETE /fellowship-comments
// ---------------------------------------------------------------------------

async function handleDeleteComment(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { comment_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.comment_id) throw new AppError('VALIDATION_ERROR', 'comment_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: comment, error: commentError } = await db
    .from('fellowship_comments')
    .select('fellowship_id, author_user_id')
    .eq('id', body.comment_id)
    .eq('is_deleted', false)
    .maybeSingle()

  if (commentError) {
    console.error('[fellowship-comments/delete] Comment fetch error:', commentError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch comment', 500)
  }
  if (!comment) throw new AppError('NOT_FOUND', 'Comment not found', 404)

  const isAuthor = comment.author_user_id === user.id
  if (!isAuthor) {
    const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
      p_fellowship_id: comment.fellowship_id,
      p_user_id: user.id
    })
    if (rpcError) {
      console.error('[fellowship-comments/delete] RPC error:', rpcError)
      throw new AppError('DATABASE_ERROR', 'Failed to verify permissions', 500)
    }
    if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Cannot delete this comment', 403)
  }

  const { error } = await db
    .from('fellowship_comments')
    .update({ is_deleted: true })
    .eq('id', body.comment_id)

  if (error) {
    console.error('[fellowship-comments/delete] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to delete comment', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Comment deleted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleComments(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  if (req.method === 'GET') return handleListComments(req, services)
  if (req.method === 'POST') return handleCreateComment(req, services)
  if (req.method === 'DELETE') return handleDeleteComment(req, services)

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleComments, {
  allowedMethods: ['GET', 'POST', 'DELETE'],
  enableAnalytics: true,
  timeout: 10000,
})
