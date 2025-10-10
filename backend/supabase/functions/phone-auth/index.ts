/**
 * Phone Auth Edge Function
 * 
 * Refactored to use clean architecture with function factory
 * Note: This function does NOT require authentication (uses createSimpleFunction)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

// ============================================================================
// Rate Limiting Configuration
// ============================================================================

const RATE_LIMIT_CONFIG = {
  // OTP Send limits
  PHONE_SEND_BURST_LIMIT: 3,        // 3 OTPs per hour per phone
  PHONE_SEND_DAILY_LIMIT: 10,       // 10 OTPs per day per phone
  IP_SEND_BURST_LIMIT: 5,           // 5 OTPs per hour per IP
  IP_SEND_DAILY_LIMIT: 20,          // 20 OTPs per day per IP
  
  // OTP Verify limits
  PHONE_VERIFY_BURST_LIMIT: 5,      // 5 attempts per hour per phone
  PHONE_VERIFY_DAILY_LIMIT: 15,     // 15 attempts per day per phone
  IP_VERIFY_BURST_LIMIT: 10,        // 10 attempts per hour per IP
  IP_VERIFY_DAILY_LIMIT: 30,        // 30 attempts per day per IP
  
  // Time windows
  BURST_WINDOW_MINUTES: 60,         // 1 hour
  DAILY_WINDOW_MINUTES: 1440,       // 24 hours
} as const

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Extract client IP address from request
 */
function getClientIP(req: Request): string {
  // Check various headers in order of priority
  const xForwardedFor = req.headers.get('x-forwarded-for')
  if (xForwardedFor) {
    // x-forwarded-for can contain multiple IPs, take the first one
    return xForwardedFor.split(',')[0].trim()
  }
  
  const xRealIp = req.headers.get('x-real-ip')
  if (xRealIp) {
    return xRealIp.trim()
  }
  
  // Fallback to a default value (should not happen in production)
  return 'unknown'
}

/**
 * Create rate limit identifier for phone number
 */
function createPhoneRateLimitKey(phone: string, action: 'send' | 'verify', window: 'burst' | 'daily'): string {
  return `phone:${action}:${window}:${phone}`
}

/**
 * Create rate limit identifier for IP address
 */
function createIPRateLimitKey(ip: string, action: 'send' | 'verify', window: 'burst' | 'daily'): string {
  return `ip:${action}:${window}:${ip}`
}

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
  services: ServiceContainer,
  req: Request
): Promise<Response> {
  const formattedPhone = formatPhoneNumber(phoneNumber)
  
  if (!validatePhoneNumber(formattedPhone)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid phone number format', 400)
  }

  const clientIP = getClientIP(req)
  
  // ========================================================================
  // Rate Limiting - Check both phone and IP limits
  // ========================================================================
  
  try {
    // Check phone-based burst limit (hourly)
    const phoneBurstResult = await services.rateLimiter.checkRateLimit(
      createPhoneRateLimitKey(formattedPhone, 'send', 'burst'),
      'anonymous'
    )
    
    if (!phoneBurstResult.allowed) {
      await services.analyticsLogger.logEvent('otp_send_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'phone_burst',
        attempts: phoneBurstResult.currentUsage,
        limit: phoneBurstResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Too many OTP requests for this phone number. Try again in ${phoneBurstResult.resetTime} minutes.`,
        429
      )
    }
    
    // Check phone-based daily limit
    const phoneDailyResult = await services.rateLimiter.checkRateLimit(
      createPhoneRateLimitKey(formattedPhone, 'send', 'daily'),
      'anonymous'
    )
    
    if (!phoneDailyResult.allowed) {
      await services.analyticsLogger.logEvent('otp_send_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'phone_daily',
        attempts: phoneDailyResult.currentUsage,
        limit: phoneDailyResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Daily OTP limit reached for this phone number. Try again tomorrow.`,
        429
      )
    }
    
    // Check IP-based burst limit (hourly)
    const ipBurstResult = await services.rateLimiter.checkRateLimit(
      createIPRateLimitKey(clientIP, 'send', 'burst'),
      'anonymous'
    )
    
    if (!ipBurstResult.allowed) {
      await services.analyticsLogger.logEvent('otp_send_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'ip_burst',
        attempts: ipBurstResult.currentUsage,
        limit: ipBurstResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Too many OTP requests from this device. Try again in ${ipBurstResult.resetTime} minutes.`,
        429
      )
    }
    
    // Check IP-based daily limit
    const ipDailyResult = await services.rateLimiter.checkRateLimit(
      createIPRateLimitKey(clientIP, 'send', 'daily'),
      'anonymous'
    )
    
    if (!ipDailyResult.allowed) {
      await services.analyticsLogger.logEvent('otp_send_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'ip_daily',
        attempts: ipDailyResult.currentUsage,
        limit: ipDailyResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Daily OTP limit reached for this device. Try again tomorrow.`,
        429
      )
    }
  } catch (error) {
    // If it's already an AppError, rethrow it
    if (error instanceof AppError) {
      throw error
    }
    
    // Log rate limiter errors but allow request to proceed (fail-open)
    console.error('Rate limiter error during OTP send:', error)
  }
  
  // ========================================================================
  // Send OTP via Supabase Auth
  // ========================================================================
  
  const { error } = await services.supabaseServiceClient.auth.signInWithOtp({
    phone: formattedPhone,
  })

  if (error) {
    // Log failed OTP send
    await services.analyticsLogger.logEvent('otp_send_failed', {
      phone_hash: formattedPhone.substring(0, 5) + '***',
      ip: clientIP,
      error_message: error.message,
    }, clientIP)
    
    throw new AppError('AUTH_ERROR', `Failed to send OTP: ${error.message}`, 400)
  }
  
  // ========================================================================
  // Record successful usage and log analytics
  // ========================================================================
  
  try {
    // Record usage for all rate limit keys
    await Promise.all([
      services.rateLimiter.recordUsage(
        createPhoneRateLimitKey(formattedPhone, 'send', 'burst'),
        'anonymous'
      ),
      services.rateLimiter.recordUsage(
        createPhoneRateLimitKey(formattedPhone, 'send', 'daily'),
        'anonymous'
      ),
      services.rateLimiter.recordUsage(
        createIPRateLimitKey(clientIP, 'send', 'burst'),
        'anonymous'
      ),
      services.rateLimiter.recordUsage(
        createIPRateLimitKey(clientIP, 'send', 'daily'),
        'anonymous'
      ),
    ])
    
    // Log successful OTP send
    await services.analyticsLogger.logEvent('otp_sent', {
      phone_hash: formattedPhone.substring(0, 5) + '***',
      ip: clientIP,
      outcome: 'success',
    }, clientIP)
  } catch (error) {
    // Don't fail the request if analytics/usage recording fails
    console.error('Failed to record OTP send usage/analytics:', error)
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
  services: ServiceContainer,
  req: Request
): Promise<Response> {
  const formattedPhone = formatPhoneNumber(phoneNumber)
  
  if (!validatePhoneNumber(formattedPhone)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid phone number format', 400)
  }

  // Strict numeric validation: exactly 6 digits
  if (typeof otpCode !== 'string' || !/^\d{6}$/.test(otpCode)) {
    throw new AppError('VALIDATION_ERROR', 'OTP must be 6 digits', 400)
  }
  
  const clientIP = getClientIP(req)
  
  // ========================================================================
  // Rate Limiting - Check both phone and IP limits for verification
  // ========================================================================
  
  try {
    // Check phone-based burst limit (hourly)
    const phoneBurstResult = await services.rateLimiter.checkRateLimit(
      createPhoneRateLimitKey(formattedPhone, 'verify', 'burst'),
      'anonymous'
    )
    
    if (!phoneBurstResult.allowed) {
      await services.analyticsLogger.logEvent('otp_verify_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'phone_burst',
        attempts: phoneBurstResult.currentUsage,
        limit: phoneBurstResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Too many verification attempts for this phone number. Try again in ${phoneBurstResult.resetTime} minutes.`,
        429
      )
    }
    
    // Check phone-based daily limit
    const phoneDailyResult = await services.rateLimiter.checkRateLimit(
      createPhoneRateLimitKey(formattedPhone, 'verify', 'daily'),
      'anonymous'
    )
    
    if (!phoneDailyResult.allowed) {
      await services.analyticsLogger.logEvent('otp_verify_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'phone_daily',
        attempts: phoneDailyResult.currentUsage,
        limit: phoneDailyResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Daily verification limit reached for this phone number. Try again tomorrow.`,
        429
      )
    }
    
    // Check IP-based burst limit (hourly)
    const ipBurstResult = await services.rateLimiter.checkRateLimit(
      createIPRateLimitKey(clientIP, 'verify', 'burst'),
      'anonymous'
    )
    
    if (!ipBurstResult.allowed) {
      await services.analyticsLogger.logEvent('otp_verify_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'ip_burst',
        attempts: ipBurstResult.currentUsage,
        limit: ipBurstResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Too many verification attempts from this device. Try again in ${ipBurstResult.resetTime} minutes.`,
        429
      )
    }
    
    // Check IP-based daily limit
    const ipDailyResult = await services.rateLimiter.checkRateLimit(
      createIPRateLimitKey(clientIP, 'verify', 'daily'),
      'anonymous'
    )
    
    if (!ipDailyResult.allowed) {
      await services.analyticsLogger.logEvent('otp_verify_rate_limited', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        limit_type: 'ip_daily',
        attempts: ipDailyResult.currentUsage,
        limit: ipDailyResult.limit,
      }, clientIP)
      
      throw new AppError(
        'RATE_LIMIT',
        `Daily verification limit reached for this device. Try again tomorrow.`,
        429
      )
    }
  } catch (error) {
    // If it's already an AppError, rethrow it
    if (error instanceof AppError) {
      throw error
    }
    
    // Log rate limiter errors but allow request to proceed (fail-open)
    console.error('Rate limiter error during OTP verification:', error)
  }

  // ========================================================================
  // Verify OTP via Supabase Auth
  // ========================================================================
  
  const { data, error } = await services.supabaseServiceClient.auth.verifyOtp({
    phone: formattedPhone,
    token: otpCode,
    type: 'sms',
  })

  if (error) {
    // Record usage even for failed attempts to prevent brute force
    try {
      await Promise.all([
        services.rateLimiter.recordUsage(
          createPhoneRateLimitKey(formattedPhone, 'verify', 'burst'),
          'anonymous'
        ),
        services.rateLimiter.recordUsage(
          createPhoneRateLimitKey(formattedPhone, 'verify', 'daily'),
          'anonymous'
        ),
        services.rateLimiter.recordUsage(
          createIPRateLimitKey(clientIP, 'verify', 'burst'),
          'anonymous'
        ),
        services.rateLimiter.recordUsage(
          createIPRateLimitKey(clientIP, 'verify', 'daily'),
          'anonymous'
        ),
      ])
      
      // Log failed verification
      await services.analyticsLogger.logEvent('otp_verify_failed', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        outcome: 'failed',
        error_message: error.message,
      }, clientIP)
    } catch (usageError) {
      console.error('Failed to record failed OTP verification usage:', usageError)
    }
    
    throw new AppError('AUTH_ERROR', `Failed to verify OTP: ${error.message}`, 400)
  }

  if (!data.user) {
    // Record usage for failed verification attempts
    try {
      await Promise.all([
        services.rateLimiter.recordUsage(
          createPhoneRateLimitKey(formattedPhone, 'verify', 'burst'),
          'anonymous'
        ),
        services.rateLimiter.recordUsage(
          createPhoneRateLimitKey(formattedPhone, 'verify', 'daily'),
          'anonymous'
        ),
        services.rateLimiter.recordUsage(
          createIPRateLimitKey(clientIP, 'verify', 'burst'),
          'anonymous'
        ),
        services.rateLimiter.recordUsage(
          createIPRateLimitKey(clientIP, 'verify', 'daily'),
          'anonymous'
        ),
      ])
      
      await services.analyticsLogger.logEvent('otp_verify_failed', {
        phone_hash: formattedPhone.substring(0, 5) + '***',
        ip: clientIP,
        outcome: 'failed',
        reason: 'no_user_data',
      }, clientIP)
    } catch (usageError) {
      console.error('Failed to record failed OTP verification usage:', usageError)
    }
    
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
  
  // ========================================================================
  // Record successful verification usage and log analytics
  // ========================================================================
  
  try {
    // Record usage for all rate limit keys
    await Promise.all([
      services.rateLimiter.recordUsage(
        createPhoneRateLimitKey(formattedPhone, 'verify', 'burst'),
        'anonymous'
      ),
      services.rateLimiter.recordUsage(
        createPhoneRateLimitKey(formattedPhone, 'verify', 'daily'),
        'anonymous'
      ),
      services.rateLimiter.recordUsage(
        createIPRateLimitKey(clientIP, 'verify', 'burst'),
        'anonymous'
      ),
      services.rateLimiter.recordUsage(
        createIPRateLimitKey(clientIP, 'verify', 'daily'),
        'anonymous'
      ),
    ])
    
    // Log successful verification
    await services.analyticsLogger.logEvent('otp_verified', {
      phone_hash: formattedPhone.substring(0, 5) + '***',
      ip: clientIP,
      outcome: 'success',
      user_id: user.id,
      requires_onboarding: requiresOnboarding,
    }, clientIP)
  } catch (error) {
    // Don't fail the request if analytics/usage recording fails
    console.error('Failed to record OTP verification usage/analytics:', error)
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
      return sendOTP(body.phone_number, services, req)
      
    case 'verify_otp':
      if (!body.otp_code) {
        throw new AppError('VALIDATION_ERROR', 'OTP code required for verification', 400)
      }
      return verifyOTP(body.phone_number, body.otp_code, services, req)
      
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
