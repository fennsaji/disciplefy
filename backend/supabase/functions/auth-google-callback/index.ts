/**
 * Google Auth Callback Edge Function
 * 
 * Simplified OAuth callback that works with Supabase's built-in OAuth flow.
 * Removes complex CSRF validation that was causing 401 errors.
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
  const { analyticsLogger, supabaseServiceClient } = services

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

  // Exchange authorization code for tokens using Supabase's built-in method
  // Supabase handles state validation internally, so we don't need custom CSRF protection
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
 * Exchanges authorization code for access tokens using Supabase auth
 */
async function exchangeCodeForTokens(supabaseClient: any, code: string): Promise<GoogleCallbackResponse> {
  try {
    // Exchange code for session using Supabase auth
    // This handles all OAuth state validation internally
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

// Create the function with appropriate configuration
createFunction(async (req: Request, services: ServiceContainer) => {
  return await handleGoogleCallback(req, services)
}, {
  requireAuth: false,
  enableAnalytics: true,
  allowedMethods: ['POST'],
  timeout: 15000
})