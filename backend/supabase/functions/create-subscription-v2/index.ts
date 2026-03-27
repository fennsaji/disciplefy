/**
 * Create Subscription V2 Edge Function
 *
 * Generic subscription creation endpoint supporting multiple payment providers:
 * - Razorpay (Web): Creates subscription and returns authorization URL
 * - Google Play (Android): Validates receipt and activates subscription
 * - Apple App Store (iOS): Validates receipt and activates subscription
 *
 * Request Body:
 * - plan_code: Plan identifier (standard, plus, premium)
 * - provider: Payment provider (razorpay, google_play, apple_appstore)
 * - region: Region code (default: IN)
 * - promo_code: Optional promotional code
 * - receipt: Purchase receipt for IAP (Google Play/Apple only)
 *
 * Returns:
 * - success: Boolean
 * - subscription_id: Internal subscription UUID
 * - provider_subscription_id: External provider subscription ID
 * - authorization_url: Razorpay checkout URL (Razorpay only)
 * - status: Subscription status
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'
import { PaymentProviderFactory } from '../_shared/services/payment-providers/provider-factory.ts'
import { ProviderType } from '../_shared/services/payment-providers/base-provider.ts'
import { validateAndProcessReceipt } from '../_shared/services/receipt-validation-service.ts'
import { cancelGooglePlaySubscription } from '../_shared/services/google-play-validator.ts'

interface CreateSubscriptionRequest {
  plan_code: string
  provider: string
  region?: string
  promo_code?: string
  receipt?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request
    const body: CreateSubscriptionRequest = await req.json()
    const { plan_code, provider, region = 'IN', promo_code, receipt } = body

    console.log('[create-subscription-v2] Request:', {
      plan_code,
      provider,
      region,
      has_promo: !!promo_code,
      has_receipt: !!receipt
    })

    // Validate required fields
    if (!plan_code || !provider) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'plan_code and provider are required'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Validate provider
    if (!PaymentProviderFactory.isValidProviderType(provider)) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid provider. Must be one of: razorpay, google_play, apple_appstore'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // For IAP providers, receipt is required
    if ((provider === 'google_play' || provider === 'apple_appstore') && !receipt) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Receipt is required for in-app purchases'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Authenticate user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Authentication required'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
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
        JSON.stringify({
          success: false,
          error: 'Invalid authentication token'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('[create-subscription-v2] User:', user.id)

    // Check for existing active subscription
    const { data: existingSubs, error: existingError } = await supabase
      .from('subscriptions')
      .select('id, status, plan_type, provider, plan_id, is_iap_subscription, provider_subscription_id, iap_product_id, current_period_start, current_period_end, amount_paise')
      .eq('user_id', user.id)
      .in('status', ['active', 'in_progress', 'created', 'pending_cancellation', 'trial', 'paused'])

    if (existingError) {
      console.error('[create-subscription-v2] Existing sub check error:', JSON.stringify(existingError))
      throw new Error('Failed to check existing subscriptions')
    }

    // Track old subscription to cancel before creating new one
    let oldSubIdToCancel: string | null = null
    let oldProviderSubId: string | null = null // Provider sub ID to cancel via API
    let oldSubProvider: string | null = null   // Provider of the OLD subscription (for correct API cancel)
    let oldIapProductId: string | null = null  // Google Play product ID of old subscription (for cancel API)
    let oldSubForRefund: { periodStart: string; periodEnd: string; amountPaise: number } | null = null

    // Downgrade-specific state (cancel at cycle end, new sub starts at period end)
    let isDowngradeCase = false
    let oldSubIdToScheduleCancel: string | null = null  // pending_cancellation instead of cancelled
    let downgradeStartAtUnix: number | null = null      // Unix ts for new sub's start_at

    // Sort by status priority so the "most active" sub is always existingSubs[0].
    // This matters during downgrade when both a pending_cancellation old sub and a
    // created new sub exist simultaneously.
    const STATUS_PRIORITY: Record<string, number> = {
      active: 1, pending_cancellation: 2, in_progress: 3, trial: 4, created: 5, paused: 6
    }
    existingSubs?.sort((a, b) => (STATUS_PRIORITY[a.status] ?? 99) - (STATUS_PRIORITY[b.status] ?? 99))

    if (existingSubs && existingSubs.length > 0) {
      const existing = existingSubs[0]
      const isIAPProvider = provider === 'google_play' || provider === 'apple_appstore'
      const existingIsIAP = existing.provider === 'google_play' || existing.provider === 'apple_appstore'
      const existingPlanCode = existing.plan_type
      const isDifferentPlan = existingPlanCode !== plan_code
      const isStaleCreated = existing.status === 'created'
      const isProviderSwitch = existing.provider !== provider

      console.log('[create-subscription-v2] Existing sub found:', {
        id: existing.id,
        status: existing.status,
        existingPlanCode,
        newPlanCode: plan_code,
        provider,
        existingProvider: existing.provider,
        isDifferentPlan,
        isStaleCreated,
        isProviderSwitch
      })

      if (existing.status === 'trial') {
        // Trial subscription superseded by a paid purchase — cancel trial and proceed
        console.log('[create-subscription-v2] Trial subscription detected, cancelling to allow paid upgrade')
        oldSubIdToCancel = existing.id
      } else if (isStaleCreated) {
        // Stale 'created' record from a previous failed backend call — cancel and allow retry
        console.log('[create-subscription-v2] Stale created record detected, cancelling and allowing retry')
        oldSubIdToCancel = existing.id
      } else if (isIAPProvider && isDifferentPlan) {
        // IAP plan upgrade / downgrade — cancel old after new receipt validates
        console.log('[create-subscription-v2] IAP plan change:', { from: existingPlanCode, to: plan_code })
        oldSubIdToCancel = existing.id
        oldProviderSubId = existing.provider_subscription_id ?? null
        oldSubProvider = existing.provider
        oldIapProductId = (existing as any).iap_product_id ?? null
      } else if (isProviderSwitch) {
        // Switching payment provider (e.g. Razorpay → Google Play) — cancel old
        console.log('[create-subscription-v2] Provider switch:', { from: existing.provider, to: provider })
        oldSubIdToCancel = existing.id
        oldProviderSubId = existing.provider_subscription_id ?? null
        oldSubProvider = existing.provider
        oldIapProductId = (existing as any).iap_product_id ?? null
      } else if (!isIAPProvider && isDifferentPlan) {
        // Razorpay plan change — split into upgrade (immediate) vs downgrade (at cycle end)
        const PLAN_TIERS: Record<string, number> = { free: 0, standard: 1, plus: 2, premium: 3 }
        const normalizePlan = (code: string) => code.replace('_monthly', '')
        const existingTier = PLAN_TIERS[normalizePlan(existingPlanCode)] ?? 0
        const newTier = PLAN_TIERS[normalizePlan(plan_code)] ?? 0

        if (newTier < existingTier) {
          // Downgrade: keep old sub active until cycle end, schedule new sub to start then
          if (existing.status === 'pending_cancellation') {
            // Downgrade already scheduled — don't allow a second one
            return new Response(
              JSON.stringify({
                success: false,
                error: 'A downgrade is already scheduled for the end of your billing period.',
                code: 'DOWNGRADE_ALREADY_SCHEDULED'
              }),
              {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
              }
            )
          }
          console.log('[create-subscription-v2] Razorpay downgrade (at cycle end):', { from: existingPlanCode, to: plan_code })
          isDowngradeCase = true
          oldSubIdToScheduleCancel = existing.id
          oldProviderSubId = existing.provider_subscription_id ?? null
          oldSubProvider = existing.provider
          if (existing.current_period_end) {
            downgradeStartAtUnix = Math.floor(new Date(existing.current_period_end).getTime() / 1000)
          }
        } else {
          // Upgrade: immediate cancellation + prorated refund
          console.log('[create-subscription-v2] Razorpay upgrade (immediate):', { from: existingPlanCode, to: plan_code })
          oldSubIdToCancel = existing.id
          oldProviderSubId = existing.provider_subscription_id ?? null
          oldSubProvider = existing.provider
          // Capture billing period for prorated refund calculation
          if (existing.current_period_start && existing.current_period_end && existing.amount_paise) {
            oldSubForRefund = {
              periodStart: existing.current_period_start,
              periodEnd: existing.current_period_end,
              amountPaise: existing.amount_paise
            }
          }
        }
      } else {
        // Genuinely duplicate: same active subscription on same plan and provider
        return new Response(
          JSON.stringify({
            success: false,
            error: 'You already have an active subscription',
            code: 'ALREADY_SUBSCRIBED'
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Special handling for free plan (no provider configuration needed)
    if (plan_code === 'free') {
      // Cancel any existing paid subscription immediately.
      // Downgrade to free is always immediate — no billing period to preserve since free costs nothing.
      const cancelTargetId = oldSubIdToCancel || oldSubIdToScheduleCancel
      if (cancelTargetId) {
        // Cancel on Razorpay API side if the old sub was Razorpay
        if (oldProviderSubId) {
          try {
            const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
            await (razorpayProvider as any).cancelSubscription(oldProviderSubId, false)
            console.log('[create-subscription-v2] Cancelled old Razorpay sub for free plan downgrade:', oldProviderSubId)
          } catch (cancelApiError) {
            console.error('[create-subscription-v2] Razorpay API cancel failed (non-fatal) on free downgrade:', cancelApiError)
          }
        }
        const { error: cancelError } = await supabase
          .from('subscriptions')
          .update({
            status: 'cancelled',
            cancelled_at: new Date().toISOString(),
            cancellation_reason: 'Downgraded to free plan',
            cancel_at_cycle_end: false,
            updated_at: new Date().toISOString()
          })
          .eq('id', cancelTargetId)
        if (cancelError) {
          console.error('[create-subscription-v2] Failed to cancel old sub for free plan downgrade:', cancelError)
          throw new Error('Failed to cancel existing subscription before downgrade to free')
        }
        console.log('[create-subscription-v2] Cancelled old subscription for free plan downgrade:', cancelTargetId)
      }

      // Fetch free plan details without provider config
      const { data: freePlanData, error: freePlanError } = await supabase
        .from('subscription_plans')
        .select('id, plan_code, plan_name, features')
        .eq('plan_code', 'free')
        .eq('is_active', true)
        .maybeSingle()

      if (freePlanError || !freePlanData) {
        console.error('[create-subscription-v2] Free plan fetch error:', freePlanError)
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Free plan not found'
          }),
          {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // Create free subscription directly (no payment needed)
      // First, get the free plan_id
      const { data: freePlan, error: freePlanIdError } = await supabase
        .from('subscription_plans')
        .select('id')
        .eq('plan_code', 'free')
        .single()

      if (freePlanIdError || !freePlan) {
        console.error('[create-subscription-v2] Failed to find free plan:', freePlanIdError)
        throw new Error('Free plan not found in subscription_plans')
      }

      const { data: newSub, error: subError } = await supabase
        .from('subscriptions')
        .insert({
          user_id: user.id,
          plan_id: freePlan.id, // Required field - links to subscription_plans
          // subscription_plan removed - plan code is accessed via plan_id → subscription_plans.plan_code
          plan_type: 'free_monthly',
          status: 'active',
          provider: provider,
          provider_subscription_id: `free_${user.id}`,
          current_period_start: new Date().toISOString(),
          current_period_end: null, // Free plan never expires
        })
        .select()
        .single()

      if (subError) {
        console.error('[create-subscription-v2] Free sub creation error:', subError)
        throw new Error('Failed to create free subscription')
      }

      console.log('[create-subscription-v2] Free subscription created:', newSub.id)

      return new Response(
        JSON.stringify({
          success: true,
          subscription_id: newSub.id,
          provider_subscription_id: newSub.provider_subscription_id,
          status: 'active',
          plan_code: 'free'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Fetch plan details for paid plans
    const { data: planData, error: planError } = await supabase
      .from('subscription_plans')
      .select(`
        id,
        plan_code,
        plan_name,
        features,
        subscription_plan_providers!inner (
          provider,
          provider_plan_id,
          base_price_minor,
          currency
        )
      `)
      .eq('plan_code', plan_code)
      .eq('subscription_plan_providers.provider', provider)
      .eq('subscription_plan_providers.region', region)
      .eq('subscription_plan_providers.is_active', true)
      .eq('is_active', true)
      .maybeSingle()

    if (planError || !planData) {
      console.error('[create-subscription-v2] Plan fetch error:', planError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Plan not found or not available for this provider/region'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const planProviderData = planData.subscription_plan_providers[0]
    let basePriceMinor = planProviderData.base_price_minor
    let discountedPriceMinor: number | undefined
    let promotionalCampaignId: string | null = null
    let razorpayOfferId: string | null = null

    // Env var override for provider_plan_id — allows test vs prod plan IDs without DB changes.
    // Local dev sets RAZORPAY_PLUS_PLAN_ID etc. in .env.local (test mode IDs).
    // Production sets them in Supabase project secrets (live mode IDs).
    // Falls back to DB value if env var is not set.
    const planIdEnvKey = `RAZORPAY_${plan_code.toUpperCase()}_PLAN_ID`
    const effectiveProviderPlanId = Deno.env.get(planIdEnvKey) || planProviderData.provider_plan_id
    console.log('[create-subscription-v2] Plan ID resolution:', {
      plan_code,
      envKey: planIdEnvKey,
      fromEnv: Deno.env.get(planIdEnvKey) ?? null,
      fromDb: planProviderData.provider_plan_id,
      effective: effectiveProviderPlanId
    })

    // Validate and apply promo code
    if (promo_code) {
      const { data: promoData, error: promoError } = await supabase
        .from('promotional_campaigns')
        .select('*')
        .eq('campaign_code', promo_code)
        .eq('is_active', true)
        .gte('valid_until', new Date().toISOString())
        .lte('valid_from', new Date().toISOString())
        .maybeSingle()

      if (promoData) {
        // Check applicability
        const appliesToPlan = promoData.applicable_plans.includes('*') ||
          promoData.applicable_plans.includes(plan_code)
        const appliesToProvider = promoData.applicable_providers.includes('*') ||
          promoData.applicable_providers.includes(provider)

        if (appliesToPlan && appliesToProvider) {
          // Enforce per-user redemption limit (default: 1 use per user)
          const maxUsesPerUser = promoData.max_uses_per_user ?? 1
          const { count: existingRedemptions, error: redemptionCheckError } = await supabase
            .from('promotional_redemptions')
            .select('id', { count: 'exact', head: true })
            .eq('campaign_id', promoData.id)
            .eq('user_id', user.id)

          if (redemptionCheckError) {
            console.error('[create-subscription-v2] Failed to check promo redemptions:', redemptionCheckError)
          } else if (existingRedemptions !== null && existingRedemptions >= maxUsesPerUser) {
            console.warn('[create-subscription-v2] Promo code already used by user:', {
              promo_code,
              user_id: user.id,
              existingRedemptions,
              maxUsesPerUser
            })
            // Skip promo — treat as if no promo was provided
          } else {

          promotionalCampaignId = promoData.id

          // Resolve per-plan offer ID and discount from razorpay_offer_ids JSONB first,
          // then fall back to the scalar razorpay_offer_id / discount_value fields.
          const planOffer = promoData.razorpay_offer_ids?.[plan_code]
          if (planOffer?.offer_id) {
            razorpayOfferId = planOffer.offer_id
            // Use plan-specific discount percentage for DB tracking
            if (typeof planOffer.discount_pct === 'number') {
              const clampedPct = Math.min(100, Math.max(0, planOffer.discount_pct))
              discountedPriceMinor = Math.round(basePriceMinor * (1 - clampedPct / 100))
            }
          } else {
            // Fallback: scalar offer_id + campaign-level discount
            razorpayOfferId = promoData.razorpay_offer_id ?? null
            if (promoData.discount_type === 'percentage') {
              const clampedPct = Math.min(100, Math.max(0, promoData.discount_value))
              discountedPriceMinor = Math.round(basePriceMinor * (1 - clampedPct / 100))
            } else if (promoData.discount_type === 'fixed_amount') {
              discountedPriceMinor = Math.max(0, basePriceMinor - promoData.discount_value)
            }
          }

          // Env var override for offer ID — allows test vs prod offer IDs without DB changes.
          // Pattern: RAZORPAY_{CAMPAIGN_CODE}_{PLAN_CODE}_OFFER_ID
          // e.g. RAZORPAY_FIRSTMONTH_PLUS_OFFER_ID
          if (razorpayOfferId) {
            const offerEnvKey = `RAZORPAY_${promo_code.toUpperCase()}_${plan_code.toUpperCase()}_OFFER_ID`
            const envOfferId = Deno.env.get(offerEnvKey)
            if (envOfferId) {
              console.log('[create-subscription-v2] Offer ID overridden from env:', { offerEnvKey, envOfferId })
              razorpayOfferId = envOfferId
            }
          }

          console.log('[create-subscription-v2] Applied promo:', {
            code: promo_code,
            plan_code,
            discountedPriceMinor,
            razorpay_offer_id: razorpayOfferId
          })
          } // end: per-user redemption limit check (else branch)
        }
      }
    }

    // Calculate final price after discount
    const finalPriceMinor = discountedPriceMinor !== undefined ? discountedPriceMinor : basePriceMinor

    // Check if plan is free (₹0)
    const isFreeSubscription = finalPriceMinor === 0

    console.log('[create-subscription-v2] Price check:', {
      basePriceMinor,
      discountedPriceMinor,
      finalPriceMinor,
      isFreeSubscription
    })

    // Get payment provider (only if not free)
    const paymentProvider = isFreeSubscription ? null : PaymentProviderFactory.getProvider(provider as ProviderType)

    // Handle by provider type
    let providerResponse: any
    let subscriptionStatus = 'created'
    let authorizationUrl: string | null = null

    if (isFreeSubscription) {
      // Free subscription - skip Razorpay and activate directly
      console.log('[create-subscription-v2] Free subscription detected, activating directly')

      providerResponse = {
        id: `free_${crypto.randomUUID()}`,
        status: 'active'
      }

      subscriptionStatus = 'active' // Directly active, no authorization needed
      authorizationUrl = null

    } else if (provider === 'razorpay') {
      // Guard: reject placeholder plan IDs (plan not yet configured in Razorpay)
      if (planProviderData.provider_plan_id.includes('placeholder')) {
        return new Response(
          JSON.stringify({
            success: false,
            error: 'This plan is not yet available for purchase. Please try another plan.',
            code: 'PLAN_NOT_CONFIGURED'
          }),
          {
            status: 503,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // Razorpay: Create subscription and get authorization URL
      console.log('[create-subscription-v2] Creating Razorpay subscription with params:', {
        providerPlanId: effectiveProviderPlanId,
        plan_code,
        razorpayOfferId,
        basePriceMinor,
        discountedPriceMinor
      })

      providerResponse = await paymentProvider!.createSubscription({
        userId: user.id,
        planCode: plan_code,
        planId: planData.id,
        providerPlanId: effectiveProviderPlanId,
        basePriceMinor,
        currency: planProviderData.currency,
        discountedPriceMinor,
        promotionalCampaignId,
        offerId: razorpayOfferId,
        userEmail: user.email,
        notes: {
          user_id: user.id,
          plan_code: plan_code
        },
        // For downgrade: schedule new sub to start when old sub's billing period ends
        ...(isDowngradeCase && downgradeStartAtUnix && { startAt: downgradeStartAtUnix })
      })
      subscriptionStatus = 'created' // User needs to authorize
      authorizationUrl = providerResponse.authorizationUrl ?? null

    } else if (provider === 'google_play' || provider === 'apple_appstore') {
      // IAP: Validate receipt using new validation service
      console.log('[create-subscription-v2] Processing IAP receipt for provider:', provider)

      // Hoisted outside try so the catch block can access them for rollback.
      let cancelledSubSnapshot: Record<string, unknown> | null = null
      let cancelledSubId: string | null = oldSubIdToCancel

      try {
        // Get product_id from plan providers table
        const { data: productData, error: productError } = await supabase
          .from('subscription_plan_providers')
          .select('product_id')
          .eq('plan_id', planData.id)
          .eq('provider', provider)
          .eq('region', region)
          .single()

        if (productError || !productData?.product_id) {
          console.error('[create-subscription-v2] Product ID fetch error:', productError)
          return new Response(
            JSON.stringify({
              success: false,
              error: 'Product configuration not found',
              code: 'PRODUCT_NOT_FOUND'
            }),
            {
              status: 404,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        // For IAP, the purchase has already occurred on the device — cancel any
        // existing subscription BEFORE inserting the new one so the unique-per-user
        // constraint doesn't block the INSERT inside validateAndProcessReceipt.
        // IMPORTANT: snapshot the old sub first so we can restore it if validation fails.

        if (oldSubIdToCancel) {
          // Snapshot the current state for rollback
          const { data: snapData } = await supabase
            .from('subscriptions')
            .select('status, cancelled_at, cancellation_reason')
            .eq('id', oldSubIdToCancel)
            .single()
          cancelledSubSnapshot = snapData

          await supabase
            .from('subscriptions')
            .update({
              status: 'cancelled',
              cancelled_at: new Date().toISOString(),
              cancellation_reason: 'Superseded by new IAP purchase',
              updated_at: new Date().toISOString()
            })
            .eq('id', oldSubIdToCancel)
          console.log('[create-subscription-v2] Old subscription cancelled before IAP validation')
          oldSubIdToCancel = null // Already done — skip post-validation cancel
        }

        // Validate receipt and create subscription
        const validationResult = await validateAndProcessReceipt(supabase, {
          provider: provider as 'google_play' | 'apple_appstore',
          receiptData: receipt!,
          productId: productData.product_id,
          userId: user.id,
          planCode: plan_code,
          environment: Deno.env.get('APP_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production'
        })

        if (!validationResult.success || !validationResult.isValid) {
          // Rollback: restore old subscription so user isn't left with nothing
          if (cancelledSubId && cancelledSubSnapshot) {
            await supabase
              .from('subscriptions')
              .update({
                status: (cancelledSubSnapshot as any).status ?? 'active',
                cancelled_at: (cancelledSubSnapshot as any).cancelled_at ?? null,
                cancellation_reason: (cancelledSubSnapshot as any).cancellation_reason ?? null,
                updated_at: new Date().toISOString()
              })
              .eq('id', cancelledSubId)
            console.log('[create-subscription-v2] Rolled back old subscription — IAP validation failed')
          }
          return new Response(
            JSON.stringify({
              success: false,
              error: validationResult.error || 'Invalid purchase receipt',
              code: 'INVALID_RECEIPT'
            }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        console.log('[create-subscription-v2] IAP subscription created:', validationResult.subscriptionId)

        // Cancel the old subscription at the provider level after IAP activation.
        // DB cancellation already happened above; this ensures the old provider
        // stops billing the user immediately.
        if (oldProviderSubId && oldSubProvider) {
          try {
            if (oldSubProvider === 'razorpay') {
              const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
              await (razorpayProvider as any).cancelSubscription(oldProviderSubId, false)
              console.log('[create-subscription-v2] Old Razorpay subscription cancelled via API after IAP activation:', oldProviderSubId)
            } else if (oldSubProvider === 'google_play') {
              // provider_subscription_id stores the raw purchase token.
              // oldIapProductId holds the Google Play product ID (e.g. com.disciplefy.plus_monthly).
              const gpPurchaseToken = oldProviderSubId
              const gpProductId = oldIapProductId
              if (gpProductId && gpPurchaseToken) {
                const gpEnv = Deno.env.get('APP_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production'
                const gpPackageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') || Deno.env.get('GOOGLE_PLAY_SANDBOX_PACKAGE_NAME') || 'com.disciplefy.bible_study'
                await cancelGooglePlaySubscription(supabase, gpPackageName, gpProductId, gpPurchaseToken, gpEnv as 'sandbox' | 'production')
                console.log('[create-subscription-v2] Old Google Play subscription cancelled via API after IAP upgrade:', oldProviderSubId)
              } else {
                console.warn('[create-subscription-v2] Cannot cancel old Google Play sub — missing product ID or purchase token', { gpProductId, hasPurchaseToken: !!gpPurchaseToken })
              }
            }
            // Apple App Store: server-side cancellation not supported
          } catch (cancelApiError) {
            // Non-fatal: DB is already updated, log for manual follow-up if needed
            console.error('[create-subscription-v2] Old provider API cancellation failed (non-fatal):', cancelApiError)
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            subscription_id: validationResult.subscriptionId,
            provider_subscription_id: validationResult.transactionId,
            receipt_id: validationResult.receiptId,
            status: 'active',
            expiry_date: validationResult.expiryDate?.toISOString(),
            auto_renewing: validationResult.autoRenewing,
            message: 'IAP subscription activated successfully'
          }),
          {
            status: 201,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      } catch (iapError) {
        console.error('[create-subscription-v2] IAP validation error:', iapError)
        // Rollback: restore old subscription if we cancelled it before the error
        if (cancelledSubId && cancelledSubSnapshot) {
          try {
            await supabase
              .from('subscriptions')
              .update({
                status: (cancelledSubSnapshot as any).status ?? 'active',
                cancelled_at: (cancelledSubSnapshot as any).cancelled_at ?? null,
                cancellation_reason: (cancelledSubSnapshot as any).cancellation_reason ?? null,
                updated_at: new Date().toISOString()
              })
              .eq('id', cancelledSubId)
            console.log('[create-subscription-v2] Rolled back old subscription after IAP error')
          } catch (rollbackErr) {
            console.error('[create-subscription-v2] Rollback failed:', rollbackErr)
          }
        }
        return new Response(
          JSON.stringify({
            success: false,
            error: iapError instanceof Error ? iapError.message : 'Receipt validation failed',
            code: 'IAP_VALIDATION_ERROR'
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Cancel old subscription before inserting new one.
    // Must happen before INSERT to satisfy the unique-per-active-user constraint.
    if (oldSubIdToCancel) {
      // Issue prorated refund for Razorpay plan upgrades
      if (oldSubForRefund && oldProviderSubId && provider === 'razorpay') {
        try {
          const now = new Date()
          const periodStart = new Date(oldSubForRefund.periodStart)
          const periodEnd = new Date(oldSubForRefund.periodEnd)
          const totalDays = Math.max(1, Math.round((periodEnd.getTime() - periodStart.getTime()) / 86400000))
          const remainingDays = Math.max(0, Math.round((periodEnd.getTime() - now.getTime()) / 86400000))
          const refundAmountPaise = Math.round(oldSubForRefund.amountPaise * remainingDays / totalDays)

          console.log('[create-subscription-v2] Prorated refund calculation:', {
            totalDays, remainingDays, amountPaise: oldSubForRefund.amountPaise, refundAmountPaise
          })

          if (refundAmountPaise > 0) {
            // Fetch last paid invoice to get the Razorpay payment ID
            const { data: lastInvoice } = await supabase
              .from('subscription_invoices')
              .select('razorpay_payment_id')
              .eq('subscription_id', oldSubIdToCancel)
              .eq('status', 'paid')
              .order('paid_at', { ascending: false })
              .limit(1)
              .maybeSingle()

            if (lastInvoice?.razorpay_payment_id) {
              const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
              const refundId = await (razorpayProvider as any).issueRefund(
                lastInvoice.razorpay_payment_id,
                refundAmountPaise,
                { reason: 'Plan upgrade — prorated refund', remaining_days: String(remainingDays) }
              )
              console.log('[create-subscription-v2] Prorated refund issued:', { refundId, refundAmountPaise })
            } else {
              console.log('[create-subscription-v2] No paid invoice found for refund — skipping')
            }
          } else {
            console.log('[create-subscription-v2] No remaining days — skipping refund')
          }
        } catch (refundError) {
          // Log but don't block the upgrade — refund failure shouldn't prevent plan change
          console.error('[create-subscription-v2] Prorated refund failed (non-fatal):', refundError)
        }
      }

      // Cancel on the old provider's side (immediate)
      if (oldProviderSubId && oldSubProvider) {
        if (oldSubProvider === 'razorpay') {
          try {
            const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
            await (razorpayProvider as any).cancelSubscription(oldProviderSubId, false)
            console.log('[create-subscription-v2] Old Razorpay subscription cancelled via API:', oldProviderSubId)
          } catch (cancelApiError) {
            console.error('[create-subscription-v2] Razorpay API cancellation failed (non-fatal):', cancelApiError)
          }
        } else if (oldSubProvider === 'google_play') {
          // Cancel via Android Publisher API so Google stops billing the user.
          // providerSubscriptionId format: "{productId}:{purchaseToken}"
          const [productId, purchaseToken] = oldProviderSubId.split(':')
          if (productId && purchaseToken) {
            const gpEnvironment = Deno.env.get('APP_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production'
            const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') || Deno.env.get('GOOGLE_PLAY_SANDBOX_PACKAGE_NAME') || 'com.disciplefy.bible_study'
            await cancelGooglePlaySubscription(supabase, packageName, productId, purchaseToken, gpEnvironment)
            console.log('[create-subscription-v2] Old Google Play subscription cancelled via API:', productId)
          } else {
            console.warn('[create-subscription-v2] Could not parse Google Play providerSubscriptionId for cancellation:', oldProviderSubId)
          }
        }
        // Note: Apple App Store cancellation is not supported via server API — user must cancel from App Store.
      }

      const { error: cancelError } = await supabase
        .from('subscriptions')
        .update({
          status: 'cancelled',
          cancelled_at: new Date().toISOString(),
          cancellation_reason: 'Superseded by new subscription',
          updated_at: new Date().toISOString()
        })
        .eq('id', oldSubIdToCancel)

      if (cancelError) {
        console.error('[create-subscription-v2] Failed to cancel old subscription:', cancelError)
        throw new Error('Failed to cancel existing subscription before upgrade')
      }

      console.log('[create-subscription-v2] Old subscription cancelled in DB:', oldSubIdToCancel)
    }

    // For downgrade: cancel old Razorpay sub at cycle end + mark as pending_cancellation in DB.
    // The new (lower-tier) sub will be created with start_at = old period end.
    if (oldSubIdToScheduleCancel) {
      // Cancel on Razorpay side with cancelAtCycleEnd=true (user keeps access until period ends)
      if (oldProviderSubId && oldSubProvider === 'razorpay') {
        try {
          const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
          await razorpayProvider.cancelSubscription(oldProviderSubId, true)
          console.log('[create-subscription-v2] Old Razorpay sub scheduled for cancellation at cycle end:', oldProviderSubId)
        } catch (cancelApiError) {
          // Non-fatal: old sub may already be in a terminal state or Razorpay may reject
          console.error('[create-subscription-v2] Razorpay cycle-end cancellation failed (non-fatal):', cancelApiError)
        }
      }

      // Mark old sub as pending_cancellation in DB — access continues until current_period_end
      const { error: pendingCancelError } = await supabase
        .from('subscriptions')
        .update({
          status: 'pending_cancellation',
          cancel_at_cycle_end: true,
          cancellation_reason: `Scheduled downgrade to ${plan_code}`,
          updated_at: new Date().toISOString()
        })
        .eq('id', oldSubIdToScheduleCancel)

      if (pendingCancelError) {
        console.error('[create-subscription-v2] Failed to mark old sub as pending_cancellation:', pendingCancelError)
        throw new Error('Failed to schedule subscription cancellation for downgrade')
      }

      console.log('[create-subscription-v2] Old sub marked as pending_cancellation for downgrade:', oldSubIdToScheduleCancel)
    }

    // Store subscription in database
    const now = new Date()
    const periodEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000) // 30 days from now

    const { data: subscription, error: subError } = await supabase
      .from('subscriptions')
      .insert({
        user_id: user.id,
        plan_id: planData.id,
        provider: provider,
        provider_subscription_id: isFreeSubscription ? providerResponse.id : providerResponse.providerSubscriptionId,
        provider_metadata: providerResponse.metadata || {},
        // subscription_plan removed - plan code is accessed via plan_id → subscription_plans.plan_code
        plan_type: `${plan_code}_monthly`,
        status: subscriptionStatus,
        amount_paise: finalPriceMinor,
        currency: planProviderData.currency,
        promotional_campaign_id: promotionalCampaignId,
        discounted_price_minor: discountedPriceMinor,
        ...(isFreeSubscription && {
          current_period_start: now.toISOString(),
          current_period_end: periodEnd.toISOString()
        }),
        ...(provider === 'razorpay' && !isFreeSubscription && {
          provider_plan_id: effectiveProviderPlanId
        })
      })
      .select()
      .single()

    if (subError) {
      console.error('[create-subscription-v2] Database error inserting new subscription:', subError)

      // Compensating transaction: attempt to restore the old cancelled subscription so the user
      // is not left without an active plan. This is a best-effort rollback — if it also fails
      // the user will need manual recovery, but this covers the common single-failure case.
      if (oldSubIdToCancel) {
        const { error: restoreError } = await supabase
          .from('subscriptions')
          .update({
            status: 'active',
            cancelled_at: null,
            cancellation_reason: null,
            updated_at: new Date().toISOString()
          })
          .eq('id', oldSubIdToCancel)
        if (restoreError) {
          console.error('[create-subscription-v2] CRITICAL: Failed to restore old subscription after insert failure — manual recovery needed:', {
            oldSubId: oldSubIdToCancel,
            restoreError
          })
        } else {
          console.log('[create-subscription-v2] Restored old subscription after insert failure:', oldSubIdToCancel)
        }
      }

      // Downgrade rollback: cancel orphaned Razorpay sub and restore old sub's DB status.
      // Without this, the new Razorpay subscription is left dangling (never stored in DB)
      // and the old sub remains stuck in pending_cancellation, preventing future retries.
      if (oldSubIdToScheduleCancel) {
        // 1. Cancel the newly created (orphaned) Razorpay subscription immediately
        try {
          const newProviderSubId = isFreeSubscription
            ? (providerResponse as any).id
            : (providerResponse as any).providerSubscriptionId
          if (newProviderSubId && provider === 'razorpay') {
            const razorpayProvider = PaymentProviderFactory.getProvider('razorpay' as ProviderType)
            await razorpayProvider.cancelSubscription(newProviderSubId, false)
            console.log('[create-subscription-v2] Rollback: cancelled orphaned Razorpay sub:', newProviderSubId)
          }
        } catch (cancelErr) {
          console.error('[create-subscription-v2] Rollback: failed to cancel orphaned Razorpay sub (manual cleanup needed):', cancelErr)
        }

        // 2. Restore old DB sub from pending_cancellation back to active
        const { error: restoreErr } = await supabase
          .from('subscriptions')
          .update({
            status: 'active',
            cancel_at_cycle_end: false,
            cancellation_reason: null,
            updated_at: new Date().toISOString()
          })
          .eq('id', oldSubIdToScheduleCancel)
        if (restoreErr) {
          console.error('[create-subscription-v2] CRITICAL: Failed to restore downgrade sub after insert failure — manual recovery needed:', {
            oldSubId: oldSubIdToScheduleCancel,
            restoreErr
          })
        } else {
          console.log('[create-subscription-v2] Rollback: restored old subscription to in_progress:', oldSubIdToScheduleCancel)
        }
      }

      throw new Error('Failed to store subscription')
    }

    // Record promo redemption if applicable
    if (promotionalCampaignId && discountedPriceMinor) {
      await supabase.from('promotional_redemptions').insert({
        campaign_id: promotionalCampaignId,
        user_id: user.id,
        subscription_id: subscription.id,
        discount_amount_minor: basePriceMinor - discountedPriceMinor,
        original_price_minor: basePriceMinor,
        final_price_minor: discountedPriceMinor,
        provider: provider,
        plan_code: plan_code
      })

      // Increment campaign use count
      await supabase.rpc('increment_campaign_use_count', {
        campaign_id: promotionalCampaignId
      })
    }

    console.log('[create-subscription-v2] Subscription created:', subscription.id)

    // Build response
    const response: any = {
      success: true,
      subscription_id: subscription.id,
      provider_subscription_id: isFreeSubscription ? providerResponse.id : providerResponse.providerSubscriptionId,
      status: subscriptionStatus,
      message: isFreeSubscription
        ? 'Free subscription activated successfully'
        : isDowngradeCase
          ? 'Downgrade scheduled. Authorize the new plan — it will start at the end of your current billing period.'
          : 'Subscription created successfully. Complete payment authorization.'
    }

    // Add authorization URL for paid subscriptions
    if (!isFreeSubscription && authorizationUrl) {
      response.authorization_url = authorizationUrl
    } else if (isFreeSubscription) {
      response.authorization_url = null  // Explicitly null for free subscriptions
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 201,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    console.error('[create-subscription-v2] Error:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Internal server error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
