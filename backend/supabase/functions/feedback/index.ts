/**
 * Simplified Feedback Edge Function (for testing without LLM dependencies)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'

interface FeedbackRequest {
  readonly study_guide_id?: string
  readonly was_helpful: boolean
  readonly message?: string
  readonly category?: string
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

async function handleFeedback(req: Request): Promise<Response> {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ success: false, error: 'Method not allowed' }), 
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // TODO: Use user context for user id: authService.getUserContext(req)
  try {
    // Parse request body
    let requestBody: any
    const bodyText = await req.text()
    console.log('Raw request body:', bodyText)
    
    try {
      requestBody = JSON.parse(bodyText)
      console.log('Parsed JSON:', requestBody)
    } catch (error) {
      console.error('JSON parse error:', error)
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid JSON in request body', debug: bodyText }), 
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate required fields
    if (typeof requestBody.was_helpful !== 'boolean') {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'was_helpful field is required and must be a boolean' 
        }), 
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Optional validation for study_guide_id
    if (requestBody.study_guide_id && typeof requestBody.study_guide_id !== 'string') {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'study_guide_id must be a string' 
        }), 
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Insert feedback into database
    const { data, error } = await supabase
      .from('feedback')
      .insert({
        study_guide_id: requestBody.study_guide_id || null,
        was_helpful: requestBody.was_helpful,
        message: requestBody.message || null,
        category: requestBody.category || 'general',
        user_id: null, // Use null for anonymous users instead of a string
        created_at: new Date().toISOString()
      })
      .select()
      .single()

    if (error) {
      console.error('Database error:', error)
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Failed to save feedback' 
        }), 
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          id: data.id,
          was_helpful: data.was_helpful,
          message: data.message,
          category: data.category,
          created_at: data.created_at
        },
        message: 'Thank you for your feedback!'
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: 'Internal server error' 
      }), 
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
}

Deno.serve(handleFeedback)