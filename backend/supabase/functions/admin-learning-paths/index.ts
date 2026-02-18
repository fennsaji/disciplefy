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
    } else if (method === 'DELETE' && pathParts.length === 2) {
      // DELETE /admin-learning-paths/:id - Delete path
      const pathId = pathParts[1]
      return await handleDelete(serviceClient, pathId)
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
    console.error('Admin learning paths error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Internal server error'
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

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

  // Fetch topic counts for each path
  const { data: topicCounts, error: topicError } = await client
    .from('learning_path_topics')
    .select('learning_path_id, topic_id')

  if (topicError) {
    throw new Error(`Failed to fetch topic counts: ${topicError.message}`)
  }

  // Fetch enrollment counts for each path
  const { data: enrollments, error: enrollmentError } = await client
    .from('user_learning_path_progress')
    .select('learning_path_id, user_id')

  if (enrollmentError) {
    throw new Error(`Failed to fetch enrollment counts: ${enrollmentError.message}`)
  }

  // Aggregate counts
  const topicCountMap: Record<string, number> = {}
  const enrollmentCountMap: Record<string, number> = {}

  topicCounts?.forEach((tc: any) => {
    topicCountMap[tc.learning_path_id] = (topicCountMap[tc.learning_path_id] || 0) + 1
  })

  enrollments?.forEach((e: any) => {
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
    .select('position, is_milestone, recommended_topics(*)')
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
