import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'

interface SessionRequest {
  action: 'create_anonymous' | 'migrate_to_authenticated'
  device_fingerprint?: string
  anonymous_session_id?: string
}

interface SessionResponse {
  session_id: string
  expires_at: string
  is_anonymous: boolean
  migration_successful?: boolean
}

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      throw new AppError('METHOD_NOT_ALLOWED', 'Only POST requests are allowed', 405)
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Parse request body
    const requestBody: SessionRequest = await req.json()
    
    if (!requestBody.action) {
      throw new AppError('INVALID_REQUEST', 'action field is required')
    }

    let response: SessionResponse

    if (requestBody.action === 'create_anonymous') {
      response = await createAnonymousSession(supabaseClient, requestBody, req)
    } else if (requestBody.action === 'migrate_to_authenticated') {
      response = await migrateToAuthenticated(supabaseClient, requestBody, req)
    } else {
      throw new AppError('INVALID_REQUEST', 'Invalid action. Use "create_anonymous" or "migrate_to_authenticated"')
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: response
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

async function createAnonymousSession(
  supabaseClient: any, 
  requestBody: SessionRequest, 
  req: Request
): Promise<SessionResponse> {
  
  // Create device fingerprint hash for privacy
  const deviceFingerprint = requestBody.device_fingerprint || 'unknown'
  const ipAddress = req.headers.get('x-forwarded-for') || 'unknown'
  
  // Hash sensitive data
  const deviceHash = await hashData(deviceFingerprint)
  const ipHash = await hashData(ipAddress)

  // Create anonymous session
  const { data: session, error } = await supabaseClient
    .from('anonymous_sessions')
    .insert({
      device_fingerprint_hash: deviceHash,
      ip_address_hash: ipHash,
      created_at: new Date().toISOString(),
      last_activity: new Date().toISOString(),
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 24 hours
      study_guides_count: 0,
      jeff_reed_sessions_count: 0
    })
    .select()
    .single()

  if (error) {
    console.error('Anonymous session creation error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to create anonymous session')
  }

  // Log analytics event
  await supabaseClient
    .from('analytics_events')
    .insert({
      event_type: 'anonymous_session_created',
      event_data: {
        device_fingerprint_provided: !!requestBody.device_fingerprint
      },
      session_id: session.session_id,
      ip_address: req.headers.get('x-forwarded-for')
    })

  return {
    session_id: session.session_id,
    expires_at: session.expires_at,
    is_anonymous: true
  }
}

async function migrateToAuthenticated(
  supabaseClient: any, 
  requestBody: SessionRequest, 
  req: Request
): Promise<SessionResponse> {
  
  if (!requestBody.anonymous_session_id) {
    throw new AppError('INVALID_REQUEST', 'anonymous_session_id is required for migration')
  }

  // Get the current authenticated user
  const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
  
  if (userError || !user) {
    throw new AppError('UNAUTHORIZED', 'User must be authenticated to migrate session')
  }

  // Get the anonymous session
  const { data: anonymousSession, error: sessionError } = await supabaseClient
    .from('anonymous_sessions')
    .select('*')
    .eq('session_id', requestBody.anonymous_session_id)
    .single()

  if (sessionError || !anonymousSession) {
    throw new AppError('NOT_FOUND', 'Anonymous session not found')
  }

  // Check if session has expired
  if (new Date(anonymousSession.expires_at) < new Date()) {
    throw new AppError('SESSION_EXPIRED', 'Anonymous session has expired')
  }

  // Migrate anonymous study guides to authenticated user
  const { error: migrateStudyGuidesError } = await supabaseClient
    .from('anonymous_study_guides')
    .select('*')
    .eq('session_id', requestBody.anonymous_session_id)
    .then(async ({ data: guides }) => {
      if (guides && guides.length > 0) {
        // Transform anonymous guides to authenticated guides
        const authenticatedGuides = guides.map(guide => ({
          user_id: user.id,
          input_type: guide.input_type,
          input_value: 'migrated_from_anonymous', // Don't store original value for privacy
          summary: guide.summary,
          context: guide.context,
          related_verses: guide.related_verses,
          reflection_questions: guide.reflection_questions,
          prayer_points: guide.prayer_points,
          language: guide.language,
          is_saved: true,
          created_at: guide.created_at
        }))

        return await supabaseClient
          .from('study_guides')
          .insert(authenticatedGuides)
      }
      return { error: null }
    })

  if (migrateStudyGuidesError) {
    console.error('Study guides migration error:', migrateStudyGuidesError)
    throw new AppError('MIGRATION_ERROR', 'Failed to migrate study guides')
  }

  // Mark anonymous session as migrated
  await supabaseClient
    .from('anonymous_sessions')
    .update({ 
      is_migrated: true,
      last_activity: new Date().toISOString()
    })
    .eq('session_id', requestBody.anonymous_session_id)

  // Log analytics event
  await supabaseClient
    .from('analytics_events')
    .insert({
      user_id: user.id,
      event_type: 'anonymous_session_migrated',
      event_data: {
        original_session_id: requestBody.anonymous_session_id,
        study_guides_migrated: anonymousSession.study_guides_count
      },
      session_id: requestBody.anonymous_session_id,
      ip_address: req.headers.get('x-forwarded-for')
    })

  return {
    session_id: user.id, // Use user ID as the new session identifier
    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    is_anonymous: false,
    migration_successful: true
  }
}

async function hashData(data: string): Promise<string> {
  const encoder = new TextEncoder()
  const dataBytes = encoder.encode(data)
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBytes)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}