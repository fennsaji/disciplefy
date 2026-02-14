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
      .select('id, status, subscription_plan')
      .eq('user_id', user.id)
      .in('status', ['active', 'authenticated', 'created', 'pending_cancellation'])

    if (existingError) {
      console.error('[create-subscription-v2] Existing sub check error:', existingError)
      throw new Error('Failed to check existing subscriptions')
    }

    if (existingSubs && existingSubs.length > 0) {
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

    // Special handling for free plan (no provider configuration needed)
    if (plan_code === 'free') {
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
          // Calculate discount
          if (promoData.discount_type === 'percentage') {
            discountedPriceMinor = Math.round(basePriceMinor * (1 - promoData.discount_value / 100))
          } else if (promoData.discount_type === 'fixed_amount') {
            discountedPriceMinor = Math.max(0, basePriceMinor - promoData.discount_value)
          }
          promotionalCampaignId = promoData.id
          console.log('[create-subscription-v2] Applied promo:', {
            code: promo_code,
            discount: promoData.discount_value,
            type: promoData.discount_type
          })
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
      // Razorpay: Create subscription and get authorization URL
      providerResponse = await paymentProvider!.createSubscription({
        userId: user.id,
        planCode: plan_code,
        planId: planData.id,
        providerPlanId: planProviderData.provider_plan_id,
        basePriceMinor,
        currency: planProviderData.currency,
        discountedPriceMinor,
        promotionalCampaignId,
        userEmail: user.email,
        notes: {
          user_id: user.id,
          plan_code: plan_code
        }
      })
      subscriptionStatus = 'created' // User needs to authorize
      authorizationUrl = providerResponse.short_url

    } else if (provider === 'google_play' || provider === 'apple_appstore') {
      // IAP: Validate receipt
      if (!paymentProvider) {
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Payment provider not initialized',
            code: 'PROVIDER_ERROR'
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      const platform = provider === 'google_play' ? 'android' : 'ios'
      const receiptValidation = await paymentProvider.validateReceipt!(receipt!, platform)

      if (!receiptValidation.valid) {
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Invalid purchase receipt',
            code: 'INVALID_RECEIPT'
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      providerResponse = receiptValidation
      subscriptionStatus = 'active' // IAP subscriptions are immediately active
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
          razorpay_subscription_id: providerResponse.providerSubscriptionId,
          razorpay_plan_id: planProviderData.provider_plan_id
        })
      })
      .select()
      .single()

    if (subError) {
      console.error('[create-subscription-v2] Database error:', subError)
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
