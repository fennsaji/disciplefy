/**
 * Resume Subscription Edge Function
 *
 * Allows authenticated users to resume their cancelled premium subscription.
 * Only works for subscriptions cancelled with cancel_at_cycle_end=true
 * that are still within their billing period.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { SubscriptionService } from '../_shared/services/subscription-service.ts'
import type { Subscription } from '../_shared/types/subscription-types.ts'
import type { PostgrestError } from 'https://esm.sh/@supabase/supabase-js@2'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

interface ResumeSubscriptionResponse {
  success: boolean
  subscription_id: string
  status: string
  resumed_at: string
  message: string
}

/**
 * Main subscription resume handler
 */
async function handleResumeSubscription(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  try {
    // 1. Authenticate user
    const userContext = await services.authService.getUserContext(req)

    if (userContext.type !== 'authenticated') {
      throw new AppError(
        'AUTHENTICATION_REQUIRED',
        'You must be logged in to resume a subscription',
        401
      )
    }

    const userId = userContext.userId!

    // 2. Create subscription service
    const subscriptionService = new SubscriptionService(services.supabaseServiceClient)

    // 3. Get user's pending_cancellation subscription (scheduled to cancel at period end)
    const { data: cancelledSubscription, error } = await services.supabaseServiceClient
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'pending_cancellation')
      .eq('cancel_at_cycle_end', true)
      .maybeSingle() as { data: Subscription | null, error: PostgrestError | null }

    if (error) {
      console.error('[ResumeSubscription] Database error:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to fetch subscription',
        500
      )
    }

    if (!cancelledSubscription) {
      throw new AppError(
        'SUBSCRIPTION_NOT_FOUND',
        'No pending cancellation found to resume',
        404
      )
    }

    // 4. Verify subscription is still within billing period
    if (cancelledSubscription.current_period_end) {
      const periodEnd = new Date(cancelledSubscription.current_period_end)
      const now = new Date()
      if (periodEnd <= now) {
        throw new AppError(
          'SUBSCRIPTION_EXPIRED',
          'Subscription period has expired and cannot be resumed',
          400
        )
      }
    }

    // 5. Resume subscription
    console.log(`[ResumeSubscription] Resuming subscription ${cancelledSubscription.id} for user ${userId}`)

    const resumedSubscription = await subscriptionService.resumeSubscription({
      userId,
      subscriptionId: cancelledSubscription.id
    })

    // 6. Log resumption
    await services.analyticsLogger.logEvent(
      'subscription_resumed',
      {
        subscription_id: resumedSubscription.id,
        razorpay_subscription_id: resumedSubscription.razorpay_subscription_id,
        resumed_at: new Date().toISOString(),
        user_id: userId
      }
    )

    // 7. Build response
    const response: ResumeSubscriptionResponse = {
      success: true,
      subscription_id: resumedSubscription.id,
      status: resumedSubscription.status,
      resumed_at: new Date().toISOString(),
      message: 'Subscription has been successfully resumed. Your premium access will continue.'
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    // Log error
    if (error instanceof AppError) {
      console.error(`[ResumeSubscription] AppError: ${error.code} - ${error.message}`)
    } else {
      console.error('[ResumeSubscription] Unexpected error:', error)
    }

    // Let error handler handle the response
    throw error
  }
}

/**
 * Export Edge Function using function factory
 */
createSimpleFunction(handleResumeSubscription, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
