/**
 * Admin Study Modifier Edge Function
 *
 * Allows admins to modify existing study guide content.
 *
 * Supported Operations:
 * - GET /admin-study-modifier/:id - Load existing study guide for editing
 * - PUT /admin-study-modifier/:id - Update study guide content
 *
 * Update Options:
 * - update_cache: true (default) - Update the existing cached study guide
 * - update_cache: false - Create a new version (useful for A/B testing)
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS'
}

/**
 * Study guide content interface
 */
interface StudyGuideContent {
  summary?: string
  context?: string
  interpretation?: string
  passage?: string | null
  relatedVerses?: Array<{ reference: string; text: string }>
  reflectionQuestions?: string[]
  prayerPoints?: string[]
  interpretationInsights?: string[]
  summaryInsights?: string[]
  reflectionAnswers?: string[]
  contextQuestion?: string
  summaryQuestion?: string
  relatedVersesQuestion?: string
  reflectionQuestion?: string
  prayerQuestion?: string
}

/**
 * Request body for updating study guide
 */
interface UpdateStudyGuideRequest {
  content: StudyGuideContent
  update_cache?: boolean // Default true
  notes?: string // Optional admin notes about the changes
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
    if (method === 'GET' && pathParts.length === 2) {
      // GET /admin-study-modifier/:id - Load study guide
      const guideId = pathParts[1]
      return await handleLoad(serviceClient, guideId)
    } else if (method === 'PUT' && pathParts.length === 2) {
      // PUT /admin-study-modifier/:id - Update study guide
      const guideId = pathParts[1]
      const body = await req.json()
      return await handleUpdate(serviceClient, guideId, body, user.id)
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
    console.error('Admin study modifier error:', error)
    const errorMessage = error instanceof Error ? error.message : 'Internal server error'
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

/**
 * Load existing study guide for editing
 */
async function handleLoad(client: any, guideId: string): Promise<Response> {
  // Fetch study guide
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

  // Format response with all editable fields
  const editableGuide = {
    id: guide.id,
    input_type: guide.input_type,
    input_value: guide.input_value,
    input_value_display: guide.input_value_display,
    language: guide.language,
    study_mode: guide.study_mode,
    content: {
      summary: guide.summary,
      context: guide.context,
      interpretation: guide.interpretation,
      passage: guide.passage,
      relatedVerses: guide.related_verses,
      reflectionQuestions: guide.reflection_questions,
      prayerPoints: guide.prayer_points,
      interpretationInsights: guide.interpretation_insights,
      summaryInsights: guide.summary_insights,
      reflectionAnswers: guide.reflection_answers,
      contextQuestion: guide.context_question,
      summaryQuestion: guide.summary_question,
      relatedVersesQuestion: guide.related_verses_question,
      reflectionQuestion: guide.reflection_question,
      prayerQuestion: guide.prayer_question
    },
    creator_user_id: guide.creator_user_id,
    creator_session_id: guide.creator_session_id,
    created_at: guide.created_at,
    updated_at: guide.updated_at
  }

  return new Response(
    JSON.stringify({ study_guide: editableGuide }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/**
 * Update study guide content
 */
async function handleUpdate(
  client: any,
  guideId: string,
  body: UpdateStudyGuideRequest,
  adminUserId: string
): Promise<Response> {
  // Validate request
  if (!body.content) {
    return new Response(
      JSON.stringify({ error: 'Missing content field' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Check if study guide exists
  const { data: existing, error: existingError } = await client
    .from('study_guides')
    .select('id, input_type, input_value, language, study_mode')
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

  const updateCache = body.update_cache !== false // Default to true

  if (updateCache) {
    // UPDATE EXISTING CACHE
    console.log('📝 [ADMIN-MODIFY] Updating existing study guide:', guideId)

    // Build update object with only provided fields
    const updates: Record<string, any> = {}

    if (body.content.summary !== undefined) updates.summary = body.content.summary
    if (body.content.context !== undefined) updates.context = body.content.context
    if (body.content.interpretation !== undefined) updates.interpretation = body.content.interpretation
    if (body.content.passage !== undefined) updates.passage = body.content.passage
    if (body.content.relatedVerses !== undefined) updates.related_verses = body.content.relatedVerses
    if (body.content.reflectionQuestions !== undefined) updates.reflection_questions = body.content.reflectionQuestions
    if (body.content.prayerPoints !== undefined) updates.prayer_points = body.content.prayerPoints
    if (body.content.interpretationInsights !== undefined) updates.interpretation_insights = body.content.interpretationInsights
    if (body.content.summaryInsights !== undefined) updates.summary_insights = body.content.summaryInsights
    if (body.content.reflectionAnswers !== undefined) updates.reflection_answers = body.content.reflectionAnswers
    if (body.content.contextQuestion !== undefined) updates.context_question = body.content.contextQuestion
    if (body.content.summaryQuestion !== undefined) updates.summary_question = body.content.summaryQuestion
    if (body.content.relatedVersesQuestion !== undefined) updates.related_verses_question = body.content.relatedVersesQuestion
    if (body.content.reflectionQuestion !== undefined) updates.reflection_question = body.content.reflectionQuestion
    if (body.content.prayerQuestion !== undefined) updates.prayer_question = body.content.prayerQuestion

    // Update the study guide
    const { data: updated, error: updateError } = await client
      .from('study_guides')
      .update(updates)
      .eq('id', guideId)
      .select()
      .single()

    if (updateError) {
      throw new Error(`Failed to update study guide: ${updateError.message}`)
    }

    // Log modification
    await logModification(client, guideId, adminUserId, 'update', body.notes)

    return new Response(
      JSON.stringify({
        message: 'Study guide updated successfully',
        study_guide: updated,
        version_type: 'cache_updated'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } else {
    // CREATE NEW VERSION
    console.log('🆕 [ADMIN-MODIFY] Creating new version of study guide')

    // Create new study guide with modified content
    const { data: newVersion, error: createError } = await client
      .from('study_guides')
      .insert({
        input_type: existing.input_type,
        input_value: existing.input_value,
        language: existing.language,
        study_mode: existing.study_mode,
        summary: body.content.summary,
        context: body.content.context,
        interpretation: body.content.interpretation,
        passage: body.content.passage,
        related_verses: body.content.relatedVerses,
        reflection_questions: body.content.reflectionQuestions,
        prayer_points: body.content.prayerPoints,
        interpretation_insights: body.content.interpretationInsights,
        summary_insights: body.content.summaryInsights,
        reflection_answers: body.content.reflectionAnswers,
        context_question: body.content.contextQuestion,
        summary_question: body.content.summaryQuestion,
        related_verses_question: body.content.relatedVersesQuestion,
        reflection_question: body.content.reflectionQuestion,
        prayer_question: body.content.prayerQuestion,
        creator_user_id: adminUserId // Admin is creator of new version
      })
      .select()
      .single()

    if (createError) {
      throw new Error(`Failed to create new version: ${createError.message}`)
    }

    // Log modification
    await logModification(client, newVersion.id, adminUserId, 'new_version', body.notes)

    return new Response(
      JSON.stringify({
        message: 'New study guide version created successfully',
        study_guide: newVersion,
        version_type: 'new_version',
        original_guide_id: guideId
      }),
      {
        status: 201,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
}

/**
 * Log modification to audit trail (optional - could create a modifications table)
 */
async function logModification(
  client: any,
  guideId: string,
  adminUserId: string,
  modificationType: 'update' | 'new_version',
  notes?: string
): Promise<void> {
  try {
    // This could be expanded to write to an audit log table
    console.log('📋 [ADMIN-MODIFY] Modification logged:', {
      guide_id: guideId,
      admin_user_id: adminUserId,
      modification_type: modificationType,
      notes: notes || 'No notes provided',
      timestamp: new Date().toISOString()
    })

    // Future: Create audit_log table and insert record
    // await client.from('study_guide_modifications').insert({
    //   study_guide_id: guideId,
    //   admin_user_id: adminUserId,
    //   modification_type: modificationType,
    //   notes: notes
    // })
  } catch (error) {
    console.error('⚠️ [ADMIN-MODIFY] Failed to log modification:', error)
    // Don't throw - logging failure shouldn't block the modification
  }
}
