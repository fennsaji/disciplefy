/**
 * Apple App Store Server Notifications V2 Webhook
 *
 * Handles subscription lifecycle events from Apple's App Store Server Notifications V2.
 * Documentation: https://developer.apple.com/documentation/appstoreservernotifications
 *
 * IMPORTANT — Why this does NOT use `createServiceRoleFunction`:
 * That factory hard-rejects any request lacking `Authorization: Bearer {SERVICE_ROLE_KEY}`
 * (returns 401/403 *before* the handler runs). Apple's App Store Server Notifications send
 * NO Authorization header — authenticity is proven by the JWS signature in the body, not a
 * bearer token. Forcing the factory would make every real Apple call fail. We therefore
 * mirror `google-play-webhook` exactly: raw `serve()` + a direct service-role
 * `createClient(...)`. Authentication here is the JWS x5c-chain verification against the
 * pinned Apple Root CA - G3 (Section 2), which is strictly stronger than Google's static
 * query-param push token.
 *
 * Events handled (notificationType[.subtype]):
 * - SUBSCRIBED (INITIAL_BUY / RESUBSCRIBE)
 * - DID_RENEW
 * - DID_CHANGE_RENEWAL_STATUS (AUTO_RENEW_DISABLED / AUTO_RENEW_ENABLED)
 * - DID_FAIL_TO_RENEW (GRACE_PERIOD or none)
 * - GRACE_PERIOD_EXPIRED
 * - EXPIRED
 * - REFUND
 * - REVOKE
 * - TEST + various log-only types (RENEWAL_EXTENDED, PRICE_INCREASE, OFFER_REDEEMED, ...)
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Buffer } from 'node:buffer'
import { corsHeaders } from '../_shared/utils/cors.ts'
import {
  SignedDataVerifier,
  Environment,
} from 'npm:@apple/app-store-server-library@3.1.0'

// ---------------------------------------------------------------------------
// Apple Root CA - G3 (pinned trust anchor).
// DER bytes (base64), source: https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
// SHA-256: 63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179
// Pinned at build time — NEVER fetched at runtime.
// ---------------------------------------------------------------------------
const APPLE_ROOT_CA_G3_B64 =
  'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA=='

// ---------------------------------------------------------------------------
// Types — Apple App Store Server Notifications V2 decoded payloads.
// ---------------------------------------------------------------------------
interface SignedPayloadBody {
  signedPayload?: string
}

interface ResponseBodyV2DecodedPayload {
  notificationType: string
  subtype?: string
  notificationUUID: string
  version: string
  signedDate: number
  data?: {
    appAppleId?: number
    bundleId: string
    bundleVersion?: string
    environment: 'Sandbox' | 'Production'
    signedTransactionInfo?: string
    signedRenewalInfo?: string
  }
}

interface JWSTransactionDecodedPayload {
  transactionId: string
  originalTransactionId: string
  bundleId: string
  productId: string
  purchaseDate?: number
  originalPurchaseDate?: number
  expiresDate?: number
  type?: string
  environment?: string
}

interface JWSRenewalInfoDecodedPayload {
  originalTransactionId: string
  autoRenewProductId?: string
  productId?: string
  autoRenewStatus?: number // 0 = off, 1 = on
  expirationIntent?: number
  gracePeriodExpiresDate?: number
  environment?: string
}

// ---------------------------------------------------------------------------
// JWS / x5c certificate-chain verification (Apple official library).
//
// `SignedDataVerifier` performs the FULL security-critical checks that a naive
// JWS decode does NOT:
//   - Builds & verifies the x5c chain (leaf -> intermediate -> pinned root).
//   - Verifies the JWS signature with the leaf public key (ES256 / P-256).
//   - Enforces cert validity windows and (when enabled) OCSP revocation.
//   - Asserts the bundleId matches.
// We instantiate one verifier per environment, lazily cached, with the pinned
// Apple Root CA - G3 as the only trust anchor.
// ---------------------------------------------------------------------------

const verifierCache = new Map<string, SignedDataVerifier>()

function getVerifier(environment: 'sandbox' | 'production'): SignedDataVerifier {
  const cached = verifierCache.get(environment)
  if (cached) return cached

  const bundleIds = (Deno.env.get('APPLE_BUNDLE_ID') ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
  if (bundleIds.length === 0) {
    throw new Error('APPLE_BUNDLE_ID is not configured')
  }
  // The verifier binds to a single bundleId; use the first as the primary.
  // Additional bundles (multi-bundle setups) are still gate-checked separately
  // via isBundleAllowed() before processing.
  const bundleId = bundleIds[0]

  const env = environment === 'sandbox' ? Environment.SANDBOX : Environment.PRODUCTION
  // appAppleId is required by the library for PRODUCTION.
  const appAppleIdRaw = Deno.env.get('APPLE_APP_APPLE_ID')
  const appAppleId = appAppleIdRaw ? Number(appAppleIdRaw) : undefined
  if (env === Environment.PRODUCTION && (!appAppleId || Number.isNaN(appAppleId))) {
    throw new Error('APPLE_APP_APPLE_ID is required for PRODUCTION notifications')
  }

  const root = Buffer.from(APPLE_ROOT_CA_G3_B64, 'base64')
  // enableOnlineChecks=false: skip per-call OCSP revocation lookups. The full
  // x5c chain is still cryptographically verified against the pinned Apple Root
  // CA-G3, so forged payloads are rejected. We disable OCSP because it adds a
  // hard outbound dependency on Apple's OCSP responder to EVERY webhook — if it
  // were slow/down, legitimate notifications would be 401'd and lost. Apple
  // signing-cert revocation is extremely rare; flip to `true` if you want strict
  // revocation checking and can tolerate that availability risk.
  const verifier = new SignedDataVerifier([root], false, env, bundleId, appAppleId)
  verifierCache.set(environment, verifier)
  return verifier
}

/**
 * Verify+decode the outer notification. Determines environment from the
 * unverified payload first (only to pick the right verifier); the verifier then
 * cryptographically validates the full chain & signature.
 */
async function verifyAndDecodeNotification(
  signedPayload: string,
): Promise<ResponseBodyV2DecodedPayload> {
  // Peek environment from the unverified payload to select the verifier. This is
  // NOT trusted for auth — the verifier re-validates everything cryptographically.
  let peekedEnv: 'sandbox' | 'production' = 'production'
  try {
    const claimsB64 = signedPayload.split('.')[1]
    const claims = JSON.parse(atob(claimsB64.replace(/-/g, '+').replace(/_/g, '/')))
    if (claims?.data?.environment === 'Sandbox') peekedEnv = 'sandbox'
  } catch {
    // fall back to production verifier
  }
  const verifier = getVerifier(peekedEnv)
  return (await verifier.verifyAndDecodeNotification(signedPayload)) as unknown as ResponseBodyV2DecodedPayload
}

// ---------------------------------------------------------------------------
// Helpers (mirroring google-play-webhook conventions).
// ---------------------------------------------------------------------------

function getEventType(notificationType: string, subtype?: string): string {
  return subtype ? `${notificationType}.${subtype}` : notificationType
}

async function getSubscriptionMetadata(
  supabase: any,
  subscriptionId: string,
): Promise<Record<string, unknown>> {
  const { data } = await supabase
    .from('subscriptions')
    .select('metadata')
    .eq('id', subscriptionId)
    .single()
  return (data?.metadata as Record<string, unknown>) ?? {}
}

function isBundleAllowed(bundleId: string | undefined): boolean {
  const allow = (Deno.env.get('APPLE_BUNDLE_ID') ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
  if (allow.length === 0) {
    console.warn('[APPLE_NOTIFICATIONS] APPLE_BUNDLE_ID not configured — rejecting')
    return false
  }
  return !!bundleId && allow.includes(bundleId)
}

// ---------------------------------------------------------------------------
// Webhook entry point.
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  // ---- Parse body --------------------------------------------------------
  let body: SignedPayloadBody
  try {
    body = await req.json()
  } catch {
    return new Response('Bad request', { status: 400, headers: corsHeaders })
  }
  const signedPayload = body?.signedPayload
  if (!signedPayload || typeof signedPayload !== 'string') {
    return new Response('Missing signedPayload', { status: 400, headers: corsHeaders })
  }

  // ---- Verify signature (security-critical) ------------------------------
  let notification: ResponseBodyV2DecodedPayload
  try {
    notification = await verifyAndDecodeNotification(signedPayload)
  } catch (err) {
    console.warn('[APPLE_NOTIFICATIONS] JWS verification failed:', err instanceof Error ? err.message : err)
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  // ---- Bundle-id allow-list ----------------------------------------------
  if (!isBundleAllowed(notification.data?.bundleId)) {
    console.warn('[APPLE_NOTIFICATIONS] bundleId not in allow-list:', notification.data?.bundleId)
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  const notificationUUID = notification.notificationUUID
  const eventType = getEventType(notification.notificationType, notification.subtype)
  const environment = notification.data?.environment === 'Sandbox' ? 'sandbox' : 'production'

  console.log('[APPLE_NOTIFICATIONS] Verified notification:', {
    notificationUUID,
    eventType,
    environment,
  })

  // ---- Supabase service-role client --------------------------------------
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // ---- Idempotency via atomic INSERT ON CONFLICT (notificationUUID) ------
  const { data: dedupResult, error: dedupError } = await supabase
    .from('iap_webhook_events')
    .insert({
      provider: 'apple_appstore',
      event_type: 'DEDUP_CHECK',
      notification_id: notificationUUID,
      raw_payload: {},
      processing_status: 'pending',
    })
    .select('id')
    .single()

  if (dedupError) {
    if (dedupError.code === '23505') {
      console.log('[APPLE_NOTIFICATIONS] Duplicate notification (constraint), skipping')
      return new Response('OK', { status: 200, headers: corsHeaders })
    }
    const { data: existing } = await supabase
      .from('iap_webhook_events')
      .select('id')
      .eq('provider', 'apple_appstore')
      .eq('notification_id', notificationUUID)
      .maybeSingle()
    if (existing) {
      console.log('[APPLE_NOTIFICATIONS] Duplicate notification, skipping')
      return new Response('OK', { status: 200, headers: corsHeaders })
    }
    // Transient DB error on the dedup insert AND no existing row: fail closed so
    // Apple re-delivers. Proceeding here with an undefined dedupRowId would skip
    // recording the event and lose replay protection for this notificationUUID.
    console.error('[APPLE_NOTIFICATIONS] Dedup insert error:', dedupError)
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }
  const dedupRowId = dedupResult!.id

  // ---- Decode inner JWS (independently signed) ---------------------------
  let tx: JWSTransactionDecodedPayload | null = null
  let renew: JWSRenewalInfoDecodedPayload | null = null
  try {
    const verifier = getVerifier(environment)
    if (notification.data?.signedTransactionInfo) {
      tx = (await verifier.verifyAndDecodeTransaction(
        notification.data.signedTransactionInfo,
      )) as unknown as JWSTransactionDecodedPayload
    }
    if (notification.data?.signedRenewalInfo) {
      renew = (await verifier.verifyAndDecodeRenewalInfo(
        notification.data.signedRenewalInfo,
      )) as unknown as JWSRenewalInfoDecodedPayload
    }
  } catch (err) {
    console.warn('[APPLE_NOTIFICATIONS] Inner JWS verification failed:', err instanceof Error ? err.message : err)
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  // ---- Store the verified event on the dedup row -------------------------
  const { data: webhookEvent, error: webhookError } = await supabase
    .from('iap_webhook_events')
    .update({
      event_type: eventType,
      raw_payload: notification as unknown as Record<string, unknown>,
      parsed_data: { transaction: tx, renewal: renew, environment } as unknown as Record<string, unknown>,
      transaction_id: tx?.transactionId ?? null,
      processing_status: 'pending',
    })
    .eq('id', dedupRowId)
    .select()
    .single()

  if (webhookError || !webhookEvent) {
    console.error('[APPLE_NOTIFICATIONS] Failed to store event:', webhookError)
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }

  // ---- Log-only / no-subscription-touch event types ----------------------
  const LOG_ONLY = new Set([
    'TEST',
    'RENEWAL_EXTENDED',
    'RENEWAL_EXTENSION',
    'PRICE_INCREASE',
    'OFFER_REDEEMED',
    'CONSUMPTION_REQUEST',
    'DID_CHANGE_RENEWAL_PREF',
    'METADATA_UPDATE',
  ])
  if (LOG_ONLY.has(notification.notificationType)) {
    console.log('[APPLE_NOTIFICATIONS] Log-only event:', eventType)
    await supabase
      .from('iap_webhook_events')
      .update({ processing_status: 'processed', processed_at: new Date().toISOString() })
      .eq('id', webhookEvent.id)
    return new Response('OK', { status: 200, headers: corsHeaders })
  }

  // ---- Locate the subscription via stable originalTransactionId ----------
  // Apple's transactionId rotates per renewal; originalTransactionId is stable.
  // Primary: subscriptions.iap_original_transaction_id.
  // Fallback: iap_receipts.transaction_id (purchase-time transactionId).
  if (!tx) {
    await supabase
      .from('iap_webhook_events')
      .update({
        processing_status: 'failed',
        error_message: 'Missing signedTransactionInfo',
        processed_at: new Date().toISOString(),
      })
      .eq('id', webhookEvent.id)
    // Permanent (won't recover on retry) — ack with 200 to stop retry storm.
    return new Response('OK', { status: 200, headers: corsHeaders })
  }

  let subscriptionId: string | null = null
  let receiptId: string | null = null

  const { data: subByOriginal } = await supabase
    .from('subscriptions')
    .select('id, iap_receipt_id')
    .eq('provider', 'apple_appstore')
    .eq('iap_original_transaction_id', tx.originalTransactionId)
    .maybeSingle()

  if (subByOriginal) {
    subscriptionId = subByOriginal.id
    receiptId = subByOriginal.iap_receipt_id
  } else {
    // Fallback: match receipt by the original/current transactionId.
    const { data: receipt } = await supabase
      .from('iap_receipts')
      .select('id, subscription_id')
      .eq('provider', 'apple_appstore')
      .in('transaction_id', [tx.originalTransactionId, tx.transactionId])
      .maybeSingle()
    if (receipt) {
      receiptId = receipt.id
      subscriptionId = receipt.subscription_id
    }
  }

  if (!subscriptionId) {
    // Receipt/subscription not yet created (timing race with create-subscription).
    // Mark pending; a cron can retry. Ack 200 so Apple stops re-delivering.
    console.warn('[APPLE_NOTIFICATIONS] Subscription not found for originalTransactionId:', tx.originalTransactionId)
    await supabase
      .from('iap_webhook_events')
      .update({
        processing_status: 'pending',
        error_message: 'Receipt not found - pending retry',
        receipt_id: receiptId,
        processed_at: null,
      })
      .eq('id', webhookEvent.id)
    return new Response('OK', { status: 200, headers: corsHeaders })
  }

  await supabase
    .from('iap_webhook_events')
    .update({ receipt_id: receiptId, subscription_id: subscriptionId })
    .eq('id', webhookEvent.id)

  // ---- Process the event --------------------------------------------------
  try {
    await processNotification(supabase, notification, tx, renew, subscriptionId, receiptId, environment)

    await supabase
      .from('iap_webhook_events')
      .update({ processing_status: 'processed', processed_at: new Date().toISOString() })
      .eq('id', webhookEvent.id)

    console.log('[APPLE_NOTIFICATIONS] Event processed successfully:', eventType)
    return new Response('OK', { status: 200, headers: corsHeaders })
  } catch (processingError) {
    console.error('[APPLE_NOTIFICATIONS] Processing error:', processingError)
    await supabase
      .from('iap_webhook_events')
      .update({
        processing_status: 'failed',
        error_message: processingError instanceof Error ? processingError.message : 'Unknown error',
        processed_at: new Date().toISOString(),
      })
      .eq('id', webhookEvent.id)
    // Transient — return 500 so Apple re-delivers.
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }
})

// ---------------------------------------------------------------------------
// Subscription state machine — maps notificationType[.subtype] to updates.
// ---------------------------------------------------------------------------
async function processNotification(
  supabase: any,
  notification: ResponseBodyV2DecodedPayload,
  tx: JWSTransactionDecodedPayload,
  renew: JWSRenewalInfoDecodedPayload | null,
  subscriptionId: string,
  receiptId: string | null,
  environment: 'sandbox' | 'production',
): Promise<void> {
  const type = notification.notificationType
  const subtype = notification.subtype
  const now = new Date().toISOString()
  // Apple V2 timestamps are epoch MILLISECONDS. Guard against an unparseable
  // value so a bad date can't throw and trigger an Apple retry storm.
  const expiresDateObj = tx.expiresDate ? new Date(tx.expiresDate) : null
  const expiresIso =
    expiresDateObj && !Number.isNaN(expiresDateObj.getTime())
      ? expiresDateObj.toISOString()
      : undefined
  const autoRenewOff = renew?.autoRenewStatus === 0

  switch (type) {
    // -- New subscription / resubscribe --------------------------------------
    case 'SUBSCRIBED': {
      const meta = await getSubscriptionMetadata(supabase, subscriptionId)
      const { paused, paused_at, in_grace_period, grace_period_started_at, grace_period_expires_at, on_hold, on_hold_at, billing_retry, ...rest } = meta
      await supabase.from('subscriptions').update({
        status: 'active',
        ...(expiresIso ? { current_period_end: expiresIso } : {}),
        cancel_at_cycle_end: false,
        metadata: rest,
        updated_at: now,
      }).eq('id', subscriptionId)
      break
    }

    // -- Renewal succeeded ---------------------------------------------------
    case 'DID_RENEW': {
      const meta = await getSubscriptionMetadata(supabase, subscriptionId)
      const { in_grace_period, grace_period_started_at, grace_period_expires_at, billing_retry, ...rest } = meta
      await supabase.from('subscriptions').update({
        status: 'active',
        ...(expiresIso ? { current_period_end: expiresIso } : {}),
        // Only touch the renewal flag when renewal info is actually present —
        // otherwise a missing signedRenewalInfo would silently clear a prior cancel.
        ...(renew ? { cancel_at_cycle_end: autoRenewOff } : {}),
        metadata: rest,
        updated_at: now,
      }).eq('id', subscriptionId)
      break
    }

    // -- Auto-renew toggled --------------------------------------------------
    case 'DID_CHANGE_RENEWAL_STATUS': {
      if (subtype === 'AUTO_RENEW_DISABLED') {
        await supabase.from('subscriptions').update({
          status: 'pending_cancellation',
          cancel_at_cycle_end: true,
          cancelled_at: now,
          updated_at: now,
        }).eq('id', subscriptionId)
      } else {
        // AUTO_RENEW_ENABLED (re-enabled before expiry)
        await supabase.from('subscriptions').update({
          status: 'active',
          cancel_at_cycle_end: false,
          cancelled_at: null,
          cancellation_reason: null,
          updated_at: now,
        }).eq('id', subscriptionId)
      }
      break
    }

    // -- Renewal failed ------------------------------------------------------
    case 'DID_FAIL_TO_RENEW': {
      const meta = await getSubscriptionMetadata(supabase, subscriptionId)
      if (subtype === 'GRACE_PERIOD') {
        // Access maintained during grace window.
        const graceExpiry = renew?.gracePeriodExpiresDate
          ? new Date(renew.gracePeriodExpiresDate).toISOString()
          : expiresIso
        await supabase.from('subscriptions').update({
          status: 'active',
          ...(graceExpiry ? { current_period_end: graceExpiry } : {}),
          metadata: {
            ...meta,
            in_grace_period: true,
            grace_period_started_at: now,
            grace_period_expires_at: graceExpiry,
            billing_retry: true,
          },
          updated_at: now,
        }).eq('id', subscriptionId)
      } else {
        // No grace period -> suspend access.
        await supabase.from('subscriptions').update({
          status: 'on_hold',
          metadata: { ...meta, on_hold: true, on_hold_at: now, billing_retry: true },
          updated_at: now,
        }).eq('id', subscriptionId)
      }
      break
    }

    // -- Grace window closed without recovery --------------------------------
    case 'GRACE_PERIOD_EXPIRED': {
      const meta = await getSubscriptionMetadata(supabase, subscriptionId)
      const { in_grace_period, grace_period_started_at, grace_period_expires_at, ...rest } = meta
      await supabase.from('subscriptions').update({
        status: 'expired',
        metadata: rest,
        updated_at: now,
      }).eq('id', subscriptionId)
      break
    }

    // -- Hard expiry ---------------------------------------------------------
    case 'EXPIRED': {
      await supabase.from('subscriptions').update({
        status: 'expired',
        updated_at: now,
      }).eq('id', subscriptionId)
      break
    }

    // -- Refund (access revoked) ---------------------------------------------
    case 'REFUND': {
      await supabase.from('subscriptions').update({
        status: 'cancelled',
        cancelled_at: now,
        cancellation_reason: 'Refunded',
        updated_at: now,
      }).eq('id', subscriptionId)
      if (receiptId) {
        await supabase.from('iap_receipts').update({
          validation_status: 'refunded',
          updated_at: now,
        }).eq('id', receiptId)
      }
      break
    }

    // -- Family Sharing access revoked ---------------------------------------
    case 'REVOKE': {
      await supabase.from('subscriptions').update({
        status: 'cancelled',
        cancelled_at: now,
        cancellation_reason: 'Family Sharing revoked',
        updated_at: now,
      }).eq('id', subscriptionId)
      if (receiptId) {
        await supabase.from('iap_receipts').update({
          validation_status: 'cancelled',
          updated_at: now,
        }).eq('id', receiptId)
      }
      break
    }

    default:
      console.log('[APPLE_NOTIFICATIONS] Unhandled notificationType (no-op):', type, subtype)
  }
}
