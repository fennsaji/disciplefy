/**
 * Create Standard Subscription Edge Function
 *
 * Allows authenticated users to create a Standard subscription (Rs.50/month).
 * Standard plan is free until March 31st, 2025. After that, subscription is required.
 * Returns Razorpay authorization URL for customer to complete payment setup.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { SubscriptionService } from '../_shared/services/subscription-service.ts'
import { isStandardTrialActive, isInGracePeriod, getPlanConfig } from '../_shared/config/subscription-config.ts'
import type { CreateSubscriptionResponse } from '../_shared/types/subscription-types.ts'

/**
 * Main Standard subscription creation handler
 */
async function handleCreateStandardSubscription(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  try {
    // 1. Authenticate user
    const userContext = await services.authService.getUserContext(req)

    if (userContext.type !== 'authenticated') {
      throw new AppError(
        'AUTHENTICATION_REQUIRED',
        'You must be logged in to create a subscription',
        401
      )
    }

    const userId = userContext.userId!

    // 2. Rate limiting (prevent spam)
    await services.rateLimiter.enforceRateLimit(userId, 'authenticated')

    // 3. Check if trial is still active (allow subscription during grace period)
    if (await isStandardTrialActive() && !await isInGracePeriod()) {
      throw new AppError(
        'TRIAL_STILL_ACTIVE',
        'Standard plan is currently free. Subscription will be required after March 31st, 2025.',
        400
      )
    }
    // Note: Users CAN subscribe during grace period (April 1-7) to continue access

    // 4. Validate user is on Standard plan
    const userPlan = await services.authService.getUserPlan(req)

    if (userPlan === 'premium') {
      throw new AppError(
        'ALREADY_PREMIUM',
        'You already have premium access. No need for Standard subscription.',
        400
      )
    }

    // 5. Check if user already has active standard subscription
    const { data: existingSubscription } = await services.supabaseServiceClient
      .from('subscriptions')
      .select('id, status, subscription_plan')
      .eq('user_id', userId)
      .eq('subscription_plan', 'standard')
      .in('status', ['active', 'authenticated', 'created', 'pending_cancellation'])
      .maybeSingle()

    if (existingSubscription) {
      throw new AppError(
        'SUBSCRIPTION_EXISTS',
        'You already have an active Standard subscription',
        400
      )
    }

    // 6. Create subscription service
    const subscriptionService = new SubscriptionService(services.supabaseServiceClient)

    // 7. Create Standard subscription
    console.log(`[CreateStandardSubscription] Creating subscription for user ${userId}`)

    const planConfig = await getPlanConfig('standard')

    const { subscription, shortUrl } = await subscriptionService.createSubscription({
      userId,
      planType: 'standard',  // Standard subscription (Rs.50/month)
      notes: {
        source: 'mobile_app',
        plan_name: planConfig.name,
        created_at: new Date().toISOString()
      }
    })

    // 8. Log success
    await services.analyticsLogger.logEvent(
      'standard_subscription_created',
      {
        subscription_id: subscription.id,
        razorpay_subscription_id: subscription.razorpay_subscription_id,
        amount_rupees: planConfig.price,
        status: subscription.status,
        user_id: userId
      }
    )

    // 9. Build response
    const response: CreateSubscriptionResponse = {
      success: true,
      subscription_id: subscription.id,
      razorpay_subscription_id: subscription.razorpay_subscription_id,
      short_url: shortUrl,
      amount_rupees: planConfig.price,
      status: subscription.status,
      message: 'Standard subscription created successfully. Complete payment authorization to activate.'
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
      console.error(`[CreateStandardSubscription] AppError: ${error.code} - ${error.message}`)
    } else {
      console.error('[CreateStandardSubscription] Unexpected error:', error)
    }

    // Let error handler handle the response
    throw error
  }
}

/**
 * Export Edge Function using function factory
 */
createSimpleFunction(handleCreateStandardSubscription, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
