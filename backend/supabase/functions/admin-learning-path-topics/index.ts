/**
 * Admin Learning Path Topics Management Edge Function
 *
 * Manages the association between learning paths and recommended topics.
 *
 * Supported Operations:
 * - POST /admin-learning-path-topics - Add topic to learning path
 * - DELETE /admin-learning-path-topics - Remove topic from learning path
 * - PATCH /admin-learning-path-topics/reorder - Reorder topics in path
 * - PATCH /admin-learning-path-topics/:pathId/:topicId/milestone - Toggle milestone flag
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, PATCH, OPTIONS'
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
    // Create Supabase client for authentication
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! }
        }
      }
    )

    // Verify authentication
    const {
      data: { user },
      error: authError
    } = await supabaseClient.auth.getUser()

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Verify admin status
    const { data: profile, error: profileError } = await supabaseClient
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (profileError || !profile?.is_admin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden - Admin access required' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Create service role client for admin operations
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse URL and method
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)
    const method = req.method

    // Route to appropriate handler
    if (method === 'POST' && pathParts.length === 1) {
      // POST /admin-learning-path-topics - Add topic to path
      const body = await req.json()
      return await handleAddTopic(serviceClient, body)
    } else if (method === 'DELETE' && pathParts.length === 1) {
      // DELETE /admin-learning-path-topics - Remove topic from path
      const body = await req.json()
      return await handleRemoveTopic(serviceClient, body)
    } else if (method === 'PATCH' && pathParts.length === 2 && pathParts[1] === 'reorder') {
      // PATCH /admin-learning-path-topics/reorder - Reorder topics
      const body = await req.json()
      return await handleReorder(serviceClient, body)
    } else if (method === 'PATCH' && pathParts.length === 4 && pathParts[3] === 'milestone') {
      // PATCH /admin-learning-path-topics/:pathId/:topicId/milestone - Toggle milestone
      const pathId = pathParts[1]
      const topicId = pathParts[2]
      const body = await req.json()
      return await handleToggleMilestone(serviceClient, pathId, topicId, body.is_milestone)
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
    console.error('Admin learning path topics error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Internal server error'
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

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
async function handleReorder(client: any, body: ReorderTopicsRequest): Promise<Response> {
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
