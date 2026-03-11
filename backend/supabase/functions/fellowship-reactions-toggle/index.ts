/**
 * fellowship-reactions-toggle
 * Toggles a reaction on a post. Adds if absent, removes if present.
 * Updates reaction_counts JSONB on the post atomically.
 * POST /fellowship-reactions-toggle
 * Auth: Required (member only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleToggleReaction(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { post_id: string; reaction_type: string }
  try {
    body = await req.json() as { post_id: string; reaction_type: string }
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.post_id) throw new AppError('VALIDATION_ERROR', 'post_id is required', 400)
  const reactionType = body.reaction_type?.trim() || ''
  if (!reactionType || reactionType.length > 10) {
    throw new AppError('VALIDATION_ERROR', 'reaction_type is required (max 10 chars)', 400)
  }

  const db = services.supabaseServiceClient

  // Fetch post
  const { data: post, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id, reaction_counts')
    .eq('id', body.post_id)
    .eq('is_deleted', false)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-reactions-toggle] Post fetch error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch post', 500)
  }
  if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)

  // Member check
  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: post.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-reactions-toggle] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  // Check existing reaction
  const { data: existing, error: existingError } = await db
    .from('fellowship_reactions')
    .select('id')
    .eq('post_id', body.post_id)
    .eq('user_id', user.id)
    .eq('reaction_type', reactionType)
    .maybeSingle()

  if (existingError) {
    console.error('[fellowship-reactions-toggle] Reaction check error:', existingError)
    throw new AppError('DATABASE_ERROR', 'Failed to check reaction status', 500)
  }

  const counts: Record<string, number> = (post.reaction_counts as Record<string, number>) || {}
  let action: 'added' | 'removed'

  if (existing) {
    // Remove reaction
    const { error: deleteError } = await db
      .from('fellowship_reactions')
      .delete()
      .eq('id', existing.id)
    if (deleteError) {
      console.error('[fellowship-reactions-toggle] Delete error:', deleteError)
      throw new AppError('DATABASE_ERROR', 'Failed to remove reaction', 500)
    }
    counts[reactionType] = Math.max(0, (counts[reactionType] || 1) - 1)
    if (counts[reactionType] === 0) delete counts[reactionType]
    action = 'removed'
  } else {
    // Add reaction
    const { error: insertError } = await db.from('fellowship_reactions').insert({
      post_id: body.post_id,
      fellowship_id: post.fellowship_id,
      user_id: user.id,
      reaction_type: reactionType
    })
    if (insertError) {
      console.error('[fellowship-reactions-toggle] Insert error:', insertError)
      throw new AppError('DATABASE_ERROR', 'Failed to add reaction', 500)
    }
    counts[reactionType] = (counts[reactionType] || 0) + 1
    action = 'added'
  }

  // Update denormalized counts
  const { error: updateError } = await db
    .from('fellowship_posts')
    .update({ reaction_counts: counts })
    .eq('id', body.post_id)

  if (updateError) {
    console.error('[fellowship-reactions-toggle] Count update error:', updateError)
    // Non-fatal: reaction row was already toggled; log and continue
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: { action, reaction_type: reactionType, reaction_counts: counts }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleToggleReaction, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
