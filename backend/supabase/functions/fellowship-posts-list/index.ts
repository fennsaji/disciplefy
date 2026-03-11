/**
 * fellowship-posts-list
 * Cursor-based paginated feed. 20 posts per page, newest first.
 * GET /fellowship-posts-list?fellowship_id=UUID&cursor=ISO_TIMESTAMP&limit=20&topic_id=STR
 * Auth: Required (member only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleListPosts(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const cursor = url.searchParams.get('cursor')
  const topicId = url.searchParams.get('topic_id') ?? null
  const rawLimit = parseInt(url.searchParams.get('limit') || '20', 10)
  const limit = Number.isNaN(rawLimit) || rawLimit < 1 ? 20 : Math.min(rawLimit, 50)
  const countByTopic = url.searchParams.get('count_by_topic') === 'true'

  const db = services.supabaseServiceClient

  // Member check
  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: fellowshipId,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-posts-list] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  // Lightweight mode: return per-topic post counts (no enrichment, no pagination).
  if (countByTopic) {
    const { data: topicPosts, error: topicError } = await db
      .from('fellowship_posts')
      .select('topic_id')
      .eq('fellowship_id', fellowshipId)
      .eq('is_deleted', false)
      .not('topic_id', 'is', null)
    if (topicError) throw new AppError('DATABASE_ERROR', 'Failed to fetch topic counts', 500)
    const counts: Record<string, number> = {}
    for (const post of topicPosts ?? []) {
      const tid = (post as { topic_id: string }).topic_id
      counts[tid] = (counts[tid] ?? 0) + 1
    }
    return new Response(
      JSON.stringify({ success: true, data: counts }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  let query = db
    .from('fellowship_posts')
    .select('id, fellowship_id, topic_id, topic_title, guide_title, lesson_index, study_guide_id, guide_input_type, guide_language, content, post_type, reaction_counts, author_user_id, is_deleted, created_at')
    .eq('fellowship_id', fellowshipId)
    .eq('is_deleted', false)
    .order('created_at', { ascending: false })
    .limit(limit + 1)

  // When topic_id is provided, scope to guide-specific discussion only.
  // Otherwise show all posts (including study_note posts that carry a topic_id).
  if (topicId) {
    query = query.eq('topic_id', topicId)
  }

  if (cursor) {
    query = query.lt('created_at', cursor)
  }

  const { data: posts, error } = await query
  if (error) {
    console.error('[fellowship-posts-list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowship posts', 500)
  }

  const hasMore = (posts?.length ?? 0) > limit
  const pagePosts = hasMore ? posts!.slice(0, limit) : (posts ?? [])
  const nextCursor = hasMore ? pagePosts[pagePosts.length - 1].created_at : null

  if (pagePosts.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        data: [],
        pagination: { has_more: false, next_cursor: null }
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const postIds = pagePosts.map((p: { id: string }) => p.id)
  const uniqueAuthorIds = [...new Set(pagePosts.map((p: { author_user_id: string }) => p.author_user_id))]

  // Parallel enrichment: author info, comment counts, user reactions
  const [authorEntries, commentsResult, reactionsResult] = await Promise.all([
    // Author display names and avatars (same pattern as fellowship-members-list)
    Promise.all(
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
    ),

    // All non-deleted comments for these posts (count per post in JS — one query)
    db
      .from('fellowship_comments')
      .select('post_id')
      .in('post_id', postIds)
      .eq('is_deleted', false),

    // Current user's reactions for these posts (one query)
    db
      .from('fellowship_reactions')
      .select('post_id, reaction_type')
      .eq('user_id', user.id)
      .in('post_id', postIds)
  ])

  // Build lookup maps
  const authorMap = new Map(
    authorEntries.map((e: { userId: string; displayName: string; avatarUrl: string | null }) =>
      [e.userId, e]
    )
  )

  const commentCountMap = new Map<string, number>()
  for (const c of commentsResult.data ?? []) {
    const postId = (c as { post_id: string }).post_id
    commentCountMap.set(postId, (commentCountMap.get(postId) ?? 0) + 1)
  }

  const reactionMap = new Map<string, string>()
  for (const r of reactionsResult.data ?? []) {
    const row = r as { post_id: string; reaction_type: string }
    reactionMap.set(row.post_id, row.reaction_type)
  }

  // Assemble enriched response
  const enrichedPosts = pagePosts.map((post: {
    id: string
    fellowship_id: string
    topic_id: string | null
    topic_title: string | null
    guide_title: string | null
    lesson_index: number | null
    study_guide_id: string | null
    guide_input_type: string | null
    guide_language: string | null
    content: string
    post_type: string
    reaction_counts: Record<string, number>
    author_user_id: string
    is_deleted: boolean
    created_at: string
  }) => {
    const author = authorMap.get(post.author_user_id)
    return {
      id: post.id,
      fellowship_id: post.fellowship_id,
      topic_id: post.topic_id ?? null,
      topic_title: post.topic_title ?? null,
      guide_title: post.guide_title ?? null,
      lesson_index: post.lesson_index ?? null,
      study_guide_id: post.study_guide_id ?? null,
      guide_input_type: post.guide_input_type ?? null,
      guide_language: post.guide_language ?? null,
      content: post.content,
      post_type: post.post_type,
      reaction_counts: post.reaction_counts ?? {},
      author_user_id: post.author_user_id,
      is_deleted: post.is_deleted,
      created_at: post.created_at,
      author_display_name: author?.displayName ?? 'Unknown Member',
      author_avatar_url: author?.avatarUrl ?? null,
      comment_count: commentCountMap.get(post.id) ?? 0,
      user_reaction: reactionMap.get(post.id) ?? null
    }
  })

  return new Response(
    JSON.stringify({
      success: true,
      data: enrichedPosts,
      pagination: { has_more: hasMore, next_cursor: nextCursor }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleListPosts, {
  allowedMethods: ['GET'],
  enableAnalytics: false,
  timeout: 15000
})
