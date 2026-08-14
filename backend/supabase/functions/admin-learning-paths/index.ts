/**
 * Admin Learning Paths Management Edge Function
 *
 * Provides full CRUD operations for learning paths with admin-only access.
 *
 * Supported Operations:
 * - GET /admin-learning-paths - List all learning paths with stats
 * - GET /admin-learning-paths/:id - Get full learning path details
 * - POST /admin-learning-paths - Create new learning path
 * - PUT /admin-learning-paths/:id - Update existing learning path
 * - DELETE /admin-learning-paths/:id - Delete learning path (with cascade check)
 * - PATCH /admin-learning-paths/:id/reorder - Update display_order
 * - PATCH /admin-learning-paths/:id/toggle - Activate/deactivate path
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS'
}

/**
 * Learning Path interface matching database schema
 */
interface LearningPath {
  id: string
  slug: string
  title: string
  description: string
  icon_name: string
  color: string
  total_xp: number
  estimated_days: number
  difficulty_level: 'beginner' | 'intermediate' | 'advanced'
  disciple_level: 'seeker' | 'follower' | 'disciple' | 'leader'
  recommended_mode: 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon'
  is_featured: boolean
  is_active: boolean
  display_order: number
  allow_non_sequential_access: boolean
  created_at?: string
  updated_at?: string
}

/**
 * Translation interface
 */
interface Translation {
  learning_path_id: string
  language: 'en' | 'hi' | 'ml'
  title: string
  description: string
}

/**
 * Request body for creating learning path
 */
interface CreateLearningPathRequest {
  slug: string
  title: string
  description: string
  icon_name: string
  color: string
  estimated_days: number
  difficulty_level: 'beginner' | 'intermediate' | 'advanced'
  disciple_level: 'seeker' | 'follower' | 'disciple' | 'leader'
  recommended_mode: 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon'
  is_featured?: boolean
  is_active?: boolean
  allow_non_sequential_access?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

/**
 * Request body for updating learning path
 */
interface UpdateLearningPathRequest {
  title?: string
  description?: string
  icon_name?: string
  color?: string
  estimated_days?: number
  difficulty_level?: 'beginner' | 'intermediate' | 'advanced'
  disciple_level?: 'seeker' | 'follower' | 'disciple' | 'leader'
  recommended_mode?: 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon'
  is_featured?: boolean
  is_active?: boolean
  allow_non_sequential_access?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

/**
 * Request body for adding topic to path
 */
interface AddTopicRequest {
  learning_path_id: string
  topic_id: string
  position: number
  is_milestone?: boolean
}

/**
 * Request body for removing topic from path
 */
interface RemoveTopicRequest {
  learning_path_id: string
  topic_id: string
}

/**
 * Request body for reordering topics
 */
interface ReorderTopicsRequest {
  learning_path_id: string
  topic_orders: Array<{
    topic_id: string
    position: number
  }>
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify service role authentication
    const authHeader = req.headers.get('Authorization')
    const adminUserId = req.headers.get('x-admin-user-id')

    if (!authHeader || !adminUserId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Missing credentials' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify it's the service role key
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const providedKey = authHeader.replace('Bearer ', '')

    if (providedKey !== serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Invalid credentials' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create service role client for admin operations
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey
    )

    // Verify admin status
    const { data: profile, error: profileError } = await serviceClient
      .from('user_profiles')
      .select('is_admin')
      .eq('id', adminUserId)
      .single()

    if (profileError || !profile?.is_admin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden - Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse URL and method
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)
    const method = req.method

    // Route to appropriate handler
    if (method === 'GET' && pathParts.length === 1) {
      // GET /admin-learning-paths - List all paths
      return await handleList(serviceClient)
    } else if (method === 'GET' && pathParts.length === 2) {
      // GET /admin-learning-paths/:id - Get path by ID
      const pathId = pathParts[1]
      return await handleGetById(serviceClient, pathId)
    } else if (method === 'POST' && pathParts.length === 1) {
      // POST /admin-learning-paths - Create new path
      const body = await req.json()
      return await handleCreate(serviceClient, body)
    } else if (method === 'PUT' && pathParts.length === 2) {
      // PUT /admin-learning-paths/:id - Update path
      const pathId = pathParts[1]
      const body = await req.json()
      return await handleUpdate(serviceClient, pathId, body)
    } else if (method === 'DELETE' && pathParts.length === 2 && pathParts[1] === 'topics') {
      // DELETE /admin-learning-paths/topics - Remove topic from path
      const body = await req.json()
      return await handleRemoveTopic(serviceClient, body)
    } else if (method === 'DELETE' && pathParts.length === 2) {
      // DELETE /admin-learning-paths/:id - Delete path
      const pathId = pathParts[1]
      return await handleDelete(serviceClient, pathId)
    } else if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'topics') {
      // POST /admin-learning-paths/topics - Add topic to path
      const body = await req.json()
      return await handleAddTopic(serviceClient, body)
    } else if (method === 'PATCH' && pathParts.length === 3 && pathParts[1] === 'topics' && pathParts[2] === 'reorder') {
      // PATCH /admin-learning-paths/topics/reorder - Reorder topics
      const body = await req.json()
      return await handleReorderTopics(serviceClient, body)
    } else if (method === 'PATCH' && pathParts.length === 5 && pathParts[1] === 'topics' && pathParts[4] === 'milestone') {
      // PATCH /admin-learning-paths/topics/:pathId/:topicId/milestone - Toggle milestone
      const pathId = pathParts[2]
      const topicId = pathParts[3]
      const body = await req.json()
      return await handleToggleMilestone(serviceClient, pathId, topicId, body.is_milestone)
    } else if (method === 'PATCH' && pathParts.length === 3 && pathParts[2] === 'reorder') {
      // PATCH /admin-learning-paths/:id/reorder - Update display order
      const pathId = pathParts[1]
      const body = await req.json()
      return await handleReorder(serviceClient, pathId, body.display_order)
    } else if (method === 'PATCH' && pathParts.length === 3 && pathParts[2] === 'toggle') {
      // PATCH /admin-learning-paths/:id/toggle - Toggle active status
      const pathId = pathParts[1]
      const body = await req.json()
      return await handleToggle(serviceClient, pathId, body.is_active)
    } else {
      return new Response(
        JSON.stringify({ error: 'Not Found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }
  } catch (error: unknown) {
    console.error('[admin-learning-paths] Unhandled error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

/**
 * Read every row of a query past PostgREST's silent 1000-row response cap.
 * `buildPage` must build a FRESH query per page (query builders are single-use).
 */
async function fetchAllRows(buildPage: (from: number, to: number) => any): Promise<any[]> {
  const PAGE = 1000
  const MAX_PAGES = 100 // safety cap: 100k rows
  const rows: any[] = []
  for (let page = 0; page < MAX_PAGES; page++) {
    const from = page * PAGE
    const { data, error } = await buildPage(from, from + PAGE - 1)
    if (error) throw new Error(error.message)
    rows.push(...(data || []))
    if (!data || data.length < PAGE) break
  }
  return rows
}

/**
 * List all learning paths with enrollment and topic counts
 */
async function handleList(client: any): Promise<Response> {
  // Fetch all learning paths
  const { data: paths, error: pathsError } = await client
    .from('learning_paths')
    .select('*')
    .order('display_order', { ascending: true })

  if (pathsError) {
    throw new Error(`Failed to fetch learning paths: ${pathsError.message}`)
  }

  // Topic and enrollment counts back the "Topics" and "Total Enrolled" stats,
  // so both reads must page past the 1000-row cap or the numbers silently
  // plateau once a path passes a thousand rows.
  const topicCounts = await fetchAllRows((from, to) =>
    client
      .from('learning_path_topics')
      .select('learning_path_id, topic_id')
      .order('learning_path_id', { ascending: true })
      .range(from, to)
  )

  const enrollments = await fetchAllRows((from, to) =>
    client
      .from('user_learning_path_progress')
      .select('learning_path_id, user_id')
      .order('learning_path_id', { ascending: true })
      .range(from, to)
  )

  // Aggregate counts
  const topicCountMap: Record<string, number> = {}
  const enrollmentCountMap: Record<string, number> = {}

  topicCounts.forEach((tc: any) => {
    topicCountMap[tc.learning_path_id] = (topicCountMap[tc.learning_path_id] || 0) + 1
  })

  enrollments.forEach((e: any) => {
    enrollmentCountMap[e.learning_path_id] = (enrollmentCountMap[e.learning_path_id] || 0) + 1
  })

  // Combine data
  const pathsWithStats = paths.map((path: any) => ({
    ...path,
    topics_count: topicCountMap[path.id] || 0,
    enrolled_count: enrollmentCountMap[path.id] || 0
  }))

  return new Response(
    JSON.stringify({ learning_paths: pathsWithStats }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Get learning path by ID with full details including topics and translations
 */
async function handleGetById(client: any, pathId: string): Promise<Response> {
  // Fetch learning path
  const { data: path, error: pathError } = await client
    .from('learning_paths')
    .select('*')
    .eq('id', pathId)
    .single()

  if (pathError) {
    if (pathError.code === 'PGRST116') {
      return new Response(
        JSON.stringify({ error: 'Learning path not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }
    throw new Error(`Failed to fetch learning path: ${pathError.message}`)
  }

  // Fetch translations
  const { data: translations, error: translationsError } = await client
    .from('learning_path_translations')
    .select('lang_code, title, description')
    .eq('learning_path_id', pathId)

  if (translationsError) {
    throw new Error(`Failed to fetch translations: ${translationsError.message}`)
  }

  // Fetch topics in this path
  const { data: pathTopics, error: pathTopicsError } = await client
    .from('learning_path_topics')
    .select('position, is_milestone, is_active, recommended_topics(*)')
    .eq('learning_path_id', pathId)
    .order('position', { ascending: true })

  if (pathTopicsError) {
    throw new Error(`Failed to fetch path topics: ${pathTopicsError.message}`)
  }

  // Format response
  const translationsObj: Record<string, any> = {}
  translations?.forEach((t: any) => {
    translationsObj[t.lang_code] = {
      title: t.title,
      description: t.description
    }
  })

  return new Response(
    JSON.stringify({
      learning_path: {
        ...path,
        translations: translationsObj,
        topics: pathTopics.map((pt: any) => ({
          ...pt.recommended_topics,
          position: pt.position,
          is_milestone: pt.is_milestone
        }))
      }
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Create new learning path with translations
 */
async function handleCreate(client: any, body: CreateLearningPathRequest): Promise<Response> {
  // Validate required fields
  if (!body.slug || !body.title || !body.description) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: slug, title, description' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check if slug already exists
  const { data: existing, error: existingError } = await client
    .from('learning_paths')
    .select('id')
    .eq('slug', body.slug)
    .single()

  if (existing) {
    return new Response(
      JSON.stringify({ error: 'Slug already exists' }),
      {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Get max display_order
  const { data: maxOrder } = await client
    .from('learning_paths')
    .select('display_order')
    .order('display_order', { ascending: false })
    .limit(1)
    .single()

  const displayOrder = (maxOrder?.display_order || 0) + 1

  // Create learning path
  const { data: newPath, error: createError } = await client
    .from('learning_paths')
    .insert({
      slug: body.slug,
      title: body.title,
      description: body.description,
      icon_name: body.icon_name,
      color: body.color,
      total_xp: 0, // Will be calculated when topics are added
      estimated_days: body.estimated_days,
      difficulty_level: body.difficulty_level,
      disciple_level: body.disciple_level,
      recommended_mode: body.recommended_mode,
      is_featured: body.is_featured ?? false,
      is_active: body.is_active ?? true,
      allow_non_sequential_access: body.allow_non_sequential_access ?? true,
      display_order: displayOrder
    })
    .select()
    .single()

  if (createError) {
    throw new Error(`Failed to create learning path: ${createError.message}`)
  }

  // Create translations if provided
  if (body.translations) {
    const translationsToInsert = []
    const validLanguages = ['en', 'hi', 'ml']

    for (const [lang, trans] of Object.entries(body.translations)) {
      // Skip if language code is invalid or translation data is missing
      if (!validLanguages.includes(lang) || !trans || !trans.title || !trans.description) {
        continue
      }

      translationsToInsert.push({
        learning_path_id: newPath.id,
        lang_code: lang,
        title: trans.title,
        description: trans.description
      })
    }

    if (translationsToInsert.length > 0) {
      const { error: transError } = await client
        .from('learning_path_translations')
        .insert(translationsToInsert)

      if (transError) {
        console.error('Failed to create translations:', transError)
        // Don't fail the entire request, just log the error
      }
    }
  }

  return new Response(
    JSON.stringify({ learning_path: newPath }),
    {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Update existing learning path
 */
async function handleUpdate(client: any, pathId: string, body: UpdateLearningPathRequest): Promise<Response> {
  // Check if path exists
  const { data: existing, error: existingError } = await client
    .from('learning_paths')
    .select('id')
    .eq('id', pathId)
    .single()

  if (!existing) {
    return new Response(
      JSON.stringify({ error: 'Learning path not found' }),
      {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Build update object
  const updates: Record<string, any> = {}
  if (body.title !== undefined) updates.title = body.title
  if (body.description !== undefined) updates.description = body.description
  if (body.icon_name !== undefined) updates.icon_name = body.icon_name
  if (body.color !== undefined) updates.color = body.color
  if (body.estimated_days !== undefined) updates.estimated_days = body.estimated_days
  if (body.difficulty_level !== undefined) updates.difficulty_level = body.difficulty_level
  if (body.disciple_level !== undefined) updates.disciple_level = body.disciple_level
  if (body.recommended_mode !== undefined) updates.recommended_mode = body.recommended_mode
  if (body.is_featured !== undefined) updates.is_featured = body.is_featured
  if (body.is_active !== undefined) updates.is_active = body.is_active
  if (body.allow_non_sequential_access !== undefined) updates.allow_non_sequential_access = body.allow_non_sequential_access

  // Update learning path
  const { data: updatedPath, error: updateError } = await client
    .from('learning_paths')
    .update(updates)
    .eq('id', pathId)
    .select()
    .single()

  if (updateError) {
    throw new Error(`Failed to update learning path: ${updateError.message}`)
  }

  // Update translations if provided
  if (body.translations) {
    // Validate language codes
    const validLanguages = ['en', 'hi', 'ml']

    for (const [lang, trans] of Object.entries(body.translations)) {
      // Skip if language code is invalid or translation data is missing
      if (!validLanguages.includes(lang) || !trans || !trans.title || !trans.description) {
        continue
      }

      // Upsert translation
      const { error: transError } = await client
        .from('learning_path_translations')
        .upsert({
          learning_path_id: pathId,
          lang_code: lang,
          title: trans.title,
          description: trans.description
        }, {
          onConflict: 'learning_path_id,lang_code'
        })

      if (transError) {
        console.error(`Failed to update ${lang} translation:`, transError)
      }
    }
  }

  return new Response(
    JSON.stringify({ learning_path: updatedPath }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Delete learning path with cascade check
 */
async function handleDelete(client: any, pathId: string): Promise<Response> {
  // Check if path exists
  const { data: existing, error: existingError } = await client
    .from('learning_paths')
    .select('id, title')
    .eq('id', pathId)
    .single()

  if (!existing) {
    return new Response(
      JSON.stringify({ error: 'Learning path not found' }),
      {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check for enrollments (warn about cascade)
  const { data: enrollments, error: enrollmentError } = await client
    .from('user_learning_path_progress')
    .select('user_id')
    .eq('learning_path_id', pathId)
    .limit(1)

  const hasEnrollments = enrollments && enrollments.length > 0

  // Check for topics
  const { data: topics, error: topicsError } = await client
    .from('learning_path_topics')
    .select('topic_id')
    .eq('learning_path_id', pathId)
    .limit(1)

  const hasTopics = topics && topics.length > 0

  // Delete path (CASCADE will handle translations, topics, and progress)
  const { error: deleteError } = await client
    .from('learning_paths')
    .delete()
    .eq('id', pathId)

  if (deleteError) {
    throw new Error(`Failed to delete learning path: ${deleteError.message}`)
  }

  return new Response(
    JSON.stringify({
      message: 'Learning path deleted successfully',
      cascade_warnings: {
        had_enrollments: hasEnrollments,
        had_topics: hasTopics
      }
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Update display order
 */
async function handleReorder(client: any, pathId: string, displayOrder: number): Promise<Response> {
  if (typeof displayOrder !== 'number' || displayOrder < 0) {
    return new Response(
      JSON.stringify({ error: 'Invalid display_order value' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  const { data: updated, error: updateError } = await client
    .from('learning_paths')
    .update({ display_order: displayOrder })
    .eq('id', pathId)
    .select()
    .single()

  if (updateError) {
    if (updateError.code === 'PGRST116') {
      return new Response(
        JSON.stringify({ error: 'Learning path not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }
    throw new Error(`Failed to update display order: ${updateError.message}`)
  }

  return new Response(
    JSON.stringify({ learning_path: updated }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Toggle active status
 */
async function handleToggle(client: any, pathId: string, isActive: boolean): Promise<Response> {
  if (typeof isActive !== 'boolean') {
    return new Response(
      JSON.stringify({ error: 'Invalid is_active value' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  const { data: updated, error: updateError } = await client
    .from('learning_paths')
    .update({ is_active: isActive })
    .eq('id', pathId)
    .select()
    .single()

  if (updateError) {
    if (updateError.code === 'PGRST116') {
      return new Response(
        JSON.stringify({ error: 'Learning path not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }
    throw new Error(`Failed to toggle active status: ${updateError.message}`)
  }

  return new Response(
    JSON.stringify({ learning_path: updated }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Add topic to learning path at specified position
 */
async function handleAddTopic(client: any, body: AddTopicRequest): Promise<Response> {
  // Validate required fields
  if (!body.learning_path_id || !body.topic_id || body.position === undefined) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: learning_path_id, topic_id, position' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check if learning path exists
  const { data: path, error: pathError } = await client
    .from('learning_paths')
    .select('id')
    .eq('id', body.learning_path_id)
    .single()

  if (!path) {
    return new Response(
      JSON.stringify({ error: 'Learning path not found' }),
      {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check if topic exists
  const { data: topic, error: topicError } = await client
    .from('recommended_topics')
    .select('id, xp_value')
    .eq('id', body.topic_id)
    .single()

  if (!topic) {
    return new Response(
      JSON.stringify({ error: 'Topic not found' }),
      {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check if topic is already in path
  const { data: existing } = await client
    .from('learning_path_topics')
    .select('*')
    .eq('learning_path_id', body.learning_path_id)
    .eq('topic_id', body.topic_id)
    .single()

  if (existing) {
    return new Response(
      JSON.stringify({ error: 'Topic already exists in this learning path' }),
      {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Shift existing topics at or after this position
  const { error: shiftError } = await client.rpc('shift_learning_path_topics', {
    p_learning_path_id: body.learning_path_id,
    p_from_position: body.position
  })

  if (shiftError) {
    console.error('Failed to shift topics:', shiftError)
    // Continue anyway - insert will still work
  }

  // Insert new topic
  const { data: newEntry, error: insertError } = await client
    .from('learning_path_topics')
    .insert({
      learning_path_id: body.learning_path_id,
      topic_id: body.topic_id,
      position: body.position,
      is_milestone: body.is_milestone ?? false
    })
    .select()
    .single()

  if (insertError) {
    throw new Error(`Failed to add topic to path: ${insertError.message}`)
  }

  // Update learning path total_xp
  await recalculateTotalXP(client, body.learning_path_id)

  return new Response(
    JSON.stringify({
      message: 'Topic added to learning path successfully',
      entry: newEntry
    }),
    {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Remove topic from learning path
 */
async function handleRemoveTopic(client: any, body: RemoveTopicRequest): Promise<Response> {
  // Validate required fields
  if (!body.learning_path_id || !body.topic_id) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: learning_path_id, topic_id' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check if entry exists
  const { data: existing, error: existingError } = await client
    .from('learning_path_topics')
    .select('position')
    .eq('learning_path_id', body.learning_path_id)
    .eq('topic_id', body.topic_id)
    .single()

  if (!existing) {
    return new Response(
      JSON.stringify({ error: 'Topic not found in this learning path' }),
      {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Delete entry
  const { error: deleteError } = await client
    .from('learning_path_topics')
    .delete()
    .eq('learning_path_id', body.learning_path_id)
    .eq('topic_id', body.topic_id)

  if (deleteError) {
    throw new Error(`Failed to remove topic from path: ${deleteError.message}`)
  }

  // Shift remaining topics down
  const { error: shiftError } = await client
    .from('learning_path_topics')
    .update({ position: client.raw('position - 1') })
    .eq('learning_path_id', body.learning_path_id)
    .gt('position', existing.position)

  if (shiftError) {
    console.error('Failed to shift topics after removal:', shiftError)
  }

  // Update learning path total_xp
  await recalculateTotalXP(client, body.learning_path_id)

  return new Response(
    JSON.stringify({ message: 'Topic removed from learning path successfully' }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Reorder topics in learning path
 */
async function handleReorderTopics(client: any, body: ReorderTopicsRequest): Promise<Response> {
  // Validate required fields
  if (!body.learning_path_id || !Array.isArray(body.topic_orders)) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: learning_path_id, topic_orders' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Update each topic's position
  const updatePromises = body.topic_orders.map(async (order) => {
    const { error } = await client
      .from('learning_path_topics')
      .update({ position: order.position })
      .eq('learning_path_id', body.learning_path_id)
      .eq('topic_id', order.topic_id)

    if (error) {
      throw new Error(`Failed to update position for topic ${order.topic_id}: ${error.message}`)
    }
  })

  await Promise.all(updatePromises)

  return new Response(
    JSON.stringify({ message: 'Topics reordered successfully' }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Toggle milestone flag for a topic in a learning path
 */
async function handleToggleMilestone(
  client: any,
  pathId: string,
  topicId: string,
  isMilestone: boolean
): Promise<Response> {
  if (typeof isMilestone !== 'boolean') {
    return new Response(
      JSON.stringify({ error: 'Invalid is_milestone value' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Update milestone flag
  const { data: updated, error: updateError } = await client
    .from('learning_path_topics')
    .update({ is_milestone: isMilestone })
    .eq('learning_path_id', pathId)
    .eq('topic_id', topicId)
    .select()
    .single()

  if (updateError) {
    if (updateError.code === 'PGRST116') {
      return new Response(
        JSON.stringify({ error: 'Topic not found in learning path' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }
    throw new Error(`Failed to toggle milestone: ${updateError.message}`)
  }

  return new Response(
    JSON.stringify({
      message: 'Milestone flag updated successfully',
      entry: updated
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Recalculate total XP for a learning path based on its topics
 */
async function recalculateTotalXP(client: any, pathId: string): Promise<void> {
  // Get all topics in the path
  const { data: pathTopics, error: topicsError } = await client
    .from('learning_path_topics')
    .select('recommended_topics(xp_value)')
    .eq('learning_path_id', pathId)

  if (topicsError) {
    console.error('Failed to fetch topics for XP calculation:', topicsError)
    return
  }

  // Calculate total XP
  const totalXP = pathTopics.reduce((sum: number, pt: any) => {
    return sum + (pt.recommended_topics?.xp_value || 0)
  }, 0)

  // Update learning path
  const { error: updateError } = await client
    .from('learning_paths')
    .update({ total_xp: totalXP })
    .eq('id', pathId)

  if (updateError) {
    console.error('Failed to update total XP:', updateError)
  }
}
