/**
 * fellowship-posts  (merged)
 * Routes:
 *   GET    /fellowship-posts?fellowship_id=UUID  → paginated post feed (member)
 *   POST   /fellowship-posts                      → create post (member)
 *   DELETE /fellowship-posts                      → soft-delete post (author or mentor)
 *   POST   /fellowship-posts/react               → toggle reaction on post (member)
 *   POST   /fellowship-posts/report              → report post or comment (member)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { FCMService } from '../_shared/fcm-service.ts'

// ---------------------------------------------------------------------------
// List posts  GET /fellowship-posts
// ---------------------------------------------------------------------------

async function handleListPosts(req: Request, services: ServiceContainer): Promise<Response> {
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

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: fellowshipId,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-posts/list] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

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

  if (topicId) query = query.eq('topic_id', topicId)
  if (cursor) query = query.lt('created_at', cursor)

  const { data: posts, error } = await query
  if (error) {
    console.error('[fellowship-posts/list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowship posts', 500)
  }

  const hasMore = (posts?.length ?? 0) > limit
  const pagePosts = hasMore ? posts!.slice(0, limit) : (posts ?? [])
  const nextCursor = hasMore ? pagePosts[pagePosts.length - 1].created_at : null

  if (pagePosts.length === 0) {
    return new Response(
      JSON.stringify({ success: true, data: [], pagination: { has_more: false, next_cursor: null } }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const postIds = pagePosts.map((p: { id: string }) => p.id)
  const uniqueAuthorIds = [...new Set(pagePosts.map((p: { author_user_id: string }) => p.author_user_id))]

  const [authorEntries, commentsResult, reactionsResult] = await Promise.all([
    Promise.all(
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
    ),
    db.from('fellowship_comments').select('post_id').in('post_id', postIds).eq('is_deleted', false),
    db.from('fellowship_reactions').select('post_id, reaction_type').eq('user_id', user.id).in('post_id', postIds)
  ])

  const authorMap = new Map(
    authorEntries.map((e: { userId: string; displayName: string; avatarUrl: string | null }) => [e.userId, e])
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

  const enrichedPosts = pagePosts.map((post: any) => {
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
    JSON.stringify({ success: true, data: enrichedPosts, pagination: { has_more: hasMore, next_cursor: nextCursor } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Create post  POST /fellowship-posts
// ---------------------------------------------------------------------------

interface CreatePostRequest {
  fellowship_id: string
  content: string
  post_type?: 'general' | 'prayer' | 'praise' | 'question' | 'study_note' | 'shared_guide'
  topic_id?: string | null
  topic_title?: string | null
  guide_title?: string | null
  lesson_index?: number | null
  study_guide_id?: string | null
  guide_input_type?: string | null
  guide_language?: string | null
}

async function handleCreatePost(req: Request, services: ServiceContainer): Promise<Response> {
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

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-posts/create] RPC error:', rpcError)
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
    console.error('[fellowship-posts/create] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to create post', 500)
  }

  const [authorResult, membersResult] = await Promise.all([
    services.supabaseServiceClient.auth.admin.getUserById(user.id),
    db.from('fellowship_members').select('user_id')
      .eq('fellowship_id', body.fellowship_id).eq('is_active', true).neq('user_id', user.id)
  ])

  const authorUser = authorResult.data?.user
  const authorDisplayName: string =
    authorUser?.user_metadata?.full_name ?? authorUser?.user_metadata?.name ??
    authorUser?.user_metadata?.display_name ?? authorUser?.email ?? 'Unknown Member'
  const authorAvatarUrl: string | null = authorUser?.user_metadata?.avatar_url ?? null

  if (membersResult.error) console.error('[fellowship-posts/create] Members fetch error:', membersResult.error)
  const members = membersResult.data ?? []

  // Send FCM to all other active members (fire-and-forget)
  if (members.length > 0) {
    ;(async () => {
      try {
        const memberIds = members.map((m: { user_id: string }) => m.user_id)
        const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').in('user_id', memberIds)
        const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
        if (tokens.length === 0) return
        const fcm = new FCMService()
        const preview = post.content.length > 80 ? post.content.substring(0, 80) + '…' : post.content
        await fcm.sendBatchNotifications(
          tokens,
          { title: `✍️ ${authorDisplayName} posted`, body: preview },
          { type: 'fellowship_new_post', fellowship_id: body.fellowship_id, post_id: post.id, post_type: postType }
        )
      } catch (err) { console.error('[fellowship-posts/create] FCM error (non-fatal):', err) }
    })()
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: post.id,
        fellowship_id: post.fellowship_id,
        topic_id: post.topic_id ?? null,
        topic_title: post.topic_title ?? null,
        guide_title: post.guide_title ?? null,
        lesson_index: post.lesson_index ?? null,
        study_guide_id: post.study_guide_id ?? null,
        guide_input_type: post.guide_input_type ?? null,
        guide_language: post.guide_language ?? null,
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

// ---------------------------------------------------------------------------
// Delete post  DELETE /fellowship-posts
// ---------------------------------------------------------------------------

async function handleDeletePost(req: Request, services: ServiceContainer): Promise<Response> {
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
    console.error('[fellowship-posts/delete] Post fetch error:', postError)
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
      console.error('[fellowship-posts/delete] RPC error:', rpcError)
      throw new AppError('DATABASE_ERROR', 'Failed to verify permissions', 500)
    }
    if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Cannot delete this post', 403)
  }

  const { error } = await db
    .from('fellowship_posts')
    .update({ is_deleted: true })
    .eq('id', body.post_id)

  if (error) {
    console.error('[fellowship-posts/delete] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to delete post', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Post deleted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Toggle reaction  POST /fellowship-posts/react
// ---------------------------------------------------------------------------

async function handleToggleReaction(req: Request, services: ServiceContainer): Promise<Response> {
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

  const { data: post, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id, author_user_id, reaction_counts')
    .eq('id', body.post_id)
    .eq('is_deleted', false)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-posts/react] Post fetch error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch post', 500)
  }
  if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: post.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-posts/react] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const { data: existing, error: existingError } = await db
    .from('fellowship_reactions')
    .select('id')
    .eq('post_id', body.post_id)
    .eq('user_id', user.id)
    .eq('reaction_type', reactionType)
    .maybeSingle()

  if (existingError) {
    console.error('[fellowship-posts/react] Reaction check error:', existingError)
    throw new AppError('DATABASE_ERROR', 'Failed to check reaction status', 500)
  }

  const counts: Record<string, number> = (post.reaction_counts as Record<string, number>) || {}
  let action: 'added' | 'removed'

  if (existing) {
    const { error: deleteError } = await db.from('fellowship_reactions').delete().eq('id', existing.id)
    if (deleteError) {
      console.error('[fellowship-posts/react] Delete error:', deleteError)
      throw new AppError('DATABASE_ERROR', 'Failed to remove reaction', 500)
    }
    counts[reactionType] = Math.max(0, (counts[reactionType] || 1) - 1)
    if (counts[reactionType] === 0) delete counts[reactionType]
    action = 'removed'
  } else {
    const { error: insertError } = await db.from('fellowship_reactions').insert({
      post_id: body.post_id,
      fellowship_id: post.fellowship_id,
      user_id: user.id,
      reaction_type: reactionType
    })
    if (insertError) {
      console.error('[fellowship-posts/react] Insert error:', insertError)
      throw new AppError('DATABASE_ERROR', 'Failed to add reaction', 500)
    }
    counts[reactionType] = (counts[reactionType] || 0) + 1
    action = 'added'
  }

  const { error: updateError } = await db
    .from('fellowship_posts')
    .update({ reaction_counts: counts })
    .eq('id', body.post_id)
  if (updateError) console.error('[fellowship-posts/react] Count update error — non-fatal:', updateError)

  // Notify post author when someone adds a reaction (not on remove, not self-reaction)
  if (action === 'added' && post.author_user_id !== user.id) {
    ;(async () => {
      try {
        const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').eq('user_id', post.author_user_id)
        const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
        if (tokens.length > 0) {
          const fcm = new FCMService()
          await fcm.sendBatchNotifications(
            tokens,
            { title: `${reactionType} Someone reacted to your post`, body: 'A fellowship member reacted to your post' },
            { type: 'fellowship_reaction', fellowship_id: post.fellowship_id, post_id: body.post_id, reaction_type: reactionType }
          )
        }
      } catch (err) { console.error('[fellowship-posts/react] FCM error (non-fatal):', err) }
    })()
  }

  return new Response(
    JSON.stringify({ success: true, data: { action, reaction_type: reactionType, reaction_counts: counts } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Create report  POST /fellowship-posts/report
// ---------------------------------------------------------------------------

async function handleCreateReport(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; content_type: string; content_id: string; reason: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.content_type || !['post', 'comment'].includes(body.content_type)) {
    throw new AppError('VALIDATION_ERROR', 'content_type must be "post" or "comment"', 400)
  }
  if (!body.content_id) throw new AppError('VALIDATION_ERROR', 'content_id is required', 400)
  const reason = body.reason?.trim() || ''
  if (reason.length < 5 || reason.length > 500) {
    throw new AppError('VALIDATION_ERROR', 'reason must be 5–500 characters', 400)
  }

  const db = services.supabaseServiceClient

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-posts/report] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const { data: report, error } = await db
    .from('fellowship_reports')
    .insert({
      fellowship_id: body.fellowship_id,
      reporter_user_id: user.id,
      content_type: body.content_type,
      content_id: body.content_id,
      reason
    })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-posts/report] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to submit report', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: { id: report.id, status: report.status, created_at: report.created_at },
      message: 'Report submitted. Thank you for keeping the fellowship safe.'
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handlePosts(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const pathname = new URL(req.url).pathname

  if (req.method === 'POST') {
    if (pathname.endsWith('/react'))  return handleToggleReaction(req, services)
    if (pathname.endsWith('/report')) return handleCreateReport(req, services)
    return handleCreatePost(req, services)
  }

  if (req.method === 'GET')    return handleListPosts(req, services)
  if (req.method === 'DELETE') return handleDeletePost(req, services)

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handlePosts, {
  allowedMethods: ['GET', 'POST', 'DELETE'],
  enableAnalytics: true,
  timeout: 15000,
})
