/**
 * Confirm Token Purchase Edge Function
 * 
 * Handles manual payment confirmation with signature verification
 * for frontend payment completion
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { createHmac } from 'node:crypto'

interface ConfirmPurchaseRequest {
  order_id: string
  payment_id: string
  signature: string
}

/**
 * Handle payment confirmation with signature verification - main orchestrator
 */
async function handleConfirmPurchase(req: Request, services: ServiceContainer): Promise<Response> {
  try {
    const userContext = await authenticateUser(req, services.authService)
    const requestData = await parseAndValidateRequest(req)
    await verifySignature(requestData)
    const pendingPurchase = await loadPendingPurchase(requestData.order_id, userContext.userId!, services.supabaseServiceClient)
    
    // Check if already processed
    const shortCircuitResponse = await shortCircuitIfCompletedOrFailed(pendingPurchase, userContext.userId!, services.tokenService)
    if (shortCircuitResponse) {
      return shortCircuitResponse
    }
    
    // Atomic claim for processing to prevent double-processing
    const claimedPurchase = await claimPendingPurchaseForProcessing(pendingPurchase.order_id, services.supabaseServiceClient)
    
    // Process the purchase
    const addResult = await creditTokens(userContext.userId!, claimedPurchase.token_amount, services.tokenService)
    await recordPurchaseHistory(claimedPurchase, requestData.payment_id, userContext.userId!, services.supabaseServiceClient)
    await markPendingCompleted(claimedPurchase.order_id, requestData.payment_id, services.supabaseServiceClient)
    
    // Get updated tokens and log success
    const updatedTokens = await services.tokenService.getUserTokens(userContext.userId!, 'standard')
    await services.analyticsLogger.logEvent('purchase_confirmed_by_user', {
      user_id: userContext.userId,
      order_id: requestData.order_id,
      payment_id: requestData.payment_id,
      token_amount: claimedPurchase.token_amount,
      new_purchased_balance: addResult.newPurchasedBalance
    })
    
    return buildResponse({
      success: true,
      message: 'Purchase confirmed successfully',
      tokens_added: claimedPurchase.token_amount,
      token_balance: updatedTokens
    })
    
  } catch (error) {
    console.error('[Purchase] Failed to confirm purchase:', error)
    
    // Extract order_id for failure marking if available
    try {
      const requestData = await parseAndValidateRequest(req)
      await markPendingFailed(requestData.order_id, error, services.supabaseServiceClient)
    } catch {
      // Ignore parsing errors during error handling
    }
    
    throw error instanceof AppError ? error : new AppError(
      'PURCHASE_CONFIRMATION_FAILED',
      'Failed to confirm token purchase',
      500
    )
  }
}

/**
 * Authenticate user and ensure they're logged in
 */
async function authenticateUser(req: Request, authService: any): Promise<any> {
  const userContext = await authService.getUserContext(req)
  if (userContext.type !== 'authenticated') {
    throw new AppError(
      'AUTHENTICATION_REQUIRED',
      'You must be logged in to confirm purchase',
      401
    )
  }
  return userContext
}

/**
 * Parse and validate request body
 */
async function parseAndValidateRequest(req: Request): Promise<ConfirmPurchaseRequest> {
  const requestData: ConfirmPurchaseRequest = await req.json()
  
  if (!requestData.order_id || !requestData.payment_id || !requestData.signature) {
    throw new AppError(
      'INVALID_REQUEST',
      'Missing required fields: order_id, payment_id, signature',
      400
    )
  }
  
  return requestData
}

/**
 * Verify Razorpay payment signature
 */
async function verifySignature(requestData: ConfirmPurchaseRequest): Promise<void> {
  const isValidSignature = verifyPaymentSignature({
    orderId: requestData.order_id,
    paymentId: requestData.payment_id,
    signature: requestData.signature
  })
  
  if (!isValidSignature) {
    console.error(`[Security] Invalid signature for payment confirmation: ${requestData.payment_id}`)
    throw new AppError(
      'INVALID_SIGNATURE',
      'Payment signature verification failed',
      401
    )
  }
  
  console.log(`[Security] ✅ Payment signature verified: ${requestData.payment_id}`)
}

/**
 * Load pending purchase from database
 */
async function loadPendingPurchase(orderId: string, userId: string, supabaseServiceClient: any): Promise<any> {
  const { data: pendingPurchase, error } = await supabaseServiceClient
    .from('pending_token_purchases')
    .select('*')
    .eq('order_id', orderId)
    .eq('user_id', userId)
    .single()
  
  if (error || !pendingPurchase) {
    throw new AppError(
      'PURCHASE_NOT_FOUND',
      'Pending purchase not found or unauthorized',
      404
    )
  }
  
  return pendingPurchase
}

/**
 * Atomic claim operation - updates status from pending to processing 
 */
async function claimPendingPurchaseForProcessing(orderId: string, supabaseServiceClient: any): Promise<any> {
  const { data: claimedPurchase, error } = await supabaseServiceClient
    .from('pending_token_purchases')
    .update({ 
      status: 'processing', 
      updated_at: new Date().toISOString() 
    })
    .eq('order_id', orderId)
    .eq('status', 'pending') // Only update if still pending
    .select('*')
    .single()
  
  if (error || !claimedPurchase) {
    throw new AppError(
      'PURCHASE_ALREADY_PROCESSING',
      'Purchase is already being processed or completed',
      409
    )
  }
  
  return claimedPurchase
}

/**
 * Short-circuit if purchase is already completed or failed
 */
async function shortCircuitIfCompletedOrFailed(pendingPurchase: any, userId: string, tokenService: any): Promise<Response | null> {
  if (pendingPurchase.status === 'completed') {
    const currentTokens = await tokenService.getUserTokens(userId, 'standard')
    return buildResponse({
      success: true,
      message: 'Purchase already completed',
      token_balance: currentTokens
    })
  }
  
  if (pendingPurchase.status === 'failed') {
    throw new AppError(
      'PURCHASE_FAILED',
      'This purchase has failed and cannot be completed',
      400
    )
  }
  
  return null
}

/**
 * Credit tokens to user account
 */
async function creditTokens(userId: string, tokenAmount: number, tokenService: any): Promise<any> {
  const addResult = await tokenService.addPurchasedTokens(
    userId,
    'standard',
    tokenAmount,
    {
      userId,
      userPlan: 'standard',
      operation: 'purchase',
      timestamp: new Date()
    }
  )
  
  if (!addResult.success) {
    throw new Error('Failed to add purchased tokens')
  }
  
  return addResult
}

/**
 * Record purchase in history table
 */
async function recordPurchaseHistory(purchase: any, paymentId: string, userId: string, supabaseServiceClient: any): Promise<void> {
  const costRupees = purchase.amount_paise / 100
  const paymentMethod = 'razorpay'
  
  const { data: historyId, error: historyError } = await supabaseServiceClient
    .rpc('record_purchase_history', {
      p_user_id: userId,
      p_token_amount: purchase.token_amount,
      p_cost_rupees: costRupees,
      p_cost_paise: purchase.amount_paise,
      p_payment_id: paymentId,
      p_order_id: purchase.order_id,
      p_payment_method: paymentMethod,
      p_status: 'completed'
    })
  
  if (historyError) {
    console.error('[Purchase] Failed to record purchase history:', historyError)
    // Continue despite history error - don't fail the purchase
  } else {
    console.log(`[Purchase] ✅ Purchase history recorded: ${historyId}`)
  }
}

/**
 * Mark pending purchase as completed
 */
async function markPendingCompleted(orderId: string, paymentId: string, supabaseServiceClient: any): Promise<void> {
  await supabaseServiceClient
    .from('pending_token_purchases')
    .update({
      status: 'completed',
      payment_id: paymentId,
      updated_at: new Date().toISOString()
    })
    .eq('order_id', orderId)
}

/**
 * Mark pending purchase as failed
 */
async function markPendingFailed(orderId: string, error: any, supabaseServiceClient: any): Promise<void> {
  await supabaseServiceClient
    .from('pending_token_purchases')
    .update({
      status: 'failed',
      error_message: error instanceof Error ? error.message : 'Unknown error',
      updated_at: new Date().toISOString()
    })
    .eq('order_id', orderId)
}

/**
 * Build standardized response
 */
function buildResponse(data: any): Response {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Verify Razorpay payment signature
 */
function verifyPaymentSignature({
  orderId,
  paymentId,
  signature
}: {
  orderId: string
  paymentId: string
  signature: string
}): boolean {
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')
  if (!keySecret) {
    console.error('[Security] RAZORPAY_KEY_SECRET not configured')
    return false
  }
  
  const body = `${orderId}|${paymentId}`
  const expectedSignature = createHmac('sha256', keySecret)
    .update(body)
    .digest('hex')
  
  return signature === expectedSignature
}

createSimpleFunction(handleConfirmPurchase, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})