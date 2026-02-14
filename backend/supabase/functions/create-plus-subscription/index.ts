/**
 * Create Plus Subscription Edge Function
 *
 * Allows authenticated users to create a Plus subscription (₹149/month).
 * Plus plan offers enhanced features including 50 daily tokens, 10 follow-ups per guide,
 * 10 AI Discipler conversations/month, and more.
 * Returns Razorpay authorization URL for customer to complete payment setup.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { SubscriptionService } from '../_shared/services/subscription-service.ts'
import { getPlanConfig } from '../_shared/config/subscription-config.ts'
import type { CreateSubscriptionResponse } from '../_shared/types/subscription-types.ts'

/**
 * Main Plus subscription creation handler
 */
async function handleCreatePlusSubscription(
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

    // 3. Validate user is not on Premium plan
    const userPlan = await services.authService.getUserPlan(req)

    if (userPlan === 'premium') {
      throw new AppError(
        'ALREADY_PREMIUM',
        'You already have premium access. No need for Plus subscription.',
        400
      )
    }

    // 4. Check if user already has active Plus subscription
    const { data: existingSubscription } = await services.supabaseServiceClient
      .from('subscriptions')
      .select('id, status, subscription_plan')
      .eq('user_id', userId)
      .eq('subscription_plan', 'plus')
      .in('status', ['active', 'authenticated', 'created', 'pending_cancellation'])
      .maybeSingle()

    if (existingSubscription) {
      throw new AppError(
        'SUBSCRIPTION_EXISTS',
        'You already have an active Plus subscription',
        400
      )
    }

    // 5. Create subscription service
    const subscriptionService = new SubscriptionService(services.supabaseServiceClient)

    // 6. Create Plus subscription
    console.log(`[CreatePlusSubscription] Creating subscription for user ${userId}`)

    const planConfig = await getPlanConfig('plus')

    const { subscription, shortUrl } = await subscriptionService.createSubscription({
      userId,
      planType: 'plus',  // Plus subscription (₹149/month)
      notes: {
        source: 'mobile_app',
        plan_name: planConfig.name,
        created_at: new Date().toISOString()
      }
    })

    // 7. Log success
    await services.analyticsLogger.logEvent(
      'plus_subscription_created',
      {
        subscription_id: subscription.id,
        razorpay_subscription_id: subscription.razorpay_subscription_id,
        amount_rupees: planConfig.price,
        status: subscription.status,
        user_id: userId
      }
    )

    // 8. Build response
    const response: CreateSubscriptionResponse = {
      success: true,
      subscription_id: subscription.id,
      razorpay_subscription_id: subscription.razorpay_subscription_id,
      short_url: shortUrl,
      amount_rupees: planConfig.price,
      status: subscription.status,
      message: 'Plus subscription created successfully. Complete payment authorization to activate.'
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
      console.error(`[CreatePlusSubscription] AppError: ${error.code} - ${error.message}`)
    } else {
      console.error('[CreatePlusSubscription] Unexpected error:', error)
    }

    // Let error handler handle the response
    throw error
  }
}

/**
 * Export Edge Function using function factory
 */
createSimpleFunction(handleCreatePlusSubscription, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
