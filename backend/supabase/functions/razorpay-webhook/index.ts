/**
 * Razorpay Webhook Handler Edge Function
 * 
 * Handles payment confirmation webhooks from Razorpay
 * and completes token purchase process
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { generateHmacSha256 } from '../_shared/utils/crypto-utils.ts'
import type { RazorpaySubscriptionWebhook } from '../_shared/types/subscription-types.ts'
import { PaymentProviderFactory } from '../_shared/services/payment-providers/provider-factory.ts'
import { ProviderType } from '../_shared/services/payment-providers/base-provider.ts'
import { cancelGooglePlaySubscription } from '../_shared/services/google-play-validator.ts'

/**
 * Razorpay payment entity (for token purchases)
 */
interface RazorpayPaymentEntity {
  readonly id: string
  readonly order_id?: string | null
  readonly amount: number
  readonly currency: string
  readonly status?: string
  readonly method?: string
  readonly captured?: boolean
  readonly error_code?: string | null
  readonly error_description?: string | null
  readonly created_at?: number
}

/**
 * Razorpay order entity (for token purchases)
 */
interface RazorpayOrderEntity {
  readonly id: string
  readonly amount?: number
  readonly currency?: string
  readonly status?: string
  readonly notes?: Record<string, string>
}

/**
 * Razorpay Webhook Handler
 *
 * Handles payment confirmation webhooks from Razorpay
 * and completes token purchase process
 */
async function handleRazorpayWebhook(req: Request, services: ServiceContainer): Promise<Response> {
  const { analyticsLogger } = services

  if (req.method !== 'POST') {
    throw new AppError(
      'METHOD_NOT_ALLOWED',
      'Webhook endpoint only accepts POST requests',
      405
    )
  }

  // M3: Read event ID for deduplication
  const razorpayEventId = req.headers.get('x-razorpay-event-id')

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
  const isValidSignature = await verifyWebhookSignature(body, signature)
  if (!isValidSignature) {
    console.error('[Webhook] Invalid signature received')
    throw new AppError(
      'INVALID_SIGNATURE',
      'Webhook signature verification failed',
      401
    )
  }

  console.log('[Webhook] Valid signature verified')

  // M3: Deduplicate by event ID (if provided) to prevent replay attacks.
  // Razorpay retries on non-2xx; idempotent 200 on replay is the correct response.
  if (razorpayEventId) {
    const { data: existingEvent } = await services.supabaseServiceClient
      .from('razorpay_webhook_events')
      .select('event_id')
      .eq('event_id', razorpayEventId)
      .maybeSingle()
    if (existingEvent) {
      console.log('[Webhook] Duplicate event ID — already processed:', razorpayEventId)
      return new Response(JSON.stringify({ received: true, duplicate: true }), {
        status: 200, headers: { 'Content-Type': 'application/json' }
      })
    }
  }

  // Declare variables outside try block to make them accessible in catch block
  let event: string | undefined
  let paymentEntity: RazorpayPaymentEntity | undefined = undefined
  let orderEntity: RazorpayOrderEntity | undefined = undefined
  
  try {
    // Parse webhook payload with error handling
    let payload: unknown
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
    if (typeof payload !== 'object' || payload === null) {
      throw new AppError(
        'INVALID_PAYLOAD',
        'Webhook payload must be an object',
        400
      )
    }

    const payloadObj = payload as Record<string, unknown>

    if (!payloadObj.event || typeof payloadObj.event !== 'string') {
      throw new AppError(
        'INVALID_PAYLOAD',
        'Webhook payload missing required event field',
        400
      )
    }

    if (!payloadObj.payload) {
      throw new AppError(
        'INVALID_PAYLOAD',
        'Webhook payload missing required payload field',
        400
      )
    }

    event = payloadObj.event
    const payloadData = payloadObj.payload as Record<string, unknown>

    // Extract payment entity if present
    const paymentData = payloadData?.payment as Record<string, unknown> | undefined
    if (paymentData?.entity) {
      paymentEntity = paymentData.entity as RazorpayPaymentEntity
    }

    // Extract order entity if present
    const orderData = payloadData?.order as Record<string, unknown> | undefined
    if (orderData?.entity) {
      orderEntity = orderData.entity as RazorpayOrderEntity
    }
    
    console.log(`[Webhook] Processing event: ${event}`)

    // Handle payment events (token purchases)
    if (event === 'payment.captured') {
      await handlePaymentCaptured(paymentEntity, orderEntity, services)
    } else if (event === 'payment.failed') {
      await handlePaymentFailed(paymentEntity, orderEntity, services)
    }
    // Handle subscription events
    else if (event === 'subscription.authenticated') {
      await handleSubscriptionAuthenticated(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'subscription.activated') {
      await handleSubscriptionActivated(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'subscription.charged') {
      await handleSubscriptionCharged(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'subscription.cancelled') {
      await handleSubscriptionCancelled(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'subscription.paused') {
      await handleSubscriptionPaused(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'subscription.resumed') {
      await handleSubscriptionResumed(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'subscription.completed') {
      await handleSubscriptionCompleted(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'subscription.halted') {
      // M7: Halted = exhausted payment retries. Revoke access.
      await handleSubscriptionHalted(payload as RazorpaySubscriptionWebhook, services)
    } else if (event === 'refund.created') {
      await handleRefundCreated(payload, services)
    } else {
      console.log(`[Webhook] Ignoring event: ${event}`)
    }
    
    // M3: Record event ID so replays are skipped on retry
    if (razorpayEventId && event) {
      await services.supabaseServiceClient
        .from('razorpay_webhook_events')
        .upsert({ event_id: razorpayEventId, event_type: event }, { onConflict: 'event_id', ignoreDuplicates: true })
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
async function verifyWebhookSignature(body: string, signature: string): Promise<boolean> {
  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')
  if (!webhookSecret) {
    console.error('[Webhook] RAZORPAY_WEBHOOK_SECRET not configured')
    return false
  }

  const expectedSignature = await generateHmacSha256(webhookSecret, body)

  // CRITICAL: Use constant-time comparison to prevent timing attacks
  return timingSafeEqual(signature, expectedSignature)
}

/**
 * Handle successful payment capture
 */
async function handlePaymentCaptured(
  payment: RazorpayPaymentEntity | undefined,
  order: RazorpayOrderEntity | undefined,
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
    // Not a token purchase — likely a subscription payment, skip gracefully
    console.log(`[Webhook] No pending token purchase for order: ${orderId} — may be a subscription payment, skipping`)
    return
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
    .maybeSingle()

  if (claimError) {
    console.error(`[Webhook] ❌ Claim error for order: ${orderId}`, claimError)
    throw new Error(`Failed to claim purchase: ${claimError.message}`)
  }

  if (!claimedPurchase) {
    console.log(`[Webhook] ✅ Purchase already processed by another handler: ${orderId}`)
    return // Already processed by manual confirmation or another webhook
  }
  
  console.log(`[Webhook] ✅ Purchase claimed successfully - Status: processing`)
  
  // Use the claimed purchase data for the rest of the processing
  const processingPurchase = claimedPurchase
  
  try {
    // F6: Verify currency/amount INSIDE try/catch so a mismatch marks the row failed
    // instead of leaving it stuck in `processing` forever.
    const expectedCurrency = 'INR'

    if (currency !== expectedCurrency) {
      throw new Error(`Currency mismatch for order ${orderId}: expected ${expectedCurrency}, got ${currency}`)
    }

    if (amount !== processingPurchase.amount_paise) {
      throw new Error(`Amount mismatch for order ${orderId}: expected ${processingPurchase.amount_paise} paise, got ${amount} paise`)
    }
    // Resolve real user plan from DB
    const { data: resolvedPlan } = await supabaseServiceClient
      .rpc('get_user_plan_with_subscription', { p_user_id: processingPurchase.user_id })
    const userPlan = ((resolvedPlan as string | null) || 'free') as 'free' | 'standard' | 'plus' | 'premium'

    // Add tokens to user account
    const addResult = await tokenService.addPurchasedTokens(
      processingPurchase.user_id,
      userPlan,
      processingPurchase.token_amount,
      {
        userId: processingPurchase.user_id,
        userPlan,
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
  payment: RazorpayPaymentEntity | undefined,
  order: RazorpayOrderEntity | undefined,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  
  const orderId = order?.id || payment?.order_id
  const paymentId = payment?.id
  const errorDescription = payment?.error_description
  
  console.log(`[Webhook] Payment failed: ${paymentId} for order: ${orderId}`)
  console.log(`[Webhook] Error: ${errorDescription}`)
  
  // Mark pending purchase as failed — only from pending/processing states.
  // Guard prevents an out-of-order payment.failed event from overwriting a completed row.
  await supabaseServiceClient
    .from('pending_token_purchases')
    .update({
      status: 'failed',
      payment_id: paymentId,
      error_message: errorDescription || 'Payment failed',
      updated_at: new Date().toISOString()
    })
    .eq('order_id', orderId)
    .in('status', ['pending', 'processing'])
  
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
  payload: RazorpaySubscriptionWebhook,
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
  // Extract plan_code from notes (set during subscription creation)
  const planCode = subscriptionEntity.notes?.plan_code || 'premium'

  console.log(`[Webhook] Subscription authenticated: ${razorpaySubId}, plan: ${planCode}`)

  // Update subscription status and provider metadata.
  // Status guard: only advance to in_progress from 'created'. A late authenticated
  // event arriving after subscription.activated must not regress active → in_progress.
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'in_progress',
      provider: 'razorpay',
      provider_subscription_id: razorpaySubId,
      provider_customer_id: subscriptionEntity.customer_id,
      // subscription_plan removed - plan code is accessed via plan_id → subscription_plans.plan_code
      provider_metadata: {
        customer_id: subscriptionEntity.customer_id,
        plan_id: subscriptionEntity.plan_id,
        status: subscriptionEntity.status,
        quantity: subscriptionEntity.quantity,
        authenticated_at: new Date().toISOString()
      },
      updated_at: new Date().toISOString()
    })
    .eq('provider_subscription_id', razorpaySubId)
    .eq('status', 'created')

  if (error) {
    console.error('[Webhook] Failed to update subscription:', error)
    return
  }

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_authenticated', {
    user_id: userId,
    subscription_id: razorpaySubId,
    plan_code: planCode
  })
}

/**
 * Handle subscription.activated event
 * Subscription is now active - grant plan access (standard, plus, or premium)
 */
async function handleSubscriptionActivated(
  payload: RazorpaySubscriptionWebhook,
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
  // Extract plan_code from notes (set during subscription creation)
  const planCode = subscriptionEntity.notes?.plan_code || 'premium'

  console.log(`[Webhook] Subscription activated: ${razorpaySubId} for user: ${userId}, plan: ${planCode}`)

  // M3: Update only when the subscription is in an expected prior state.
  // Allow paused/expired recovery for the same Razorpay subscription: payment
  // failure recovery can arrive after reconciliation has expired the paused row.
  const { data: activatedRows, error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'active',
      provider: 'razorpay',
      provider_subscription_id: razorpaySubId,
      // subscription_plan removed - plan code is accessed via plan_id → subscription_plans.plan_code
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
      provider_metadata: {
        customer_id: subscriptionEntity.customer_id,
        plan_id: subscriptionEntity.plan_id,
        status: subscriptionEntity.status,
        quantity: subscriptionEntity.quantity,
        current_start: subscriptionEntity.current_start,
        current_end: subscriptionEntity.current_end,
        charge_at: subscriptionEntity.charge_at,
        paid_count: subscriptionEntity.paid_count,
        remaining_count: subscriptionEntity.remaining_count,
        activated_at: new Date().toISOString()
      },
      updated_at: new Date().toISOString()
    })
    .eq('provider_subscription_id', razorpaySubId)
    .in('status', ['created', 'in_progress', 'pending_cancellation', 'paused', 'expired'])  // M3: state precondition
    .select('id')

  if (error) {
    console.error('[Webhook] Failed to activate subscription:', error)
    return
  }

  if (!activatedRows?.length) {
    console.warn('[Webhook] Activation ignored because subscription is not recoverable:', razorpaySubId)
    return
  }

  const planLabel = planCode === 'standard' ? 'Standard' : planCode === 'plus' ? 'Plus' : 'Premium'
  console.log(`[Webhook] ✅ ${planLabel} access granted to user: ${userId}`)

  // Complete deferred upgrade: cancel the old subscription now that payment is confirmed
  const { data: newSubRow } = await supabaseServiceClient
    .from('subscriptions')
    .select('provider_metadata')
    .eq('provider_subscription_id', razorpaySubId)
    .maybeSingle()

  const meta = newSubRow?.provider_metadata as Record<string, any> | null
  if (meta?.upgrading_from_sub_id) {
    await _completeUpgradeCancellation(supabaseServiceClient, meta)
  }

  // Log event
  await analyticsLogger.logEvent('webhook_subscription_activated', {
    user_id: userId,
    subscription_id: razorpaySubId,
    plan_code: planCode,
    period_start: subscriptionEntity.current_start,
    period_end: subscriptionEntity.current_end
  })
}

// deno-lint-ignore no-explicit-any
async function _completeUpgradeCancellation(
  supabase: any,
  meta: Record<string, any>
): Promise<void> {
  const now = new Date()
  const oldSubId: string = meta.upgrading_from_sub_id
  const oldProvider: string | undefined = meta.upgrading_from_provider
  const oldProviderSubId: string | undefined = meta.upgrading_from_provider_sub_id

  // Issue prorated refund for Razorpay-billed old subscription
  if (oldProvider === 'razorpay' && oldProviderSubId && meta.upgrading_from_amount_paise && meta.upgrading_from_period_end) {
    try {
      const periodEnd = new Date(meta.upgrading_from_period_end)
      const periodStart = new Date(meta.upgrading_from_period_start)
      // Use exact millisecond ratio to avoid double-rounding on day counts (F33 fix).
      const totalMs = Math.max(1, periodEnd.getTime() - periodStart.getTime())
      const remainingMs = Math.max(0, periodEnd.getTime() - now.getTime())

      if (remainingMs > 0) {
        // Fetch the last paid invoice to use the actual charge amount, not the
        // potentially-discounted first-month amount stored in subscription metadata (F33 fix).
        const { data: lastInvoice } = await supabase
          .from('subscription_invoices')
          .select('razorpay_payment_id, amount_paise')
          .eq('subscription_id', oldSubId)
          .eq('status', 'paid')
          .order('paid_at', { ascending: false })
          .limit(1)
          .maybeSingle()

        const chargeAmountPaise = (lastInvoice as any)?.amount_paise ?? meta.upgrading_from_amount_paise
        const refundAmountPaise = Math.round(chargeAmountPaise * remainingMs / totalMs)

        if (lastInvoice?.razorpay_payment_id && refundAmountPaise > 0) {
          const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
          await (razorpayProvider as any).issueRefund(
            lastInvoice.razorpay_payment_id,
            refundAmountPaise,
            { reason: 'Plan upgrade — prorated refund', remaining_ms: String(remainingMs) }
          )
          console.log('[Webhook] Upgrade: prorated refund issued:', { refundAmountPaise, remainingMs })
        }
      }
    } catch (refundError) {
      console.error('[Webhook] Upgrade: prorated refund failed (non-fatal):', refundError)
    }

    // Cancel old Razorpay subscription via API
    try {
      const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
      await (razorpayProvider as any).cancelSubscription(oldProviderSubId, false)
      console.log('[Webhook] Upgrade: old Razorpay sub cancelled via API:', oldProviderSubId)
    } catch (cancelApiError) {
      console.error('[Webhook] Upgrade: old Razorpay sub API cancel failed (non-fatal):', cancelApiError)
    }
  } else if (oldProvider === 'google_play' && oldProviderSubId) {
    try {
      const gpProductId: string | undefined = meta.upgrading_from_iap_product_id
      if (gpProductId) {
        const gpEnv: 'sandbox' | 'production' = Deno.env.get('APP_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production'
        const gpPackageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') || 'com.disciplefy.bible_study'
        await cancelGooglePlaySubscription(supabase as any, gpPackageName, gpProductId, oldProviderSubId, gpEnv)
        console.log('[Webhook] Upgrade: old Google Play sub cancelled via API:', gpProductId)
      }
    } catch (gpCancelError) {
      console.error('[Webhook] Upgrade: old Google Play sub API cancel failed (non-fatal):', gpCancelError)
    }
  }

  // Mark old sub as cancelled in DB (only if still parked as pending_cancellation)
  const { error } = await supabase
    .from('subscriptions')
    .update({
      status: 'cancelled',
      cancelled_at: now.toISOString(),
      cancellation_reason: 'Superseded by plan upgrade',
      updated_at: now.toISOString()
    })
    .eq('id', oldSubId)
    .eq('status', 'pending_cancellation')

  if (error) {
    console.error('[Webhook] Upgrade: failed to cancel old sub in DB (non-fatal):', { oldSubId, error })
  } else {
    console.log('[Webhook] Upgrade: old subscription cancelled in DB:', oldSubId)
  }
}

/**
 * Handle subscription.charged event
 * Monthly payment successful - create invoice and extend period
 */
async function handleSubscriptionCharged(
  payload: RazorpaySubscriptionWebhook,
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
    .eq('provider_subscription_id', razorpaySubId)
    .single()

  if (!subscription) {
    console.error('[Webhook] Subscription not found in database')
    return
  }

  // Update subscription billing info, reset status to active, and update provider metadata.
  // Resetting status handles the case where the subscription was in pending_cancellation
  // but the user re-enabled auto-renew and was successfully charged again. Include expired
  // so successful payment recovery after reconciliation restores access.
  const { data: chargedRows, error: chargedUpdateError } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'active',
      provider: 'razorpay',
      provider_subscription_id: razorpaySubId,
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
      provider_metadata: {
        customer_id: subscriptionEntity.customer_id,
        plan_id: subscriptionEntity.plan_id,
        status: subscriptionEntity.status,
        current_start: subscriptionEntity.current_start,
        current_end: subscriptionEntity.current_end,
        charge_at: subscriptionEntity.charge_at,
        paid_count: subscriptionEntity.paid_count,
        remaining_count: subscriptionEntity.remaining_count,
        last_charged_at: new Date().toISOString()
      },
      updated_at: new Date().toISOString()
    })
    .eq('id', subscription.id)
    .in('status', ['active', 'pending_cancellation', 'paused', 'expired'])  // M3: charged can only happen on these statuses
    .select('id')

  if (chargedUpdateError) {
    console.error('[Webhook] Failed to update subscription after charge:', chargedUpdateError)
    return
  }

  if (!chargedRows?.length) {
    console.warn('[Webhook] Charge ignored because subscription is not recoverable:', razorpaySubId)
    return
  }

  // Check for existing invoice before inserting (idempotency)
  const { data: existingInvoice } = await supabaseServiceClient
    .from('subscription_invoices')
    .select('id')
    .eq('razorpay_payment_id', paymentId)
    .maybeSingle()

  if (existingInvoice) {
    console.log(`[Webhook] Invoice already exists for payment ${paymentId}, skipping duplicate`)
    return
  }

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
  payload: RazorpaySubscriptionWebhook,
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

  // Fetch existing metadata so we can merge (not overwrite) it
  const { data: existingSubC } = await supabaseServiceClient
    .from('subscriptions')
    .select('provider_metadata')
    .eq('provider_subscription_id', razorpaySubId)
    .maybeSingle()

  // Update subscription status to cancelled (final state)
  // Clear cancel_at_cycle_end flag as it's now actually cancelled
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'cancelled',
      provider: 'razorpay',
      provider_subscription_id: razorpaySubId,
      cancelled_at: new Date().toISOString(),
      cancel_at_cycle_end: false,  // Clear flag as it's now actually cancelled
      provider_metadata: {
        ...(existingSubC?.provider_metadata ?? {}),
        cancelled_at: new Date().toISOString(),
        cancellation_source: 'razorpay_webhook'
      },
      updated_at: new Date().toISOString()
    })
    .eq('provider_subscription_id', razorpaySubId)

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
  payload: RazorpaySubscriptionWebhook,
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

  // Fetch existing metadata so we can merge (not overwrite) it
  const { data: existingSubP } = await supabaseServiceClient
    .from('subscriptions')
    .select('provider_metadata')
    .eq('provider_subscription_id', razorpaySubId)
    .maybeSingle()

  // Update subscription status and provider metadata
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'paused',
      provider: 'razorpay',
      provider_subscription_id: razorpaySubId,
      provider_metadata: {
        ...(existingSubP?.provider_metadata ?? {}),
        paused_at: new Date().toISOString(),
        pause_reason: 'payment_failure'
      },
      updated_at: new Date().toISOString()
    })
    .eq('provider_subscription_id', razorpaySubId)

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
  payload: RazorpaySubscriptionWebhook,
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

  // Fetch existing metadata so we can merge (not overwrite) it
  const { data: existingSubR } = await supabaseServiceClient
    .from('subscriptions')
    .select('provider_metadata')
    .eq('provider_subscription_id', razorpaySubId)
    .maybeSingle()

  // Update subscription status back to active and update provider metadata
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'active',
      cancel_at_cycle_end: false,
      provider: 'razorpay',
      provider_subscription_id: razorpaySubId,
      provider_metadata: {
        ...(existingSubR?.provider_metadata ?? {}),
        resumed_at: new Date().toISOString(),
        previous_status: 'paused'
      },
      updated_at: new Date().toISOString()
    })
    .eq('provider_subscription_id', razorpaySubId)

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
  payload: RazorpaySubscriptionWebhook,
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

  // Fetch existing metadata so we can merge (not overwrite) it
  const { data: existingSubCo } = await supabaseServiceClient
    .from('subscriptions')
    .select('provider_metadata')
    .eq('provider_subscription_id', razorpaySubId)
    .maybeSingle()

  // Update subscription status and provider metadata
  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'completed',
      provider: 'razorpay',
      provider_subscription_id: razorpaySubId,
      provider_metadata: {
        ...(existingSubCo?.provider_metadata ?? {}),
        completed_at: new Date().toISOString(),
        total_cycles_completed: subscriptionEntity.paid_count || 0
      },
      updated_at: new Date().toISOString()
    })
    .eq('provider_subscription_id', razorpaySubId)

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

/**
 * Handle refund.created event
 * Razorpay sends this when a payment is refunded.
 * Revokes subscription access and marks receipt as refunded.
 */
async function handleRefundCreated(
  payload: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const paymentEntity = payload.payload?.payment?.entity
  const refundEntity = payload.payload?.refund?.entity

  const paymentId = paymentEntity?.id || refundEntity?.payment_id
  if (!paymentId) {
    console.warn('[Webhook] refund.created: no payment_id found, skipping')
    return
  }

  console.log(`[Webhook] Refund created for payment: ${paymentId}`)

  // Find subscription via invoice linked to this payment
  const { data: invoice } = await supabaseServiceClient
    .from('subscription_invoices')
    .select('subscription_id, user_id')
    .eq('razorpay_payment_id', paymentId)
    .maybeSingle()

  if (!invoice?.subscription_id) {
    console.warn('[Webhook] refund.created: no subscription found for payment', paymentId)
    return
  }

  // Revoke subscription access immediately
  await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'cancelled',
      cancelled_at: new Date().toISOString(),
      cancellation_reason: 'Refunded',
      updated_at: new Date().toISOString()
    })
    .eq('id', invoice.subscription_id)

  // Mark invoice as refunded
  await supabaseServiceClient
    .from('subscription_invoices')
    .update({ status: 'refunded' })
    .eq('razorpay_payment_id', paymentId)

  console.log(`[Webhook] ✅ Subscription ${invoice.subscription_id} cancelled due to refund of payment ${paymentId}`)

  await analyticsLogger.logEvent('webhook_refund_created', {
    user_id: invoice.user_id,
    subscription_id: invoice.subscription_id,
    payment_id: paymentId,
    refund_id: refundEntity?.id
  })
}

/**
 * M7: Handle subscription.halted event — exhausted all payment retries.
 * Revokes access by marking the subscription 'paused' so users can't consume
 * premium features while they have an outstanding failed payment.
 */
async function handleSubscriptionHalted(
  payload: RazorpaySubscriptionWebhook,
  services: ServiceContainer
): Promise<void> {
  const { supabaseServiceClient, analyticsLogger } = services
  const subscriptionEntity = payload.payload?.subscription?.entity
  if (!subscriptionEntity) {
    console.error('[Webhook] subscription.halted missing subscription entity')
    return
  }

  const razorpaySubId = subscriptionEntity.id
  console.log(`[Webhook] Subscription halted (payment exhausted): ${razorpaySubId}`)

  const { error } = await supabaseServiceClient
    .from('subscriptions')
    .update({
      status: 'paused',
      updated_at: new Date().toISOString()
    })
    .eq('provider_subscription_id', razorpaySubId)
    .in('status', ['active', 'pending_cancellation'])

  if (error) {
    console.error('[Webhook] Failed to pause halted subscription:', error)
    return
  }

  const { data: sub } = await supabaseServiceClient
    .from('subscriptions')
    .select('user_id, id')
    .eq('provider_subscription_id', razorpaySubId)
    .maybeSingle()

  await analyticsLogger.logEvent('webhook_subscription_halted', {
    user_id: sub?.user_id,
    subscription_id: sub?.id,
    razorpay_subscription_id: razorpaySubId
  })
}

// Create the Edge Function
createSimpleFunction(handleRazorpayWebhook, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
