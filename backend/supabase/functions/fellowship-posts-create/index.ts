/**
 * fellowship-posts-create
 * Member creates a post in the fellowship feed.
 * POST /fellowship-posts-create
 * Auth: Required (member only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

interface CreatePostRequest {
  fellowship_id: string
  content: string
  post_type?: 'general' | 'prayer' | 'praise' | 'question' | 'study_note' | 'shared_guide'
  topic_id?: string | null
  // study_note fields
  topic_title?: string | null
  guide_title?: string | null
  lesson_index?: number | null
  // shared_guide fields
  study_guide_id?: string | null
  guide_input_type?: string | null
  guide_language?: string | null
}

async function handleCreatePost(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: CreatePostRequest
  try {
    body = await req.json() as CreatePostRequest
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }

  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.content?.trim()) throw new AppError('VALIDATION_ERROR', 'content is required', 400)
  if (body.content.length > 2000) throw new AppError('VALIDATION_ERROR', 'content exceeds 2000 characters', 400)

  const validTypes = ['general', 'prayer', 'praise', 'question', 'study_note', 'shared_guide']
  const postType = body.post_type || 'general'
  if (!validTypes.includes(postType)) throw new AppError('VALIDATION_ERROR', 'Invalid post_type', 400)

  const db = services.supabaseServiceClient

  // Member check
  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-posts-create] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const { data: post, error } = await db
    .from('fellowship_posts')
    .insert({
      fellowship_id: body.fellowship_id,
      author_user_id: user.id,
      content: body.content.trim(),
      post_type: postType,
      ...(body.topic_id        ? { topic_id:        body.topic_id }        : {}),
      ...(body.topic_title     ? { topic_title:      body.topic_title }     : {}),
      ...(body.guide_title     ? { guide_title:      body.guide_title }     : {}),
      ...(body.lesson_index   != null ? { lesson_index: body.lesson_index } : {}),
      ...(body.study_guide_id  ? { study_guide_id:   body.study_guide_id }  : {}),
      ...(body.guide_input_type ? { guide_input_type: body.guide_input_type } : {}),
      ...(body.guide_language   ? { guide_language:   body.guide_language }  : {})
    })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-posts-create] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to create post', 500)
  }

  // Fetch author display info and enqueue notifications in parallel
  const [authorResult, membersResult] = await Promise.all([
    services.supabaseServiceClient.auth.admin.getUserById(user.id),
    db
      .from('fellowship_members')
      .select('user_id')
      .eq('fellowship_id', body.fellowship_id)
      .eq('is_active', true)
      .neq('user_id', user.id)
  ])

  const authorUser = authorResult.data?.user
  const authorDisplayName: string =
    authorUser?.user_metadata?.full_name ??
    authorUser?.user_metadata?.name ??
    authorUser?.user_metadata?.display_name ??
    authorUser?.email ??
    'Unknown Member'
  const authorAvatarUrl: string | null = authorUser?.user_metadata?.avatar_url ?? null

  if (membersResult.error) {
    console.error('[fellowship-posts-create] Members fetch error:', membersResult.error)
  }
  const members = membersResult.data ?? []

  if (members.length > 0) {
    const notifications = members.map((m: { user_id: string }) => ({
      fellowship_id: body.fellowship_id,
      recipient_user_id: m.user_id,
      notification_type: 'new_post',
      payload: { post_id: post.id, post_type: postType }
    }))
    const { error: notifError } = await db.from('fellowship_notification_queue').insert(notifications)
    if (notifError) console.error('[fellowship-posts-create] Notification enqueue error:', notifError)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: post.id,
        fellowship_id: post.fellowship_id,
        topic_id: post.topic_id ?? null,
        topic_title:      post.topic_title      ?? null,
        guide_title:      post.guide_title      ?? null,
        lesson_index:     post.lesson_index     ?? null,
        study_guide_id:   post.study_guide_id   ?? null,
        guide_input_type: post.guide_input_type ?? null,
        guide_language:   post.guide_language   ?? null,
        author_user_id: post.author_user_id,
        content: post.content,
        post_type: post.post_type,
        reaction_counts: post.reaction_counts ?? {},
        is_deleted: post.is_deleted,
        created_at: post.created_at,
        author_display_name: authorDisplayName,
        author_avatar_url: authorAvatarUrl,
        comment_count: 0,
        user_reaction: null
      }
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleCreatePost, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
