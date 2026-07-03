/**
 * Confirm Token Purchase Edge Function
 *
 * Handles manual payment confirmation with signature verification
 * for frontend payment completion
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { verifyHmacSha256 } from '../_shared/utils/crypto-utils.ts'
import type { UserContext } from '../_shared/types/index.ts'
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import type { TokenService } from '../_shared/services/token-service.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import Razorpay from 'npm:razorpay'

interface ConfirmPurchaseRequest {
  order_id: string
  payment_id: string
  signature: string
}

interface PendingPurchase {
  order_id: string
  user_id: string
  token_amount: number
  amount_paise: number
  status: 'pending' | 'processing' | 'completed' | 'failed'
  payment_id?: string
  error_message?: string
  updated_at?: string
}

interface AddTokensResult {
  success: boolean
  newPurchasedBalance: number
}

interface AuthService {
  getUserContext(req: Request): Promise<UserContext>
}

/**
 * Handle payment confirmation with signature verification - main orchestrator
 */
async function handleConfirmPurchase(req: Request, services: ServiceContainer): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  let requestData: ConfirmPurchaseRequest | null = null
  let userContext: UserContext | null = null
  let purchaseWasClaimed = false
  
  try {
    console.log('[Purchase] 🚀 Starting payment confirmation process')
    
    userContext = await authenticateUser(req, services.authService)
    console.log(`[Purchase] ✅ User authenticated: ${userContext.userId}`)
    
    requestData = await parseAndValidateRequest(req)
    console.log(`[Purchase] ✅ Request parsed - Order: ${requestData.order_id}, Payment: ${requestData.payment_id}`)
    
    await verifySignature(requestData)
    console.log(`[Purchase] ✅ Signature verified successfully`)

    const pendingPurchase = await loadPendingPurchase(requestData.order_id, userContext.userId!, services.supabaseServiceClient)
    console.log(`[Purchase] ✅ Pending purchase loaded - Status: ${pendingPurchase.status}, Amount: ${pendingPurchase.token_amount}`)

    // C2: Verify the captured payment amount matches what we expected to charge.
    // Without this, a client could submit a real signature for a ₹1 payment and
    // receive tokens priced at ₹40 if they manipulated token_amount at order time.
    await verifyPaymentAmount(requestData.payment_id, pendingPurchase.amount_paise)
    console.log(`[Purchase] ✅ Payment amount verified`)

    // Check if already processed
    const shortCircuitResponse = await shortCircuitIfCompletedOrFailed(pendingPurchase, userContext.userId!, services.tokenService)
    if (shortCircuitResponse) {
      console.log(`[Purchase] ↩️ Short-circuit response - already processed`)
      return shortCircuitResponse
    }

    // Atomic claim for processing to prevent double-processing
    console.log(`[Purchase] 🔒 Attempting atomic claim for order: ${pendingPurchase.order_id}`)
    const claimedPurchase = await claimPendingPurchaseForProcessing(pendingPurchase.order_id, userContext.userId!, services.supabaseServiceClient)
    purchaseWasClaimed = true
    console.log(`[Purchase] ✅ Purchase claimed successfully - Status: processing`)
    
    // Resolve the user's real plan so the token row isn't clobbered to 'standard'
    const { data: resolvedPlan } = await services.supabaseServiceClient
      .rpc('get_user_plan_with_subscription', { p_user_id: userContext.userId! })
    const userPlan = ((resolvedPlan as string | null) || 'free') as 'free' | 'standard' | 'plus' | 'premium'

    // Process the purchase
    console.log(`[Purchase] 💰 Adding ${claimedPurchase.token_amount} tokens to user (plan: ${userPlan})`)
    const addResult = await creditTokens(userContext.userId!, claimedPurchase.token_amount, userPlan, services.tokenService)
    console.log(`[Purchase] ✅ Tokens credited - New purchased balance: ${addResult.newPurchasedBalance}`)

    console.log(`[Purchase] 📝 Recording purchase history`)
    await recordPurchaseHistory(claimedPurchase, requestData.payment_id, userContext.userId!, services.supabaseServiceClient)
    console.log(`[Purchase] ✅ Purchase history recorded`)

    console.log(`[Purchase] 🏁 Marking purchase as completed`)
    await markPendingCompleted(claimedPurchase.order_id, requestData.payment_id, services.supabaseServiceClient)
    console.log(`[Purchase] ✅ Purchase marked as completed`)

    // Get updated tokens and log success
    const updatedTokens = await services.tokenService.getUserTokens(userContext.userId!, userPlan)
    console.log(`[Purchase] 📊 Final token balance: ${JSON.stringify(updatedTokens)}`)
    
    await services.analyticsLogger.logEvent('purchase_confirmed_by_user', {
      user_id: userContext.userId,
      order_id: requestData.order_id,
      payment_id: requestData.payment_id,
      token_amount: claimedPurchase.token_amount,
      new_purchased_balance: addResult.newPurchasedBalance
    })
    
    console.log(`[Purchase] 🎉 Payment confirmation completed successfully!`)
    return buildResponse({
      success: true,
      message: 'Purchase confirmed successfully',
      tokens_added: claimedPurchase.token_amount,
      token_balance: updatedTokens
    })
    
  } catch (error) {
    console.error(`[Purchase] ❌ FAILED to confirm purchase:`, error)
    console.error(`[Purchase] ❌ Error details:`, {
      name: error instanceof Error ? error.name : 'Unknown',
      message: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined
    })
    
    // Only mark failed for definitive payment errors, not transient/concurrency errors.
    // Pre-claim amount/capture failures are terminal; other pre-claim failures remain retryable.
    const isPreClaimPaymentFailure = error instanceof AppError &&
      error.statusCode === 402 &&
      (error.code === 'PAYMENT_NOT_CAPTURED' || error.code === 'PAYMENT_AMOUNT_MISMATCH')
    const isDefinitiveFailure = purchaseWasClaimed || isPreClaimPaymentFailure
    if (isDefinitiveFailure && requestData?.order_id) {
      try {
        console.log(`[Purchase] 🚫 Marking order ${requestData.order_id} as failed`)
        const markedFailed = await markPendingFailed(
          requestData.order_id,
          error,
          services.supabaseServiceClient,
          purchaseWasClaimed ? ['processing'] : ['pending']
        )
        if (markedFailed) {
          console.log(`[Purchase] ✅ Order marked as failed`)
        } else {
          console.warn(`[Purchase] ⚠️ Order was not marked failed because status changed or was not eligible`)
        }
      } catch (markError) {
        console.error(`[Purchase] ❌ Failed to mark order as failed:`, markError)
      }
    } else if (!requestData?.order_id) {
      console.error(`[Purchase] ❌ No order_id available to mark as failed`)
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
async function authenticateUser(req: Request, authService: AuthService): Promise<UserContext> {
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
  const isValidSignature = await verifyPaymentSignature({
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
 * C2: Fetch the captured Razorpay payment and assert amount_paid >= stored paise.
 * Prevents a client from submitting a valid signature for a ₹1 payment to claim
 * tokens worth ₹40 by comparing against the server-computed amount we stored.
 */
async function verifyPaymentAmount(paymentId: string, expectedPaise: number): Promise<void> {
  const keyId = Deno.env.get('RAZORPAY_KEY_ID')
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')
  if (!keyId || !keySecret) {
    throw new AppError('CONFIGURATION_ERROR', 'Payment service not configured', 500)
  }

  const razorpay = new Razorpay({ key_id: keyId, key_secret: keySecret })
  let payment: Record<string, unknown>
  try {
    payment = await (razorpay.payments as any).fetch(paymentId)
  } catch (err) {
    throw new AppError('PAYMENT_FETCH_ERROR', 'Unable to verify payment with Razorpay', 502)
  }

  const capturedAmount = Number(payment.amount)
  const capturedStatus = String(payment.status)

  if (capturedStatus !== 'captured') {
    throw new AppError('PAYMENT_NOT_CAPTURED', `Payment ${paymentId} is ${capturedStatus}, not captured`, 402)
  }

  if (!Number.isFinite(capturedAmount) || capturedAmount < expectedPaise) {
    throw new AppError(
      'PAYMENT_AMOUNT_MISMATCH',
      `Payment amount ${capturedAmount} paise is less than expected ${expectedPaise} paise`,
      402
    )
  }
}

/**
 * Load pending purchase from database
 */
async function loadPendingPurchase(orderId: string, userId: string, supabaseServiceClient: SupabaseClient): Promise<PendingPurchase> {
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
 * Atomic claim operation - updates status from pending or retryable failed to processing
 */
async function claimPendingPurchaseForProcessing(orderId: string, userId: string, supabaseServiceClient: SupabaseClient): Promise<PendingPurchase> {
  // First try to claim pending purchases
  let { data: claimedPurchase, error } = await supabaseServiceClient
    .from('pending_token_purchases')
    .update({
      status: 'processing',
      updated_at: new Date().toISOString()
    })
    .eq('order_id', orderId)
    .eq('user_id', userId) // Security: Only update records for this user
    .eq('status', 'pending') // Only update if still pending
    .select('*')
    .maybeSingle() // Use maybeSingle to handle 0 rows gracefully

  // If no pending purchase found, check current status
  if (error || !claimedPurchase) {
    console.log(`[Purchase] 🔄 No pending purchase found, checking current status: ${orderId}`)

    const { data: currentPurchase, error: statusError } = await supabaseServiceClient
      .from('pending_token_purchases')
      .select('*')
      .eq('order_id', orderId)
      .eq('user_id', userId) // Security: Only check records for this user
      .single()

    if (statusError || !currentPurchase) {
      throw new AppError(
        'PURCHASE_NOT_FOUND',
        'Purchase record not found',
        404
      )
    }

    // If already completed, this is success (webhook processed it)
    if (currentPurchase.status === 'completed') {
      console.log(`[Purchase] ✅ Purchase already completed by webhook: ${orderId}`)
      return currentPurchase
    }

    // If currently processing, check if stale (handler crashed) or live
    if (currentPurchase.status === 'processing') {
      const updatedAt = currentPurchase.updated_at ? new Date(currentPurchase.updated_at) : null
      const staleThresholdMs = 5 * 60 * 1000 // 5 minutes
      const isStale = updatedAt && (Date.now() - updatedAt.getTime()) > staleThresholdMs

      if (isStale) {
        // F6: Original handler likely crashed — reclaim the row so this request can proceed.
        console.warn(`[Purchase] ⚠️ Found stale processing purchase (> 5 min), reclaiming: ${orderId}`)
        const { data: reclaimedPurchase } = await supabaseServiceClient
          .from('pending_token_purchases')
          .update({ status: 'processing', updated_at: new Date().toISOString() })
          .eq('order_id', orderId)
          .eq('user_id', userId)
          .eq('status', 'processing')
          .select('*')
          .maybeSingle()
        if (reclaimedPurchase) return reclaimedPurchase
      }

      console.log(`[Purchase] ⏳ Purchase is being processed by another handler: ${orderId}`)
      // Wait 2 seconds and check again
      await new Promise(resolve => setTimeout(resolve, 2000))

      const { data: finalStatus } = await supabaseServiceClient
        .from('pending_token_purchases')
        .select('*')
        .eq('order_id', orderId)
        .eq('user_id', userId)
        .single()

      if (finalStatus?.status === 'completed') {
        console.log(`[Purchase] ✅ Purchase completed by other handler: ${orderId}`)
        return finalStatus
      }
    }

    // If still pending, try to claim it one more time (race condition with webhook)
    if (currentPurchase.status === 'pending') {
      console.log(`[Purchase] 🔄 Purchase still pending, retrying atomic claim: ${orderId}`)

      const { data: retryClaimedPurchase, error: retryError } = await supabaseServiceClient
        .from('pending_token_purchases')
        .update({
          status: 'processing',
          updated_at: new Date().toISOString()
        })
        .eq('order_id', orderId)
        .eq('user_id', userId) // Security: Only update records for this user
        .eq('status', 'pending')
        .select('*')
        .maybeSingle()

      if (!retryError && retryClaimedPurchase) {
        console.log(`[Purchase] ✅ Successfully claimed pending purchase on retry: ${orderId}`)
        return retryClaimedPurchase
      }

      // If still can't claim, wait and check if webhook processed it
      console.log(`[Purchase] ⏳ Still can't claim pending purchase, waiting for webhook: ${orderId}`)
      await new Promise(resolve => setTimeout(resolve, 3000))

      const { data: finalCheck } = await supabaseServiceClient
        .from('pending_token_purchases')
        .select('*')
        .eq('order_id', orderId)
        .eq('user_id', userId) // Security: Only check records for this user
        .single()

      if (finalCheck?.status === 'completed') {
        console.log(`[Purchase] ✅ Purchase completed by webhook during wait: ${orderId}`)
        return finalCheck
      }
    }

    // Try to claim retryable failed purchases (where another handler owned the row during a race)
    if (currentPurchase.status === 'failed' && currentPurchase.error_message?.includes('Cannot claim purchase with status:')) {
      console.log(`[Purchase] ♻️ Found retryable failed purchase, resetting to processing: ${orderId}`)

      const { data: retriedPurchase, error: retryError } = await supabaseServiceClient
        .from('pending_token_purchases')
        .update({
          status: 'processing',
          error_message: null, // Clear the error message
          updated_at: new Date().toISOString()
        })
        .eq('order_id', orderId)
        .eq('user_id', userId) // Security: Only update records for this user
        .eq('status', 'failed')
        .select('*')
        .maybeSingle()

      if (!retryError && retriedPurchase) {
        return retriedPurchase
      }
    }

    throw new AppError(
      'PURCHASE_ALREADY_PROCESSING',
      `Cannot claim purchase with status: ${currentPurchase.status}`,
      409
    )
  }

  return claimedPurchase
}

/**
 * Short-circuit if purchase is already completed or failed
 */
async function shortCircuitIfCompletedOrFailed(pendingPurchase: PendingPurchase, userId: string, tokenService: TokenService): Promise<Response | null> {
  if (pendingPurchase.status === 'completed') {
    const currentTokens = await tokenService.getUserTokens(userId, 'standard')
    return buildResponse({
      success: true,
      message: 'Purchase already completed',
      token_balance: currentTokens
    })
  }

  if (pendingPurchase.status === 'failed') {
    // Allow retry for race condition errors (these were system errors, not payment failures)
    const isRetryableError = pendingPurchase.error_message?.includes('Purchase is already being processed or completed')

    if (isRetryableError) {
      console.log(`[Purchase] ♻️ Allowing retry for race condition error: ${pendingPurchase.order_id}`)
      // Reset to pending status to allow retry
      return null
    }

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
async function creditTokens(userId: string, tokenAmount: number, userPlan: 'free' | 'standard' | 'plus' | 'premium', tokenService: TokenService): Promise<AddTokensResult> {
  const addResult = await tokenService.addPurchasedTokens(
    userId,
    userPlan,
    tokenAmount,
    {
      userId,
      userPlan,
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
async function recordPurchaseHistory(purchase: PendingPurchase, paymentId: string, userId: string, supabaseServiceClient: SupabaseClient): Promise<void> {
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
async function markPendingCompleted(orderId: string, paymentId: string, supabaseServiceClient: SupabaseClient): Promise<void> {
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
async function markPendingFailed(
  orderId: string,
  error: unknown,
  supabaseServiceClient: SupabaseClient,
  eligibleStatuses: Array<'pending' | 'processing'> = ['processing']
): Promise<boolean> {
  // Only transition from eligible in-flight statuses; never overwrite completed rows.
  const { data } = await supabaseServiceClient
    .from('pending_token_purchases')
    .update({
      status: 'failed',
      error_message: error instanceof Error ? error.message : 'Unknown error',
      updated_at: new Date().toISOString()
    })
    .eq('order_id', orderId)
    .in('status', eligibleStatuses)
    .select('id')

  return (data?.length ?? 0) > 0
}

/**
 * Build standardized response
 */
function buildResponse(data: Record<string, unknown>): Response {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Verify Razorpay payment signature
 */
async function verifyPaymentSignature({
  orderId,
  paymentId,
  signature
}: {
  orderId: string
  paymentId: string
  signature: string
}): Promise<boolean> {
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')
  if (!keySecret) {
    console.error('[Security] RAZORPAY_KEY_SECRET not configured')
    return false
  }

  const body = `${orderId}|${paymentId}`
  return verifyHmacSha256(keySecret, body, signature)
}

createSimpleFunction(handleConfirmPurchase, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
