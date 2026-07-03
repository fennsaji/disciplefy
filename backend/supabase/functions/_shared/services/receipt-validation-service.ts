/**
 * Unified Receipt Validation Service
 *
 * Routes receipt validation to appropriate provider (Google Play or Apple App Store).
 * Stores receipts and validation results in database.
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { validateGooglePlayReceipt, acknowledgeGooglePlayPurchase, GooglePlayReceipt } from './google-play-validator.ts'
import { validateAppleReceipt, AppleReceiptData } from './apple-appstore-validator.ts'
import { IAPProvider, IAPEnvironment } from './iap-config-service.ts'
import { AppError } from '../utils/error-handler.ts'

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

  // H1: Before upserting, check that no other user already owns this transaction.
  const { data: existingReceipt } = await supabase
    .from('iap_receipts')
    .select('user_id')
    .eq('transaction_id', validationResult.transactionId)
    .maybeSingle()
  if (existingReceipt && existingReceipt.user_id !== request.userId) {
    console.error('[RECEIPT_VALIDATION] transaction_id already claimed by another user:', existingReceipt.user_id)
    throw new AppError(
      'RECEIPT_ALREADY_CLAIMED',
      'This purchase is already associated with a different account',
      400
    )
  }

  // Step 2: Store receipt in database (upsert by transaction_id to handle retries)
  const { data: receiptRecord, error: receiptError } = await supabase
    .from('iap_receipts')
    .upsert({
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
    }, { onConflict: 'transaction_id' })
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

    // Lookup plan_id and expected provider_plan_id for FK linkage and product verification (C4)
    const { data: planRow, error: planLookupError } = await supabase
      .from('subscription_plans')
      .select('id, subscription_plan_providers!inner(provider_plan_id)')
      .eq('plan_code', request.planCode)
      .eq('subscription_plan_providers.provider', request.provider)
      .maybeSingle()

    if (planLookupError || !planRow) {
      console.error('[RECEIPT_VALIDATION] Plan not found for planCode:', request.planCode, planLookupError)
      throw new Error(`Subscription plan '${request.planCode}' not found — cannot create subscription without valid plan`)
    }

    // C4: Assert the store-confirmed product matches the requested plan's product.
    // Without this check a buyer can purchase the cheapest tier and claim premium.
    const expectedProductId = (planRow as any).subscription_plan_providers?.[0]?.provider_plan_id
    const storeProductId = validationResult.validatedProductId
    if (expectedProductId && storeProductId && storeProductId !== expectedProductId) {
      console.error('[RECEIPT_VALIDATION] Product mismatch — store returned:', storeProductId, 'expected for plan', request.planCode, ':', expectedProductId)
      throw new AppError(
        'PRODUCT_MISMATCH',
        `Receipt is for product '${storeProductId}', not '${expectedProductId}' — cannot grant '${request.planCode}'`,
        400
      )
    }

    const insertResult = await supabase
      .from('subscriptions')
      .insert({
        user_id: request.userId,
        plan_id: planRow.id,
        plan_type: request.productId.includes('yearly')
          ? `${request.planCode}_yearly`
          : `${request.planCode}_monthly`,
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

    let subscriptionRow = insertResult.data

    if (insertResult.error) {
      // Idempotency: StoreKit/Google Play re-deliver the same purchase update, so a
      // second validation collides on the unique provider_subscription_id (code 23505).
      // The first call already activated the subscription — return that existing row
      // instead of erroring with a spurious "something went wrong". (Can't use
      // ON CONFLICT upsert here: provider_subscription_id is a partial unique index,
      // which Postgres won't accept for conflict inference.)
      if ((insertResult.error as { code?: string }).code === '23505') {
        const { data: existing } = await supabase
          .from('subscriptions')
          .select()
          .eq('provider_subscription_id', validationResult.transactionId)
          .maybeSingle()
        // H1: reject if the existing subscription belongs to a different user
        if (existing && existing.user_id !== request.userId) {
          console.error('[RECEIPT_VALIDATION] Receipt already claimed by another user:', existing.user_id)
          throw new AppError(
            'RECEIPT_ALREADY_CLAIMED',
            'This purchase receipt is already associated with a different account',
            400
          )
        }
        subscriptionRow = existing
        if (subscriptionRow) {
          const { data: updatedExisting, error: updateExistingError } = await supabase
            .from('subscriptions')
            .update({
              status: 'active',
              current_period_start: validationResult.purchaseDate.toISOString(),
              current_period_end: validationResult.expiryDate?.toISOString(),
              cancel_at_cycle_end: !validationResult.autoRenewing,
              iap_receipt_id: receiptRecord.id,
              iap_product_id: request.productId,
              iap_original_transaction_id: originalTransactionId,
              updated_at: new Date().toISOString()
            })
            .eq('id', subscriptionRow.id)
            .select()
            .single()

          if (updateExistingError) {
            throw new Error(`[RECEIPT_VALIDATION] Failed to update duplicate subscription record: ${updateExistingError.message}`)
          }

          subscriptionRow = updatedExisting
          console.log('[RECEIPT_VALIDATION] Duplicate purchase callback — updated existing subscription')
        }
      }

      if (!subscriptionRow) {
        // Throw so the caller returns HTTP 500. The receipt is stored but NOT acknowledged,
        // so Google Play will re-deliver the purchase event and the user can retry.
        throw new Error(`[RECEIPT_VALIDATION] Failed to create subscription record: ${insertResult.error.message}`)
      }
    }

    subscriptionId = subscriptionRow.id

    // Update receipt with subscription ID
    await supabase
      .from('iap_receipts')
      .update({ subscription_id: subscriptionId })
      .eq('id', receiptRecord.id)

    // Step 5: Acknowledge purchase ONLY after successful subscription creation.
    // If we acknowledge before the subscription exists, Google Play won't
    // re-deliver the purchase and the user loses their entitlement.
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
 *
 * Validates the receipt with the provider and, if valid, UPDATEs the
 * existing subscription row rather than inserting a duplicate.
 */
export async function revalidateReceipt(
  supabase: SupabaseClient,
  receiptId: string
): Promise<ReceiptValidationResponse> {
  // Fetch existing receipt (with its linked subscription)
  const { data: receipt, error } = await supabase
    .from('iap_receipts')
    .select('*')
    .eq('id', receiptId)
    .single()

  if (error || !receipt) {
    throw new Error('Receipt not found')
  }

  const environment = receipt.environment as IAPEnvironment
  const planCode = (receipt.product_id.split('.').pop() || 'standard').replace(/_monthly$|_yearly$|_annual$/, '')

  // Validate with provider
  let validationResult
  if (receipt.provider === 'google_play') {
    const receiptData: GooglePlayReceipt = JSON.parse(receipt.receipt_data)
    validationResult = await validateGooglePlayReceipt(supabase, receiptData, environment)
  } else {
    const appleReceipt: AppleReceiptData = { receiptData: receipt.receipt_data }
    validationResult = await validateAppleReceipt(supabase, appleReceipt, environment)
  }

  // Update the receipt row with latest validation result.
  // For Google Play renewals, the purchase token can rotate — update transaction_id
  // and receipt_data so future re-validations use the current token.
  const receiptUpdate: Record<string, unknown> = {
    validation_status: validationResult.isValid ? 'valid' : 'invalid',
    validation_response: validationResult.validationResponse,
    validated_at: new Date().toISOString(),
    expiry_date: validationResult.expiryDate?.toISOString(),
    is_trial: validationResult.isTrial,
    is_intro_offer: validationResult.isIntroOffer,
    updated_at: new Date().toISOString()
  }

  // If the provider returned a different token (Google Play renewal token rotation),
  // update transaction_id so future calls use the latest token.
  if (receipt.provider === 'google_play' && validationResult.transactionId && validationResult.transactionId !== receipt.transaction_id) {
    console.log(`[RECEIPT_VALIDATION] Token rotated: ${receipt.transaction_id} → ${validationResult.transactionId}`)
    receiptUpdate.transaction_id = validationResult.transactionId
  }

  await supabase
    .from('iap_receipts')
    .update(receiptUpdate)
    .eq('id', receiptId)

  // Log validation attempt
  await supabase
    .from('iap_verification_logs')
    .insert({
      receipt_id: receiptId,
      provider: receipt.provider,
      verification_method: 'api',
      verification_result: validationResult.isValid ? 'success' : 'failure',
      request_payload: { productId: receipt.product_id, environment },
      response_payload: validationResult.validationResponse,
      error_message: validationResult.error,
      http_status_code: validationResult.isValid ? 200 : 400
    })

  // If valid, UPDATE the existing subscription (don't INSERT)
  let subscriptionId: string | undefined

  if (validationResult.isValid) {
    // For Google Play, purchase tokens rotate on renewal — iap_original_transaction_id
    // was set from originalTransactionId (stable) during initial purchase.
    // Use originalTransactionId for lookup; fall back to transactionId for Apple.
    const lookupTransactionId = 'originalTransactionId' in validationResult
      ? (validationResult as any).originalTransactionId
      : validationResult.transactionId

    // Find the existing subscription by receipt or by original transaction id
    const { data: existingSub } = await supabase
      .from('subscriptions')
      .select('id')
      .eq('user_id', receipt.user_id)
      .eq('provider', receipt.provider)
      .eq('iap_original_transaction_id', lookupTransactionId)
      .maybeSingle()

    const subId = existingSub?.id ?? receipt.subscription_id

    if (subId) {
      await supabase
        .from('subscriptions')
        .update({
          status: 'active',
          current_period_end: validationResult.expiryDate?.toISOString(),
          cancel_at_cycle_end: !validationResult.autoRenewing,
          updated_at: new Date().toISOString()
        })
        .eq('id', subId)

      subscriptionId = subId
    } else {
      // No existing subscription found — fall back to insert path
      console.warn('[RECEIPT_VALIDATION] revalidateReceipt: no existing subscription found, falling back to insert')
      const insertResult = await validateAndProcessReceipt(supabase, {
        provider: receipt.provider as IAPProvider,
        receiptData: receipt.receipt_data,
        productId: receipt.product_id,
        userId: receipt.user_id,
        planCode,
        environment
      })
      return insertResult
    }
  }

  return {
    success: validationResult.isValid,
    receiptId,
    subscriptionId,
    transactionId: validationResult.transactionId,
    isValid: validationResult.isValid,
    expiryDate: validationResult.expiryDate,
    autoRenewing: validationResult.autoRenewing,
    error: validationResult.error
  }
}
