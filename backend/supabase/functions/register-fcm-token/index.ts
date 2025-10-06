/**
 * Register FCM Token Edge Function
 * 
 * Refactored to use clean architecture with function factory:
 * - No manual CORS handling (factory handles it)
 * - No manual authentication (factory handles it)
 * - Clean separation of concerns
 * - Automatic error handling
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { UserContext } from '../_shared/types/index.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

// ============================================================================
// Request Interfaces
// ============================================================================

interface RegisterTokenRequest {
  fcmToken: string
  platform: 'ios' | 'android' | 'web'
  timezoneOffsetMinutes?: number
  dailyVerseEnabled?: boolean
  recommendedTopicEnabled?: boolean
}

interface UpdatePreferencesRequest {
  dailyVerseEnabled?: boolean
  recommendedTopicEnabled?: boolean
  timezoneOffsetMinutes?: number
}

// ============================================================================
// Main Handler (Routes all methods)
// ============================================================================

async function handleFCMToken(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }

  const userId = userContext.userId!

  switch (req.method) {
    case 'POST':
      return handleRegisterToken(req, services, userId)
    
    case 'PUT':
      return handleUpdatePreferences(req, services, userId)
    
    case 'GET':
      return handleGetPreferences(req, services, userId)
    
    case 'DELETE':
      return handleUnregisterToken(req, services, userId)
    
    default:
      throw new AppError('METHOD_NOT_ALLOWED', `Method ${req.method} not allowed`, 405)
  }
}

// ============================================================================
// POST - Register New FCM Token
// ============================================================================

async function handleRegisterToken(
  req: Request,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const requestData = await req.json() as RegisterTokenRequest

  // Validate required fields
  if (!requestData.fcmToken || !requestData.platform) {
    throw new AppError('VALIDATION_ERROR', 'FCM token and platform are required', 400)
  }

  // Validate platform
  if (!['ios', 'android', 'web'].includes(requestData.platform)) {
    throw new AppError('VALIDATION_ERROR', 'Platform must be ios, android, or web', 400)
  }

  console.log(`[Register Token] User: ${userId}, Platform: ${requestData.platform}`)

  // Detect timezone offset
  const timezoneOffset = requestData.timezoneOffsetMinutes ?? 0

  // Upsert token and preferences
  const { data, error } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .upsert({
      user_id: userId,
      fcm_token: requestData.fcmToken,
      platform: requestData.platform,
      timezone_offset_minutes: timezoneOffset,
      daily_verse_enabled: requestData.dailyVerseEnabled ?? true,
      recommended_topic_enabled: requestData.recommendedTopicEnabled ?? true,
      token_updated_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id',
    })
    .select()
    .single()

  if (error) {
    console.error('[Register Token] Database error:', error)
    throw new AppError('DATABASE_ERROR', error.message, 500)
  }

  console.log('[Register Token] Token registered successfully')

  return new Response(
    JSON.stringify({
      success: true,
      message: 'FCM token registered successfully',
      preferences: {
        dailyVerseEnabled: data.daily_verse_enabled,
        recommendedTopicEnabled: data.recommended_topic_enabled,
        timezoneOffsetMinutes: data.timezone_offset_minutes,
      },
    }),
    { 
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// ============================================================================
// PUT - Update Notification Preferences
// ============================================================================

async function handleUpdatePreferences(
  req: Request,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const requestData = await req.json() as UpdatePreferencesRequest

  // Build update object with only provided fields
  const updateData: any = {}
  if (requestData.dailyVerseEnabled !== undefined) {
    updateData.daily_verse_enabled = requestData.dailyVerseEnabled
  }
  if (requestData.recommendedTopicEnabled !== undefined) {
    updateData.recommended_topic_enabled = requestData.recommendedTopicEnabled
  }
  if (requestData.timezoneOffsetMinutes !== undefined) {
    updateData.timezone_offset_minutes = requestData.timezoneOffsetMinutes
  }

  if (Object.keys(updateData).length === 0) {
    throw new AppError('VALIDATION_ERROR', 'No fields to update', 400)
  }

  // Add updated timestamp
  updateData.updated_at = new Date().toISOString()

  console.log(`[Update Preferences] User: ${userId}, Fields: ${Object.keys(updateData).join(', ')}`)

  // Update preferences
  const { data, error } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .update(updateData)
    .eq('user_id', userId)
    .select()
    .single()

  if (error) {
    console.error('[Update Preferences] Database error:', error)
    throw new AppError('DATABASE_ERROR', error.message, 500)
  }

  if (!data) {
    throw new AppError('NOT_FOUND', 'User notification preferences not found. Register token first.', 404)
  }

  console.log('[Update Preferences] Preferences updated successfully')

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Notification preferences updated successfully',
      preferences: {
        dailyVerseEnabled: data.daily_verse_enabled,
        recommendedTopicEnabled: data.recommended_topic_enabled,
        timezoneOffsetMinutes: data.timezone_offset_minutes,
      },
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// ============================================================================
// GET - Retrieve Current Preferences
// ============================================================================

async function handleGetPreferences(
  req: Request,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  console.log(`[Get Preferences] User: ${userId}`)

  const { data, error } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .select('*')
    .eq('user_id', userId)
    .single()

  if (error && error.code !== 'PGRST116') { // PGRST116 = not found
    console.error('[Get Preferences] Database error:', error)
    throw new AppError('DATABASE_ERROR', error.message, 500)
  }

  if (!data) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No notification preferences found',
        preferences: null,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Notification preferences retrieved',
      preferences: {
        fcmToken: data.fcm_token,
        platform: data.platform,
        dailyVerseEnabled: data.daily_verse_enabled,
        recommendedTopicEnabled: data.recommended_topic_enabled,
        timezoneOffsetMinutes: data.timezone_offset_minutes,
        tokenUpdatedAt: data.token_updated_at,
      },
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// ============================================================================
// DELETE - Unregister Token
// ============================================================================

async function handleUnregisterToken(
  req: Request,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  console.log(`[Unregister Token] User: ${userId}`)

  const { error } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .delete()
    .eq('user_id', userId)

  if (error) {
    console.error('[Unregister Token] Database error:', error)
    throw new AppError('DATABASE_ERROR', error.message, 500)
  }

  console.log('[Unregister Token] Token unregistered successfully')

  return new Response(
    JSON.stringify({
      success: true,
      message: 'FCM token unregistered successfully',
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// ============================================================================
// Create Function with Factory (Handles CORS, Auth, Errors automatically)
// ============================================================================

createAuthenticatedFunction(handleFCMToken, {
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  enableAnalytics: true,
  timeout: 15000
})
