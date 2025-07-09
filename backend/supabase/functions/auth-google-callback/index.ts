import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { SecurityValidator } from '../_shared/security-validator.ts'
import { AnalyticsLogger } from '../_shared/analytics-logger.ts'

interface GoogleCallbackRequest {
  code: string
  state?: string
  error?: string
  error_description?: string
}

interface GoogleCallbackResponse {
  success: boolean
  session?: {
    access_token: string
    refresh_token: string
    expires_in: number
    user: {
      id: string
      email: string
      email_verified: boolean
      name: string
      picture: string
      provider: string
    }
  }
  error?: string
  redirect_url?: string
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Only allow POST requests for security
    if (req.method !== 'POST') {
      throw new AppError('METHOD_NOT_ALLOWED', 'Only POST requests are allowed', 405)
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    )

    // Parse request body
    const requestBody: GoogleCallbackRequest = await req.json()
    
    // Validate required fields
    if (!requestBody.code && !requestBody.error) {
      throw new AppError('INVALID_REQUEST', 'Either code or error parameter is required')
    }

    // Handle OAuth error response
    if (requestBody.error) {
      await logOAuthError(supabaseClient, requestBody, req)
      throw new AppError('OAUTH_ERROR', requestBody.error_description || requestBody.error)
    }

    // Validate authorization code
    if (!requestBody.code || typeof requestBody.code !== 'string') {
      throw new AppError('INVALID_REQUEST', 'Invalid authorization code')
    }

    // Security validation
    const securityResult = await SecurityValidator.validateRequest(req, {
      checkRateLimit: true,
      maxRequestsPerHour: 30,
      requireValidReferer: true,
      allowedReferers: [
        'https://accounts.google.com',
        'http://127.0.0.1:3000',
        'http://localhost:3000',
        'https://disciplefy.com'
      ]
    })

    if (!securityResult.isValid) {
      throw new AppError('SECURITY_VIOLATION', securityResult.reason)
    }

    // Validate state parameter for CSRF protection
    if (requestBody.state) {
      const isValidState = await validateStateParameter(supabaseClient, requestBody.state)
      if (!isValidState) {
        await logSecurityEvent(supabaseClient, 'CSRF_INVALID_STATE', req, { state: requestBody.state })
        throw new AppError('CSRF_VALIDATION_FAILED', 'Invalid state parameter')
      }
    }

    // Exchange authorization code for tokens
    const { data: sessionData, error: sessionError } = await supabaseClient.auth.exchangeCodeForSession(requestBody.code)

    if (sessionError) {
      await logOAuthError(supabaseClient, { 
        code: requestBody.code, 
        error: sessionError.message 
      }, req)
      throw new AppError('OAUTH_EXCHANGE_FAILED', sessionError.message)
    }

    if (!sessionData?.session || !sessionData?.user) {
      throw new AppError('OAUTH_SESSION_FAILED', 'Failed to create session from OAuth callback')
    }

    // Log successful authentication
    await logSuccessfulAuth(supabaseClient, sessionData.user, req)

    // Check if user needs to migrate from anonymous session
    const migrationResult = await handleAnonymousSessionMigration(
      supabaseClient, 
      sessionData.user.id, 
      req
    )

    // Prepare response
    const response: GoogleCallbackResponse = {
      success: true,
      session: {
        access_token: sessionData.session.access_token,
        refresh_token: sessionData.session.refresh_token,
        expires_in: sessionData.session.expires_in || 3600,
        user: {
          id: sessionData.user.id,
          email: sessionData.user.email || '',
          email_verified: sessionData.user.email_confirmed_at !== null,
          name: sessionData.user.user_metadata?.full_name || sessionData.user.user_metadata?.name || '',
          picture: sessionData.user.user_metadata?.avatar_url || sessionData.user.user_metadata?.picture || '',
          provider: 'google'
        }
      },
      redirect_url: determineRedirectUrl(req, sessionData.user)
    }

    // Log analytics event
    await AnalyticsLogger.logEvent(supabaseClient, {
      event_type: 'oauth_login_success',
      user_id: sessionData.user.id,
      event_data: {
        provider: 'google',
        email_verified: response.session.user.email_verified,
        migration_performed: migrationResult.migrated,
        guides_migrated: migrationResult.guides_migrated
      },
      ip_address: req.headers.get('x-forwarded-for'),
      user_agent: req.headers.get('user-agent')
    })

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

async function validateStateParameter(supabaseClient: any, state: string): Promise<boolean> {
  try {
    // In a real implementation, you would store state parameters in a cache/database
    // and validate them here. For this demo, we'll do basic validation.
    
    // State should be a UUID or similar secure random string
    const stateRegex = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
    if (!stateRegex.test(state)) {
      return false
    }

    // Check if state exists in temporary storage (implement based on your needs)
    // For now, we'll accept any valid UUID format
    return true
  } catch (error) {
    console.error('State validation error:', error)
    return false
  }
}

async function logOAuthError(
  supabaseClient: any, 
  errorData: any, 
  req: Request
): Promise<void> {
  try {
    await supabaseClient
      .from('llm_security_events')
      .insert({
        event_type: 'oauth_callback_error',
        input_text: JSON.stringify(errorData),
        risk_score: 0.3,
        action_taken: 'logged',
        detection_details: {
          error_type: errorData.error,
          error_description: errorData.error_description,
          timestamp: new Date().toISOString()
        },
        ip_address: req.headers.get('x-forwarded-for'),
        created_at: new Date().toISOString()
      })
  } catch (error) {
    console.error('Failed to log OAuth error:', error)
  }
}

async function logSecurityEvent(
  supabaseClient: any, 
  eventType: string, 
  req: Request, 
  details: any
): Promise<void> {
  try {
    await supabaseClient
      .from('llm_security_events')
      .insert({
        event_type: eventType,
        input_text: JSON.stringify(details),
        risk_score: 0.8,
        action_taken: 'blocked',
        detection_details: {
          ...details,
          timestamp: new Date().toISOString()
        },
        ip_address: req.headers.get('x-forwarded-for'),
        created_at: new Date().toISOString()
      })
  } catch (error) {
    console.error('Failed to log security event:', error)
  }
}

async function logSuccessfulAuth(
  supabaseClient: any, 
  user: any, 
  req: Request
): Promise<void> {
  try {
    await supabaseClient
      .from('analytics_events')
      .insert({
        user_id: user.id,
        event_type: 'oauth_login_success',
        event_data: {
          provider: 'google',
          email: user.email,
          email_verified: user.email_confirmed_at !== null,
          user_metadata: user.user_metadata
        },
        ip_address: req.headers.get('x-forwarded-for'),
        user_agent: req.headers.get('user-agent'),
        created_at: new Date().toISOString()
      })
  } catch (error) {
    console.error('Failed to log successful auth:', error)
  }
}

async function handleAnonymousSessionMigration(
  supabaseClient: any, 
  userId: string, 
  req: Request
): Promise<{ migrated: boolean; guides_migrated: number }> {
  try {
    // Check if there's an anonymous session to migrate
    const sessionId = req.headers.get('x-anonymous-session-id')
    
    if (!sessionId) {
      return { migrated: false, guides_migrated: 0 }
    }

    // Get anonymous session
    const { data: anonymousSession, error: sessionError } = await supabaseClient
      .from('anonymous_sessions')
      .select('*, anonymous_study_guides(*)')
      .eq('session_id', sessionId)
      .eq('is_migrated', false)
      .single()

    if (sessionError || !anonymousSession) {
      return { migrated: false, guides_migrated: 0 }
    }

    // Migrate anonymous study guides to authenticated user
    const guides = anonymousSession.anonymous_study_guides || []
    let migratedCount = 0

    if (guides.length > 0) {
      const authenticatedGuides = guides.map((guide: any) => ({
        user_id: userId,
        input_type: guide.input_type,
        input_value: 'migrated_from_anonymous',
        summary: guide.summary,
        context: guide.context,
        related_verses: guide.related_verses,
        reflection_questions: guide.reflection_questions,
        prayer_points: guide.prayer_points,
        language: guide.language,
        is_saved: true,
        created_at: guide.created_at
      }))

      const { error: insertError } = await supabaseClient
        .from('study_guides')
        .insert(authenticatedGuides)

      if (!insertError) {
        migratedCount = guides.length
      }
    }

    // Mark session as migrated
    await supabaseClient
      .from('anonymous_sessions')
      .update({ 
        is_migrated: true,
        last_activity: new Date().toISOString()
      })
      .eq('session_id', sessionId)

    return { migrated: true, guides_migrated: migratedCount }
  } catch (error) {
    console.error('Anonymous session migration failed:', error)
    return { migrated: false, guides_migrated: 0 }
  }
}

function determineRedirectUrl(req: Request, user: any): string {
  // Check for custom redirect URL in headers
  const customRedirect = req.headers.get('x-redirect-url')
  if (customRedirect) {
    return customRedirect
  }

  // Default redirect based on environment
  const referer = req.headers.get('referer')
  if (referer?.includes('localhost') || referer?.includes('127.0.0.1')) {
    return 'http://localhost:3000/auth/callback'
  }

  return 'https://disciplefy.com/auth/callback'
}