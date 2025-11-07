/**
 * Cancel Subscription Edge Function
 *
 * Allows authenticated users to cancel their premium subscription.
 * Supports immediate cancellation or cancel at end of billing cycle.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { SubscriptionService } from '../_shared/services/subscription-service.ts'
import type {
  CancelSubscriptionRequest,
  CancelSubscriptionResponse
} from '../_shared/types/subscription-types.ts'

/**
 * Main subscription cancellation handler
 */
async function handleCancelSubscription(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  try {
    // 1. Authenticate user
    const userContext = await services.authService.getUserContext(req)

    if (userContext.type !== 'authenticated') {
      throw new AppError(
        'AUTHENTICATION_REQUIRED',
        'You must be logged in to cancel a subscription',
        401
      )
    }

    const userId = userContext.userId!

    // 2. Parse request body
    const body = await parseRequestBody(req)

    // 3. Create subscription service
    const subscriptionService = new SubscriptionService(services.supabaseServiceClient)

    // 4. Get user's active subscription
    const activeSubscription = await subscriptionService.getActiveSubscription(userId)

    if (!activeSubscription) {
      throw new AppError(
        'SUBSCRIPTION_NOT_FOUND',
        'No active subscription found',
        404
      )
    }

    // 5. Cancel subscription
    console.log(`[CancelSubscription] Cancelling subscription ${activeSubscription.id} for user ${userId}`)

    const cancelledSubscription = await subscriptionService.cancelSubscription({
      userId,
      subscriptionId: activeSubscription.id,
      cancelAtCycleEnd: body.cancel_at_cycle_end,
      reason: body.reason
    })

    // 6. Log cancellation
    await services.analyticsLogger.logEvent(
      'subscription_cancelled',
      {
        subscription_id: cancelledSubscription.id,
        razorpay_subscription_id: cancelledSubscription.razorpay_subscription_id,
        cancel_at_cycle_end: body.cancel_at_cycle_end,
        reason: body.reason || 'not_provided',
        cancelled_at: cancelledSubscription.cancelled_at,
        active_until: cancelledSubscription.current_period_end,
        user_id: userId
      }
    )

    // 7. Build response
    const response: CancelSubscriptionResponse = {
      success: true,
      subscription_id: cancelledSubscription.id,
      status: cancelledSubscription.status,
      cancelled_at: cancelledSubscription.cancelled_at!,
      active_until: body.cancel_at_cycle_end
        ? cancelledSubscription.current_period_end
        : null,
      message: body.cancel_at_cycle_end
        ? `Subscription will be cancelled at the end of your current billing period (${cancelledSubscription.current_period_end})`
        : 'Subscription cancelled immediately. Premium access has ended.'
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
      console.error(`[CancelSubscription] AppError: ${error.code} - ${error.message}`)
    } else {
      console.error('[CancelSubscription] Unexpected error:', error)
    }

    // Let error handler handle the response
    throw error
  }
}

/**
 * Type guard for CancelSubscriptionRequest
 * Validates that the value is an object with required cancel_at_cycle_end boolean
 * and optional reason string
 */
function isCancelSubscriptionRequest(value: unknown): value is CancelSubscriptionRequest {
  if (typeof value !== 'object' || value === null) {
    return false
  }

  const obj = value as Record<string, unknown>

  // Required: cancel_at_cycle_end must be boolean
  if (typeof obj.cancel_at_cycle_end !== 'boolean') {
    return false
  }

  // Optional: reason must be string if present
  if (obj.reason !== undefined && typeof obj.reason !== 'string') {
    return false
  }

  return true
}

/**
 * Parse and validate request body
 */
async function parseRequestBody(req: Request): Promise<CancelSubscriptionRequest> {
  let body: unknown

  try {
    body = await req.json()
  } catch (_error) {
    throw new AppError(
      'INVALID_REQUEST_BODY',
      'Request body must be valid JSON',
      400
    )
  }

  // Use type guard to validate structure
  if (!isCancelSubscriptionRequest(body)) {
    // Provide specific error messages by checking what failed
    if (typeof body !== 'object' || body === null) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Request body must be an object',
        400
      )
    }

    const obj = body as Record<string, unknown>

    // Validate cancel_at_cycle_end field
    if (typeof obj.cancel_at_cycle_end !== 'boolean') {
      throw new AppError(
        'VALIDATION_ERROR',
        'cancel_at_cycle_end is required and must be a boolean',
        400
      )
    }

    // Optional reason field
    if (obj.reason !== undefined && typeof obj.reason !== 'string') {
      throw new AppError(
        'VALIDATION_ERROR',
        'reason must be a string',
        400
      )
    }
  }

  // Type guard has validated the structure, safe to assert and return
  // This returns only the validated fields, not any additional properties from the request
  const validatedBody = body as CancelSubscriptionRequest
  return {
    cancel_at_cycle_end: validatedBody.cancel_at_cycle_end,
    reason: validatedBody.reason
  }
}

/**
 * Export Edge Function using function factory
 */
createSimpleFunction(handleCancelSubscription, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
