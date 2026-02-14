/**
 * Start Premium Trial Edge Function
 *
 * Allows eligible users to start a 7-day Premium trial.
 * Eligibility: User must have signed up after April 1st, 2025
 * and not have already used their trial.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import {
  isPremiumTrialAvailable,
  canStartPremiumTrial,
  calculatePremiumTrialEndDate,
  PREMIUM_TRIAL_DAYS
} from '../_shared/config/subscription-config.ts'

/**
 * Response type for starting Premium trial
 */
interface StartPremiumTrialResponse {
  success: boolean
  trial_started_at: string
  trial_end_at: string
  days_remaining: number
  message: string
}

/**
 * Main Premium trial start handler
 */
async function handleStartPremiumTrial(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  try {
    // 1. Authenticate user
    const userContext = await services.authService.getUserContext(req)

    if (userContext.type !== 'authenticated') {
      throw new AppError(
        'AUTHENTICATION_REQUIRED',
        'You must be logged in to start a Premium trial',
        401
      )
    }

    const userId = userContext.userId!

    // 2. Rate limiting (prevent spam)
    await services.rateLimiter.enforceRateLimit(userId, 'authenticated')

    // 3. Check if Premium trial feature is available (after April 1st, 2025)
    if (!isPremiumTrialAvailable()) {
      throw new AppError(
        'TRIAL_NOT_AVAILABLE',
        'Premium trial is not available yet. It will be available from April 1st, 2025.',
        400
      )
    }

    // 4. Check if user already has active subscription
    const userPlan = await services.authService.getUserPlan(req)

    if (userPlan === 'premium') {
      throw new AppError(
        'ALREADY_PREMIUM',
        'You already have Premium access.',
        400
      )
    }

    // 5. Get user creation date and check eligibility
    const { data: userProfile } = await services.supabaseServiceClient
      .from('user_profiles')
      .select('created_at, has_used_premium_trial, premium_trial_end_at')
      .eq('id', userId)
      .maybeSingle()

    // Check if user has already used their trial
    if (userProfile?.has_used_premium_trial) {
      throw new AppError(
        'TRIAL_ALREADY_USED',
        'You have already used your Premium trial.',
        400
      )
    }

    // Check if user is currently in a trial (shouldn't happen, but safety check)
    if (userProfile?.premium_trial_end_at) {
      const trialEndDate = new Date(userProfile.premium_trial_end_at)
      if (trialEndDate > new Date()) {
        throw new AppError(
          'TRIAL_ALREADY_ACTIVE',
          'You already have an active Premium trial.',
          400
        )
      }
    }

    // Get user creation date (from auth.users if not in profile)
    let userCreatedAt: Date

    if (userProfile?.created_at) {
      userCreatedAt = new Date(userProfile.created_at)
    } else {
      // Fallback: get from auth.users via RPC
      const { data: authCreatedAt } = await services.supabaseServiceClient
        .rpc('get_user_created_at', { p_user_id: userId })

      if (authCreatedAt) {
        userCreatedAt = new Date(authCreatedAt)
      } else {
        // Default to now if we can't determine (will fail eligibility check)
        userCreatedAt = new Date()
      }
    }

    // Check if user signed up after April 1st, 2025
    if (!await canStartPremiumTrial(userCreatedAt)) {
      throw new AppError(
        'NOT_ELIGIBLE',
        'Premium trial is only available for users who signed up after April 1st, 2025.',
        400
      )
    }

    // 6. Start the Premium trial
    const trialStartedAt = new Date()
    const trialEndAt = await calculatePremiumTrialEndDate(trialStartedAt)

    console.log(`[StartPremiumTrial] Starting trial for user ${userId}`)
    console.log(`[StartPremiumTrial] Trial period: ${trialStartedAt.toISOString()} to ${trialEndAt.toISOString()}`)

    // Update or insert user profile with trial information
    const { error: updateError } = await services.supabaseServiceClient
      .from('user_profiles')
      .upsert({
        id: userId,
        premium_trial_started_at: trialStartedAt.toISOString(),
        premium_trial_end_at: trialEndAt.toISOString(),
        has_used_premium_trial: true,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'id'
      })

    if (updateError) {
      console.error('[StartPremiumTrial] Failed to update user profile:', updateError)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to start Premium trial. Please try again.',
        500
      )
    }

    // 7. Log success
    await services.analyticsLogger.logEvent(
      'premium_trial_started',
      {
        user_id: userId,
        trial_started_at: trialStartedAt.toISOString(),
        trial_end_at: trialEndAt.toISOString(),
        trial_days: PREMIUM_TRIAL_DAYS
      }
    )

    // 8. Build response
    const response: StartPremiumTrialResponse = {
      success: true,
      trial_started_at: trialStartedAt.toISOString(),
      trial_end_at: trialEndAt.toISOString(),
      days_remaining: PREMIUM_TRIAL_DAYS,
      message: `Your ${PREMIUM_TRIAL_DAYS}-day Premium trial has started! Enjoy unlimited access to all features.`
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 201,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    // Log error
    if (error instanceof AppError) {
      console.error(`[StartPremiumTrial] AppError: ${error.code} - ${error.message}`)
    } else {
      console.error('[StartPremiumTrial] Unexpected error:', error)
    }

    // Let error handler handle the response
    throw error
  }
}

/**
 * Export Edge Function using function factory
 */
createSimpleFunction(handleStartPremiumTrial, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
