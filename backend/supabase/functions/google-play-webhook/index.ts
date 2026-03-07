/**
 * Google Play Real-Time Developer Notifications Webhook
 *
 * Handles subscription events from Google Play via Cloud Pub/Sub.
 * Documentation: https://developer.android.com/google/play/billing/rtdn-reference
 *
 * Events handled:
 * - SUBSCRIPTION_PURCHASED
 * - SUBSCRIPTION_RENEWED
 * - SUBSCRIPTION_CANCELED
 * - SUBSCRIPTION_EXPIRED
 * - SUBSCRIPTION_RECOVERED
 * - SUBSCRIPTION_ON_HOLD
 * - SUBSCRIPTION_IN_GRACE_PERIOD
 * - SUBSCRIPTION_RESTARTED
 * - SUBSCRIPTION_PAUSED
 * - SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED
 * - SUBSCRIPTION_REVOKED
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'
import { revalidateReceipt } from '../_shared/services/receipt-validation-service.ts'

interface PubSubMessage {
  message: {
    data: string  // Base64 encoded JSON
    messageId: string
    publishTime: string
  }
  subscription: string
}

interface DeveloperNotification {
  version: string
  packageName: string
  eventTimeMillis: string
  subscriptionNotification?: {
    version: string
    notificationType: number
    purchaseToken: string
    subscriptionId: string
  }
  testNotification?: {
    version: string
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  // Validate Pub/Sub push token
  const url = new URL(req.url)
  const requestToken = url.searchParams.get('token')
  const expectedToken = Deno.env.get('GOOGLE_PLAY_WEBHOOK_TOKEN')
  if (!expectedToken || requestToken !== expectedToken) {
    console.warn('[GOOGLE_PLAY_WEBHOOK] Invalid or missing token')
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  try {
    console.log('[GOOGLE_PLAY_WEBHOOK] Received notification')

    // Parse Pub/Sub message
    const pubSubMessage: PubSubMessage = await req.json()
    const messageId = pubSubMessage.message.messageId

    // Decode base64 data
    const decodedData = atob(pubSubMessage.message.data)
    const notification: DeveloperNotification = JSON.parse(decodedData)

    console.log('[GOOGLE_PLAY_WEBHOOK] Notification:', {
      messageId,
      packageName: notification.packageName,
      type: notification.subscriptionNotification?.notificationType
    })

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Check for duplicate notification (idempotency).
    // Use an atomic INSERT ON CONFLICT DO NOTHING to avoid a race condition
    // where two concurrent requests both see no existing row and both proceed.
    const { data: dedupResult, error: dedupError } = await supabase
      .from('iap_webhook_events')
      .insert({
        provider: 'google_play',
        event_type: 'DEDUP_CHECK',
        notification_id: messageId,
        raw_payload: {},
        processing_status: 'pending'
      })
      .select('id')
      .single()

    if (dedupError) {
      // Unique constraint violation (code 23505) means duplicate — return OK
      if (dedupError.code === '23505') {
        console.log('[GOOGLE_PLAY_WEBHOOK] Duplicate notification (constraint), skipping')
        return new Response('OK', { status: 200, headers: corsHeaders })
      }
      // Re-check: maybe the row already existed before this request arrived
      const { data: existing } = await supabase
        .from('iap_webhook_events')
        .select('id')
        .eq('provider', 'google_play')
        .eq('notification_id', messageId)
        .maybeSingle()

      if (existing) {
        console.log('[GOOGLE_PLAY_WEBHOOK] Duplicate notification, skipping')
        return new Response('OK', { status: 200, headers: corsHeaders })
      }
      // Unexpected error — log and continue so the event is not silently dropped
      console.error('[GOOGLE_PLAY_WEBHOOK] Dedup insert error:', dedupError)
    }

    // dedupResult holds the placeholder row id; it will be updated below
    const dedupRowId = dedupResult?.id

    // Handle test notification
    if (notification.testNotification) {
      console.log('[GOOGLE_PLAY_WEBHOOK] Test notification received')

      // Update the dedup row (already inserted above) with actual event details
      if (dedupRowId) {
        await supabase.from('iap_webhook_events').update({
          event_type: 'TEST_NOTIFICATION',
          raw_payload: notification,
          processing_status: 'processed',
          processed_at: new Date().toISOString()
        }).eq('id', dedupRowId)
      }

      return new Response('OK', { status: 200, headers: corsHeaders })
    }

    // Handle subscription notification
    if (notification.subscriptionNotification) {
      const subNotification = notification.subscriptionNotification
      const eventType = getEventType(subNotification.notificationType)

      // Update the dedup row (already inserted above) with actual event details
      const { data: webhookEvent, error: webhookError } = await supabase
        .from('iap_webhook_events')
        .update({
          event_type: eventType,
          raw_payload: notification,
          transaction_id: subNotification.purchaseToken,
          processing_status: 'pending'
        })
        .eq('id', dedupRowId)
        .select()
        .single()

      if (webhookError) {
        console.error('[GOOGLE_PLAY_WEBHOOK] Failed to store event:', webhookError)
        throw new Error('Failed to store webhook event')
      }

      try {
        // Find receipt by transaction ID
        const { data: receipt, error: receiptError } = await supabase
          .from('iap_receipts')
          .select('id, subscription_id')
          .eq('transaction_id', subNotification.purchaseToken)
          .eq('provider', 'google_play')
          .maybeSingle()

        if (!receipt) {
          console.warn('[GOOGLE_PLAY_WEBHOOK] Receipt not found for token:', subNotification.purchaseToken)

          // Mark as pending (not failed) — receipt may not yet exist due to timing race.
          // A future cron job can retry events where processed_at is null and
          // error_message starts with 'Receipt not found'.
          await supabase
            .from('iap_webhook_events')
            .update({
              processing_status: 'pending',
              error_message: 'Receipt not found - pending retry',
              processed_at: null
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
          eventType,
          subNotification,
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

        console.log('[GOOGLE_PLAY_WEBHOOK] Event processed successfully')
      } catch (processingError) {
        console.error('[GOOGLE_PLAY_WEBHOOK] Processing error:', processingError)

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
    }

    return new Response('OK', { status: 200, headers: corsHeaders })
  } catch (error) {
    console.error('[GOOGLE_PLAY_WEBHOOK] Error:', error)
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }
})

/**
 * Map Google Play notification type to event name
 */
function getEventType(notificationType: number): string {
  const types: Record<number, string> = {
    1: 'SUBSCRIPTION_RECOVERED',
    2: 'SUBSCRIPTION_RENEWED',
    3: 'SUBSCRIPTION_CANCELED',
    4: 'SUBSCRIPTION_PURCHASED',
    5: 'SUBSCRIPTION_ON_HOLD',
    6: 'SUBSCRIPTION_IN_GRACE_PERIOD',
    7: 'SUBSCRIPTION_RESTARTED',
    8: 'SUBSCRIPTION_PRICE_CHANGE_CONFIRMED',
    9: 'SUBSCRIPTION_DEFERRED',
    10: 'SUBSCRIPTION_PAUSED',
    11: 'SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED',
    12: 'SUBSCRIPTION_REVOKED',
    13: 'SUBSCRIPTION_EXPIRED'
  }
  return types[notificationType] || `UNKNOWN_TYPE_${notificationType}`
}

/**
 * Fetch current metadata for a subscription to enable safe merging.
 * All metadata writes must merge with existing keys rather than replacing.
 */
async function getSubscriptionMetadata(supabase: any, subscriptionId: string): Promise<Record<string, unknown>> {
  const { data } = await supabase
    .from('subscriptions')
    .select('metadata')
    .eq('id', subscriptionId)
    .single()
  return (data?.metadata as Record<string, unknown>) ?? {}
}

/**
 * Process subscription event and update database
 */
async function processSubscriptionEvent(
  supabase: any,
  eventType: string,
  notification: any,
  receiptId: string,
  subscriptionId: string | null
): Promise<void> {
  console.log('[GOOGLE_PLAY_WEBHOOK] Processing event:', eventType)

  if (!subscriptionId) {
    console.warn('[GOOGLE_PLAY_WEBHOOK] No subscription ID, skipping update')
    return
  }

  // Re-validate receipt for renewal events.
  // Note: revalidateReceipt uses the stored purchase token. For renewals, Google
  // may issue a new token — sync-subscription-status handles token rotation on
  // app open (Scenario 3). Here we attempt re-validation and proceed even if it
  // returns invalid, to avoid silently dropping the renewal event.
  if (eventType === 'SUBSCRIPTION_RENEWED' || eventType === 'SUBSCRIPTION_RECOVERED') {
    console.log('[GOOGLE_PLAY_WEBHOOK] Re-validating receipt')
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
    } else {
      // Token may have rotated — mark pending so sync-subscription-status retries on next app open
      console.warn('[GOOGLE_PLAY_WEBHOOK] Re-validation returned invalid — token may have rotated, sync will correct on next app open')
    }
  }

  // Handle cancellation — user cancelled, access continues until period end
  if (eventType === 'SUBSCRIPTION_CANCELED') {
    await supabase
      .from('subscriptions')
      .update({
        status: 'pending_cancellation',
        cancel_at_cycle_end: true,
        cancelled_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
  }

  // Handle expiration
  if (eventType === 'SUBSCRIPTION_EXPIRED') {
    await supabase
      .from('subscriptions')
      .update({
        status: 'expired',
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
  }

  // Handle revocation (refund) — revoke access immediately
  if (eventType === 'SUBSCRIPTION_REVOKED') {
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

  // Handle account on hold — payment failed, access must be suspended immediately.
  // Uses dedicated 'on_hold' status distinct from user-initiated 'paused'.
  if (eventType === 'SUBSCRIPTION_ON_HOLD') {
    const existingMetadata = await getSubscriptionMetadata(supabase, subscriptionId)
    await supabase
      .from('subscriptions')
      .update({
        status: 'on_hold',
        metadata: { ...existingMetadata, on_hold: true, on_hold_at: new Date().toISOString() },
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
  }

  // Handle purchase confirmed (idempotent — app flow already creates sub via create-subscription-v2)
  if (eventType === 'SUBSCRIPTION_PURCHASED') {
    await supabase
      .from('subscriptions')
      .update({
        status: 'active',
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
    console.log('[GOOGLE_PLAY_WEBHOOK] Purchase confirmed active:', subscriptionId)
  }

  // Handle grace period — payment failed but access maintained temporarily.
  // Re-validate to get actual expiry from Google Play rather than computing NOW+7.
  if (eventType === 'SUBSCRIPTION_IN_GRACE_PERIOD') {
    const existingMetadata = await getSubscriptionMetadata(supabase, subscriptionId)
    let gracePeriodExpiry: string

    try {
      const validationResult = await revalidateReceipt(supabase, receiptId)
      // Google Play returns the real expiry (end of grace window) in expiryDate
      gracePeriodExpiry = validationResult.expiryDate?.toISOString() ?? new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
    } catch {
      // Fallback to 7 days if re-validation fails
      gracePeriodExpiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
    }

    await supabase
      .from('subscriptions')
      .update({
        status: 'active',
        metadata: {
          ...existingMetadata,
          in_grace_period: true,
          grace_period_started_at: new Date().toISOString(),
          grace_period_expires_at: gracePeriodExpiry
        },
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
    console.log('[GOOGLE_PLAY_WEBHOOK] Grace period set, expires:', gracePeriodExpiry)
  }

  // Handle restart — user re-subscribed from on-hold or paused state.
  // Clear only the state flags; preserve other business metadata.
  if (eventType === 'SUBSCRIPTION_RESTARTED') {
    const existingMetadata = await getSubscriptionMetadata(supabase, subscriptionId)
    const { on_hold, on_hold_at, paused, paused_at, in_grace_period, grace_period_started_at, grace_period_expires_at, ...remainingMetadata } = existingMetadata
    await supabase
      .from('subscriptions')
      .update({
        status: 'active',
        cancel_at_cycle_end: false,
        metadata: remainingMetadata,
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
  }

  // Handle pause — user voluntarily paused, access ends at current_period_end.
  // Set status to 'paused' so access gating takes effect at period end.
  if (eventType === 'SUBSCRIPTION_PAUSED') {
    const existingMetadata = await getSubscriptionMetadata(supabase, subscriptionId)
    await supabase
      .from('subscriptions')
      .update({
        status: 'paused',
        cancel_at_cycle_end: true,
        metadata: { ...existingMetadata, paused: true, paused_at: new Date().toISOString() },
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
  }

  // Handle pause schedule changed (log only, no access change)
  if (eventType === 'SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED') {
    console.log('[GOOGLE_PLAY_WEBHOOK] Pause schedule changed for subscription:', subscriptionId)
  }

  // Handle price change confirmed by user — record in metadata, no status change
  if (eventType === 'SUBSCRIPTION_PRICE_CHANGE_CONFIRMED') {
    const existingMetadata = await getSubscriptionMetadata(supabase, subscriptionId)
    await supabase
      .from('subscriptions')
      .update({
        metadata: { ...existingMetadata, price_change_confirmed: true, price_change_confirmed_at: new Date().toISOString() },
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
    console.log('[GOOGLE_PLAY_WEBHOOK] Price change confirmed for subscription:', subscriptionId)
  }

  // Handle deferred billing — payment deferred, subscription remains active
  if (eventType === 'SUBSCRIPTION_DEFERRED') {
    const existingMetadata = await getSubscriptionMetadata(supabase, subscriptionId)
    await supabase
      .from('subscriptions')
      .update({
        metadata: { ...existingMetadata, payment_deferred: true, deferred_at: new Date().toISOString() },
        updated_at: new Date().toISOString()
      })
      .eq('id', subscriptionId)
    console.log('[GOOGLE_PLAY_WEBHOOK] Billing deferred for subscription:', subscriptionId)
  }
}
