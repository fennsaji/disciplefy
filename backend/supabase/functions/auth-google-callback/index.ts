/**
 * Google Auth Callback Edge Function
 * 
 * Refactored according to security guide to implement proper CSRF protection
 * and use centralized services.
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse } from '../_shared/types/index.ts'

/**
 * Google callback request payload
 */
interface GoogleCallbackRequest {
  readonly code: string
  readonly state?: string
  readonly error?: string
  readonly error_description?: string
}

/**
 * Google callback response data
 */
interface GoogleCallbackResponse {
  readonly session?: {
    readonly access_token: string
    readonly refresh_token: string
    readonly expires_in: number
    readonly user: {
      readonly id: string
      readonly email: string
      readonly email_verified: boolean
      readonly name: string
      readonly picture: string
      readonly provider: string
    }
  }
  readonly error?: string
}

/**
 * Complete API response structure
 */
interface GoogleCallbackApiResponse extends ApiSuccessResponse<GoogleCallbackResponse> {}

/**
 * Main handler for Google auth callback
 */
async function handleGoogleCallback(req: Request, services: ServiceContainer): Promise<Response> {
  const { authService, securityValidator, analyticsLogger, supabaseServiceClient } = services
  // Parse request body
  let requestData: GoogleCallbackRequest
  try {
    requestData = await req.json()
  } catch (error) {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400)
  }

  // Check for OAuth error
  if (requestData.error) {
    throw new AppError(
      'AUTHENTICATION_ERROR',
      `OAuth error: ${requestData.error_description || requestData.error}`,
      401
    )
  }

  // Validate authorization code
  if (!requestData.code) {
    throw new AppError('VALIDATION_ERROR', 'Authorization code is required', 400)
  }

  // Proper CSRF protection - validate state parameter (required)
  if (!requestData.state) {
    throw new AppError('SECURITY_VIOLATION', 'State parameter is required for CSRF protection', 400)
  }
  await validateStateParameter(requestData.state, { ...securityValidator, supabaseClient: supabaseServiceClient })

  // Exchange authorization code for tokens
  const sessionData = await exchangeCodeForTokens(supabaseServiceClient, requestData.code)

  // Log analytics
  await analyticsLogger.logEvent('google_auth_callback_success', {
    user_id: sessionData.session?.user.id,
    email_verified: sessionData.session?.user.email_verified,
    provider: 'google'
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: GoogleCallbackApiResponse = {
    success: true,
    data: sessionData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Validates OAuth state parameter for proper CSRF protection
 * 
 * This implements complete CSRF protection by validating the state parameter
 * against a securely stored value in the database.
 */
async function validateStateParameter(state: string, securityValidator: any): Promise<void> {
  // First, validate the state parameter format for security
  const securityResult = await securityValidator.validateInput(state, 'oauth_state')
  
  if (!securityResult.isValid) {
    throw new AppError('SECURITY_VIOLATION', 'Invalid state parameter format', 400)
  }

  // Basic format validation
  if (!state || state.length < 16) {
    throw new AppError('SECURITY_VIOLATION', 'State parameter too short or missing', 400)
  }

  // Validate state is a valid UUID or random string
  const statePattern = /^[a-zA-Z0-9_-]{16,128}$/
  if (!statePattern.test(state)) {
    throw new AppError('SECURITY_VIOLATION', 'Invalid state parameter format', 400)
  }

  // Retrieve and validate the stored state from database
  const { data: storedState, error } = await securityValidator.supabaseClient
    .from('oauth_states')
    .select('state, created_at, used')
    .eq('state', state)
    .eq('used', false)
    .single()

  if (error || !storedState) {
    throw new AppError('SECURITY_VIOLATION', 'Invalid or expired state parameter', 400)
  }

  // Check if state has expired (15 minutes)
  const stateAge = Date.now() - new Date(storedState.created_at).getTime()
  const maxAge = 15 * 60 * 1000 // 15 minutes in milliseconds
  
  if (stateAge > maxAge) {
    // Clean up expired state
    await securityValidator.supabaseClient
      .from('oauth_states')
      .delete()
      .eq('state', state)
    
    throw new AppError('SECURITY_VIOLATION', 'State parameter has expired', 400)
  }

  // Perform constant-time comparison to prevent timing attacks
  if (!constantTimeEquals(state, storedState.state)) {
    throw new AppError('SECURITY_VIOLATION', 'State parameter mismatch', 400)
  }

  // Mark state as used to prevent reuse
  const { error: updateError } = await securityValidator.supabaseClient
    .from('oauth_states')
    .update({ used: true, used_at: new Date().toISOString() })
    .eq('state', state)

  if (updateError) {
    console.error('Failed to mark OAuth state as used:', updateError)
    // Don't fail the request for this, but log it
  }
}

/**
 * Constant-time string comparison to prevent timing attacks
 */
function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false
  }
  
  let result = 0
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  
  return result === 0
}

/**
 * Exchanges authorization code for access tokens
 */
async function exchangeCodeForTokens(supabaseClient: any, code: string): Promise<GoogleCallbackResponse> {
  try {
    // Exchange code for session using Supabase auth
    const { data, error } = await supabaseClient.auth.exchangeCodeForSession(code)

    if (error) {
      throw new AppError('AUTHENTICATION_ERROR', `Failed to exchange code: ${error.message}`, 401)
    }

    if (!data.session || !data.user) {
      throw new AppError('AUTHENTICATION_ERROR', 'No session or user data returned', 401)
    }

    return {
      session: {
        access_token: data.session.access_token,
        refresh_token: data.session.refresh_token,
        expires_in: data.session.expires_in || 3600,
        user: {
          id: data.user.id,
          email: data.user.email || '',
          email_verified: data.user.email_confirmed_at ? true : false,
          name: data.user.user_metadata?.name || data.user.user_metadata?.full_name || '',
          picture: data.user.user_metadata?.avatar_url || data.user.user_metadata?.picture || '',
          provider: data.user.app_metadata?.provider || 'google'
        }
      }
    }
  } catch (error) {
    if (error instanceof AppError) {
      throw error
    }
    const errorMessage = error instanceof Error ? error.message : 'Unknown authentication error'
    throw new AppError('AUTHENTICATION_ERROR', `Authentication failed: ${errorMessage}`, 401)
  }
}

// Wrap the handler in the factory
createFunction(async (req: Request, services: ServiceContainer) => {
  return await handleGoogleCallback(req, services)
}, {
  requireAuth: false,
  enableAnalytics: true,
  allowedMethods: ['POST'],
  timeout: 15000
})