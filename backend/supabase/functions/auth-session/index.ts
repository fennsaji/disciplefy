/**
 * Auth Session Edge Function
 * 
 * Refactored to use the new clean architecture with:
 * - Function factory for boilerplate elimination
 * - Singleton services for performance
 * - Clean separation of concerns
 */

import { createFunction, FunctionHandler } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Session request payload
 */
interface SessionRequest {
  readonly action: 'create_anonymous' | 'migrate_to_authenticated'
  readonly device_fingerprint?: string
  readonly anonymous_session_id?: string
}

/**
 * Session response data
 */
interface SessionResponse {
  readonly session_id: string
  readonly expires_at: string
  readonly is_anonymous: boolean
  readonly migration_successful?: boolean
}

/**
 * Complete API response structure
 */
interface SessionApiResponse extends ApiSuccessResponse<SessionResponse> {}

/**
 * Main handler for auth session operations
 */
async function handleAuthSession(req: Request, services: ServiceContainer, userContext?: UserContext): Promise<Response> {
  // Parse request body
  let requestData: SessionRequest
  try {
    requestData = await req.json()
  } catch (error) {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400)
  }

  // Validate request
  validateSessionRequest(requestData)

  let sessionData: SessionResponse

  if (requestData.action === 'create_anonymous') {
    sessionData = await createAnonymousSession(services, requestData.device_fingerprint)
  } else if (requestData.action === 'migrate_to_authenticated') {
    // Require authentication for migration
    if (!userContext || !userContext.userId) {
      throw new AppError('AUTHENTICATION_ERROR', 'Authentication required for session migration', 401)
    }
    sessionData = await migrateToAuthenticated(services, requestData.anonymous_session_id!, userContext)
  } else {
    throw new AppError('INVALID_REQUEST', 'Invalid action', 400)
  }

  // Log analytics
  await services.analyticsLogger.logEvent('auth_session_action', {
    action: requestData.action,
    is_anonymous: sessionData.is_anonymous,
    migration_successful: sessionData.migration_successful
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: SessionApiResponse = {
    success: true,
    data: sessionData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Validates session request
 */
function validateSessionRequest(requestData: any): void {
  if (!requestData.action || !['create_anonymous', 'migrate_to_authenticated'].includes(requestData.action)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid action', 400)
  }

  if (requestData.action === 'migrate_to_authenticated' && !requestData.anonymous_session_id) {
    throw new AppError('VALIDATION_ERROR', 'anonymous_session_id is required for migration', 400)
  }
}

/**
 * Creates anonymous session
 */
async function createAnonymousSession(services: ServiceContainer, deviceFingerprint?: string): Promise<SessionResponse> {
  // Create anonymous session using Supabase auth
  const { data, error } = await services.supabaseServiceClient.auth.signInAnonymously({
    options: {
      data: {
        device_fingerprint: deviceFingerprint
      }
    }
  })

  if (error) {
    throw new AppError('AUTHENTICATION_ERROR', `Failed to create anonymous session: ${error.message}`, 401)
  }

  return {
    session_id: data.session?.access_token || data.user?.id || '',
    expires_at: data.session?.expires_at ? String(data.session.expires_at) : new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    is_anonymous: true
  }
}

/**
 * Migrates anonymous session to authenticated
 */
async function migrateToAuthenticated(services: ServiceContainer, anonymousSessionId: string, userContext: UserContext): Promise<SessionResponse> {
  try {
    // Validate the anonymous session exists and hasn't been migrated
    const { data: sessionCheck, error: sessionError } = await services.supabaseServiceClient
      .from('user_sessions')
      .select('id, is_migrated, created_at')
      .eq('session_id', anonymousSessionId)
      .eq('is_anonymous', true)
      .single()

    if (sessionError || !sessionCheck) {
      throw new AppError('VALIDATION_ERROR', 'Invalid or non-existent anonymous session', 400)
    }

    if (sessionCheck.is_migrated) {
      throw new AppError('VALIDATION_ERROR', 'Anonymous session has already been migrated', 400)
    }

    // Migrate study guides
    const { error: guidesError } = await services.supabaseServiceClient
      .from('study_guides')
      .update({ user_id: userContext.userId })
      .eq('session_id', anonymousSessionId)
      .is('user_id', null)

    if (guidesError) {
      console.error('Failed to migrate study guides:', guidesError)
    }

    // Migrate feedback data
    const { error: feedbackError } = await services.supabaseServiceClient
      .from('feedback')
      .update({ user_id: userContext.userId })
      .eq('session_id', anonymousSessionId)
      .is('user_id', null)

    if (feedbackError) {
      console.error('Failed to migrate feedback:', feedbackError)
    }

    // Mark session as migrated
    const { error: updateError } = await services.supabaseServiceClient
      .from('user_sessions')
      .update({ 
        is_migrated: true, 
        migrated_to_user_id: userContext.userId,
        migrated_at: new Date().toISOString()
      })
      .eq('session_id', anonymousSessionId)

    if (updateError) {
      throw new AppError('DATABASE_ERROR', 'Failed to mark session as migrated', 500)
    }

    // Create authenticated session token
    const { data: authData, error: authError } = await services.supabaseServiceClient.auth.getUser()
    
    const sessionId = authData?.user?.id || `auth_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`

    return {
      session_id: sessionId,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days
      is_anonymous: false,
      migration_successful: true
    }
  } catch (error) {
    if (error instanceof AppError) {
      throw error
    }
    throw new AppError('INTERNAL_SERVER_ERROR', 'Failed to migrate anonymous session', 500)
  }
}

// Create the function with conditional authentication based on action
const authHandler: FunctionHandler = async (req, services, userContext) => {
  // Check if migration is requested and require auth
  if (req.method === 'POST') {
    const body = await req.clone().json().catch(() => ({}))
    if (body.action === 'migrate_to_authenticated' && !userContext?.userId) {
      throw new AppError('AUTHENTICATION_ERROR', 'Authentication required for session migration', 401)
    }
  }
  return handleAuthSession(req, services, userContext)
}

createFunction(authHandler, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000, // 10 seconds
  requireAuth: false // We handle auth conditionally in the handler
})