/**
 * Token Purchase Edge Function
 * 
 * Handles token purchase requests for authenticated users.
 * Integrates with Razorpay payment processing and adds purchased
 * tokens to user accounts that never reset.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { RequestValidator } from '../_shared/utils/request-validator.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { TokenPurchaseRequest, TokenPurchaseResult } from '../_shared/types/token-types.ts'

/**
 * Token purchase handler
 * 
 * This handler processes token purchases for authenticated users:
 * 1. Validates user is authenticated (no anonymous purchases)
 * 2. Validates token amount and payment information
 * 3. Processes payment via Razorpay integration
 * 4. Adds purchased tokens to user account
 * 5. Returns updated token balance
 */
async function handleTokenPurchase(req: Request, services: ServiceContainer): Promise<Response> {
  const { authService, tokenService, analyticsLogger } = services
  // 1. Get user context and ensure user is authenticated
  const userContext = await authService.getUserContext(req)
  
  if (userContext.type !== 'authenticated') {
    throw new AppError(
      'AUTHENTICATION_REQUIRED',
      'You must be logged in to purchase tokens',
      401
    )
  }

  // 2. Determine user plan
  const userPlan = await authService.getUserPlan(req)
  
  // 3. Validate user can purchase tokens (only standard plan)
  if (!tokenService.canPurchaseTokens(userPlan)) {
    throw new AppError(
      'PURCHASE_NOT_ALLOWED',
      `${userPlan} plan users cannot purchase tokens`,
      403
    )
  }

  // 4. Parse and validate request
  const { token_amount, payment_method_id } = await parseAndValidateRequest(req)
  
  // 5. Calculate cost in paise for Razorpay (10 tokens = ₹1 = 100 paise)
  const costInRupees = tokenService.calculateCostInRupees(token_amount)
  const costInPaise = costInRupees * 100
  
  try {
    // 6. Process payment via Razorpay
    // Note: This is a placeholder for Razorpay integration
    // In a real implementation, you would integrate with Razorpay SDK
    const paymentResult = await processRazorpayPayment({
      amount: costInPaise,
      currency: 'INR',
      payment_method_id,
      user_id: userContext.userId!,
      metadata: {
        token_amount,
        purchase_type: 'token_purchase'
      }
    })

    if (paymentResult.status !== 'captured') {
      throw new AppError(
        'PAYMENT_FAILED',
        'Payment processing failed',
        402
      )
    }

    // 7. Add purchased tokens to user account
    const addResult = await tokenService.addPurchasedTokens(
      userContext.userId!,
      userPlan,
      token_amount,
      {
        userId: userContext.userId,
        userPlan: userPlan,
        operation: 'purchase',
        ipAddress: req.headers.get('x-forwarded-for') || undefined,
        userAgent: req.headers.get('user-agent') || undefined,
        timestamp: new Date()
      }
    )

    // 8. Get updated token information
    const updatedTokenInfo = await tokenService.getUserTokens(
      userContext.userId!,
      userPlan
    )

    // 9. Log successful purchase for analytics
    await analyticsLogger.logEvent('token_purchase_success', {
      user_id: userContext.userId,
      token_amount,
      cost_in_paise: costInPaise,
      cost_in_rupees: costInRupees,
      payment_id: paymentResult.payment_id,
      user_plan: userPlan
    }, req.headers.get('x-forwarded-for'))

    // 10. Build success response
    const response: TokenPurchaseResult = {
      success: true,
      tokens_purchased: token_amount,
      cost_paid: costInRupees,
      tokens_per_rupee: 10,
      new_token_balance: updatedTokenInfo,
      payment_id: paymentResult.payment_id
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    // Log failed purchase for analytics
    await analyticsLogger.logEvent('token_purchase_failed', {
      user_id: userContext.userId,
      token_amount,
      cost_in_paise: costInPaise,
      error_message: error instanceof Error ? error.message : 'Unknown error',
      user_plan: userPlan
    }, req.headers.get('x-forwarded-for'))

    // Re-throw AppErrors, wrap others
    if (error instanceof AppError) {
      throw error
    }

    console.error('[PurchaseTokens] Unexpected error:', error)
    throw new AppError(
      'PURCHASE_ERROR',
      'Failed to process token purchase',
      500
    )
  }
}

/**
 * Parses and validates token purchase request
 */
async function parseAndValidateRequest(req: Request): Promise<TokenPurchaseRequest> {
  if (req.method !== 'POST') {
    throw new AppError(
      'METHOD_NOT_ALLOWED',
      'Token purchase endpoint only supports POST requests',
      405
    )
  }

  const requestValidator = new RequestValidator()
  
  let body
  try {
    body = await req.json()
  } catch {
    throw new AppError(
      'INVALID_REQUEST_BODY',
      'Request body must be valid JSON',
      400
    )
  }

  // Validate required fields
  if (!body.token_amount || typeof body.token_amount !== 'number') {
    throw new AppError(
      'VALIDATION_ERROR',
      'token_amount is required and must be a number',
      400
    )
  }

  if (!body.payment_method_id || typeof body.payment_method_id !== 'string') {
    throw new AppError(
      'VALIDATION_ERROR', 
      'payment_method_id is required and must be a string',
      400
    )
  }

  // Validate token amount range (1-10,000)
  if (!Number.isInteger(body.token_amount) || body.token_amount < 1 || body.token_amount > 10000) {
    throw new AppError(
      'INVALID_TOKEN_AMOUNT',
      'Token amount must be an integer between 1 and 10,000',
      400
    )
  }

  // Validate payment method ID format (basic validation)
  if (body.payment_method_id.length < 10 || body.payment_method_id.length > 100) {
    throw new AppError(
      'INVALID_PAYMENT_METHOD',
      'Invalid payment method ID format',
      400
    )
  }

  return {
    token_amount: body.token_amount,
    payment_method_id: body.payment_method_id
  }
}

/**
 * Processes Razorpay payment (placeholder implementation)
 * 
 * Note: This is a simplified implementation. In a real application,
 * you would integrate with the actual Razorpay SDK and handle
 * webhooks for payment confirmation.
 */
async function processRazorpayPayment(params: {
  amount: number
  currency: string
  payment_method_id: string
  user_id: string
  metadata: Record<string, any>
}): Promise<{ status: string; payment_id: string }> {
  // TODO: Replace with actual Razorpay integration
  // This is a placeholder that simulates successful payment
  
  console.log('[PurchaseTokens] Processing Razorpay payment:', {
    amount: params.amount,
    currency: params.currency,
    user_id: params.user_id,
    metadata: params.metadata
  })

  // Simulate payment processing delay
  await new Promise(resolve => setTimeout(resolve, 100))

  // For development/testing: simulate successful payment
  // In production, this would integrate with Razorpay SDK:
  /*
  const razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID!,
    key_secret: process.env.RAZORPAY_KEY_SECRET!
  })

  const order = await razorpay.orders.create({
    amount: params.amount,
    currency: params.currency,
    payment_capture: true,
    receipt: `token_purchase_${params.user_id}_${Date.now()}`,
    notes: params.metadata
  })

  // Process payment with payment_method_id
  const payment = await razorpay.payments.capture(
    params.payment_method_id,
    params.amount
  )
  */

  return {
    status: 'captured',
    payment_id: `razorpay_${Date.now()}_${Math.random().toString(36).substring(2)}`
  }
}

// Create the Edge Function using the factory pattern
createSimpleFunction(handleTokenPurchase, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})