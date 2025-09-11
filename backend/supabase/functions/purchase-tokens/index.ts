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
import Razorpay from 'npm:razorpay@2.9.2'
import { createHmac } from 'node:crypto'

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
  const { token_amount } = await parseAndValidateRequest(req)
  
  // 5. Calculate cost in paise for Razorpay (10 tokens = ₹1 = 100 paise)
  const costInRupees = tokenService.calculateCostInRupees(token_amount)
  const costInPaise = costInRupees * 100
  
  try {
    // 6. Process payment via Razorpay - Create order
    const paymentResult = await processRazorpayPayment({
      amount: costInPaise,
      currency: 'INR',
      user_id: userContext.userId!,
      token_amount,
      metadata: {
        user_plan: userPlan,
        timestamp: new Date().toISOString()
      }
    })

    if (!paymentResult.success) {
      throw new AppError(
        'PAYMENT_FAILED',
        paymentResult.error || 'Payment processing failed',
        402
      )
    }

    // 7. Store pending purchase (will be confirmed by webhook)
    await storePendingPurchase({
      user_id: userContext.userId!,
      order_id: paymentResult.order_id!,
      token_amount,
      amount_paise: costInPaise
    }, services)

    // 8. Log order creation for analytics
    await analyticsLogger.logEvent('payment_order_created', {
      user_id: userContext.userId,
      order_id: paymentResult.order_id,
      token_amount,
      cost_in_paise: costInPaise,
      cost_in_rupees: costInRupees,
      user_plan: userPlan
    }, req.headers.get('x-forwarded-for'))

    // 9. Return order details for frontend payment
    return new Response(JSON.stringify({
      success: true,
      order_id: paymentResult.order_id,
      amount: costInPaise,
      currency: 'INR',
      key_id: Deno.env.get('RAZORPAY_KEY_ID'),
      token_amount
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    // Log failed order creation for analytics
    await analyticsLogger.logEvent('payment_order_failed', {
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
      'ORDER_CREATION_ERROR',
      'Failed to create payment order',
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

  // payment_method_id is no longer required for order creation
  // Payment will be processed via frontend Razorpay checkout

  // Validate token amount range (1-10,000)
  if (!Number.isInteger(body.token_amount) || body.token_amount < 1 || body.token_amount > 10000) {
    throw new AppError(
      'INVALID_TOKEN_AMOUNT',
      'Token amount must be an integer between 1 and 10,000',
      400
    )
  }

  // No payment method validation needed for order creation

  return {
    token_amount: body.token_amount
  }
}

/**
 * Processes Razorpay payment - Real implementation
 * Creates a Razorpay order for frontend payment processing
 */
async function processRazorpayPayment(params: {
  amount: number           // Amount in paise
  currency: string         // 'INR'
  user_id: string
  token_amount: number
  metadata: Record<string, any>
}): Promise<{ 
  success: boolean
  order_id?: string
  payment_id?: string
  error?: string 
}> {
  const razorpay = new Razorpay({
    key_id: Deno.env.get('RAZORPAY_KEY_ID')!,
    key_secret: Deno.env.get('RAZORPAY_KEY_SECRET')!
  })

  try {
    console.log(`[Razorpay] Creating order for ${params.amount} paise`)
    
    // Create Razorpay order
    const order = await razorpay.orders.create({
      amount: params.amount,
      currency: params.currency,
      receipt: `token_${params.user_id}_${Date.now()}`,
      notes: {
        user_id: params.user_id,
        token_amount: params.token_amount.toString(),
        purchase_type: 'token_purchase',
        ...params.metadata
      }
    })

    console.log(`[Razorpay] Order created: ${order.id}`)
    
    return {
      success: true,
      order_id: order.id,
      payment_id: order.id  // Will be updated by webhook
    }

  } catch (error) {
    console.error('[Razorpay] Order creation failed:', error)
    
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Payment processing failed'
    }
  }
}

/**
 * Stores pending purchase for webhook confirmation
 */
async function storePendingPurchase(params: {
  user_id: string
  order_id: string
  token_amount: number
  amount_paise: number
}, services: ServiceContainer): Promise<void> {
  const { supabaseServiceClient } = services
  
  const { data, error } = await supabaseServiceClient
    .rpc('store_pending_purchase', {
      p_user_id: params.user_id,
      p_order_id: params.order_id,
      p_token_amount: params.token_amount,
      p_amount_paise: params.amount_paise
    })

  if (error) {
    console.error('[Database] Failed to store pending purchase:', error)
    throw new AppError(
      'DATABASE_ERROR',
      'Failed to store purchase record',
      500
    )
  }
}

// Create the Edge Function using the factory pattern
createSimpleFunction(handleTokenPurchase, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})