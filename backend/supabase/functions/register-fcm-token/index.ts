/**
 * Register FCM Token Edge Function
 * 
 * Refactored to use clean architecture with function factory:
 * - No manual CORS handling (factory handles it)
 * - No manual authentication (factory handles it)
 * - Clean separation of concerns
 * - Automatic error handling
 */

import { createFunction } from '../_shared/core/function-factory.ts'
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
  streakReminderEnabled?: boolean
  streakMilestoneEnabled?: boolean
  streakLostEnabled?: boolean
  streakReminderTime?: string
  memoryVerseReminderEnabled?: boolean
  memoryVerseReminderTime?: string
  memoryVerseOverdueEnabled?: boolean
  timezoneOffsetMinutes?: number
}

interface PreferencesUpdate {
  daily_verse_enabled?: boolean
  recommended_topic_enabled?: boolean
  streak_reminder_enabled?: boolean
  streak_milestone_enabled?: boolean
  streak_lost_enabled?: boolean
  streak_reminder_time?: string
  memory_verse_reminder_enabled?: boolean
  memory_verse_reminder_time?: string
  memory_verse_overdue_enabled?: boolean
  timezone_offset_minutes?: number
  updated_at?: string
}

// ============================================================================
// Main Handler (Routes all methods)
// ============================================================================

async function handleFCMToken(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // DELETE by specific token is allowed without a valid session — this is
  // called on sign-out when the auth session is already gone. The FCM token
  // value is unique, so deleting by value alone (via service role) is safe.
  if (req.method === 'DELETE') {
    const body = await req.json().catch(() => ({})) as { fcmToken?: string }
    if (body.fcmToken) {
      return handleUnregisterTokenByValue(services, body.fcmToken)
    }
    // Deleting all tokens requires knowing the user — fall through to auth check
  }

  // All other methods require an authenticated user
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
      // Reached only when no specific token was provided (delete-all)
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

  // Fetch existing preferences to preserve user's notification toggles
  // Use maybeSingle() to handle case where user doesn't have preferences yet
  const { data: existingPrefs, error: prefsError } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .select('daily_verse_enabled, recommended_topic_enabled')
    .eq('user_id', userId)
    .maybeSingle()

  // Check for database errors when fetching preferences
  if (prefsError) {
    console.error('[register-fcm-token] Error fetching notification preferences:', prefsError)
    throw new AppError(
      'DATABASE_ERROR',
      'Failed to fetch notification preferences',
      500
    )
  }

  // Preserve existing values if request doesn't explicitly provide them
  // Only default to true when no existing record exists
  const dailyVerseEnabled = requestData.dailyVerseEnabled !== undefined
    ? requestData.dailyVerseEnabled
    : (existingPrefs?.daily_verse_enabled ?? true)

  const recommendedTopicEnabled = requestData.recommendedTopicEnabled !== undefined
    ? requestData.recommendedTopicEnabled
    : (existingPrefs?.recommended_topic_enabled ?? true)

  // Step 1: Upsert FCM token in user_notification_tokens table
  // Note: Users can have multiple tokens (one per device/browser)
  const { error: tokenError } = await services.supabaseServiceClient
    .from('user_notification_tokens')
    .upsert({
      user_id: userId,
      fcm_token: requestData.fcmToken,
      platform: requestData.platform,
      token_updated_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id,fcm_token', // unique constraint
      ignoreDuplicates: false,
    })

  if (tokenError) {
    console.error('[Register Token] Token upsert error:', tokenError)
    throw new AppError('DATABASE_ERROR', tokenError.message, 500)
  }

  console.log('[Register Token] Token registered successfully')

  // Step 2: Upsert notification preferences in user_notification_preferences table
  const { data: prefsData, error: prefsUpsertError } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .upsert({
      user_id: userId,
      timezone_offset_minutes: timezoneOffset,
      daily_verse_enabled: dailyVerseEnabled,
      recommended_topic_enabled: recommendedTopicEnabled,
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id',
    })
    .select()
    .single()

  if (prefsUpsertError) {
    console.error('[Register Token] Preferences upsert error:', prefsUpsertError)
    throw new AppError('DATABASE_ERROR', prefsUpsertError.message, 500)
  }

  console.log('[Register Token] Token and preferences registered successfully')

  return new Response(
    JSON.stringify({
      success: true,
      message: 'FCM token registered successfully',
      preferences: {
        dailyVerseEnabled: prefsData.daily_verse_enabled,
        recommendedTopicEnabled: prefsData.recommended_topic_enabled,
        streakReminderEnabled: prefsData.streak_reminder_enabled,
        streakMilestoneEnabled: prefsData.streak_milestone_enabled,
        streakLostEnabled: prefsData.streak_lost_enabled,
        streakReminderTime: prefsData.streak_reminder_time,
        memoryVerseReminderEnabled: prefsData.memory_verse_reminder_enabled,
        memoryVerseReminderTime: prefsData.memory_verse_reminder_time,
        memoryVerseOverdueEnabled: prefsData.memory_verse_overdue_enabled,
        timezoneOffsetMinutes: prefsData.timezone_offset_minutes,
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
  const updateData: PreferencesUpdate = {}
  if (requestData.dailyVerseEnabled !== undefined) {
    updateData.daily_verse_enabled = requestData.dailyVerseEnabled
  }
  if (requestData.recommendedTopicEnabled !== undefined) {
    updateData.recommended_topic_enabled = requestData.recommendedTopicEnabled
  }
  if (requestData.streakReminderEnabled !== undefined) {
    updateData.streak_reminder_enabled = requestData.streakReminderEnabled
  }
  if (requestData.streakMilestoneEnabled !== undefined) {
    updateData.streak_milestone_enabled = requestData.streakMilestoneEnabled
  }
  if (requestData.streakLostEnabled !== undefined) {
    updateData.streak_lost_enabled = requestData.streakLostEnabled
  }
  if (requestData.streakReminderTime !== undefined) {
    updateData.streak_reminder_time = requestData.streakReminderTime
  }
  if (requestData.memoryVerseReminderEnabled !== undefined) {
    updateData.memory_verse_reminder_enabled = requestData.memoryVerseReminderEnabled
  }
  if (requestData.memoryVerseReminderTime !== undefined) {
    updateData.memory_verse_reminder_time = requestData.memoryVerseReminderTime
  }
  if (requestData.memoryVerseOverdueEnabled !== undefined) {
    updateData.memory_verse_overdue_enabled = requestData.memoryVerseOverdueEnabled
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
  // Use maybeSingle() to properly detect when user hasn't registered preferences yet
  const { data, error } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .update(updateData)
    .eq('user_id', userId)
    .select()
    .maybeSingle()

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
        streakReminderEnabled: data.streak_reminder_enabled,
        streakMilestoneEnabled: data.streak_milestone_enabled,
        streakLostEnabled: data.streak_lost_enabled,
        streakReminderTime: data.streak_reminder_time,
        memoryVerseReminderEnabled: data.memory_verse_reminder_enabled,
        memoryVerseReminderTime: data.memory_verse_reminder_time,
        memoryVerseOverdueEnabled: data.memory_verse_overdue_enabled,
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
  _req: Request,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  console.log(`[Get Preferences] User: ${userId}`)

  // Fetch notification preferences
  // Use maybeSingle() to handle case where user hasn't registered preferences yet
  const { data: prefsData, error: prefsError } = await services.supabaseServiceClient
    .from('user_notification_preferences')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle()

  if (prefsError) {
    console.error('[Get Preferences] Database error:', prefsError)
    throw new AppError('DATABASE_ERROR', prefsError.message, 500)
  }

  // Fetch FCM tokens (user may have multiple devices)
  const { data: tokensData, error: tokensError } = await services.supabaseServiceClient
    .from('user_notification_tokens')
    .select('fcm_token, platform, token_updated_at')
    .eq('user_id', userId)

  if (tokensError) {
    console.error('[Get Preferences] Tokens error:', tokensError)
    throw new AppError('DATABASE_ERROR', tokensError.message, 500)
  }

  if (!prefsData) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No notification preferences found',
        preferences: null,
        tokens: tokensData || [],
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
        dailyVerseEnabled: prefsData.daily_verse_enabled,
        recommendedTopicEnabled: prefsData.recommended_topic_enabled,
        streakReminderEnabled: prefsData.streak_reminder_enabled,
        streakMilestoneEnabled: prefsData.streak_milestone_enabled,
        streakLostEnabled: prefsData.streak_lost_enabled,
        streakReminderTime: prefsData.streak_reminder_time,
        memoryVerseReminderEnabled: prefsData.memory_verse_reminder_enabled,
        memoryVerseReminderTime: prefsData.memory_verse_reminder_time,
        memoryVerseOverdueEnabled: prefsData.memory_verse_overdue_enabled,
        timezoneOffsetMinutes: prefsData.timezone_offset_minutes,
      },
      tokens: tokensData || [], // Array of all registered tokens/devices
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// ============================================================================
// DELETE - Unregister specific token by value (no auth required)
// Used on sign-out when the session is already invalidated.
// ============================================================================

async function handleUnregisterTokenByValue(
  services: ServiceContainer,
  fcmToken: string
): Promise<Response> {
  console.log('[Unregister Token] Deleting by token value (unauthenticated sign-out)')

  const { error } = await services.supabaseServiceClient
    .from('user_notification_tokens')
    .delete()
    .eq('fcm_token', fcmToken)

  if (error) {
    console.error('[Unregister Token] Token deletion error:', error)
    throw new AppError('DATABASE_ERROR', error.message, 500)
  }

  console.log('[Unregister Token] Token unregistered successfully')

  return new Response(
    JSON.stringify({
      success: true,
      message: 'FCM token unregistered successfully',
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// DELETE - Unregister Token (authenticated — delete specific or all)
// ============================================================================

async function handleUnregisterToken(
  _req: Request,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  // Reached only when no specific fcmToken was provided — delete all tokens
  console.log(`[Unregister Token] Deleting all tokens for user: ${userId}`)

  const { error: tokensError } = await services.supabaseServiceClient
    .from('user_notification_tokens')
    .delete()
    .eq('user_id', userId)

  if (tokensError) {
    console.error('[Unregister Token] All tokens deletion error:', tokensError)
    throw new AppError('DATABASE_ERROR', tokensError.message, 500)
  }

  console.log('[Unregister Token] All tokens unregistered successfully')

  return new Response(
    JSON.stringify({
      success: true,
      message: 'All FCM tokens unregistered successfully',
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Create Function with Factory (Handles CORS, Auth, Errors automatically)
// ============================================================================

// requireAuth: false so DELETE (sign-out token cleanup) reaches the handler
// even when the session is already invalidated. Auth is enforced per-method.
createFunction(handleFCMToken, {
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  requireAuth: false,
  enableAnalytics: true,
  timeout: 15000
})
