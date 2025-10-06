/**
 * Phone Auth Edge Function
 * 
 * Refactored to use clean architecture with function factory
 * Note: This function does NOT require authentication (uses createSimpleFunction)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

interface PhoneAuthRequest {
  action: 'send_otp' | 'verify_otp'
  phone_number: string
  otp_code?: string
}

// ============================================================================
// Validation & Formatting
// ============================================================================

function validatePhoneNumber(phoneNumber: string): boolean {
  const phoneRegex = /^\+[1-9]\d{1,14}$/
  return phoneRegex.test(phoneNumber)
}

function formatPhoneNumber(phoneNumber: string): string {
  let cleaned = phoneNumber.replace(/[^\d+]/g, '')
  if (cleaned.startsWith('00')) {
    cleaned = '+' + cleaned.substring(2)
  }
  return cleaned
}

function extractCountryCode(formattedPhone: string): string {
  if (!formattedPhone.startsWith('+')) {
    return '+1'
  }

  const countryCodePattern = /^\+((?:[2-9]\d{2})|(?:[2-9]\d?)|1)/
  const match = formattedPhone.match(countryCodePattern)

  if (match && match[1]) {
    return '+' + match[1]
  }

  return '+1'
}

// ============================================================================
// Handlers
// ============================================================================

async function sendOTP(
  phoneNumber: string,
  services: ServiceContainer
): Promise<Response> {
  const formattedPhone = formatPhoneNumber(phoneNumber)
  
  if (!validatePhoneNumber(formattedPhone)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid phone number format', 400)
  }

  const { error } = await services.supabaseServiceClient.auth.signInWithOtp({
    phone: formattedPhone,
  })

  if (error) {
    throw new AppError('AUTH_ERROR', `Failed to send OTP: ${error.message}`, 400)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        message: 'OTP sent successfully',
        phone_number: formattedPhone,
        expires_in: 60
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

async function verifyOTP(
  phoneNumber: string,
  otpCode: string,
  services: ServiceContainer
): Promise<Response> {
  const formattedPhone = formatPhoneNumber(phoneNumber)
  
  if (!validatePhoneNumber(formattedPhone)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid phone number format', 400)
  }

  if (!otpCode || otpCode.length !== 6) {
    throw new AppError('VALIDATION_ERROR', 'OTP must be 6 digits', 400)
  }

  const { data, error } = await services.supabaseServiceClient.auth.verifyOtp({
    phone: formattedPhone,
    token: otpCode,
    type: 'sms',
  })

  if (error) {
    throw new AppError('AUTH_ERROR', `Failed to verify OTP: ${error.message}`, 400)
  }

  if (!data.user) {
    throw new AppError('AUTH_ERROR', 'OTP verification failed', 400)
  }

  const user = data.user
  const session = data.session

  // Check if profile exists
  const { data: existingProfile, error: profileError } = await services.supabaseServiceClient
    .from('user_profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  let onboardingStatus = 'completed'
  let requiresOnboarding = false

  if (profileError || !existingProfile) {
    const countryCode = extractCountryCode(formattedPhone)

    const { error: insertError } = await services.supabaseServiceClient
      .from('user_profiles')
      .insert({
        id: user.id,
        phone_number: formattedPhone,
        phone_verified: true,
        phone_country_code: countryCode,
        onboarding_status: 'profile_setup',
        language_preference: 'en',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })

    if (insertError) {
      throw new AppError('DATABASE_ERROR', `Failed to create user profile: ${insertError.message}`, 500)
    }

    onboardingStatus = 'profile_setup'
    requiresOnboarding = true
  } else {
    if (!existingProfile.phone_number) {
      const countryCode = extractCountryCode(formattedPhone)

      const { error: updateError } = await services.supabaseServiceClient
        .from('user_profiles')
        .update({
          phone_number: formattedPhone,
          phone_verified: true,
          phone_country_code: countryCode,
          updated_at: new Date().toISOString()
        })
        .eq('id', user.id)

      if (updateError) {
        throw new AppError('DATABASE_ERROR', `Failed to update user profile: ${updateError.message}`, 500)
      }
    }

    onboardingStatus = existingProfile.onboarding_status || 'completed'
    requiresOnboarding = onboardingStatus !== 'completed'
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        message: 'Phone verification successful',
        user,
        session,
        requires_onboarding: requiresOnboarding,
        onboarding_status: onboardingStatus
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Main Handler
// ============================================================================

async function handlePhoneAuth(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  const body: PhoneAuthRequest = await req.json()
  
  if (!body.action || !body.phone_number) {
    throw new AppError('VALIDATION_ERROR', 'Action and phone_number are required', 400)
  }

  switch (body.action) {
    case 'send_otp':
      return sendOTP(body.phone_number, services)
      
    case 'verify_otp':
      if (!body.otp_code) {
        throw new AppError('VALIDATION_ERROR', 'OTP code required for verification', 400)
      }
      return verifyOTP(body.phone_number, body.otp_code, services)
      
    default:
      throw new AppError('VALIDATION_ERROR', 'Invalid action. Must be send_otp or verify_otp', 400)
  }
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createSimpleFunction(handlePhoneAuth, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000
})
