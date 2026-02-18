/**
 * Apple App Store Receipt Validation Service
 *
 * Validates purchase receipts using Apple App Store Server API.
 * Documentation: https://developer.apple.com/documentation/appstorereceipts/verifyreceipt
 */

import { SupabaseClient } from '@supabase/supabase-js'
import { getIAPConfig } from './iap-config-service.ts'

export interface AppleReceiptData {
  receiptData: string  // Base64 encoded receipt
}

export interface AppleValidationResult {
  isValid: boolean
  transactionId: string
  originalTransactionId: string
  purchaseDate: Date
  expiryDate?: Date
  isTrial: boolean
  isIntroOffer: boolean
  autoRenewing: boolean
  validationResponse: any
  error?: string
}

/**
 * Validate Apple App Store purchase receipt
 */
export async function validateAppleReceipt(
  supabase: SupabaseClient,
  receipt: AppleReceiptData,
  environment: 'sandbox' | 'production'
): Promise<AppleValidationResult> {
  console.log('[APPLE] Validating receipt for environment:', environment)

  try {
    // Get Apple configuration
    const config = await getIAPConfig(supabase, 'apple_appstore', environment)

    // Choose verification endpoint based on environment
    const verifyUrl = environment === 'production'
      ? 'https://buy.itunes.apple.com/verifyReceipt'
      : 'https://sandbox.itunes.apple.com/verifyReceipt'

    // Verify receipt with Apple
    const response = await fetch(verifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        'receipt-data': receipt.receiptData,
        'password': config.sharedSecret,
        'exclude-old-transactions': true
      })
    })

    if (!response.ok) {
      console.error('[APPLE] API Error:', response.status)
      return {
        isValid: false,
        transactionId: '',
        originalTransactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: null,
        error: `Apple API error: ${response.status}`
      }
    }

    const validationData = await response.json()

    // Check status code
    // 0: Valid receipt
    // 21007: Sandbox receipt sent to production
    // 21008: Production receipt sent to sandbox
    if (validationData.status === 21007 && environment === 'production') {
      // Retry with sandbox endpoint
      console.log('[APPLE] Retrying with sandbox endpoint')
      return validateAppleReceipt(supabase, receipt, 'sandbox')
    }

    if (validationData.status === 21008 && environment === 'sandbox') {
      // Retry with production endpoint
      console.log('[APPLE] Retrying with production endpoint')
      return validateAppleReceipt(supabase, receipt, 'production')
    }

    if (validationData.status !== 0) {
      return {
        isValid: false,
        transactionId: '',
        originalTransactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: validationData,
        error: `Apple receipt validation failed: ${validationData.status}`
      }
    }

    // Extract latest receipt info
    const latestReceipt = validationData.latest_receipt_info?.[0]
    const pendingRenewal = validationData.pending_renewal_info?.[0]

    if (!latestReceipt) {
      return {
        isValid: false,
        transactionId: '',
        originalTransactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: validationData,
        error: 'No receipt info found'
      }
    }

    // Parse dates (Apple uses milliseconds)
    const purchaseDate = new Date(parseInt(latestReceipt.purchase_date_ms))
    const expiryDate = latestReceipt.expires_date_ms
      ? new Date(parseInt(latestReceipt.expires_date_ms))
      : undefined

    // Check if subscription is active
    const now = new Date()
    const isActive = expiryDate ? expiryDate > now : false

    // Check for trial or intro offer
    const isTrial = latestReceipt.is_trial_period === 'true'
    const isIntroOffer = latestReceipt.is_in_intro_offer_period === 'true'

    // Auto-renewing status
    const autoRenewing = pendingRenewal?.auto_renew_status === '1'

    console.log('[APPLE] Validation result:', {
      isValid: isActive,
      transactionId: latestReceipt.transaction_id,
      expiryDate,
      autoRenewing
    })

    return {
      isValid: isActive,
      transactionId: latestReceipt.transaction_id,
      originalTransactionId: latestReceipt.original_transaction_id,
      purchaseDate,
      expiryDate,
      isTrial,
      isIntroOffer,
      autoRenewing,
      validationResponse: validationData
    }
  } catch (error) {
    console.error('[APPLE] Validation error:', error)

    return {
      isValid: false,
      transactionId: '',
      originalTransactionId: '',
      purchaseDate: new Date(),
      isTrial: false,
      isIntroOffer: false,
      autoRenewing: false,
      validationResponse: null,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
}
