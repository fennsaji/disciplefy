/**
 * fellowship-comments-delete
 * Soft-deletes a comment. Author or mentor can delete.
 * DELETE /fellowship-comments-delete
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleDeleteComment(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

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
    console.error('[fellowship-comments-delete] Comment fetch error:', commentError)
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
      console.error('[fellowship-comments-delete] RPC error:', rpcError)
      throw new AppError('DATABASE_ERROR', 'Failed to verify permissions', 500)
    }
    if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Cannot delete this comment', 403)
  }

  const { error } = await db
    .from('fellowship_comments')
    .update({ is_deleted: true })
    .eq('id', body.comment_id)

  if (error) {
    console.error('[fellowship-comments-delete] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to delete comment', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Comment deleted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleDeleteComment, {
  allowedMethods: ['DELETE'],
  enableAnalytics: true,
  timeout: 10000
})
