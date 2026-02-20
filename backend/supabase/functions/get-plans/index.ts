/**
 * Get Plans Edge Function
 *
 * Fetches available subscription plans with provider-specific pricing
 * and optional promotional discounts.
 *
 * Query Parameters:
 * - provider: Payment provider (razorpay, google_play, apple_appstore)
 * - region: Region code (default: IN)
 * - promo_code: Optional promotional code to apply discount
 * - locale: BCP-47 language code for marketing feature translations (default: en)
 *           Supported: en, hi, ml
 *
 * Returns:
 * - plans: Array of available plans with pricing
 *          marketing_features is returned in the requested locale (falls back to English)
 * - promotional_campaign: Applied promo details (if any)
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'

interface Plan {
  plan_id: string
  plan_code: string
  plan_name: string
  tier: number
  interval: string
  features: Record<string, unknown>
  marketing_features: string[]
  description: string | null
  sort_order: number
  pricing: {
    provider: string
    provider_plan_id: string
    base_price_minor: number
    currency: string
    base_price_formatted: number
    discounted_price_minor?: number
    discounted_price_formatted?: number
    discount_percentage?: number
  }
}

/** Supported locale codes for marketing feature translations. */
const SUPPORTED_LOCALES = ['en', 'hi', 'ml'] as const
type SupportedLocale = typeof SUPPORTED_LOCALES[number]

/**
 * Resolves the localised marketing features for a plan.
 * Returns the translated array for non-English locales when available,
 * otherwise falls back to the English marketing_features.
 */
function resolveMarketingFeatures(
  englishFeatures: string[],
  i18n: Record<string, string[]> | null | undefined,
  locale: SupportedLocale,
): string[] {
  if (locale === 'en' || !i18n) return englishFeatures
  const translated = i18n[locale]
  // Only use translation if it exists and has the same length as the source
  if (Array.isArray(translated) && translated.length === englishFeatures.length) {
    return translated
  }
  return englishFeatures
}

interface PromoCampaign {
  id: string
  code: string
  name: string
  description: string | null
  discount_type: string
  discount_value: number
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse query parameters
    const url = new URL(req.url)
    const provider = url.searchParams.get('provider') || 'razorpay'
    const region = url.searchParams.get('region') || 'IN'
    const promoCode = url.searchParams.get('promo_code')
    const rawLocale = url.searchParams.get('locale') || 'en'
    const locale: SupportedLocale = (SUPPORTED_LOCALES as readonly string[]).includes(rawLocale)
      ? rawLocale as SupportedLocale
      : 'en'

    console.log('[get-plans] Request:', { provider, region, promo_code: promoCode, locale })

    // Validate provider
    const validProviders = ['razorpay', 'google_play', 'apple_appstore']
    if (!validProviders.includes(provider)) {
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

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch plans with provider pricing
    // Use LEFT JOIN to include Free plan (which has no provider pricing)
    const { data: plansData, error: plansError } = await supabase
      .from('subscription_plans')
      .select(`
        id,
        plan_code,
        plan_name,
        tier,
        interval,
        features,
        marketing_features,
        marketing_features_i18n,
        description,
        sort_order,
        subscription_plan_providers!left (
          provider,
          provider_plan_id,
          base_price_minor,
          currency,
          region,
          is_active
        )
      `)
      .eq('is_active', true)
      .eq('is_visible', true)
      .order('sort_order', { ascending: true })

    if (plansError) {
      console.error('[get-plans] Database error:', plansError)
      throw new Error('Failed to fetch plans')
    }

    // Validate and apply promo code if provided
    let promoCampaign: PromoCampaign | null = null
    let discountType: string | null = null
    let discountValue = 0

    if (promoCode) {
      const { data: promoData, error: promoError } = await supabase
        .from('promotional_campaigns')
        .select('id, campaign_code, campaign_name, description, discount_type, discount_value, applicable_plans, applicable_providers')
        .eq('campaign_code', promoCode)
        .eq('is_active', true)
        .gte('valid_until', new Date().toISOString())
        .lte('valid_from', new Date().toISOString())
        .maybeSingle()

      if (promoData) {
        // Check if promo applies to this provider
        const appliesToProvider = promoData.applicable_providers.includes('*') ||
          promoData.applicable_providers.includes(provider)

        if (appliesToProvider) {
          promoCampaign = {
            id: promoData.id,
            code: promoData.campaign_code,
            name: promoData.campaign_name,
            description: promoData.description,
            discount_type: promoData.discount_type,
            discount_value: promoData.discount_value
          }
          discountType = promoData.discount_type
          discountValue = promoData.discount_value

          console.log('[get-plans] Applied promo:', promoCampaign)
        }
      }
    }

    // Format plans with pricing
    // Filter and process plans based on provider availability
    const plans: Plan[] = plansData
      .filter((plan: any) => {
        // Free plan has no provider pricing - always include it
        if (plan.plan_code === 'free') {
          return true
        }

        // For paid plans, check if provider pricing exists for requested provider
        const providerPricings = plan.subscription_plan_providers || []
        return providerPricings.some((p: any) =>
          p.provider === provider &&
          p.region === region &&
          p.is_active === true
        )
      })
      .map((plan: any) => {
        // For Free plan, use default pricing values
        if (plan.plan_code === 'free') {
          const englishFeatures: string[] = plan.marketing_features ?? []
          return {
            plan_id: plan.id,
            plan_code: plan.plan_code,
            plan_name: plan.plan_name,
            tier: plan.tier,
            interval: plan.interval,
            features: plan.features,
            marketing_features: resolveMarketingFeatures(
              englishFeatures,
              plan.marketing_features_i18n,
              locale,
            ),
            description: plan.description,
            sort_order: plan.sort_order,
            pricing: {
              provider: 'free',
              provider_plan_id: 'free',
              base_price_minor: 0,
              currency: 'INR',
              base_price_formatted: 0
            }
          }
        }

        // For paid plans, get provider-specific pricing
        const providerPricings = plan.subscription_plan_providers || []
        const providerPricing = providerPricings.find((p: any) =>
          p.provider === provider && p.region === region && p.is_active === true
        )

        if (!providerPricing) {
          // Should not happen due to filter above, but handle gracefully
          throw new Error(`No pricing found for plan ${plan.plan_code}`)
        }

        const basePriceMinor = providerPricing.base_price_minor
        const currency = providerPricing.currency

        // Calculate discounted price if promo applies
        let discountedPriceMinor: number | undefined
        let discountPercentage: number | undefined

        if (promoCampaign && discountType && discountValue > 0) {
          // Check if promo applies to this plan
          const appliesToPlan = promoCampaign && (
            (promoCampaign as any).applicable_plans?.includes('*') ||
            (promoCampaign as any).applicable_plans?.includes(plan.plan_code)
          )

          if (appliesToPlan) {
            if (discountType === 'percentage') {
              discountedPriceMinor = Math.round(basePriceMinor * (1 - discountValue / 100))
              discountPercentage = discountValue
            } else if (discountType === 'fixed_amount') {
              discountedPriceMinor = Math.max(0, basePriceMinor - discountValue)
              discountPercentage = Math.round((discountValue / basePriceMinor) * 100)
            }
          }
        }

        const englishFeatures: string[] = plan.marketing_features ?? []
        return {
          plan_id: plan.id,
          plan_code: plan.plan_code,
          plan_name: plan.plan_name,
          tier: plan.tier,
          interval: plan.interval,
          features: plan.features,
          marketing_features: resolveMarketingFeatures(
            englishFeatures,
            plan.marketing_features_i18n,
            locale,
          ),
          description: plan.description,
          sort_order: plan.sort_order,
          pricing: {
            provider: providerPricing.provider,
            provider_plan_id: providerPricing.provider_plan_id,
            base_price_minor: basePriceMinor,
            currency: currency,
            base_price_formatted: basePriceMinor / 100, // Convert paise to rupees
            ...(discountedPriceMinor && {
              discounted_price_minor: discountedPriceMinor,
              discounted_price_formatted: discountedPriceMinor / 100,
              discount_percentage: discountPercentage
            })
          }
        }
      })

    // Build response
    const response = {
      success: true,
      plans,
      ...(promoCampaign && {
        promotional_campaign: {
          code: promoCampaign.code,
          name: promoCampaign.name,
          description: promoCampaign.description,
          discount_type: promoCampaign.discount_type,
          discount_value: promoCampaign.discount_value
        }
      })
    }

    console.log('[get-plans] Returning', plans.length, 'plans')

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    console.error('[get-plans] Error:', error)

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
