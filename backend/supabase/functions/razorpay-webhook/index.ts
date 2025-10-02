/**
 * Razorpay Webhook Handler Edge Function
 * 
 * Handles payment confirmation webhooks from Razorpay
 * and completes token purchase process
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { createHmac } from 'node:crypto'

/**
 * Razorpay Webhook Handler
 * 
 * Handles payment confirmation webhooks from Razorpay
 * and completes token purchase process
 */
async function handleRazorpayWebhook(req: Request, services: ServiceContainer): Promise<Response> {
  const { tokenService, analyticsLogger, supabaseServiceClient } = services
  
  if (req.method !== 'POST') {
    throw new AppError(
      'METHOD_NOT_ALLOWED',
      'Webhook endpoint only accepts POST requests',
      405
    )
  }
  
  // Get webhook signature
  const signature = req.headers.get('x-razorpay-signature')
  if (!signature) {
    throw new AppError(
      'MISSING_SIGNATURE',
      'Webhook signature is required',
      400
    )
  }
  
  // Get request body
  const body = await req.text()
  
  // Verify webhook signature
  const isValidSignature = verifyWebhookSignature(body, signature)
  if (!isValidSignature) {
    console.error('[Webhook] Invalid signature received')
    throw new AppError(
      'INVALID_SIGNATURE',
      'Webhook signature verification failed',
      401
    )
  }
  
  console.log('[Webhook] Valid signature verified')
  
  // Declare variables outside try block to make them accessible in catch block
  let event: string | undefined
  let paymentEntity: any = undefined
  let orderEntity: any = undefined
  
  try {
    // Parse webhook payload with error handling
    let payload
    try {
      payload = JSON.parse(body)
    } catch (parseError) {
      console.error('[Webhook] Failed to parse JSON payload:', parseError)
      throw new AppError(
        'INVALID_PAYLOAD',
        'Webhook payload must be valid JSON',
        400
      )
    }
    
    // Validate required payload structure
    if (!payload.event) {
      throw new AppError(
        'INVALID_PAYLOAD',
        'Webhook payload missing required event field',
        400
      )
    }
    
    if (!payload.payload) {
      throw new AppError(
        'INVALID_PAYLOAD',
        'Webhook payload missing required payload field',
        400
      )
    }
    
    event = payload.event
    paymentEntity = payload.payload?.payment?.entity
    orderEntity = payload.payload?.order?.entity
    
    console.log(`[Webhook] Processing event: ${event}`)
    
    if (event === 'payment.captured') {
      await handlePaymentCaptured(paymentEntity, orderEntity, services)
    } else if (event === 'payment.failed') {
      await handlePaymentFailed(paymentEntity, orderEntity, services)
    } else {
      console.log(`[Webhook] Ignoring event: ${event}`)
    }
    
    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('[Webhook] Error processing webhook:', error)
    
    // Log webhook failure for monitoring
    await analyticsLogger.logEvent('webhook_processing_failed', {
      event,
      error_message: error instanceof Error ? error.message : 'Unknown error',
      payment_id: paymentEntity?.id,
      order_id: orderEntity?.id
    })
    
    throw new AppError(
      'WEBHOOK_PROCESSING_ERROR',
      'Failed to process webhook',
      500
    )
  }
}

/**
 * Verify Razorpay webhook signature
 */
function verifyWebhookSignature(body: string, signature: string): boolean {
  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')
  if (!webhookSecret) {
    console.error('[Webhook] RAZORPAY_WEBHOOK_SECRET not configured')
    return false
  }
  
  const expectedSignature = createHmac('sha256', webhookSecret)
    .update(body)
    .digest('hex')
  
  return signature === expectedSignature
}

/**
 * Handle successful payment capture
 */
async function handlePaymentCaptured(
  payment: any,
  order: any,
  services: ServiceContainer
): Promise<void> {
  const { tokenService, supabaseServiceClient, analyticsLogger } = services
  
  const orderId = order?.id || payment?.order_id
  const paymentId = payment?.id
  const amount = payment?.amount // In paise
  const currency = payment?.currency // Currency code (e.g., 'INR')
  
  console.log(`[Webhook] Payment captured: ${paymentId} for order: ${orderId}`)
  
  // Get pending purchase
  const { data: pendingPurchase, error } = await supabaseServiceClient
    .from('pending_token_purchases')
    .select('*')
    .eq('order_id', orderId)
    .single()
  
  if (error || !pendingPurchase) {
    console.error(`[Webhook] Pending purchase not found for order: ${orderId}`, error)
    throw new Error(`Pending purchase not found: ${orderId}`)
  }
  
  // Atomic claim for processing to prevent race condition with manual confirmation
  console.log(`[Webhook] 🔒 Attempting atomic claim for order: ${orderId}`)
  const { data: claimedPurchase, error: claimError } = await supabaseServiceClient
    .from('pending_token_purchases')
    .update({ 
      status: 'processing', 
      updated_at: new Date().toISOString() 
    })
    .eq('order_id', orderId)
    .eq('status', 'pending') // Only update if still pending
    .select('*')
    .single()
  
  if (claimError || !claimedPurchase) {
    console.log(`[Webhook] ✅ Purchase already processed by another handler: ${orderId}`)
    return // Already processed by manual confirmation or another webhook
  }
  
  console.log(`[Webhook] ✅ Purchase claimed successfully - Status: processing`)
  
  // Use the claimed purchase data for the rest of the processing
  const processingPurchase = claimedPurchase
  
  // Verify both currency and amount match expected values
  const expectedCurrency = 'INR' // We only support INR currently
  
  if (currency !== expectedCurrency) {
    const errorMsg = `Currency mismatch for order ${orderId}: expected ${expectedCurrency}, got ${currency}`
    console.error(`[Webhook] ${errorMsg}`)
    throw new Error(`Payment currency verification failed: ${errorMsg}`)
  }
  
  if (amount !== processingPurchase.amount_paise) {
    const errorMsg = `Amount mismatch for order ${orderId}: expected ${processingPurchase.amount_paise} paise, got ${amount} paise`
    console.error(`[Webhook] ${errorMsg}`)
    throw new Error(`Payment amount verification failed: ${errorMsg}`)
  }
  
  try {
    // Add tokens to user account
    const addResult = await tokenService.addPurchasedTokens(
      processingPurchase.user_id,
      'standard', // Only standard users can purchase
      processingPurchase.token_amount,
      {
        userId: processingPurchase.user_id,
        userPlan: 'standard',
        operation: 'purchase',
        timestamp: new Date()
      }
    )
    
    if (!addResult.success) {
      throw new Error('Failed to add purchased tokens')
    }
    
    // Record purchase in history
    const costRupees = processingPurchase.amount_paise / 100
    const paymentMethod = payment?.method || 'unknown'
    
    const { data: historyId, error: historyError } = await supabaseServiceClient
      .rpc('record_purchase_history', {
        p_user_id: processingPurchase.user_id,
        p_token_amount: processingPurchase.token_amount,
        p_cost_rupees: costRupees,
        p_cost_paise: processingPurchase.amount_paise,
        p_payment_id: paymentId,
        p_order_id: orderId,
        p_payment_method: paymentMethod,
        p_status: 'completed'
      })
    
    if (historyError) {
      console.error(`[Webhook] Failed to record purchase history:`, historyError)
      // Don't fail the entire transaction, just log the error
    } else {
      console.log(`[Webhook] ✅ Purchase history recorded: ${historyId}`)
    }
    
    // Mark purchase as completed
    await supabaseServiceClient
      .from('pending_token_purchases')
      .update({
        status: 'completed',
        payment_id: paymentId,
        updated_at: new Date().toISOString()
      })
      .eq('order_id', orderId)
    
    console.log(`[Webhook] ✅ Purchase completed: ${processingPurchase.token_amount} tokens for user ${processingPurchase.user_id}`)
    
    // Log successful purchase
    await analyticsLogger.logEvent('webhook_purchase_completed', {
      user_id: processingPurchase.user_id,
      order_id: orderId,
      payment_id: paymentId,
      token_amount: processingPurchase.token_amount,
      amount_paise: amount,
      new_purchased_balance: addResult.newPurchasedBalance
    })
    
  } catch (error) {
    console.error(`[Webhook] Failed to complete purchase for order ${orderId}:`, error)
    
    // Mark purchase as failed
    await supabaseServiceClient
      .from('pending_token_purchases')
      .update({
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error',
        updated_at: new Date().toISOString()
      })
      .eq('order_id', orderId)
    
    throw error
  }
}

/**
 * Handle failed payment
 */
async function handlePaymentFailed(
  payment: any,
  order: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  
  const orderId = order?.id || payment?.order_id
  const paymentId = payment?.id
  const errorDescription = payment?.error_description
  
  console.log(`[Webhook] Payment failed: ${paymentId} for order: ${orderId}`)
  console.log(`[Webhook] Error: ${errorDescription}`)
  
  // Mark pending purchase as failed
  await supabaseServiceClient
    .from('pending_token_purchases')
    .update({
      status: 'failed',
      payment_id: paymentId,
      error_message: errorDescription || 'Payment failed',
      updated_at: new Date().toISOString()
    })
    .eq('order_id', orderId)
  
  // Log failed payment
  await analyticsLogger.logEvent('webhook_payment_failed', {
    order_id: orderId,
    payment_id: paymentId,
    error_description: errorDescription
  })
}

// Create the Edge Function
createSimpleFunction(handleRazorpayWebhook, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})