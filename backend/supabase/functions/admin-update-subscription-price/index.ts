/**
 * Admin Update Subscription Price Edge Function
 *
 * Purpose: Handle price updates for all payment providers
 *
 * Provider-Specific Behavior:
 * 1. Razorpay: Create NEW Razorpay plan, update provider_plan_id
 * 2. Google Play: Update DB price, set sync_status = pending_manual_update
 * 3. Apple App Store: Update DB price, set sync_status = pending_manual_update
 *
 * Simplified for First Release:
 * - No existing subscribers to worry about
 * - No deprecation tracking needed
 * - Simply UPDATE existing subscription_plan_providers row
 *
 * Security: Admin-only access via JWT verification
 * Audit: All changes logged to admin_subscription_price_audit table
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Razorpay from 'npm:razorpay@2.9.2'
import { corsHeaders } from '../_shared/utils/cors.ts'

interface UpdatePriceRequest {
  plan_provider_id: string  // subscription_plan_providers.id (UUID)
  new_price_minor: number   // New price in paise/cents
  notes?: string            // Admin reason for price change
  external_console_updated?: boolean  // For IAP: Checkbox confirmation
}

interface UpdatePriceResponse {
  success: boolean
  provider: string
  old_price_minor?: number
  new_price_minor?: number
  old_provider_plan_id?: string
  new_provider_plan_id?: string
  sync_status?: string
  audit_log_id?: string
  warning?: string
  error?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // ========================================================================
    // 1. Authenticate Admin User
    // ========================================================================

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Authorization header required'
        } as UpdatePriceResponse),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const jwt = authHeader.replace('Bearer ', '')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      global: {
        headers: { Authorization: authHeader }
      }
    })

    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt)

    if (authError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid authentication token'
        } as UpdatePriceResponse),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Verify admin status
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (profileError || !profile?.is_admin) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Admin access required'
        } as UpdatePriceResponse),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('[admin-update-subscription-price] Admin verified:', user.id)

    // ========================================================================
    // 2. Parse and Validate Request
    // ========================================================================

    const body: UpdatePriceRequest = await req.json()
    const {
      plan_provider_id,
      new_price_minor,
      notes,
      external_console_updated = false
    } = body

    // Validate required fields
    if (!plan_provider_id || !new_price_minor) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'plan_provider_id and new_price_minor are required'
        } as UpdatePriceResponse),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Validate price is reasonable (₹1 to ₹100,000 or $1 to $1,000)
    if (new_price_minor < 100 || new_price_minor > 10000000) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Price must be between ₹1 and ₹100,000 (or equivalent in other currencies)'
        } as UpdatePriceResponse),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ========================================================================
    // 3. Fetch Existing Plan Provider Details
    // ========================================================================

    const { data: planProvider, error: fetchError } = await supabase
      .from('subscription_plan_providers')
      .select(`
        id,
        plan_id,
        provider,
        provider_plan_id,
        product_id,
        base_price_minor,
        currency,
        region,
        subscription_plans!inner (
          plan_code,
          plan_name,
          interval
        )
      `)
      .eq('id', plan_provider_id)
      .single()

    if (fetchError || !planProvider) {
      console.error('[admin-update-subscription-price] Plan provider not found:', fetchError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Plan provider not found'
        } as UpdatePriceResponse),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const oldPriceMinor = planProvider.base_price_minor
    const provider = planProvider.provider
    const currency = planProvider.currency

    console.log('[admin-update-subscription-price] Current plan:', {
      provider,
      plan_code: (planProvider.subscription_plans as any).plan_code,
      old_price: oldPriceMinor,
      new_price: new_price_minor
    })

    // Check if price is actually changing
    if (oldPriceMinor === new_price_minor) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'New price is same as current price - no change needed'
        } as UpdatePriceResponse),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ========================================================================
    // 4. Handle Provider-Specific Price Update
    // ========================================================================

    let newProviderPlanId: string | null = null
    let syncStatus: string | null = null
    let warning: string | undefined

    // ------------------------------------------------------------------------
    // 4a. Razorpay: Create New Plan, Update provider_plan_id
    // ------------------------------------------------------------------------

    if (provider === 'razorpay') {
      const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID')
      const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET')

      if (!razorpayKeyId || !razorpayKeySecret) {
        console.error('[admin-update-subscription-price] Razorpay credentials missing')
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Razorpay credentials not configured'
          } as UpdatePriceResponse),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      const razorpay = new Razorpay({
        key_id: razorpayKeyId,
        key_secret: razorpayKeySecret
      })

      const planDescription = `${(planProvider.subscription_plans as any).plan_name} - ${currency} ${new_price_minor / 100} per ${(planProvider.subscription_plans as any).interval}`

      console.log('[admin-update-subscription-price] Creating new Razorpay plan...')

      try {
        const newRazorpayPlan = await razorpay.plans.create({
          period: (planProvider.subscription_plans as any).interval,
          interval: 1,
          item: {
            name: planDescription,
            amount: new_price_minor,
            currency: currency,
            description: planDescription
          },
          notes: {
            plan_code: (planProvider.subscription_plans as any).plan_code,
            updated_from_plan: planProvider.provider_plan_id,
            admin_user_id: user.id,
            created_via: 'admin_panel'
          }
        })

        newProviderPlanId = (newRazorpayPlan as any).id
        console.log('[admin-update-subscription-price] New Razorpay plan created:', newProviderPlanId)

      } catch (error: any) {
        console.error('[admin-update-subscription-price] Razorpay API error:', error)
        return new Response(
          JSON.stringify({
            success: false,
            error: `Razorpay API error: ${error.error?.description || error.message}`
          } as UpdatePriceResponse),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // ------------------------------------------------------------------------
    // 4b. Google Play / Apple App Store: Warn About External Console Update
    // ------------------------------------------------------------------------

    else if (provider === 'google_play' || provider === 'apple_appstore') {
      if (!external_console_updated) {
        return new Response(
          JSON.stringify({
            success: false,
            error: `You must update the price in ${provider === 'google_play' ? 'Google Play Console' : 'App Store Connect'} before updating here. Please check the confirmation checkbox.`
          } as UpdatePriceResponse),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      syncStatus = 'pending_manual_update'
      warning = `Price updated in database. Remember to verify it matches ${provider === 'google_play' ? 'Google Play Console' : 'App Store Connect'}.`
    }

    // ========================================================================
    // 5. Update Database
    // ========================================================================

    const updateData: any = {
      base_price_minor: new_price_minor,
      updated_at: new Date().toISOString()
    }

    if (newProviderPlanId) {
      updateData.provider_plan_id = newProviderPlanId
    }

    if (syncStatus) {
      updateData.sync_status = syncStatus
    }

    const { error: updateError } = await supabase
      .from('subscription_plan_providers')
      .update(updateData)
      .eq('id', plan_provider_id)

    if (updateError) {
      console.error('[admin-update-subscription-price] Failed to update:', updateError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to update price in database'
        } as UpdatePriceResponse),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('[admin-update-subscription-price] Database updated successfully')

    // ========================================================================
    // 6. Log Audit Trail
    // ========================================================================

    const action = provider === 'razorpay' ? 'razorpay_plan_creation' : 'iap_price_update'

    const { data: auditLog, error: auditError } = await supabase
      .rpc('log_subscription_price_change', {
        p_admin_user_id: user.id,
        p_plan_id: planProvider.plan_id,
        p_provider: provider,
        p_action: action,
        p_old_price_minor: oldPriceMinor,
        p_new_price_minor: new_price_minor,
        p_old_provider_plan_id: planProvider.provider_plan_id,
        p_new_provider_plan_id: newProviderPlanId,
        p_affected_subscriptions: 0,  // First release - no existing subscribers
        p_notes: notes || `Price updated from ${currency} ${oldPriceMinor / 100} to ${currency} ${new_price_minor / 100}`,
        p_metadata: {
          external_console_updated,
          first_release: true
        }
      })

    if (auditError) {
      console.error('[admin-update-subscription-price] Audit logging failed:', auditError)
    }

    // ========================================================================
    // 7. Return Success Response
    // ========================================================================

    return new Response(
      JSON.stringify({
        success: true,
        provider,
        old_price_minor: oldPriceMinor,
        new_price_minor: new_price_minor,
        old_provider_plan_id: planProvider.provider_plan_id,
        new_provider_plan_id: newProviderPlanId || planProvider.provider_plan_id,
        sync_status: syncStatus || 'synced',
        audit_log_id: auditLog,
        warning
      } as UpdatePriceResponse),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error: any) {
    console.error('[admin-update-subscription-price] Unexpected error:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error'
      } as UpdatePriceResponse),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
