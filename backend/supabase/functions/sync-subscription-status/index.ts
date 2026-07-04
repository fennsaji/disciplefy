/**
 * Sync Subscription Status Edge Function
 *
 * Called on app open (Android only, once per session) to reconcile internal
 * subscription state against Google Play's live state.
 *
 * Handles 4 scenarios:
 *   1. DB active  + device has NO purchases  → expire/cancel in DB
 *   2. DB inactive + device has active purchase → activate/create in DB
 *   3. DB active with token X + device has token Y (renewal) → update token + expiry
 *   4. DB active with SAME token → re-validate and update expiry if stale
 *
 * POST /functions/v1/sync-subscription-status
 * Authorization: Bearer <user JWT>
 *
 * Request:
 * {
 *   "provider": "google_play",
 *   "purchases": [{ "product_id", "purchase_token", "package_name", "receipt_data" }],
 *   "device_has_no_purchases": false
 * }
 *
 * Response:
 * { "success": true, "action_taken": "none|updated_expiry|expired_cancelled_subscription|token_updated|created_missing_subscription", "new_status": "active"|"expired", "subscription_id": "uuid" }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'
import { validateGooglePlayReceipt } from '../_shared/services/google-play-validator.ts'
import { validateAppleReceipt } from '../_shared/services/apple-appstore-validator.ts'
import { validateAndProcessReceipt } from '../_shared/services/receipt-validation-service.ts'

interface SyncPurchase {
  product_id: string
  // Android only
  purchase_token?: string
  package_name?: string
  receipt_data: string
}

interface SyncRequest {
  provider: string
  purchases: SyncPurchase[]
  device_has_no_purchases: boolean
}

type StoreValidationResult = Awaited<ReturnType<typeof validateAppleReceipt>> | Awaited<ReturnType<typeof validateGooglePlayReceipt>>

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Authenticate user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: 'Authentication required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Verify JWT and get user
    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid authentication token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body: SyncRequest = await req.json()
    const { provider, purchases = [], device_has_no_purchases } = body

    if (provider !== 'google_play' && provider !== 'apple_appstore') {
      return new Response(
        JSON.stringify({ success: false, error: 'Only google_play and apple_appstore providers are supported' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const isApple = provider === 'apple_appstore'

    console.log(`[sync-subscription-status] User ${user.id}, provider: ${provider}, purchases: ${purchases.length}, device_has_no_purchases: ${device_has_no_purchases}`)

    const environment: 'sandbox' | 'production' = Deno.env.get('APP_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production'

    // Fetch current DB subscription for this user (IAP only)
    const { data: dbSub } = await supabase
      .from('subscriptions')
      .select('id, status, provider_subscription_id, current_period_end, iap_receipt_id, plan_type, plan_id')
      .eq('user_id', user.id)
      .in('provider', isApple ? ['apple_appstore'] : ['google_play'])
      .in('status', ['active', 'pending_cancellation'])
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    const now = new Date()

    // =========================================================================
    // Scenario 1: DB active + device_has_no_purchases=true
    // Re-validate stored receipt; if expired/cancelled → expire in DB
    // =========================================================================
    if (device_has_no_purchases && dbSub) {
      console.log('[sync-subscription-status] Scenario 1: DB active but device has no purchases')

      // Fetch the stored receipt to re-validate
      let revalidationResult: { isValid: boolean } | null = null

      if (dbSub.iap_receipt_id) {
        const { data: storedReceipt } = await supabase
          .from('iap_receipts')
          .select('receipt_data, product_id')
          .eq('id', dbSub.iap_receipt_id)
          .maybeSingle()

        if (storedReceipt) {
          try {
            if (isApple) {
              revalidationResult = await validateAppleReceipt(supabase, { receiptData: storedReceipt.receipt_data }, environment)
            } else {
              const receiptData = JSON.parse(storedReceipt.receipt_data)
              revalidationResult = await validateGooglePlayReceipt(supabase, receiptData, environment)
            }
          } catch (e) {
            console.error('[sync-subscription-status] Re-validation error:', e)
          }
        }
      }

      // Also check if purchase token was provided even with device_has_no_purchases
      // (edge case: device signals no purchases but still sends token for safety; Android only)
      const tokenFromDevicePurchases = isApple ? undefined : purchases[0]?.purchase_token

      // Only act if we received a definitive response from the store.
      // A null result means the validation call itself failed (API error, network, config) —
      // expiring the row on a transient error would revoke paid access incorrectly.
      if (revalidationResult === null) {
        console.warn('[sync-subscription-status] Scenario 1: Re-validation returned no result (possible transient error) — taking no action')
        return new Response(
          JSON.stringify({ success: true, action_taken: 'none', new_status: dbSub.status, subscription_id: dbSub.id, reason: 'validation_unavailable' }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const isStillActive = revalidationResult.isValid

      if (!isStillActive) {
        console.log('[sync-subscription-status] Scenario 1: Subscription expired/cancelled on Play Store — expiring in DB')

        await supabase
          .from('subscriptions')
          .update({
            status: 'expired',
            cancelled_at: now.toISOString(),
            updated_at: now.toISOString()
          })
          .eq('id', dbSub.id)

        return new Response(
          JSON.stringify({
            success: true,
            action_taken: 'expired_cancelled_subscription',
            new_status: 'expired',
            subscription_id: dbSub.id
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Still valid — no action needed
      return new Response(
        JSON.stringify({ success: true, action_taken: 'none', new_status: dbSub.status, subscription_id: dbSub.id }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // =========================================================================
    // Scenario 2: DB inactive (no active IAP sub) + device has active purchase
    // Find or create subscription from device purchase
    // =========================================================================
    if (!dbSub && purchases.length > 0) {
      console.log('[sync-subscription-status] Scenario 2: DB has no active IAP sub but device has purchases')

      const devicePurchase = purchases[0]

      let validationForPurchase: StoreValidationResult | null = null
      let lookupId = devicePurchase.purchase_token

      if (isApple) {
        validationForPurchase = await validateAppleReceipt(
          supabase,
          { receiptData: devicePurchase.receipt_data },
          environment
        )
        lookupId = validationForPurchase.transactionId
      }

      if (!lookupId) {
        console.warn('[sync-subscription-status] Scenario 2: Missing store transaction id for device purchase')
        return new Response(
          JSON.stringify({ success: true, action_taken: 'none', reason: 'missing_transaction_id' }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { data: existingReceipt } = await supabase
        .from('iap_receipts')
        .select('id, subscription_id')
        .eq('transaction_id', lookupId)
        .maybeSingle()

      if (existingReceipt?.subscription_id) {
        // Receipt exists — just reactivate the linked subscription
        console.log('[sync-subscription-status] Scenario 2: Reactivating existing subscription')

        // Re-validate to get current expiry
        const validation = validationForPurchase ??
          await validateGooglePlayReceipt(supabase, JSON.parse(devicePurchase.receipt_data), environment)

        if (validation.isValid) {
          await supabase
            .from('subscriptions')
            .update({
              status: 'active',
              provider_subscription_id: validation.transactionId,
              current_period_end: validation.expiryDate?.toISOString(),
              cancel_at_cycle_end: !validation.autoRenewing,
              updated_at: now.toISOString()
            })
            .eq('id', existingReceipt.subscription_id)

          await supabase
            .from('iap_receipts')
            .update({
              receipt_data: devicePurchase.receipt_data,
              validation_status: 'valid',
              validation_response: validation.validationResponse,
              validated_at: now.toISOString(),
              expiry_date: validation.expiryDate?.toISOString(),
              updated_at: now.toISOString()
            })
            .eq('id', existingReceipt.id)

          return new Response(
            JSON.stringify({
              success: true,
              action_taken: 'reactivated_existing_subscription',
              new_status: 'active',
              subscription_id: existingReceipt.subscription_id
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
      } else {
        // No existing receipt — validate and create subscription from scratch
        console.log('[sync-subscription-status] Scenario 2: Creating new subscription from device purchase')

        // Determine plan code from product_id
        const planCode = _inferPlanCode(devicePurchase.product_id)

        if (!planCode) {
          console.error('[sync-subscription-status] Unknown product_id, cannot infer plan:', devicePurchase.product_id)
          return new Response(
            JSON.stringify({ success: false, error: 'UNKNOWN_PRODUCT', message: 'Unknown product ID — cannot create subscription' }),
            { status: 400, headers: { 'Content-Type': 'application/json' } }
          )
        }

        try {
          const result = await validateAndProcessReceipt(supabase, {
            provider: isApple ? 'apple_appstore' : 'google_play',
            receiptData: devicePurchase.receipt_data,
            productId: devicePurchase.product_id,
            userId: user.id,
            planCode,
            environment
          })

          if (result.success && result.subscriptionId) {
            return new Response(
              JSON.stringify({
                success: true,
                action_taken: 'created_missing_subscription',
                new_status: 'active',
                subscription_id: result.subscriptionId
              }),
              { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
          }
        } catch (e) {
          console.error('[sync-subscription-status] Scenario 2: receipt validation failed:', e)
        }
      }

      return new Response(
        JSON.stringify({ success: true, action_taken: 'none' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // =========================================================================
    // Scenarios 3 & 4: DB active + device has purchase(s)
    // =========================================================================
    if (dbSub && purchases.length > 0) {
      const devicePurchase = purchases[0]

      // For Apple: no purchase_token concept — skip token-mismatch (Scenario 3) and
      // go straight to receipt re-validation (Scenario 4 equivalent).
      if (!isApple) {
        const dbToken = dbSub.provider_subscription_id
        const deviceToken = devicePurchase.purchase_token

        // Scenario 3: Different token = renewal — update token and expiry
        if (dbToken !== deviceToken) {
          console.log('[sync-subscription-status] Scenario 3: Token mismatch — renewal detected')

          const receiptData = JSON.parse(devicePurchase.receipt_data)
          const validation = await validateGooglePlayReceipt(supabase, receiptData, environment)

          if (validation.isValid) {
            // Update subscription with new token + expiry
            await supabase
              .from('subscriptions')
              .update({
                provider_subscription_id: deviceToken,
                current_period_end: validation.expiryDate?.toISOString(),
                status: 'active',
                updated_at: now.toISOString()
              })
              .eq('id', dbSub.id)

            // Upsert iap_receipts with new token
            if (dbSub.iap_receipt_id) {
              await supabase
                .from('iap_receipts')
                .update({
                  transaction_id: deviceToken,
                  receipt_data: devicePurchase.receipt_data,
                  expiry_date: validation.expiryDate?.toISOString(),
                  validated_at: now.toISOString(),
                  updated_at: now.toISOString()
                })
                .eq('id', dbSub.iap_receipt_id)
            }

            return new Response(
              JSON.stringify({
                success: true,
                action_taken: 'token_updated',
                new_status: 'active',
                subscription_id: dbSub.id
              }),
              { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
          }

          return new Response(
            JSON.stringify({ success: true, action_taken: 'none', subscription_id: dbSub.id }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
      }

      // Scenario 4: Re-validate receipt and update expiry if stale (both platforms)
      // For Apple: receipt_data is the base64 App Store receipt. For Android: JSON string.
      console.log(`[sync-subscription-status] Scenario 4: Checking expiry staleness (${provider})`)

      const validation = isApple
        ? await validateAppleReceipt(supabase, { receiptData: devicePurchase.receipt_data }, environment)
        : await validateGooglePlayReceipt(supabase, JSON.parse(devicePurchase.receipt_data), environment)

      if (validation.isValid && validation.expiryDate) {
        const dbExpiry = dbSub.current_period_end ? new Date(dbSub.current_period_end) : null
        const newExpiry = validation.expiryDate

        // Update if DB expiry differs by more than 1 hour from validated expiry
        const diffMs = dbExpiry ? Math.abs(newExpiry.getTime() - dbExpiry.getTime()) : Infinity
        const oneHourMs = 60 * 60 * 1000

        if (diffMs > oneHourMs) {
          console.log('[sync-subscription-status] Scenario 4: Updating stale expiry date')

          await supabase
            .from('subscriptions')
            .update({
              current_period_end: newExpiry.toISOString(),
              status: 'active',
              updated_at: now.toISOString()
            })
            .eq('id', dbSub.id)

          return new Response(
            JSON.stringify({
              success: true,
              action_taken: 'updated_expiry',
              new_status: 'active',
              subscription_id: dbSub.id
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
      }

      // No meaningful difference — no action needed
      return new Response(
        JSON.stringify({ success: true, action_taken: 'none', new_status: dbSub.status, subscription_id: dbSub.id }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Default: nothing to sync
    return new Response(
      JSON.stringify({ success: true, action_taken: 'none' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[sync-subscription-status] Unexpected error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Internal server error'
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * Infer plan code from Google Play product ID.
 * e.g. "com.disciplefy.premium_monthly" → "premium"
 */
function _inferPlanCode(productId: string): string | null {
  if (productId.includes('premium')) return 'premium'
  if (productId.includes('plus')) return 'plus'
  if (productId.includes('standard')) return 'standard'
  return null // unknown product — fail closed
}
