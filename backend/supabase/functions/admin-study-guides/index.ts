/**
 * Admin Study Guides Management Edge Function
 *
 * Provides operations for viewing and managing generated study guides
 *
 * Supported Operations:
 * - GET /admin-study-guides - List all generated study guides with filtering
 * - GET /admin-study-guides/:id - Get study guide by ID
 * - DELETE /admin-study-guides/:id - Delete study guide
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, DELETE, OPTIONS'
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
      // GET /admin-study-guides - List all study guides
      const inputType = url.searchParams.get('input_type') as 'scripture' | 'topic' | 'question' | undefined
      const studyMode = url.searchParams.get('study_mode') as 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon' | undefined
      const language = url.searchParams.get('language') as 'en' | 'hi' | 'ml' | undefined
      const search = url.searchParams.get('search') || undefined
      return await handleList(serviceClient, inputType, studyMode, language, search)
    } else if (method === 'GET' && pathParts.length === 2) {
      // GET /admin-study-guides/:id - Get study guide by ID
      const guideId = pathParts[1]
      return await handleGetById(serviceClient, guideId)
    } else if (method === 'DELETE' && pathParts.length === 2) {
      // DELETE /admin-study-guides/:id - Delete study guide
      const guideId = pathParts[1]
      return await handleDelete(serviceClient, guideId)
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
    console.error('Admin study guides error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Internal server error'
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

/**
 * List all study guides with optional filtering
 */
async function handleList(
  client: any,
  inputType?: 'scripture' | 'topic' | 'question',
  studyMode?: 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon',
  language?: 'en' | 'hi' | 'ml',
  search?: string
): Promise<Response> {
  // Build query
  let query = client
    .from('study_guides')
    .select(`
      id,
      input_type,
      input_value,
      language,
      study_mode,
      topic_id,
      creator_user_id,
      created_at,
      updated_at
    `)
    .order('created_at', { ascending: false })

  if (inputType) {
    query = query.eq('input_type', inputType)
  }

  if (studyMode) {
    query = query.eq('study_mode', studyMode)
  }

  if (language) {
    query = query.eq('language', language)
  }

  if (search) {
    query = query.ilike('input_value', `%${search}%`)
  }

  const { data: guides, error: guidesError } = await query

  if (guidesError) {
    throw new Error(`Failed to fetch study guides: ${guidesError.message}`)
  }

  // Get usage counts (how many users have saved each guide)
  const { data: userGuides, error: userGuidesError } = await client
    .from('user_study_guides')
    .select('study_guide_id')

  if (userGuidesError) {
    console.error('Failed to fetch usage counts:', userGuidesError)
  }

  // Aggregate usage counts
  const usageMap: Record<string, number> = {}
  userGuides?.forEach((ug: any) => {
    usageMap[ug.study_guide_id] = (usageMap[ug.study_guide_id] || 0) + 1
  })

  // Get topic information for guides linked to topics
  const topicIds = guides
    .filter((g: any) => g.topic_id)
    .map((g: any) => g.topic_id)

  let topicsMap: Record<string, any> = {}
  if (topicIds.length > 0) {
    const { data: topics, error: topicsError } = await client
      .from('recommended_topics')
      .select('id, title')
      .in('id', topicIds)

    if (!topicsError && topics) {
      topics.forEach((t: any) => {
        topicsMap[t.id] = t
      })
    }
  }

  // Get creator information
  const creatorIds = guides
    .filter((g: any) => g.creator_user_id)
    .map((g: any) => g.creator_user_id)

  let creatorsMap: Record<string, any> = {}
  if (creatorIds.length > 0) {
    const { data: creators, error: creatorsError } = await client
      .from('user_profiles')
      .select('id, full_name, email')
      .in('id', creatorIds)

    if (!creatorsError && creators) {
      creators.forEach((c: any) => {
        creatorsMap[c.id] = c
      })
    }
  }

  // Combine data
  const guidesWithDetails = guides.map((guide: any) => ({
    ...guide,
    usage_count: usageMap[guide.id] || 0,
    topic_title: guide.topic_id ? topicsMap[guide.topic_id]?.title : null,
    creator_name: guide.creator_user_id ? creatorsMap[guide.creator_user_id]?.full_name || creatorsMap[guide.creator_user_id]?.email : null
  }))

  return new Response(
    JSON.stringify({ study_guides: guidesWithDetails }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Get study guide by ID
 */
async function handleGetById(client: any, guideId: string): Promise<Response> {
  const { data: guide, error: guideError } = await client
    .from('study_guides')
    .select('*')
    .eq('id', guideId)
    .single()

  if (guideError) {
    if (guideError.code === 'PGRST116') {
      return new Response(
        JSON.stringify({ error: 'Study guide not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }
    throw new Error(`Failed to fetch study guide: ${guideError.message}`)
  }

  // Get usage count
  const { count: usageCount } = await client
    .from('user_study_guides')
    .select('*', { count: 'exact', head: true })
    .eq('study_guide_id', guideId)

  // Get topic if linked
  let topicInfo = null
  if (guide.topic_id) {
    const { data: topic } = await client
      .from('recommended_topics')
      .select('id, title, category')
      .eq('id', guide.topic_id)
      .single()

    topicInfo = topic
  }

  // Get creator info
  let creatorInfo = null
  if (guide.creator_user_id) {
    const { data: creator } = await client
      .from('user_profiles')
      .select('id, full_name, email')
      .eq('id', guide.creator_user_id)
      .single()

    creatorInfo = creator
  }

  return new Response(
    JSON.stringify({
      study_guide: {
        ...guide,
        usage_count: usageCount || 0,
        topic: topicInfo,
        creator: creatorInfo
      }
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Delete study guide
 */
async function handleDelete(client: any, guideId: string): Promise<Response> {
  // Check if guide exists
  const { data: existing } = await client
    .from('study_guides')
    .select('id, input_value')
    .eq('id', guideId)
    .single()

  if (!existing) {
    return new Response(
      JSON.stringify({ error: 'Study guide not found' }),
      {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check usage count
  const { count: usageCount } = await client
    .from('user_study_guides')
    .select('*', { count: 'exact', head: true })
    .eq('study_guide_id', guideId)

  if (usageCount && usageCount > 0) {
    return new Response(
      JSON.stringify({
        error: 'Cannot delete study guide - it is being used by users',
        usage_count: usageCount
      }),
      {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Delete study guide
  const { error: deleteError } = await client
    .from('study_guides')
    .delete()
    .eq('id', guideId)

  if (deleteError) {
    throw new Error(`Failed to delete study guide: ${deleteError.message}`)
  }

  return new Response(
    JSON.stringify({ message: 'Study guide deleted successfully' }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}
