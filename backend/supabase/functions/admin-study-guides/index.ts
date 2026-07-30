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
      const limit = Math.min(Math.max(parseInt(url.searchParams.get('limit') || '50', 10) || 50, 1), 200)
      const offset = Math.max(parseInt(url.searchParams.get('offset') || '0', 10) || 0, 0)
      return await handleList(serviceClient, { inputType, studyMode, language, search, limit, offset })
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
    console.error('[admin-study-guides] Unhandled error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

interface ListParams {
  inputType?: 'scripture' | 'topic' | 'question'
  studyMode?: 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon'
  language?: 'en' | 'hi' | 'ml'
  search?: string
  limit: number
  offset: number
}

const INPUT_TYPES = ['scripture', 'topic', 'question'] as const
const STUDY_MODES = ['quick', 'standard', 'deep', 'lectio', 'sermon'] as const
const LANGUAGES = ['en', 'hi', 'ml'] as const

// PostgREST filters travel in the URL, so cap inlined id lists.
const MAX_INLINE_IDS = 300

/**
 * Read every row of a query past PostgREST's silent 1000-row response cap.
 * `buildPage` must build a FRESH query per page (query builders are single-use).
 */
async function fetchAllRows(
  buildPage: (from: number, to: number) => any
): Promise<any[]> {
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
 * List study guides.
 *
 * Filtering, search, counting and paging ALL happen in the database, so the
 * admin UI never has to filter a truncated page in the browser. `total` and
 * `stats` describe every row matching the filters, not the returned page.
 */
async function handleList(client: any, params: ListParams): Promise<Response> {
  const { inputType, studyMode, language, search, limit, offset } = params

  // Search spans input_value, the linked topic title and the creator's name,
  // so resolve the id sets those two need before building the main query.
  let topicIdMatches: string[] = []
  let creatorIdMatches: string[] = []
  if (search) {
    const [{ data: topics }, { data: creators }] = await Promise.all([
      client.from('recommended_topics').select('id').ilike('title', `%${search}%`).limit(MAX_INLINE_IDS),
      client
        .from('user_profiles')
        .select('id')
        .or(`first_name.ilike.%${search}%,last_name.ilike.%${search}%`)
        .limit(MAX_INLINE_IDS),
    ])
    topicIdMatches = (topics || []).map((t: any) => t.id)
    creatorIdMatches = (creators || []).map((c: any) => c.id)
  }

  const applyFilters = (q: any) => {
    if (inputType) q = q.eq('input_type', inputType)
    if (studyMode) q = q.eq('study_mode', studyMode)
    if (language) q = q.eq('language', language)
    if (search) {
      const conditions = [`input_value.ilike.%${search}%`]
      if (topicIdMatches.length > 0) conditions.push(`topic_id.in.(${topicIdMatches.join(',')})`)
      if (creatorIdMatches.length > 0) {
        conditions.push(`creator_user_id.in.(${creatorIdMatches.join(',')})`)
      }
      q = q.or(conditions.join(','))
    }
    return q
  }

  const guideColumns = `
      id,
      input_type,
      input_value,
      language,
      study_mode,
      topic_id,
      creator_user_id,
      created_at,
      updated_at
    `

  const { data: guides, error: guidesError } = await applyFilters(
    client.from('study_guides').select(guideColumns)
  )
    .order('created_at', { ascending: false })
    .order('id', { ascending: true })
    .range(offset, offset + limit - 1)

  if (guidesError) {
    throw new Error(`Failed to fetch study guides: ${guidesError.message}`)
  }

  const { count: total, error: countError } = await applyFilters(
    client.from('study_guides').select('id', { count: 'exact', head: true })
  )

  if (countError) {
    throw new Error(`Failed to count study guides: ${countError.message}`)
  }

  // Usage counts for THIS page only. `user_study_guides` can exceed the 1000-row
  // response cap, so page through the rows for these guide ids.
  const guideIds = guides.map((g: any) => g.id)
  const usageMap: Record<string, number> = {}
  if (guideIds.length > 0) {
    try {
      const userGuides = await fetchAllRows((from, to) =>
        client
          .from('user_study_guides')
          .select('study_guide_id')
          .in('study_guide_id', guideIds)
          .order('study_guide_id', { ascending: true })
          .range(from, to)
      )
      userGuides.forEach((ug: any) => {
        usageMap[ug.study_guide_id] = (usageMap[ug.study_guide_id] || 0) + 1
      })
    } catch (error) {
      console.error('Failed to fetch usage counts:', error)
    }
  }

  // Get topic information for guides linked to topics
  const topicIds = guides.filter((g: any) => g.topic_id).map((g: any) => g.topic_id)

  const topicsMap: Record<string, any> = {}
  if (topicIds.length > 0) {
    const { data: topics, error: topicsError } = await client
      .from('recommended_topics')
      .select('id, title')
      .in('id', topicIds)

    if (topicsError) {
      console.error('Failed to fetch topics:', topicsError)
    } else {
      ;(topics || []).forEach((t: any) => {
        topicsMap[t.id] = t
      })
    }
  }

  // Get creator information. `user_profiles` has no full_name/email columns —
  // names come from first_name/last_name, emails from the auth admin API.
  const creatorIds = guides.filter((g: any) => g.creator_user_id).map((g: any) => g.creator_user_id)

  const creatorsMap: Record<string, string> = {}
  if (creatorIds.length > 0) {
    const { data: creators, error: creatorsError } = await client
      .from('user_profiles')
      .select('id, first_name, last_name')
      .in('id', creatorIds)

    if (creatorsError) {
      console.error('Failed to fetch creators:', creatorsError)
    } else {
      ;(creators || []).forEach((c: any) => {
        const name = [c.first_name, c.last_name].filter(Boolean).join(' ')
        if (name) creatorsMap[c.id] = name
      })
    }

    // Fill any remaining creators from their auth email
    const missing = creatorIds.filter((id: string) => !creatorsMap[id])
    if (missing.length > 0) {
      await Promise.all(
        [...new Set(missing)].map(async (id: any) => {
          try {
            const { data } = await client.auth.admin.getUserById(id)
            if (data?.user?.email) creatorsMap[id] = data.user.email
          } catch (error) {
            console.error('Failed to resolve creator email:', error)
          }
        })
      )
    }
  }

  // Combine data
  const guidesWithDetails = guides.map((guide: any) => ({
    ...guide,
    usage_count: usageMap[guide.id] || 0,
    topic_title: guide.topic_id ? topicsMap[guide.topic_id]?.title ?? null : null,
    creator_name: guide.creator_user_id ? creatorsMap[guide.creator_user_id] ?? null : null
  }))

  const stats = await buildListStats(client, applyFilters, total || 0)

  return new Response(
    JSON.stringify({
      study_guides: guidesWithDetails,
      total: total || 0,
      limit,
      offset,
      stats
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Breakdown counts for the stat cards, computed by Postgres over EVERY row
 * matching the current filters — never over the page the browser holds.
 */
async function buildListStats(
  client: any,
  applyFilters: (q: any) => any,
  total: number
): Promise<Record<string, any>> {
  const countFor = async (column: string, value: string): Promise<number> => {
    const { count } = await applyFilters(
      client.from('study_guides').select('id', { count: 'exact', head: true })
    ).eq(column, value)
    return count || 0
  }

  const [inputTypeCounts, studyModeCounts, languageCounts, usageTotal] = await Promise.all([
    Promise.all(INPUT_TYPES.map(v => countFor('input_type', v))),
    Promise.all(STUDY_MODES.map(v => countFor('study_mode', v))),
    Promise.all(LANGUAGES.map(v => countFor('language', v))),
    client
      .from('user_study_guides')
      .select('id', { count: 'exact', head: true })
      .then((r: any) => r.count || 0),
  ])

  const asMap = (keys: readonly string[], counts: number[]) =>
    Object.fromEntries(keys.map((k, i) => [k, counts[i]]).filter(([, c]) => (c as number) > 0))

  return {
    total,
    total_usage: usageTotal,
    by_input_type: asMap(INPUT_TYPES, inputTypeCounts),
    by_study_mode: asMap(STUDY_MODES, studyModeCounts),
    by_language: asMap(LANGUAGES, languageCounts)
  }
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

  // Get creator info. `user_profiles` has no full_name/email columns — build the
  // name from first_name/last_name and read the email from the auth admin API.
  let creatorInfo = null
  if (guide.creator_user_id) {
    const { data: creator } = await client
      .from('user_profiles')
      .select('id, first_name, last_name')
      .eq('id', guide.creator_user_id)
      .single()

    let email: string | null = null
    try {
      const { data: authUser } = await client.auth.admin.getUserById(guide.creator_user_id)
      email = authUser?.user?.email ?? null
    } catch (error) {
      console.error('Failed to resolve creator email:', error)
    }

    creatorInfo = {
      id: guide.creator_user_id,
      full_name: [creator?.first_name, creator?.last_name].filter(Boolean).join(' ') || null,
      email
    }
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
