/**
 * Unified Receipt Validation Service
 *
 * Routes receipt validation to appropriate provider (Google Play or Apple App Store).
 * Stores receipts and validation results in database.
 */

import { SupabaseClient } from '@supabase/supabase-js'
import { validateGooglePlayReceipt, acknowledgeGooglePlayPurchase, GooglePlayReceipt } from './google-play-validator.ts'
import { validateAppleReceipt, AppleReceiptData } from './apple-appstore-validator.ts'
import { IAPProvider, IAPEnvironment } from './iap-config-service.ts'

export interface ReceiptValidationRequest {
  provider: IAPProvider
  receiptData: string
  productId: string
  userId: string
  planCode: string
  environment?: IAPEnvironment
}

export interface ReceiptValidationResponse {
  success: boolean
  receiptId: string
  subscriptionId?: string
  transactionId: string
  isValid: boolean
  expiryDate?: Date
  autoRenewing: boolean
  error?: string
}

/**
 * Validate and process IAP receipt
 */
export async function validateAndProcessReceipt(
  supabase: SupabaseClient,
  request: ReceiptValidationRequest
): Promise<ReceiptValidationResponse> {
  console.log(`[RECEIPT_VALIDATION] Processing ${request.provider} receipt for user ${request.userId}`)

  const environment = request.environment || 'production'

  // Step 1: Validate receipt with provider
  let validationResult

  if (request.provider === 'google_play') {
    const receiptData: GooglePlayReceipt = JSON.parse(request.receiptData)
    validationResult = await validateGooglePlayReceipt(supabase, receiptData, environment)
  } else {
    const appleReceipt: AppleReceiptData = { receiptData: request.receiptData }
    validationResult = await validateAppleReceipt(supabase, appleReceipt, environment)
  }

  // Step 2: Store receipt in database
  const { data: receiptRecord, error: receiptError } = await supabase
    .from('iap_receipts')
    .insert({
      user_id: request.userId,
      provider: request.provider,
      receipt_data: request.receiptData,  // TODO: Encrypt
      product_id: request.productId,
      transaction_id: validationResult.transactionId,
      validation_status: validationResult.isValid ? 'valid' : 'invalid',
      validation_response: validationResult.validationResponse,
      validated_at: new Date().toISOString(),
      purchase_date: validationResult.purchaseDate.toISOString(),
      expiry_date: validationResult.expiryDate?.toISOString(),
      is_trial: validationResult.isTrial,
      is_intro_offer: validationResult.isIntroOffer,
      environment
    })
    .select()
    .single()

  if (receiptError) {
    console.error('[RECEIPT_VALIDATION] Failed to store receipt:', receiptError)
    throw new Error('Failed to store receipt in database')
  }

  // Step 3: Log validation attempt
  await supabase
    .from('iap_verification_logs')
    .insert({
      receipt_id: receiptRecord.id,
      provider: request.provider,
      verification_method: 'api',
      verification_result: validationResult.isValid ? 'success' : 'failure',
      request_payload: {
        productId: request.productId,
        environment
      },
      response_payload: validationResult.validationResponse,
      error_message: validationResult.error,
      http_status_code: validationResult.isValid ? 200 : 400
    })

  // Step 4: If valid, create/update subscription
  let subscriptionId: string | undefined

  if (validationResult.isValid) {
    // Determine original transaction ID based on provider
    const originalTransactionId = 'originalTransactionId' in validationResult
      ? validationResult.originalTransactionId
      : validationResult.transactionId

    const { data: subscription, error: subError } = await supabase
      .from('subscriptions')
      .insert({
        user_id: request.userId,
        plan_type: request.planCode,
        provider: request.provider,
        provider_subscription_id: validationResult.transactionId,
        status: 'active',
        current_period_start: validationResult.purchaseDate.toISOString(),
        current_period_end: validationResult.expiryDate?.toISOString(),
        cancel_at_cycle_end: !validationResult.autoRenewing,
        is_iap_subscription: true,
        iap_receipt_id: receiptRecord.id,
        iap_product_id: request.productId,
        iap_original_transaction_id: originalTransactionId
      })
      .select()
      .single()

    if (subError) {
      console.error('[RECEIPT_VALIDATION] Failed to create subscription:', subError)
    } else {
      subscriptionId = subscription.id

      // Update receipt with subscription ID
      await supabase
        .from('iap_receipts')
        .update({ subscription_id: subscriptionId })
        .eq('id', receiptRecord.id)
    }

    // Step 5: Acknowledge purchase (Google Play only)
    if (request.provider === 'google_play') {
      const receiptData: GooglePlayReceipt = JSON.parse(request.receiptData)
      await acknowledgeGooglePlayPurchase(supabase, receiptData, environment)
    }
  }

  return {
    success: validationResult.isValid,
    receiptId: receiptRecord.id,
    subscriptionId,
    transactionId: validationResult.transactionId,
    isValid: validationResult.isValid,
    expiryDate: validationResult.expiryDate,
    autoRenewing: validationResult.autoRenewing,
    error: validationResult.error
  }
}

/**
 * Re-validate existing receipt (for renewals and status checks)
 */
export async function revalidateReceipt(
  supabase: SupabaseClient,
  receiptId: string
): Promise<ReceiptValidationResponse> {
  // Fetch existing receipt
  const { data: receipt, error } = await supabase
    .from('iap_receipts')
    .select('*')
    .eq('id', receiptId)
    .single()

  if (error || !receipt) {
    throw new Error('Receipt not found')
  }

  // Re-validate with provider
  return validateAndProcessReceipt(supabase, {
    provider: receipt.provider as IAPProvider,
    receiptData: receipt.receipt_data,
    productId: receipt.product_id,
    userId: receipt.user_id,
    planCode: receipt.product_id.split('.').pop() || 'standard',  // Extract plan from product ID
    environment: receipt.environment as IAPEnvironment
  })
}
