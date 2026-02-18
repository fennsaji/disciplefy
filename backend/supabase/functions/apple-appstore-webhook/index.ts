/**
 * Apple App Store Server Notifications Webhook
 *
 * Handles subscription events from Apple App Store Server Notifications V2.
 * Documentation: https://developer.apple.com/documentation/appstoreservernotifications
 *
 * Events handled:
 * - SUBSCRIBED
 * - DID_RENEW
 * - DID_FAIL_TO_RENEW
 * - DID_CHANGE_RENEWAL_STATUS
 * - EXPIRED
 * - GRACE_PERIOD_EXPIRED
 * - REFUND
 * - REFUND_DECLINED
 * - RENEWAL_EXTENDED
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'
import { revalidateReceipt } from '../_shared/services/receipt-validation-service.ts'

interface AppleNotification {
  signedPayload: string  // JWT signed notification
}

interface DecodedPayload {
  notificationType: string
  subtype?: string
  notificationUUID: string
  data: {
    appAppleId?: number
    bundleId?: string
    bundleVersion?: string
    environment: 'Sandbox' | 'Production'
    signedTransactionInfo?: string  // JWT
    signedRenewalInfo?: string      // JWT
  }
  version: string
  signedDate: number
}

interface TransactionInfo {
  originalTransactionId: string
  transactionId: string
  productId: string
  purchaseDate: number
  originalPurchaseDate: number
  expiresDate?: number
  quantity: number
  type: string
  inAppOwnershipType: string
  signedDate: number
  revocationDate?: number
  revocationReason?: number
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  try {
    console.log('[APPLE_WEBHOOK] Received notification')

    // Parse notification
    const notification: AppleNotification = await req.json()

    // TODO: Verify JWT signature with Apple's public key
    // For now, we decode without verification (should be added in production)
    const payload = decodeJWT(notification.signedPayload) as DecodedPayload
    const notificationUUID = payload.notificationUUID

    console.log('[APPLE_WEBHOOK] Notification:', {
      notificationUUID,
      type: payload.notificationType,
      subtype: payload.subtype,
      environment: payload.data.environment
    })

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Check for duplicate notification (idempotency)
    const { data: existing } = await supabase
      .from('iap_webhook_events')
      .select('id')
      .eq('provider', 'apple_appstore')
      .eq('notification_id', notificationUUID)
      .maybeSingle()

    if (existing) {
      console.log('[APPLE_WEBHOOK] Duplicate notification, skipping')
      return new Response('OK', { status: 200, headers: corsHeaders })
    }

    // Decode transaction info if present
    let transactionInfo: TransactionInfo | null = null
    let originalTransactionId: string | null = null

    if (payload.data.signedTransactionInfo) {
      transactionInfo = decodeJWT(payload.data.signedTransactionInfo) as TransactionInfo
      originalTransactionId = transactionInfo.originalTransactionId
    }

    // Store webhook event
    const { data: webhookEvent, error: webhookError } = await supabase
      .from('iap_webhook_events')
      .insert({
        provider: 'apple_appstore',
        event_type: payload.notificationType,
        notification_id: notificationUUID,
        raw_payload: payload,
        transaction_id: originalTransactionId,
        processing_status: 'pending'
      })
      .select()
      .single()

    if (webhookError) {
      console.error('[APPLE_WEBHOOK] Failed to store event:', webhookError)
      throw new Error('Failed to store webhook event')
    }

    try {
      // Find receipt by original transaction ID
      let receipt = null
      if (originalTransactionId) {
        const { data: receiptData, error: receiptError } = await supabase
          .from('iap_receipts')
          .select('id, subscription_id')
          .eq('transaction_id', originalTransactionId)
          .eq('provider', 'apple_appstore')
          .maybeSingle()

        receipt = receiptData
      }

      if (!receipt) {
        console.warn('[APPLE_WEBHOOK] Receipt not found for transaction:', originalTransactionId)

        // Mark as failed
        await supabase
          .from('iap_webhook_events')
          .update({
            processing_status: 'failed',
            error_message: 'Receipt not found',
            processed_at: new Date().toISOString()
          })
          .eq('id', webhookEvent.id)

        return new Response('OK', { status: 200, headers: corsHeaders })
      }

      // Update webhook event with related IDs
      await supabase
        .from('iap_webhook_events')
        .update({
          receipt_id: receipt.id,
          subscription_id: receipt.subscription_id
        })
        .eq('id', webhookEvent.id)

      // Process event based on type
      await processSubscriptionEvent(
        supabase,
        payload.notificationType,
        payload.subtype,
        transactionInfo,
        receipt.id,
        receipt.subscription_id
      )

      // Mark as processed
      await supabase
        .from('iap_webhook_events')
        .update({
          processing_status: 'processed',
          processed_at: new Date().toISOString()
        })
        .eq('id', webhookEvent.id)

      console.log('[APPLE_WEBHOOK] Event processed successfully')
    } catch (processingError) {
      console.error('[APPLE_WEBHOOK] Processing error:', processingError)

      // Mark as failed
      await supabase
        .from('iap_webhook_events')
        .update({
          processing_status: 'failed',
          error_message: processingError instanceof Error ? processingError.message : 'Unknown error',
          processed_at: new Date().toISOString()
        })
        .eq('id', webhookEvent.id)
    }

    return new Response('OK', { status: 200, headers: corsHeaders })
  } catch (error) {
    console.error('[APPLE_WEBHOOK] Error:', error)
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }
})

/**
 * Decode JWT without verification (for development)
 * TODO: Add signature verification with Apple's public key
 */
function decodeJWT(token: string): any {
  const parts = token.split('.')
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format')
  }

  const payload = parts[1]
  const decoded = atob(payload.replace(/-/g, '+').replace(/_/g, '/'))
  return JSON.parse(decoded)
}

/**
 * Process subscription event and update database
 */
async function processSubscriptionEvent(
  supabase: any,
  notificationType: string,
  subtype: string | undefined,
  transactionInfo: TransactionInfo | null,
  receiptId: string,
  subscriptionId: string | null
): Promise<void> {
  console.log('[APPLE_WEBHOOK] Processing event:', notificationType, subtype)

  if (!subscriptionId) {
    console.warn('[APPLE_WEBHOOK] No subscription ID, skipping update')
    return
  }

  // Handle renewal events
  if (notificationType === 'DID_RENEW') {
    console.log('[APPLE_WEBHOOK] Re-validating receipt for renewal')
    const validationResult = await revalidateReceipt(supabase, receiptId)

    if (validationResult.isValid) {
      await supabase
        .from('subscriptions')
        .update({
          status: 'active',
          current_period_end: validationResult.expiryDate?.toISOString(),
          cancel_at_cycle_end: !validationResult.autoRenewing,
          updated_at: new Date().toISOString()
        })
        .eq('id', subscriptionId)
    }
  }

  // Handle renewal status change
  if (notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
    if (subtype === 'AUTO_RENEW_DISABLED') {
      await supabase
        .from('subscriptions')
        .update({
          cancel_at_cycle_end: true,
          cancelled_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('id', subscriptionId)
    } else if (subtype === 'AUTO_RENEW_ENABLED') {
      await supabase
        .from('subscriptions')
        .update({
          cancel_at_cycle_end: false,
          updated_at: new Date().toISOString()
        })
        .eq('id', subscriptionId)
    }
  }

  // Handle expiration
  if (notificationType === 'EXPIRED' || notificationType === 'GRACE_PERIOD_EXPIRED') {
    await supabase
      .from('subscriptions')
      .update({
        status: 'expired',
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
  }

  // Handle failed renewal
  if (notificationType === 'DID_FAIL_TO_RENEW') {
    await supabase
      .from('subscriptions')
      .update({
        status: 'expired',
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
  }

  // Handle refund
  if (notificationType === 'REFUND') {
    await supabase
      .from('subscriptions')
      .update({
        status: 'cancelled',
        cancelled_at: new Date().toISOString(),
        cancellation_reason: 'Refunded',
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)

    // Mark receipt as refunded
    await supabase
      .from('iap_receipts')
      .update({
        validation_status: 'refunded',
        updated_at: new Date().toISOString()
      })
      .eq('id', receiptId)
  }
}
