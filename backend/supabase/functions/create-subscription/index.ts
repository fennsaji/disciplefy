/**
 * Create Subscription Edge Function
 *
 * Allows authenticated users to create a premium subscription (₹100/month).
 * Returns Razorpay authorization URL for customer to complete payment setup.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { SubscriptionService } from '../_shared/services/subscription-service.ts'
import type { CreateSubscriptionResponse } from '../_shared/types/subscription-types.ts'

/**
 * Main subscription creation handler
 */
async function handleCreateSubscription(
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

    // 3. Validate user is on standard or free plan
    const userPlan = await services.authService.getUserPlan(req)

    if (userPlan === 'premium') {
      throw new AppError(
        'ALREADY_PREMIUM',
        'You already have premium access',
        400
      )
    }

    // 4. Create subscription service
    const subscriptionService = new SubscriptionService(services.supabaseServiceClient)

    // 5. Create subscription
    console.log(`[CreateSubscription] Creating subscription for user ${userId}`)

    const { subscription, shortUrl } = await subscriptionService.createSubscription({
      userId,
      notes: {
        source: 'mobile_app',
        created_at: new Date().toISOString()
      }
    })

    // 6. Log success
    await services.analyticsLogger.logEvent(
      'subscription_created',
      {
        subscription_id: subscription.id,
        razorpay_subscription_id: subscription.razorpay_subscription_id,
        amount_rupees: subscription.amount_paise / 100,
        status: subscription.status,
        user_id: userId
      }
    )

    // 7. Build response
    const response: CreateSubscriptionResponse = {
      success: true,
      subscription_id: subscription.id,
      razorpay_subscription_id: subscription.razorpay_subscription_id,
      short_url: shortUrl,
      amount_rupees: subscription.amount_paise / 100,
      status: subscription.status,
      message: 'Subscription created successfully. Complete payment authorization to activate.'
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
      console.error(`[CreateSubscription] AppError: ${error.code} - ${error.message}`)
    } else {
      console.error('[CreateSubscription] Unexpected error:', error)
    }

    // Let error handler handle the response
    throw error
  }
}

/**
 * Export Edge Function using function factory
 */
createSimpleFunction(handleCreateSubscription, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
