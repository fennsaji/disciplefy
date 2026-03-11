/**
 * fellowship-posts-delete
 * Soft-deletes a post. Author or mentor can delete.
 * DELETE /fellowship-posts-delete
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleDeletePost(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { post_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.post_id) throw new AppError('VALIDATION_ERROR', 'post_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: post, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id, author_user_id')
    .eq('id', body.post_id)
    .eq('is_deleted', false)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-posts-delete] Post fetch error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch post', 500)
  }
  if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)

  const isAuthor = post.author_user_id === user.id
  if (!isAuthor) {
    const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
      p_fellowship_id: post.fellowship_id,
      p_user_id: user.id
    })
    if (rpcError) {
      console.error('[fellowship-posts-delete] RPC error:', rpcError)
      throw new AppError('DATABASE_ERROR', 'Failed to verify permissions', 500)
    }
    if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Cannot delete this post', 403)
  }

  const { error } = await db
    .from('fellowship_posts')
    .update({ is_deleted: true })
    .eq('id', body.post_id)

  if (error) {
    console.error('[fellowship-posts-delete] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to delete post', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Post deleted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleDeletePost, {
  allowedMethods: ['DELETE'],
  enableAnalytics: true,
  timeout: 10000
})
