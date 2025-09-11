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
 * Handle payment confirmation with signature verification
 */
async function handleConfirmPurchase(req: Request, services: ServiceContainer): Promise<Response> {
  const { authService, tokenService, supabaseServiceClient, analyticsLogger } = services
  
  // Authenticate user
  const userContext = await authService.getUserContext(req)
  if (userContext.type !== 'authenticated') {
    throw new AppError(
      'AUTHENTICATION_REQUIRED',
      'You must be logged in to confirm purchase',
      401
    )
  }
  
  // Parse request
  const { order_id, payment_id, signature }: ConfirmPurchaseRequest = await req.json()
  
  // Verify signature
  const isValidSignature = verifyPaymentSignature({
    orderId: order_id,
    paymentId: payment_id,
    signature
  })
  
  if (!isValidSignature) {
    console.error(`[Security] Invalid signature for payment confirmation: ${payment_id}`)
    throw new AppError(
      'INVALID_SIGNATURE',
      'Payment signature verification failed',
      401
    )
  }
  
  console.log(`[Security] ✅ Payment signature verified: ${payment_id}`)
  
  // Get and validate pending purchase
  const { data: pendingPurchase, error } = await supabaseServiceClient
    .from('pending_token_purchases')
    .select('*')
    .eq('order_id', order_id)
    .eq('user_id', userContext.userId)
    .single()
  
  if (error || !pendingPurchase) {
    throw new AppError(
      'PURCHASE_NOT_FOUND',
      'Pending purchase not found or unauthorized',
      404
    )
  }
  
  if (pendingPurchase.status === 'completed') {
    // Already completed, return current status
    const currentTokens = await tokenService.getUserTokens(
      userContext.userId!,
      'standard'
    )
    
    return new Response(JSON.stringify({
      success: true,
      message: 'Purchase already completed',
      token_balance: currentTokens
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  if (pendingPurchase.status === 'failed') {
    throw new AppError(
      'PURCHASE_FAILED',
      'This purchase has failed and cannot be completed',
      400
    )
  }
  
  try {
    // Complete the purchase
    const addResult = await tokenService.addPurchasedTokens(
      userContext.userId!,
      'standard',
      pendingPurchase.token_amount,
      {
        userId: userContext.userId,
        userPlan: 'standard',
        operation: 'purchase',
        timestamp: new Date()
      }
    )
    
    if (!addResult.success) {
      throw new Error('Failed to add purchased tokens')
    }
    
    // Record purchase in history
    const costRupees = pendingPurchase.amount_paise / 100
    const paymentMethod = 'razorpay' // Frontend payment method
    
    const { data: historyId, error: historyError } = await supabaseServiceClient
      .rpc('record_purchase_history', {
        p_user_id: userContext.userId,
        p_token_amount: pendingPurchase.token_amount,
        p_cost_rupees: costRupees,
        p_cost_paise: pendingPurchase.amount_paise,
        p_payment_id: payment_id,
        p_order_id: order_id,
        p_payment_method: paymentMethod,
        p_status: 'completed'
      })
    
    if (historyError) {
      console.error('[Purchase] Failed to record purchase history:', historyError)
      // Continue despite history error - don't fail the purchase
    } else {
      console.log(`[Purchase] ✅ Purchase history recorded: ${historyId}`)
    }
    
    // Mark as completed
    await supabaseServiceClient
      .from('pending_token_purchases')
      .update({
        status: 'completed',
        payment_id,
        updated_at: new Date().toISOString()
      })
      .eq('order_id', order_id)
    
    // Get updated token status
    const updatedTokens = await tokenService.getUserTokens(
      userContext.userId!,
      'standard'
    )
    
    // Log successful confirmation
    await analyticsLogger.logEvent('purchase_confirmed_by_user', {
      user_id: userContext.userId,
      order_id,
      payment_id,
      token_amount: pendingPurchase.token_amount,
      new_purchased_balance: addResult.newPurchasedBalance
    })
    
    return new Response(JSON.stringify({
      success: true,
      message: 'Purchase confirmed successfully',
      tokens_added: pendingPurchase.token_amount,
      token_balance: updatedTokens
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('[Purchase] Failed to confirm purchase:', error)
    
    // Mark as failed
    await supabaseServiceClient
      .from('pending_token_purchases')
      .update({
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error',
        updated_at: new Date().toISOString()
      })
      .eq('order_id', order_id)
    
    throw new AppError(
      'PURCHASE_CONFIRMATION_FAILED',
      'Failed to confirm token purchase',
      500
    )
  }
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