/**
 * User Profile Edge Function
 * 
 * Refactored to use clean architecture with function factory:
 * - No manual CORS handling (factory handles it)
 * - No manual authentication (factory handles it)
 * - Clean separation of concerns
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { UserContext } from '../_shared/types/index.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { extractOAuthProfileData, createProfileUpdateData, logProfileExtraction } from '../_shared/utils/profile-extractor.ts'

interface UserProfile {
  id: string
  language_preference: string
  theme_preference: string
  first_name: string | null
  last_name: string | null
  profile_picture: string | null
  default_study_mode: string | null
  email: string | null
  phone: string | null
  is_admin: boolean
  created_at: string
  updated_at: string
}

interface UpdateProfileRequest {
  language_preference?: string
  theme_preference?: string
  first_name?: string | null
  last_name?: string | null
  profile_picture?: string | null
  default_study_mode?: string | null
  learning_path_study_mode?: string | null
}

// ============================================================================
// Validation Utilities
// ============================================================================

function isValidUrl(url: string): boolean {
  try {
    const urlObj = new URL(url)
    return urlObj.protocol === 'http:' || urlObj.protocol === 'https:'
  } catch {
    return false
  }
}

function isValidName(name: string): boolean {
  if (typeof name !== 'string') return false
  const trimmed = name.trim()
  if (trimmed.length === 0 || trimmed.length > 50) return false
  const nameRegex = /^[a-zA-Z\u00C0-\u017F\s\-']+$/
  return nameRegex.test(trimmed)
}

function parseAndValidateUpdate(body: any): UpdateProfileRequest {
  const updateData: UpdateProfileRequest = {}

  if (body.language_preference !== undefined) {
    const validLanguages = ['en', 'hi', 'ml']
    if (!validLanguages.includes(body.language_preference)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid language preference', 400)
    }
    updateData.language_preference = body.language_preference
  }

  if (body.theme_preference !== undefined) {
    const validThemes = ['light', 'dark', 'system']
    if (!validThemes.includes(body.theme_preference)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid theme preference', 400)
    }
    updateData.theme_preference = body.theme_preference
  }

  if (body.first_name !== undefined) {
    if (body.first_name === null || body.first_name === '') {
      updateData.first_name = null
    } else if (!isValidName(body.first_name)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid first name format', 400)
    } else {
      updateData.first_name = body.first_name.trim()
    }
  }

  if (body.last_name !== undefined) {
    if (body.last_name === null || body.last_name === '') {
      updateData.last_name = null
    } else if (!isValidName(body.last_name)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid last name format', 400)
    } else {
      updateData.last_name = body.last_name.trim()
    }
  }

  if (body.profile_picture !== undefined) {
    if (body.profile_picture === null || body.profile_picture === '') {
      updateData.profile_picture = null
    } else if (!isValidUrl(body.profile_picture)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid profile picture URL format', 400)
    } else {
      updateData.profile_picture = body.profile_picture.trim()
    }
  }

  if (body.default_study_mode !== undefined) {
    if (body.default_study_mode === null || body.default_study_mode === '') {
      updateData.default_study_mode = null
    } else {
      const validModes = ['quick', 'standard', 'deep', 'lectio', 'recommended']
      if (!validModes.includes(body.default_study_mode)) {
        throw new AppError('VALIDATION_ERROR', 'Invalid study mode. Must be one of: quick, standard, deep, lectio, recommended', 400)
      }
      updateData.default_study_mode = body.default_study_mode
    }
  }

  if (body.learning_path_study_mode !== undefined) {
    if (body.learning_path_study_mode === null || body.learning_path_study_mode === '') {
      updateData.learning_path_study_mode = null
    } else {
      const validModes = ['ask', 'recommended', 'quick', 'standard', 'deep', 'lectio']
      if (!validModes.includes(body.learning_path_study_mode)) {
        throw new AppError('VALIDATION_ERROR', 'Invalid learning path study mode. Must be one of: ask, recommended, quick, standard, deep, lectio', 400)
      }
      updateData.learning_path_study_mode = body.learning_path_study_mode
    }
  }

  if (Object.keys(updateData).length === 0) {
    throw new AppError('VALIDATION_ERROR', 'No valid fields to update', 400)
  }

  return updateData
}

// ============================================================================
// Profile Management
// ============================================================================

async function createDefaultProfile(
  services: ServiceContainer,
  userId: string,
  updateData?: UpdateProfileRequest
): Promise<UserProfile> {
  let oauthData: any = {}
  
  try {
    const { data: { user }, error: userError } = await services.supabaseServiceClient.auth.admin.getUserById(userId)
    
    if (!userError && user) {
      const extractionResult = extractOAuthProfileData(user)
      
      if (extractionResult.success && extractionResult.data) {
        const profileUpdateData = createProfileUpdateData(extractionResult.data)
        oauthData = profileUpdateData
        logProfileExtraction(user, extractionResult)
        console.log('✅ [USER_PROFILE] OAuth data extracted for new profile')
      }
    }
  } catch (error) {
    console.warn('⚠️ [USER_PROFILE] Failed to extract OAuth data:', error)
  }

  return {
    id: userId,
    language_preference: updateData?.language_preference || 'en',
    theme_preference: updateData?.theme_preference || 'light',
    first_name: updateData?.first_name || oauthData.first_name || null,
    last_name: updateData?.last_name || oauthData.last_name || null,
    profile_picture: updateData?.profile_picture || oauthData.profile_picture || null,
    default_study_mode: updateData?.default_study_mode || null,
    email: null,
    phone: null,
    is_admin: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }
}

async function upsertProfile(
  services: ServiceContainer,
  userId: string,
  updateData: UpdateProfileRequest
): Promise<UserProfile> {
  // Separate profile fields from preference fields
  const { learning_path_study_mode, ...profileFields } = updateData
  
  const updateWithTimestamp = {
    ...profileFields,
    updated_at: new Date().toISOString(),
  }

  // Update user_profiles table
  const { data: updatedProfile, error: updateError } = await services.supabaseServiceClient
    .from('user_profiles')
    .update(updateWithTimestamp)
    .eq('id', userId)
    .select()
    .single()

  if (updateError?.code === 'PGRST116') {
    const defaultProfile = await createDefaultProfile(services, userId, updateData)
    const { data, error } = await services.supabaseServiceClient
      .from('user_profiles')
      .insert({
        id: userId,
        language_preference: defaultProfile.language_preference,
        theme_preference: defaultProfile.theme_preference,
        first_name: defaultProfile.first_name,
        last_name: defaultProfile.last_name,
        profile_picture: defaultProfile.profile_picture,
        is_admin: defaultProfile.is_admin
      })
      .select()
      .single()

    if (error) throw new AppError('DATABASE_ERROR', error.message, 500)
  } else if (updateError) {
    throw new AppError('DATABASE_ERROR', updateError.message, 500)
  }

  // Update user_preferences table if learning_path_study_mode is provided
  if (learning_path_study_mode !== undefined) {
    const { error: prefError } = await services.supabaseServiceClient
      .from('user_preferences')
      .upsert({
        user_id: userId,
        learning_path_study_mode: learning_path_study_mode,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' })

    if (prefError) {
      throw new AppError('DATABASE_ERROR', `Failed to update learning path study mode: ${prefError.message}`, 500)
    }
  }

  // Return the updated profile (or newly created one)
  const { data: finalProfile, error: finalError } = await services.supabaseServiceClient
    .from('user_profiles')
    .select('*')
    .eq('id', userId)
    .single()

  if (finalError) throw new AppError('DATABASE_ERROR', finalError.message, 500)
  return finalProfile
}

// ============================================================================
// Request Handlers
// ============================================================================

async function handleGetProfile(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const { data: profile, error } = await services.supabaseServiceClient
    .from('user_profiles')
    .select('*')
    .eq('id', userId)
    .single()

  let userProfile: UserProfile

  if (error?.code === 'PGRST116') {
    const defaultProfile = await createDefaultProfile(services, userId)
    const { data: newProfile, error: insertError } = await services.supabaseServiceClient
      .from('user_profiles')
      .insert({
        id: userId,
        language_preference: defaultProfile.language_preference,
        theme_preference: defaultProfile.theme_preference,
        first_name: defaultProfile.first_name,
        last_name: defaultProfile.last_name,
        profile_picture: defaultProfile.profile_picture,
        is_admin: defaultProfile.is_admin
      })
      .select()
      .single()

    if (insertError) throw new AppError('DATABASE_ERROR', 'Failed to create user profile', 500)
    userProfile = newProfile
  } else if (error) {
    throw new AppError('DATABASE_ERROR', 'Failed to fetch user profile', 500)
  } else {
    userProfile = profile
  }

  // Fetch user preferences (learning_path_study_mode)
  const { data: preferences } = await services.supabaseServiceClient
    .from('user_preferences')
    .select('learning_path_study_mode')
    .eq('user_id', userId)
    .single()

  // Fetch auth user data
  const { data: { user }, error: userError } = await services.supabaseServiceClient.auth.admin.getUserById(userId)
  
  if (!userError && user) {
    userProfile.email = user.email || null
    userProfile.phone = user.phone || null
  }

  // Merge preferences into profile response
  const profileWithPreferences = {
    ...userProfile,
    learning_path_study_mode: preferences?.learning_path_study_mode || null,
  }

  return new Response(
    JSON.stringify({ data: profileWithPreferences }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

async function handleUpdateProfile(
  req: Request,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const body = await req.json()
  const updateData = parseAndValidateUpdate(body)
  const profile = await upsertProfile(services, userId, updateData)

  // Fetch user preferences to include in response
  const { data: preferences } = await services.supabaseServiceClient
    .from('user_preferences')
    .select('learning_path_study_mode')
    .eq('user_id', userId)
    .single()

  // Merge preferences into profile response
  const profileWithPreferences = {
    ...profile,
    learning_path_study_mode: preferences?.learning_path_study_mode || null,
  }

  return new Response(
    JSON.stringify({ data: profileWithPreferences }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

async function handleSyncProfile(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const { data: { user }, error: userError } = await services.supabaseServiceClient.auth.admin.getUserById(userId)
  
  if (userError || !user) {
    throw new AppError('VALIDATION_ERROR', 'Failed to get user data for sync', 400)
  }

  const extractionResult = extractOAuthProfileData(user)
  
  if (!extractionResult.success || !extractionResult.data) {
    throw new AppError('VALIDATION_ERROR', 'No OAuth profile data available to sync', 400)
  }

  const profileUpdateData = createProfileUpdateData(extractionResult.data)
  
  if (Object.keys(profileUpdateData).length === 0) {
    return new Response(
      JSON.stringify({ 
        message: 'No profile data to sync',
        source: extractionResult.source
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const profile = await upsertProfile(services, userId, profileUpdateData)
  logProfileExtraction(user, extractionResult)
  console.log(`✅ [USER_PROFILE] Profile synced successfully for user ${userId}`)

  return new Response(
    JSON.stringify({ 
      message: 'Profile synced successfully',
      data: profile,
      source: extractionResult.source,
      synced_fields: Object.keys(profileUpdateData)
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleUserProfile(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }

  const userId = userContext.userId!

  switch (req.method) {
    case 'GET':
      return handleGetProfile(services, userId)
    case 'PUT':
      return handleUpdateProfile(req, services, userId)
    case 'POST':
      return handleSyncProfile(services, userId)
    default:
      throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
  }
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleUserProfile, {
  allowedMethods: ['GET', 'PUT', 'POST'],
  enableAnalytics: true,
  timeout: 15000
})
