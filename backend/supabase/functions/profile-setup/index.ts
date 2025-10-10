/**
 * Profile Setup Edge Function
 * 
 * Refactored to use clean architecture with function factory
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { UserContext } from '../_shared/types/index.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

interface ProfileData {
  first_name: string
  last_name: string
  age_group: string
  interests: string[]
  profile_image_url?: string
}

interface ProfileSetupRequest {
  action: 'update_profile' | 'get_profile'
  profile_data?: ProfileData
}

// ============================================================================
// Validation
// ============================================================================

function validateProfileData(data: ProfileData): void {
  if (!data.first_name || data.first_name.trim().length === 0) {
    throw new AppError('VALIDATION_ERROR', 'First name is required', 400)
  }
  
  if (!data.last_name || data.last_name.trim().length === 0) {
    throw new AppError('VALIDATION_ERROR', 'Last name is required', 400)
  }
  
  const validAgeGroups = ['13-17', '18-25', '26-35', '36-50', '51+']
  if (!data.age_group || !validAgeGroups.includes(data.age_group)) {
    throw new AppError('VALIDATION_ERROR', 'Valid age group is required', 400)
  }
  
  if (!Array.isArray(data.interests) || data.interests.length === 0) {
    throw new AppError('VALIDATION_ERROR', 'At least one interest must be selected', 400)
  }
  
  const validInterests = [
    'prayer', 'worship', 'community', 'bible_study', 'theology',
    'missions', 'youth_ministry', 'family', 'leadership', 'evangelism'
  ]
  
  for (const interest of data.interests) {
    if (!validInterests.includes(interest)) {
      throw new AppError('VALIDATION_ERROR', `Invalid interest: ${interest}`, 400)
    }
  }
  
  if (data.profile_image_url && !isValidUrl(data.profile_image_url)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid profile image URL', 400)
  }
}

function isValidUrl(string: string): boolean {
  try {
    new URL(string)
    return true
  } catch {
    return false
  }
}

function sanitizeProfileData(data: ProfileData): ProfileData {
  return {
    first_name: data.first_name.trim(),
    last_name: data.last_name.trim(),
    age_group: data.age_group,
    interests: data.interests.filter(i => i.trim().length > 0),
    profile_image_url: data.profile_image_url?.trim() || undefined
  }
}

// ============================================================================
// Handlers
// ============================================================================

async function updateProfile(
  profileData: ProfileData,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  validateProfileData(profileData)
  const sanitizedData = sanitizeProfileData(profileData)

  const { data, error } = await services.supabaseServiceClient
    .from('user_profiles')
    .update({
      first_name: sanitizedData.first_name,
      last_name: sanitizedData.last_name,
      age_group: sanitizedData.age_group,
      interests: sanitizedData.interests,
      profile_image_url: sanitizedData.profile_image_url,
      onboarding_status: 'language_selection',
      updated_at: new Date().toISOString()
    })
    .eq('id', userId)
    .select('*')
    .single()

  if (error) {
    throw new AppError('DATABASE_ERROR', 'Failed to update profile', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        profile: data,
        next_step: 'language_selection'
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

async function getProfile(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const { data, error } = await services.supabaseServiceClient
    .from('user_profiles')
    .select('*')
    .eq('id', userId)
    .single()

  if (error) {
    throw new AppError('DATABASE_ERROR', 'Failed to retrieve profile', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: { profile: data }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleProfileSetup(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }

  const userId = userContext.userId!
  const body: ProfileSetupRequest = await req.json()

  if (!body.action) {
    throw new AppError('VALIDATION_ERROR', 'Action is required', 400)
  }

  switch (body.action) {
    case 'update_profile':
      if (!body.profile_data) {
        throw new AppError('VALIDATION_ERROR', 'Profile data required for update', 400)
      }
      return updateProfile(body.profile_data, services, userId)

    case 'get_profile':
      return getProfile(services, userId)
      
    default:
      throw new AppError('VALIDATION_ERROR', 'Invalid action', 400)
  }
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleProfileSetup, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000
})
