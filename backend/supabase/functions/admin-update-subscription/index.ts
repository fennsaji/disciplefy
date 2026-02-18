import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

interface UpdateSubscriptionRequest {
  target_user_id: string
  new_tier: 'free' | 'standard' | 'plus' | 'premium'
  effective_date?: string
  reason?: string
  // Extended fields forwarded from admin panel
  new_status?: string
  new_start_date?: string
  new_end_date?: string
  plan_name?: string
  billing_cycle?: 'monthly' | 'yearly'
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // Verify user is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify user is admin
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle() // Use maybeSingle() to avoid error when no profile exists

    if (!profile?.is_admin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body: UpdateSubscriptionRequest = await req.json()

    if (!body.target_user_id || !body.new_tier) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: target_user_id, new_tier' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with service role for admin operations
    const adminSupabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get current subscription (any status - there can only be one per user)
    const { data: currentSub } = await adminSupabase
      .from('subscriptions')
      .select('*')
      .eq('user_id', body.target_user_id)
      .maybeSingle() // Use maybeSingle instead of single to avoid error if no subscription exists

    const effectiveDate = body.effective_date || new Date().toISOString()

    // Map tier names to plan codes
    const tierToPlanCode: Record<string, string> = {
      'free': 'free',
      'standard': 'standard',
      'plus': 'plus',
      'premium': 'premium'
    }

    const planCode = tierToPlanCode[body.new_tier]
    if (!planCode) {
      return new Response(
        JSON.stringify({ error: `Invalid tier: ${body.new_tier}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 1: Get the plan (free plan has no provider rows — must not use INNER join)
    const { data: plan, error: planError } = await adminSupabase
      .from('subscription_plans')
      .select('*')
      .eq('plan_code', planCode)
      .maybeSingle()

    if (!plan) {
      console.error('Plan not found:', { planCode, error: planError })
      return new Response(
        JSON.stringify({ error: `Plan not found for tier: ${body.new_tier}` }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 2: Get Razorpay pricing separately (optional — free plan has none)
    const { data: providerRow } = await adminSupabase
      .from('subscription_plan_providers')
      .select('base_price_minor, currency')
      .eq('plan_id', plan.id)
      .eq('provider', 'razorpay')
      .maybeSingle()

    // amount_paise has a CHECK (amount_paise > 0) constraint — use NULL for free/zero-price plans
    const basePriceMinor = (providerRow?.base_price_minor && providerRow.base_price_minor > 0)
      ? providerRow.base_price_minor
      : null
    const currency = providerRow?.currency ?? 'INR'

    // Use 'system' provider for free/zero-price plans (no payment provider)
    const subscriptionProvider = basePriceMinor ? 'razorpay' : 'system'

    // Resolve status — honour admin override if provided, else default to 'active'
    const newStatus = body.new_status || 'active'

    // Resolve period end — honour admin override if provided
    const periodEnd = body.new_end_date
      ? new Date(body.new_end_date)
      : (() => { const d = new Date(effectiveDate); d.setFullYear(d.getFullYear() + 1); return d })()

    // Billing cycle (monthly = 12 cycles, yearly = 1)
    const isYearly = (body.billing_cycle || 'monthly') === 'yearly'
    const totalCycles = isYearly ? 1 : 12
    const remainingCycles = totalCycles

    // Metadata for admin-created subscriptions
    const adminMetadata = {
      created_by: 'admin',
      admin_user_id: user.id,
      reason: body.reason || 'Admin manual update',
      created_at: new Date().toISOString()
    }

    let newSub
    let subError

    // Update existing subscription or create new one
    // Note: idx_subscriptions_one_per_user enforces ONE subscription per user (any status)
    // So we UPDATE the same record instead of creating a new one
    if (currentSub) {
      // UPDATE existing subscription
      const { data, error } = await adminSupabase
        .from('subscriptions')
        .update({
          plan_id: plan.id,
          plan_type: `${planCode}_monthly`, // e.g., premium_monthly
          status: newStatus,
          current_period_start: effectiveDate,
          current_period_end: periodEnd.toISOString(),
          next_billing_at: periodEnd.toISOString(), // Next renewal date
          total_count: totalCycles,
          remaining_count: remainingCycles,
          amount_paise: basePriceMinor,
          currency: currency,
          provider: subscriptionProvider,
          provider_subscription_id: `admin_manual_${Date.now()}`,
          metadata: adminMetadata,
          cancelled_at: null,
          cancellation_reason: null,
          cancel_at_cycle_end: false
        })
        .eq('id', currentSub.id)
        .select()
        .maybeSingle()

      newSub = data
      subError = error
    } else {
      // INSERT new subscription (user has no subscription at all)
      const { data, error } = await adminSupabase
        .from('subscriptions')
        .insert({
          user_id: body.target_user_id,
          plan_id: plan.id,
          plan_type: `${planCode}_monthly`, // e.g., premium_monthly
          status: newStatus,
          current_period_start: effectiveDate,
          current_period_end: periodEnd.toISOString(),
          next_billing_at: periodEnd.toISOString(), // Next renewal date
          total_count: totalCycles,
          paid_count: 0, // Admin created, not paid yet
          remaining_count: remainingCycles,
          amount_paise: basePriceMinor,
          currency: currency,
          provider: subscriptionProvider,
          provider_subscription_id: `admin_manual_${Date.now()}`,
          metadata: adminMetadata
        })
        .select()
        .maybeSingle()

      newSub = data
      subError = error
    }

    if (subError) {
      console.error('Error updating/creating subscription:', subError)
      return new Response(
        JSON.stringify({ error: 'Failed to update subscription', details: subError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Log admin action to audit log (if table exists)
    try {
      await adminSupabase
        .from('admin_audit_log')
        .insert({
          admin_user_id: user.id,
          action: 'update_subscription',
          target_user_id: body.target_user_id,
          details: {
            old_tier: currentSub?.tier,
            new_tier: body.new_tier,
            reason: body.reason,
            effective_date: effectiveDate
          }
        })
    } catch (auditError) {
      // Audit logging is optional, don't fail the request if it doesn't work
      console.warn('Failed to log admin action:', auditError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        subscription: newSub,
        message: `Subscription updated to ${body.new_tier} tier`
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in admin-update-subscription:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
