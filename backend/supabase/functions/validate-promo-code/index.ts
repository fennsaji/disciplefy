/**
 * Validate Promo Code Edge Function
 *
 * Validates promotional codes and checks eligibility rules:
 * - Campaign exists and is active
 * - Within validity period
 * - Usage limits not exceeded (total and per-user)
 * - New user eligibility (if required)
 * - Plan and provider applicability
 *
 * Request Body:
 * - promo_code: Promotional code to validate
 * - plan_code: Plan to apply promo to (optional)
 * - provider: Payment provider (optional, default: razorpay)
 *
 * Returns:
 * - valid: Boolean indicating if code is valid
 * - campaign: Campaign details (if valid)
 * - message: Validation message
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'

interface ValidatePromoRequest {
  promo_code: string
  plan_code?: string
  provider?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body: ValidatePromoRequest = await req.json()
    const { promo_code, plan_code, provider = 'razorpay' } = body

    console.log('[validate-promo-code] Request:', { promo_code, plan_code, provider })

    if (!promo_code) {
      return new Response(
        JSON.stringify({
          valid: false,
          message: 'Promo code is required'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Get authenticated user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          valid: false,
          message: 'Authentication required'
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
          valid: false,
          message: 'Invalid authentication token'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('[validate-promo-code] User:', user.id)

    // Fetch campaign
    const { data: campaign, error: campaignError } = await supabase
      .from('promotional_campaigns')
      .select('*')
      .eq('campaign_code', promo_code)
      .eq('is_active', true)
      .maybeSingle()

    if (campaignError) {
      console.error('[validate-promo-code] Database error:', campaignError)
      throw new Error('Failed to validate promo code')
    }

    if (!campaign) {
      return new Response(
        JSON.stringify({
          valid: false,
          message: 'Invalid promotional code'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check validity period
    const now = new Date()
    const validFrom = new Date(campaign.valid_from)
    const validUntil = new Date(campaign.valid_until)

    if (now < validFrom || now > validUntil) {
      return new Response(
        JSON.stringify({
          valid: false,
          message: 'Promotional code has expired'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check total usage limit
    if (campaign.max_total_uses !== null && campaign.current_use_count >= campaign.max_total_uses) {
      return new Response(
        JSON.stringify({
          valid: false,
          message: 'Promotional code usage limit has been reached'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check per-user usage limit
    const { data: userRedemptions, error: redemptionsError } = await supabase
      .from('promotional_redemptions')
      .select('id')
      .eq('campaign_id', campaign.id)
      .eq('user_id', user.id)

    if (redemptionsError) {
      console.error('[validate-promo-code] Redemptions error:', redemptionsError)
      throw new Error('Failed to check promo code usage')
    }

    const userRedemptionCount = userRedemptions?.length || 0
    if (userRedemptionCount >= campaign.max_uses_per_user) {
      return new Response(
        JSON.stringify({
          valid: false,
          message: 'You have already used this promotional code'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check new user eligibility
    if (campaign.new_users_only) {
      const userCreatedAt = new Date(user.created_at)
      if (userCreatedAt < validFrom) {
        return new Response(
          JSON.stringify({
            valid: false,
            message: 'This promotion is only available for new users'
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Check plan applicability
    if (plan_code) {
      const appliesToPlan = campaign.applicable_plans.includes('*') ||
        campaign.applicable_plans.includes(plan_code)

      if (!appliesToPlan) {
        return new Response(
          JSON.stringify({
            valid: false,
            message: 'This promotional code is not applicable to the selected plan'
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Check provider applicability
    const appliesToProvider = campaign.applicable_providers.includes('*') ||
      campaign.applicable_providers.includes(provider)

    if (!appliesToProvider) {
      return new Response(
        JSON.stringify({
          valid: false,
          message: 'This promotional code is not applicable to the selected payment method'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Valid promo code
    console.log('[validate-promo-code] Valid code:', campaign.campaign_code)

    return new Response(
      JSON.stringify({
        valid: true,
        campaign: {
          id: campaign.id,
          code: campaign.campaign_code,
          name: campaign.campaign_name,
          description: campaign.description,
          discount_type: campaign.discount_type,
          discount_value: campaign.discount_value
        },
        message: 'Promotional code is valid'
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    console.error('[validate-promo-code] Error:', error)

    return new Response(
      JSON.stringify({
        valid: false,
        message: error instanceof Error ? error.message : 'Internal server error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
