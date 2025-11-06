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
import type { RazorpaySubscriptionWebhook, SubscriptionStatus } from '../_shared/types/subscription-types.ts'

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

    // Handle payment events (token purchases)
    if (event === 'payment.captured') {
      await handlePaymentCaptured(paymentEntity, orderEntity, services)
    } else if (event === 'payment.failed') {
      await handlePaymentFailed(paymentEntity, orderEntity, services)
    }
    // Handle subscription events
    else if (event === 'subscription.authenticated') {
      await handleSubscriptionAuthenticated(payload, services)
    } else if (event === 'subscription.activated') {
      await handleSubscriptionActivated(payload, services)
    } else if (event === 'subscription.charged') {
      await handleSubscriptionCharged(payload, services)
    } else if (event === 'subscription.cancelled') {
      await handleSubscriptionCancelled(payload, services)
    } else if (event === 'subscription.paused') {
      await handleSubscriptionPaused(payload, services)
    } else if (event === 'subscription.resumed') {
      await handleSubscriptionResumed(payload, services)
    } else if (event === 'subscription.completed') {
      await handleSubscriptionCompleted(payload, services)
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
 * Constant-time string comparison to prevent timing attacks
 *
 * @param a - First string to compare
 * @param b - Second string to compare
 * @returns true if strings are equal, false otherwise
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false
  }

  let result = 0
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }

  return result === 0
}

/**
 * Verify Razorpay webhook signature using constant-time comparison
 *
 * SECURITY: Uses timingSafeEqual to prevent timing attack vulnerabilities
 * where attackers could determine the correct signature by measuring
 * comparison time differences
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

  // CRITICAL: Use constant-time comparison to prevent timing attacks
  return timingSafeEqual(signature, expectedSignature)
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

/**
 * Handle subscription.authenticated event
 * User has authorized recurring payments
 */
async function handleSubscriptionAuthenticated(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity

  if (!subscriptionEntity) {
    console.error('[Webhook] Missing subscription entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  const userId = subscriptionEntity.notes?.user_id

  console.log(`[Webhook] Subscription authenticated: ${razorpaySubId}`)

  // Update subscription status
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'authenticated',
      razorpay_customer_id: subscriptionEntity.customer_id,
      updated_at: new Date().toISOString()
    })
    .eq('razorpay_subscription_id', razorpaySubId)

  if (error) {
    console.error('[Webhook] Failed to update subscription:', error)
    return
  }

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_authenticated', {
    user_id: userId,
    subscription_id: razorpaySubId
  })
}

/**
 * Handle subscription.activated event
 * Subscription is now active - grant premium access
 */
async function handleSubscriptionActivated(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity

  if (!subscriptionEntity) {
    console.error('[Webhook] Missing subscription entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  const userId = subscriptionEntity.notes?.user_id

  console.log(`[Webhook] Subscription activated: ${razorpaySubId} for user: ${userId}`)

  // Update subscription status and billing info
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'active',
      current_period_start: subscriptionEntity.current_start
        ? new Date(subscriptionEntity.current_start * 1000).toISOString()
        : null,
      current_period_end: subscriptionEntity.current_end
        ? new Date(subscriptionEntity.current_end * 1000).toISOString()
        : null,
      next_billing_at: subscriptionEntity.charge_at
        ? new Date(subscriptionEntity.charge_at * 1000).toISOString()
        : null,
      paid_count: subscriptionEntity.paid_count,
      remaining_count: subscriptionEntity.remaining_count,
      updated_at: new Date().toISOString()
    })
    .eq('razorpay_subscription_id', razorpaySubId)

  if (error) {
    console.error('[Webhook] Failed to activate subscription:', error)
    return
  }

  console.log(`[Webhook] ✅ Premium access granted to user: ${userId}`)

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_activated', {
    user_id: userId,
    subscription_id: razorpaySubId,
    period_start: subscriptionEntity.current_start,
    period_end: subscriptionEntity.current_end
  })
}

/**
 * Handle subscription.charged event
 * Monthly payment successful - create invoice and extend period
 */
async function handleSubscriptionCharged(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity
  const paymentEntity = payload.payload?.payment?.entity

  if (!subscriptionEntity || !paymentEntity) {
    console.error('[Webhook] Missing subscription or payment entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  const paymentId = paymentEntity.id
  const userId = subscriptionEntity.notes?.user_id

  console.log(`[Webhook] Subscription charged: ${razorpaySubId}, Payment: ${paymentId}`)

  // Get subscription from database
  const { data: subscription } = await supabaseServiceClient
    .from('subscriptions')
    .select('id, user_id')
    .eq('razorpay_subscription_id', razorpaySubId)
    .single()

  if (!subscription) {
    console.error('[Webhook] Subscription not found in database')
    return
  }

  // Update subscription billing info
  await supabaseServiceClient
    .from('subscriptions')
    .update({
      current_period_start: subscriptionEntity.current_start
        ? new Date(subscriptionEntity.current_start * 1000).toISOString()
        : null,
      current_period_end: subscriptionEntity.current_end
        ? new Date(subscriptionEntity.current_end * 1000).toISOString()
        : null,
      next_billing_at: subscriptionEntity.charge_at
        ? new Date(subscriptionEntity.charge_at * 1000).toISOString()
        : null,
      paid_count: subscriptionEntity.paid_count,
      remaining_count: subscriptionEntity.remaining_count,
      updated_at: new Date().toISOString()
    })
    .eq('id', subscription.id)

  // Create invoice record
  await supabaseServiceClient
    .from('subscription_invoices')
    .insert({
      subscription_id: subscription.id,
      user_id: subscription.user_id,
      razorpay_payment_id: paymentId,
      razorpay_invoice_id: paymentEntity.invoice_id || null,
      amount_paise: paymentEntity.amount,
      currency: paymentEntity.currency,
      billing_period_start: subscriptionEntity.current_start
        ? new Date(subscriptionEntity.current_start * 1000).toISOString()
        : new Date().toISOString(),
      billing_period_end: subscriptionEntity.current_end
        ? new Date(subscriptionEntity.current_end * 1000).toISOString()
        : new Date().toISOString(),
      status: 'paid',
      payment_method: paymentEntity.method,
      paid_at: new Date(paymentEntity.created_at * 1000).toISOString()
    })

  console.log(`[Webhook] ✅ Invoice created for payment: ${paymentId}`)

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_charged', {
    user_id: userId,
    subscription_id: razorpaySubId,
    payment_id: paymentId,
    amount_rupees: paymentEntity.amount / 100
  })
}

/**
 * Handle subscription.cancelled event
 * Razorpay sends this when:
 * 1. User cancelled immediately (cancel_at_cycle_end=false)
 * 2. Billing period ended for pending_cancellation subscriptions
 *
 * Transitions:
 * - active → cancelled (immediate cancellation)
 * - pending_cancellation → cancelled (period ended)
 */
async function handleSubscriptionCancelled(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity

  if (!subscriptionEntity) {
    console.error('[Webhook] Missing subscription entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  const userId = subscriptionEntity.notes?.user_id

  console.log(`[Webhook] Subscription cancelled: ${razorpaySubId}`)

  // Update subscription status to cancelled (final state)
  // Clear cancel_at_cycle_end flag as it's now actually cancelled
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'cancelled',
      cancelled_at: new Date().toISOString(),
      cancel_at_cycle_end: false,  // Clear flag as it's now actually cancelled
      updated_at: new Date().toISOString()
    })
    .eq('razorpay_subscription_id', razorpaySubId)

  if (error) {
    console.error('[Webhook] Failed to cancel subscription:', error)
    return
  }

  console.log(`[Webhook] ✅ Subscription marked as cancelled: ${razorpaySubId}`)

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_cancelled', {
    user_id: userId,
    subscription_id: razorpaySubId
  })
}

/**
 * Handle subscription.paused event
 * Subscription paused (payment failure) - restrict premium features
 */
async function handleSubscriptionPaused(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity

  if (!subscriptionEntity) {
    console.error('[Webhook] Missing subscription entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  const userId = subscriptionEntity.notes?.user_id

  console.log(`[Webhook] Subscription paused: ${razorpaySubId}`)

  // Update subscription status
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'paused',
      updated_at: new Date().toISOString()
    })
    .eq('razorpay_subscription_id', razorpaySubId)

  if (error) {
    console.error('[Webhook] Failed to pause subscription:', error)
    return
  }

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_paused', {
    user_id: userId,
    subscription_id: razorpaySubId
  })
}

/**
 * Handle subscription.resumed event
 * Paused subscription resumed - restore premium access
 */
async function handleSubscriptionResumed(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity

  if (!subscriptionEntity) {
    console.error('[Webhook] Missing subscription entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  const userId = subscriptionEntity.notes?.user_id

  console.log(`[Webhook] Subscription resumed: ${razorpaySubId}`)

  // Update subscription status back to active
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'active',
      updated_at: new Date().toISOString()
    })
    .eq('razorpay_subscription_id', razorpaySubId)

  if (error) {
    console.error('[Webhook] Failed to resume subscription:', error)
    return
  }

  console.log(`[Webhook] ✅ Subscription resumed: ${razorpaySubId}`)

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_resumed', {
    user_id: userId,
    subscription_id: razorpaySubId
  })
}

/**
 * Handle subscription.completed event
 * Subscription reached total_count - downgrade to standard
 */
async function handleSubscriptionCompleted(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity

  if (!subscriptionEntity) {
    console.error('[Webhook] Missing subscription entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  const userId = subscriptionEntity.notes?.user_id

  console.log(`[Webhook] Subscription completed: ${razorpaySubId}`)

  // Update subscription status
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'completed',
      updated_at: new Date().toISOString()
    })
    .eq('razorpay_subscription_id', razorpaySubId)

  if (error) {
    console.error('[Webhook] Failed to complete subscription:', error)
    return
  }

  console.log(`[Webhook] ✅ Subscription completed: ${razorpaySubId}`)

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_completed', {
    user_id: userId,
    subscription_id: razorpaySubId
  })
}

// Create the Edge Function
createSimpleFunction(handleRazorpayWebhook, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})