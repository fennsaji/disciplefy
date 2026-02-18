/**
 * Admin Recommended Topics Management Edge Function
 *
 * Provides full CRUD operations for recommended topics with admin-only access.
 *
 * Supported Operations:
 * - GET /admin-recommended-topics - List all topics with filtering
 * - GET /admin-recommended-topics/:id - Get topic by ID with translations
 * - POST /admin-recommended-topics - Create new topic
 * - POST /admin-recommended-topics/bulk-import - Bulk import topics from CSV
 * - PUT /admin-recommended-topics/:id - Update existing topic
 * - DELETE /admin-recommended-topics/:id - Delete topic (with usage check)
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
}

/**
 * Recommended Topic interface
 */
interface RecommendedTopic {
  id: string
  title: string
  description: string
  category: string
  input_type: 'topic' | 'verse' | 'question'
  input_value: string
  tags: string[]
  xp_value: number
  display_order: number
  is_active: boolean
  created_at?: string
  updated_at?: string
}

/**
 * Translation interface
 */
interface TopicTranslation {
  topic_id: string
  language: 'en' | 'hi' | 'ml'
  title: string
  description: string
}

/**
 * Request body for creating topic
 */
interface CreateTopicRequest {
  title: string
  description: string
  category: string
  input_type: 'topic' | 'verse' | 'question'
  input_value: string
  tags?: string[]
  xp_value?: number
  is_active?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

/**
 * Request body for updating topic
 */
interface UpdateTopicRequest {
  title?: string
  description?: string
  category?: string
  input_type?: 'topic' | 'verse' | 'question'
  input_value?: string
  tags?: string[]
  xp_value?: number
  is_active?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

/**
 * CSV import row
 */
interface CSVTopicRow {
  title: string
  description: string
  category: string
  input_type: 'topic' | 'verse' | 'question'
  input_value: string
  tags?: string
  xp_value?: string
  title_hi?: string
  description_hi?: string
  title_ml?: string
  description_ml?: string
}

/**
 * Bulk import result
 */
interface BulkImportResult {
  success_count: number
  error_count: number
  errors: Array<{ row: number; error: string }>
  created_topics: string[]
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
      // GET /admin-recommended-topics - List all topics
      const category = url.searchParams.get('category') || undefined
      const inputType = url.searchParams.get('input_type') as 'topic' | 'verse' | 'question' | undefined
      const isActive = url.searchParams.get('is_active')
      return await handleList(serviceClient, category, inputType, isActive)
    } else if (method === 'GET' && pathParts.length === 2) {
      // GET /admin-recommended-topics/:id - Get topic by ID
      const topicId = pathParts[1]
      return await handleGetById(serviceClient, topicId)
    } else if (method === 'POST' && pathParts.length === 1) {
      // POST /admin-recommended-topics - Create new topic
      const body = await req.json()
      return await handleCreate(serviceClient, body)
    } else if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'bulk-import') {
      // POST /admin-recommended-topics/bulk-import - Bulk import
      const body = await req.json()
      return await handleBulkImport(serviceClient, body.topics)
    } else if (method === 'PUT' && pathParts.length === 2) {
      // PUT /admin-recommended-topics/:id - Update topic
      const topicId = pathParts[1]
      const body = await req.json()
      return await handleUpdate(serviceClient, topicId, body)
    } else if (method === 'DELETE' && pathParts.length === 2) {
      // DELETE /admin-recommended-topics/:id - Delete topic
      const topicId = pathParts[1]
      return await handleDelete(serviceClient, topicId)
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
    console.error('Admin recommended topics error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Internal server error'
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

/**
 * List all topics with optional filtering and usage counts
 */
async function handleList(
  client: any,
  category?: string,
  inputType?: 'topic' | 'verse' | 'question',
  isActive?: string | null
): Promise<Response> {
  // Build query
  let query = client.from('recommended_topics').select('*').order('display_order', { ascending: true })

  if (category) {
    query = query.eq('category', category)
  }

  if (inputType) {
    query = query.eq('input_type', inputType)
  }

  if (isActive !== null && isActive !== undefined) {
    const activeValue = isActive === 'true'
    query = query.eq('is_active', activeValue)
  }

  const { data: topics, error: topicsError } = await query

  if (topicsError) {
    throw new Error(`Failed to fetch topics: ${topicsError.message}`)
  }

  // Fetch usage counts (how many learning paths use each topic)
  const { data: usageCounts, error: usageError } = await client
    .from('learning_path_topics')
    .select('topic_id, learning_path_id')

  if (usageError) {
    throw new Error(`Failed to fetch usage counts: ${usageError.message}`)
  }

  // Aggregate usage counts
  const usageMap: Record<string, number> = {}
  usageCounts?.forEach((u: any) => {
    usageMap[u.topic_id] = (usageMap[u.topic_id] || 0) + 1
  })

  // Combine data
  const topicsWithUsage = topics.map((topic: any) => ({
    ...topic,
    usage_count: usageMap[topic.id] || 0
  }))

  return new Response(
    JSON.stringify({ topics: topicsWithUsage }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Get topic by ID with translations and learning path usage
 */
async function handleGetById(client: any, topicId: string): Promise<Response> {
  // Fetch topic
  const { data: topic, error: topicError } = await client
    .from('recommended_topics')
    .select('*')
    .eq('id', topicId)
    .single()

  if (topicError) {
    if (topicError.code === 'PGRST116') {
      return new Response(
        JSON.stringify({ error: 'Topic not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }
    throw new Error(`Failed to fetch topic: ${topicError.message}`)
  }

  // Fetch translations
  const { data: translations, error: translationsError } = await client
    .from('recommended_topics_translations')
    .select('*')
    .eq('topic_id', topicId)

  if (translationsError) {
    throw new Error(`Failed to fetch translations: ${translationsError.message}`)
  }

  // Fetch learning paths using this topic
  const { data: pathUsage, error: pathUsageError } = await client
    .from('learning_path_topics')
    .select('learning_path_id, position, learning_paths(id, title)')
    .eq('topic_id', topicId)

  if (pathUsageError) {
    throw new Error(`Failed to fetch learning path usage: ${pathUsageError.message}`)
  }

  // Format response
  const translationsObj: Record<string, any> = {}
  translations?.forEach((t: any) => {
    translationsObj[t.language_code] = {
      title: t.title,
      description: t.description
    }
  })

  return new Response(
    JSON.stringify({
      topic: {
        ...topic,
        translations: translationsObj,
        used_in_paths: pathUsage?.map((p: any) => ({
          learning_path_id: p.learning_path_id,
          learning_path_title: p.learning_paths?.title,
          position: p.position
        })) || []
      }
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Create new topic with translations
 */
async function handleCreate(client: any, body: CreateTopicRequest): Promise<Response> {
  // Validate required fields
  if (!body.title || !body.description || !body.category || !body.input_type || !body.input_value) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Get max display_order
  const { data: maxOrder } = await client
    .from('recommended_topics')
    .select('display_order')
    .order('display_order', { ascending: false })
    .limit(1)
    .single()

  const displayOrder = (maxOrder?.display_order || 0) + 1

  // Create topic
  const { data: newTopic, error: createError } = await client
    .from('recommended_topics')
    .insert({
      title: body.title,
      description: body.description,
      category: body.category,
      input_type: body.input_type,
      input_value: body.input_value,
      tags: body.tags || [],
      xp_value: body.xp_value || 10,
      is_active: body.is_active ?? true,
      display_order: displayOrder
    })
    .select()
    .single()

  if (createError) {
    throw new Error(`Failed to create topic: ${createError.message}`)
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
        topic_id: newTopic.id,
        language_code: lang,
        title: trans.title,
        description: trans.description
      })
    }

    if (translationsToInsert.length > 0) {
      const { error: transError } = await client
        .from('recommended_topics_translations')
        .insert(translationsToInsert)

      if (transError) {
        console.error('Failed to create translations:', transError)
      }
    }
  }

  return new Response(
    JSON.stringify({ topic: newTopic }),
    {
      status: 201,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Update existing topic
 */
async function handleUpdate(client: any, topicId: string, body: UpdateTopicRequest): Promise<Response> {
  // Check if topic exists
  const { data: existing } = await client
    .from('recommended_topics')
    .select('id')
    .eq('id', topicId)
    .single()

  if (!existing) {
    return new Response(
      JSON.stringify({ error: 'Topic not found' }),
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
  if (body.category !== undefined) updates.category = body.category
  if (body.input_type !== undefined) updates.input_type = body.input_type
  if (body.input_value !== undefined) updates.input_value = body.input_value
  if (body.tags !== undefined) updates.tags = body.tags
  if (body.xp_value !== undefined) updates.xp_value = body.xp_value
  if (body.is_active !== undefined) updates.is_active = body.is_active

  // Update topic
  const { data: updatedTopic, error: updateError } = await client
    .from('recommended_topics')
    .update(updates)
    .eq('id', topicId)
    .select()
    .single()

  if (updateError) {
    throw new Error(`Failed to update topic: ${updateError.message}`)
  }

  // Update translations if provided
  if (body.translations) {
    const validLanguages = ['en', 'hi', 'ml']

    for (const [lang, trans] of Object.entries(body.translations)) {
      // Skip if language code is invalid or translation data is missing
      if (!validLanguages.includes(lang) || !trans || !trans.title || !trans.description) {
        continue
      }

      const { error: transError } = await client
        .from('recommended_topics_translations')
        .upsert({
          topic_id: topicId,
          language_code: lang,
          title: trans.title,
          description: trans.description
        }, {
          onConflict: 'topic_id,language_code'
        })

      if (transError) {
        console.error(`Failed to update ${lang} translation:`, transError)
      }
    }
  }

  return new Response(
    JSON.stringify({ topic: updatedTopic }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Delete topic with usage check
 */
async function handleDelete(client: any, topicId: string): Promise<Response> {
  // Check if topic exists
  const { data: existing } = await client
    .from('recommended_topics')
    .select('id, title')
    .eq('id', topicId)
    .single()

  if (!existing) {
    return new Response(
      JSON.stringify({ error: 'Topic not found' }),
      {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check if topic is used in any learning paths
  const { data: usage } = await client
    .from('learning_path_topics')
    .select('learning_path_id, learning_paths(title)')
    .eq('topic_id', topicId)

  if (usage && usage.length > 0) {
    const pathTitles = usage.map((u: any) => u.learning_paths?.title).filter(Boolean)
    return new Response(
      JSON.stringify({
        error: 'Cannot delete topic - it is used in learning paths',
        used_in_paths: pathTitles,
        usage_count: usage.length
      }),
      {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Delete topic (CASCADE will handle translations)
  const { error: deleteError } = await client
    .from('recommended_topics')
    .delete()
    .eq('id', topicId)

  if (deleteError) {
    throw new Error(`Failed to delete topic: ${deleteError.message}`)
  }

  return new Response(
    JSON.stringify({ message: 'Topic deleted successfully' }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Bulk import topics from CSV data
 */
async function handleBulkImport(client: any, csvRows: CSVTopicRow[]): Promise<Response> {
  if (!Array.isArray(csvRows) || csvRows.length === 0) {
    return new Response(
      JSON.stringify({ error: 'Invalid CSV data' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  const result: BulkImportResult = {
    success_count: 0,
    error_count: 0,
    errors: [],
    created_topics: []
  }

  // Get current max display_order
  const { data: maxOrder } = await client
    .from('recommended_topics')
    .select('display_order')
    .order('display_order', { ascending: false })
    .limit(1)
    .single()

  let currentDisplayOrder = (maxOrder?.display_order || 0) + 1

  // Process each row
  for (let i = 0; i < csvRows.length; i++) {
    const row = csvRows[i]
    const rowNumber = i + 1

    try {
      // Validate required fields
      if (!row.title || !row.description || !row.category || !row.input_type || !row.input_value) {
        throw new Error('Missing required fields')
      }

      // Validate input_type
      if (!['topic', 'verse', 'question'].includes(row.input_type)) {
        throw new Error('Invalid input_type')
      }

      // Parse tags
      const tags = row.tags ? row.tags.split(',').map((t: string) => t.trim()) : []

      // Parse xp_value
      const xpValue = row.xp_value ? parseInt(row.xp_value) : 10

      // Create topic
      const { data: newTopic, error: createError } = await client
        .from('recommended_topics')
        .insert({
          title: row.title,
          description: row.description,
          category: row.category,
          input_type: row.input_type,
          input_value: row.input_value,
          tags: tags,
          xp_value: xpValue,
          is_active: true,
          display_order: currentDisplayOrder++
        })
        .select()
        .single()

      if (createError) {
        throw new Error(createError.message)
      }

      // Create translations if provided
      const translationsToInsert = []

      if (row.title_hi && row.description_hi) {
        translationsToInsert.push({
          topic_id: newTopic.id,
          language_code: 'hi',
          title: row.title_hi,
          description: row.description_hi
        })
      }

      if (row.title_ml && row.description_ml) {
        translationsToInsert.push({
          topic_id: newTopic.id,
          language_code: 'ml',
          title: row.title_ml,
          description: row.description_ml
        })
      }

      if (translationsToInsert.length > 0) {
        await client.from('recommended_topics_translations').insert(translationsToInsert)
      }

      result.success_count++
      result.created_topics.push(newTopic.id)
    } catch (error: unknown) {
      result.error_count++
      result.errors.push({
        row: rowNumber,
        error: error instanceof Error ? error.message : 'Unknown error'
      })
    }
  }

  return new Response(
    JSON.stringify(result),
    {
      status: result.error_count > 0 ? 207 : 201, // 207 Multi-Status if some failed
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}
