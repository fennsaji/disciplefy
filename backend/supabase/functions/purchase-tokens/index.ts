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
import { TokenPurchaseRequest } from '../_shared/types/token-types.ts'
import Razorpay from 'npm:razorpay'
import { createHmac } from 'node:crypto'

/**
 * Token purchase handler - main orchestrator
 * 
 * This handler processes token purchases for authenticated users
 */
async function handleTokenPurchase(req: Request, services: ServiceContainer): Promise<Response> {
  try {
    const userContext = await authenticateAndAuthorize(req, services.authService, services.rateLimiter, services.tokenService)
    const { tokenAmount, paymentId } = await parseAndValidateRequestBody(req)
    await checkForDuplicatePayment(paymentId, services.supabaseServiceClient)
    const { costInRupees, costInPaise } = computeCost(tokenAmount, services.tokenService)
    const paymentResult = await createOrder({
      amount: costInPaise,
      currency: 'INR',
      user_id: userContext.userId!,
      token_amount: tokenAmount,
      metadata: {
        user_plan: userContext.userPlan,
        timestamp: new Date().toISOString()
      }
    })
    await persistPendingPurchase({
      user_id: userContext.userId!,
      order_id: paymentResult.order_id!,
      token_amount: tokenAmount,
      amount_paise: costInPaise
    }, services.supabaseServiceClient)
    
    return logSuccessAndRespond({
      orderId: paymentResult.order_id!,
      amount: costInPaise,
      tokenAmount,
      costInRupees,
      userPlan: userContext.userPlan,
      userId: userContext.userId!
    }, services.analyticsLogger, req.headers.get('x-forwarded-for'))
    
  } catch (error) {
    await logFailure(error, services.analyticsLogger, req.headers.get('x-forwarded-for'))
    throw error instanceof AppError ? error : new AppError(
      'ORDER_CREATION_ERROR',
      'Failed to create payment order',
      500
    )
  }
}

/**
 * Authenticate user and authorize purchase operation
 */
async function authenticateAndAuthorize(req: Request, authService: any, rateLimiter: any, tokenService: any): Promise<{ userId: string, userPlan: string }> {
  const userContext = await authService.getUserContext(req)
  
  if (userContext.type !== 'authenticated') {
    throw new AppError(
      'AUTHENTICATION_REQUIRED',
      'You must be logged in to purchase tokens',
      401
    )
  }

  await rateLimiter.enforceRateLimit(userContext.userId!, 'authenticated')
  const userPlan = await authService.getUserPlan(req)
  
  if (!tokenService.canPurchaseTokens(userPlan)) {
    throw new AppError(
      'PURCHASE_NOT_ALLOWED',
      `${userPlan} plan users cannot purchase tokens`,
      403
    )
  }

  return { userId: userContext.userId!, userPlan }
}

/**
 * Parse and validate request body
 */
async function parseAndValidateRequestBody(req: Request): Promise<{ tokenAmount: number, paymentId?: string }> {
  if (req.method !== 'POST') {
    throw new AppError(
      'METHOD_NOT_ALLOWED',
      'Token purchase endpoint only supports POST requests',
      405
    )
  }

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

  if (!body.token_amount || typeof body.token_amount !== 'number') {
    throw new AppError(
      'VALIDATION_ERROR',
      'token_amount is required and must be a number',
      400
    )
  }

  if (!Number.isInteger(body.token_amount) || body.token_amount < 1 || body.token_amount > 10000) {
    throw new AppError(
      'INVALID_TOKEN_AMOUNT',
      'Token amount must be an integer between 1 and 10,000',
      400
    )
  }

  return {
    tokenAmount: body.token_amount,
    paymentId: body.payment_id
  }
}

/**
 * Check for duplicate payment to prevent double-spending
 */
async function checkForDuplicatePayment(paymentId: string | undefined, supabaseServiceClient: any): Promise<void> {
  if (!paymentId) return
  
  const { data, error } = await supabaseServiceClient
    .from('purchase_history')
    .select('id')
    .eq('razorpay_payment_id', paymentId)
    .single()

  if (error && error.code !== 'PGRST116') {
    console.error('[Database] Error checking existing payment:', error)
    throw new AppError(
      'DATABASE_ERROR',
      'Failed to verify payment uniqueness',
      500
    )
  }

  if (data !== null) {
    throw new AppError(
      'DUPLICATE_PAYMENT',
      'This payment has already been processed',
      409
    )
  }
}

/**
 * Compute cost in rupees and paise
 */
function computeCost(tokenAmount: number, tokenService: any): { costInRupees: number, costInPaise: number } {
  const costInRupees = tokenService.calculateCostInRupees(tokenAmount)
  
  if (!Number.isFinite(costInRupees)) {
    throw new AppError(
      'INVALID_COST',
      'Invalid cost calculation',
      400
    )
  }
  
  const costInPaise = Math.round(costInRupees * 100)
  return { costInRupees, costInPaise }
}

/**
 * Create Razorpay order
 */
async function createOrder(params: {
  amount: number
  currency: string
  user_id: string
  token_amount: number
  metadata: Record<string, any>
}): Promise<{ success: boolean, order_id?: string, error?: string }> {
  const paymentResult = await processRazorpayPayment(params)

  if (!paymentResult.success) {
    throw new AppError(
      'PAYMENT_FAILED',
      paymentResult.error || 'Payment processing failed',
      402
    )
  }

  return paymentResult
}

/**
 * Persist pending purchase for webhook confirmation (idempotent)
 */
async function persistPendingPurchase(params: {
  user_id: string
  order_id: string
  token_amount: number
  amount_paise: number
}, supabaseServiceClient: any): Promise<void> {
  const { data: purchaseId, error } = await supabaseServiceClient
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

  if (!purchaseId) {
    console.error('[Database] Pending purchase storage returned null ID')
    throw new AppError(
      'DATABASE_ERROR',
      'Failed to create pending purchase record',
      500
    )
  }

  console.log(`[Database] Pending purchase stored successfully: ${params.order_id} (ID: ${purchaseId})`)
}

/**
 * Log success event and return response
 */
async function logSuccessAndRespond(params: {
  orderId: string
  amount: number
  tokenAmount: number
  costInRupees: number
  userPlan: string
  userId: string
}, analyticsLogger: any, forwardedFor: string | null): Promise<Response> {
  // Validate RAZORPAY_KEY_ID is configured before including in response
  const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID')
  if (!razorpayKeyId) {
    console.error('[Payment] RAZORPAY_KEY_ID not configured')
    return new Response(JSON.stringify({
      success: false,
      error: 'Payment service is not properly configured'
    }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  await analyticsLogger.logEvent('payment_order_created', {
    user_id: params.userId,
    order_id: params.orderId,
    token_amount: params.tokenAmount,
    cost_in_paise: params.amount,
    cost_in_rupees: params.costInRupees,
    user_plan: params.userPlan
  }, forwardedFor)

  return new Response(JSON.stringify({
    success: true,
    order_id: params.orderId,
    amount: params.amount,
    currency: 'INR',
    key_id: razorpayKeyId,
    token_amount: params.tokenAmount
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Log failure event
 */
async function logFailure(error: any, analyticsLogger: any, forwardedFor: string | null): Promise<void> {
  await analyticsLogger.logEvent('payment_order_failed', {
    error_message: error instanceof Error ? error.message : 'Unknown error'
  }, forwardedFor)
  
  console.error('[PurchaseTokens] Unexpected error:', error)
}

/**
 * Processes Razorpay payment - Real implementation with simulator fallback
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
  error?: string 
}> {
  // Check if we should use simulator (only in development)
  const useSimulator = Deno.env.get('SIMULATE_RAZORPAY') === 'true'
  
  if (useSimulator) {
    console.log('[Razorpay Simulator] Creating mock order')
    return {
      success: true,
      order_id: `order_sim_${Date.now()}`
      // Note: payment_id will be provided by webhook once payment completes
    }
  }

  // Production/staging Razorpay integration - validate environment variables
  const keyId = Deno.env.get('RAZORPAY_KEY_ID')
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')
  
  if (!keyId) {
    console.error('[Razorpay] RAZORPAY_KEY_ID not configured')
    return {
      success: false,
      error: 'Payment service not properly configured: RAZORPAY_KEY_ID missing'
    }
  }
  
  if (!keySecret) {
    console.error('[Razorpay] RAZORPAY_KEY_SECRET not configured')
    return {
      success: false,
      error: 'Payment service not properly configured: RAZORPAY_KEY_SECRET missing'
    }
  }

  const razorpay = new Razorpay({
    key_id: keyId,
    key_secret: keySecret
  })

  try {
    console.log(`[Razorpay] Creating order for ${params.amount} paise`)
    
    // Create Razorpay order
    const order = await razorpay.orders.create({
      amount: params.amount,
      currency: params.currency,
      receipt: `tk_${params.user_id.slice(-8)}_${Date.now()}`.slice(0, 40),
      notes: {
        user_id: params.user_id,
        token_amount: params.token_amount.toString(),
        purchase_type: 'token_purchase',
        ...params.metadata
      }
    })

    console.log(`[Razorpay] Order created: ${order.id}`)
    
    // TODO: Implement signature verification for production
    // For real integration, verify webhook signature and order details
    // before accepting payments
    
    return {
      success: true,
      order_id: order.id
      // Note: payment_id will be provided by webhook once payment completes
    }

  } catch (error) {
    console.error('[Razorpay] Order creation failed:', error)
    
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Payment processing failed'
    }
  }
}



// Create the Edge Function using the factory pattern
createSimpleFunction(handleTokenPurchase, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})