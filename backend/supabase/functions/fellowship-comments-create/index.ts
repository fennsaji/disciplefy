/**
 * fellowship-comments-create
 * Member comments on a post.
 * POST /fellowship-comments-create
 * Auth: Required (member only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleCreateComment(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

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

  // Fetch post to get fellowship_id
  const { data: post, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id, author_user_id')
    .eq('id', body.post_id)
    .eq('is_deleted', false)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-comments-create] Post fetch error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch post', 500)
  }
  if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)

  // Member check
  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: post.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-comments-create] RPC error:', rpcError)
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
    console.error('[fellowship-comments-create] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to create comment', 500)
  }

  // Fetch author display info and send notification in parallel
  const [authorResult] = await Promise.all([
    services.supabaseServiceClient.auth.admin.getUserById(user.id),
    // Notify post author if different user
    post.author_user_id !== user.id
      ? db.from('fellowship_notification_queue').insert({
          fellowship_id: post.fellowship_id,
          recipient_user_id: post.author_user_id,
          notification_type: 'new_comment',
          payload: { post_id: body.post_id, comment_id: comment.id }
        }).then(({ error: notifError }) => {
          if (notifError) console.error('[fellowship-comments-create] Notification error:', notifError)
        })
      : Promise.resolve()
  ])

  const authorUser = authorResult.data?.user
  const authorDisplayName: string =
    authorUser?.user_metadata?.full_name ??
    authorUser?.user_metadata?.name ??
    authorUser?.user_metadata?.display_name ??
    authorUser?.email ??
    'Unknown Member'
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

createSimpleFunction(handleCreateComment, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
