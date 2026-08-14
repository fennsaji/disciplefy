/**
 * Admin Subscriptions Edge Function
 *
 * Merges:
 * - admin-update-subscription   -> POST /            (manual tier/status/date overrides)
 * - admin-update-subscription-price -> POST /price    (provider price updates)
 *
 * Auth: service-role client from the start, with the incoming user's JWT
 * verified via supabase.auth.getUser(jwt) + user_profiles.is_admin check
 * (adapted from admin-update-subscription-price's auth pattern).
 */

import { createClient } from 'jsr:@supabase/supabase-js@2'
import Razorpay from 'npm:razorpay@2.9.2'
import { corsHeaders } from '../_shared/cors.ts'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

interface UpdateSubscriptionRequest {
  target_user_id: string
  new_tier: 'free' | 'standard' | 'plus' | 'premium'
  effective_date?: string
  reason?: string
  // Extended fields forwarded from admin panel
  new_status?: string
  new_start_date?: string
  new_end_date?: string
  next_billing_at?: string
  plan_name?: string
  billing_cycle?: 'monthly' | 'yearly'
}

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

// Returns the authenticated admin context, or a Response if auth failed.
// Adapted verbatim from admin-update-subscription-price's auth block: service-role
// client from the start, with the incoming user's JWT verified via auth.getUser().
async function requireAdmin(req: Request): Promise<
  { supabase: any; user: { id: string } } | Response
> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return json({ error: 'Authorization header required' }, 401)
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
    return json({ error: 'Invalid authentication token' }, 401)
  }

  // Verify admin status
  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single()

  if (profileError || !(profile as any)?.is_admin) {
    return json({ error: 'Admin access required' }, 403)
  }

  return { supabase, user }
}

// Copied verbatim from admin-update-subscription/index.ts, with the auth-context
// shape adapted to the shared service-role client/user, and the audit-log write
// fixed from the nonexistent `admin_audit_log` table to `admin_logs`.
async function handleUpdateSubscription(
  auth: { supabase: any; user: { id: string } },
  req: Request
) {
  const { supabase: adminSupabase, user } = auth

  // Parse request body
  const body: UpdateSubscriptionRequest = await req.json()

  if (!body.target_user_id || !body.new_tier) {
    return json({ error: 'Missing required fields: target_user_id, new_tier' }, 400)
  }

  // Get most recent subscription for this user.
  // Using order+limit instead of maybeSingle() because maybeSingle() throws PGRST116
  // when the user has multiple subscription records (e.g. from previous admin operations).
  const { data: currentSubRows } = await adminSupabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', body.target_user_id)
    .order('created_at', { ascending: false })
    .limit(1)
  const currentSub = (currentSubRows as any[] | null)?.[0] ?? null

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
    return json({ error: `Invalid tier: ${body.new_tier}` }, 400)
  }

  // Step 1: Get the plan (free plan has no provider rows — must not use INNER join)
  const { data: plan, error: planError } = await adminSupabase
    .from('subscription_plans')
    .select('*')
    .eq('plan_code', planCode)
    .maybeSingle()

  if (!plan) {
    console.error('Plan not found:', { planCode, error: planError })
    return json({ error: `Plan not found for tier: ${body.new_tier}` }, 404)
  }

  // Step 2: Get Razorpay pricing separately (optional — free plan has none)
  const { data: providerRow } = await adminSupabase
    .from('subscription_plan_providers')
    .select('base_price_minor, currency')
    .eq('plan_id', (plan as any).id)
    .eq('provider', 'razorpay')
    .maybeSingle()

  // amount_paise has a CHECK (amount_paise > 0) constraint — use NULL for free/zero-price plans
  const basePriceMinor = ((providerRow as any)?.base_price_minor && (providerRow as any).base_price_minor > 0)
    ? (providerRow as any).base_price_minor
    : null
  const currency = (providerRow as any)?.currency ?? 'INR'

  // Use 'system' provider for free/zero-price plans (no payment provider)
  const subscriptionProvider = basePriceMinor ? 'razorpay' : 'system'

  // Resolve status — honour admin override if provided, else default to 'active'
  const newStatus = body.new_status || 'active'

  // Resolve period end — honour admin override if provided
  const periodEnd = body.new_end_date
    ? new Date(body.new_end_date)
    : (() => { const d = new Date(effectiveDate); d.setFullYear(d.getFullYear() + 1); return d })()

  // Resolve next billing date — honour admin override if provided, else next renewal
  const nextBillingAt = body.next_billing_at
    ? new Date(body.next_billing_at).toISOString()
    : periodEnd.toISOString()

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

  let newSub: any
  let subError

  // Update existing subscription or create new one
  // Note: idx_subscriptions_one_per_user enforces ONE subscription per user (any status)
  // So we UPDATE the same record instead of creating a new one
  if (currentSub) {
    // UPDATE existing subscription
    const { data, error } = await adminSupabase
      .from('subscriptions')
      .update({
        plan_id: (plan as any).id,
        plan_type: `${planCode}_monthly`, // e.g., premium_monthly
        status: newStatus,
        current_period_start: effectiveDate,
        current_period_end: periodEnd.toISOString(),
        next_billing_at: nextBillingAt,
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
      .eq('id', (currentSub as any).id)
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
        plan_id: (plan as any).id,
        plan_type: `${planCode}_monthly`, // e.g., premium_monthly
        status: newStatus,
        current_period_start: effectiveDate,
        current_period_end: periodEnd.toISOString(),
        next_billing_at: nextBillingAt,
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
    return json({ error: 'Failed to update subscription', details: subError.message }, 500)
  }

  // Clean up any extra duplicate subscription records for this user (keep only the one we just updated/created)
  if (newSub?.id) {
    await adminSupabase
      .from('subscriptions')
      .update({ status: 'cancelled', cancelled_at: new Date().toISOString() })
      .eq('user_id', body.target_user_id)
      .neq('id', newSub.id)
      .not('status', 'in', '("cancelled","expired","completed")')
  }

  // Log admin action to audit log (if table exists)
  try {
    const { error: auditError } = await (adminSupabase as any)
      .from('admin_logs')
      .insert({
        admin_user_id: user.id,
        action: 'update_subscription',
        target_table: 'subscriptions',
        target_id: body.target_user_id,
        details: {
          old_tier: (currentSub as any)?.tier,
          new_tier: body.new_tier,
          reason: body.reason,
          effective_date: effectiveDate
        }
      })
    if (auditError) console.warn('Failed to log admin action:', auditError)
  } catch (auditError) {
    // Audit logging is optional, don't fail the request if it doesn't work
    console.warn('Failed to log admin action:', auditError)
  }

  return json({
    success: true,
    subscription: newSub,
    message: `Subscription updated to ${body.new_tier} tier`
  })
}

// Copied verbatim from admin-update-subscription-price/index.ts, with the
// auth-context shape adapted to the shared service-role client/user.
// The `log_subscription_price_change` RPC call is left completely unchanged.
async function handleUpdatePrice(
  auth: { supabase: any; user: { id: string } },
  req: Request
) {
  const { supabase, user } = auth

  console.log('[admin-subscriptions/price] Admin verified:', user.id)

  // ========================================================================
  // Parse and Validate Request
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
    return json({
      success: false,
      error: 'plan_provider_id and new_price_minor are required'
    } as UpdatePriceResponse, 400)
  }

  // Validate price is reasonable (₹1 to ₹100,000 or $1 to $1,000)
  if (new_price_minor < 100 || new_price_minor > 10000000) {
    return json({
      success: false,
      error: 'Price must be between ₹1 and ₹100,000 (or equivalent in other currencies)'
    } as UpdatePriceResponse, 400)
  }

  // ========================================================================
  // Fetch Existing Plan Provider Details
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
    console.error('[admin-subscriptions/price] Plan provider not found:', fetchError)
    return json({
      success: false,
      error: 'Plan provider not found'
    } as UpdatePriceResponse, 404)
  }

  const oldPriceMinor = (planProvider as any).base_price_minor
  const provider = (planProvider as any).provider
  const currency = (planProvider as any).currency

  console.log('[admin-subscriptions/price] Current plan:', {
    provider,
    plan_code: (planProvider as any).subscription_plans.plan_code,
    old_price: oldPriceMinor,
    new_price: new_price_minor
  })

  // Check if price is actually changing
  if (oldPriceMinor === new_price_minor) {
    return json({
      success: false,
      error: 'New price is same as current price - no change needed'
    } as UpdatePriceResponse, 400)
  }

  // ========================================================================
  // Handle Provider-Specific Price Update
  // ========================================================================

  let newProviderPlanId: string | null = null
  let syncStatus: string | null = null
  let warning: string | undefined

  // ------------------------------------------------------------------------
  // Razorpay: Create New Plan, Update provider_plan_id
  // ------------------------------------------------------------------------

  if (provider === 'razorpay') {
    const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID')
    const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET')

    if (!razorpayKeyId || !razorpayKeySecret) {
      console.error('[admin-subscriptions/price] Razorpay credentials missing')
      return json({
        success: false,
        error: 'Razorpay credentials not configured'
      } as UpdatePriceResponse, 500)
    }

    const razorpay = new Razorpay({
      key_id: razorpayKeyId,
      key_secret: razorpayKeySecret
    })

    const planDescription = `${(planProvider as any).subscription_plans.plan_name} - ${currency} ${new_price_minor / 100} per ${(planProvider as any).subscription_plans.interval}`

    console.log('[admin-subscriptions/price] Creating new Razorpay plan...')

    try {
      const newRazorpayPlan = await razorpay.plans.create({
        period: (planProvider as any).subscription_plans.interval,
        interval: 1,
        item: {
          name: planDescription,
          amount: new_price_minor,
          currency: currency,
          description: planDescription
        },
        notes: {
          plan_code: (planProvider as any).subscription_plans.plan_code,
          updated_from_plan: (planProvider as any).provider_plan_id,
          admin_user_id: user.id,
          created_via: 'admin_panel'
        }
      })

      newProviderPlanId = (newRazorpayPlan as any).id
      console.log('[admin-subscriptions/price] New Razorpay plan created:', newProviderPlanId)

    } catch (error: any) {
      console.error('[admin-subscriptions/price] Razorpay API error:', error)
      return json({
        success: false,
        error: `Razorpay API error: ${error.error?.description || error.message}`
      } as UpdatePriceResponse, 500)
    }
  }

  // ------------------------------------------------------------------------
  // Google Play / Apple App Store: Warn About External Console Update
  // ------------------------------------------------------------------------

  else if (provider === 'google_play' || provider === 'apple_appstore') {
    if (!external_console_updated) {
      return json({
        success: false,
        error: `You must update the price in ${provider === 'google_play' ? 'Google Play Console' : 'App Store Connect'} before updating here. Please check the confirmation checkbox.`
      } as UpdatePriceResponse, 400)
    }

    syncStatus = 'pending_manual_update'
    warning = `Price updated in database. Remember to verify it matches ${provider === 'google_play' ? 'Google Play Console' : 'App Store Connect'}.`
  }

  // ========================================================================
  // Update Database
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
    console.error('[admin-subscriptions/price] Failed to update:', updateError)
    return json({
      success: false,
      error: 'Failed to update price in database'
    } as UpdatePriceResponse, 500)
  }

  console.log('[admin-subscriptions/price] Database updated successfully')

  // ========================================================================
  // Log Audit Trail
  // ========================================================================
  // NOTE: this RPC (`log_subscription_price_change`) is a different, valid audit
  // mechanism from `admin_logs` above — left completely unchanged.

  const action = provider === 'razorpay' ? 'razorpay_plan_creation' : 'iap_price_update'

  const { data: auditLog, error: auditError } = await supabase
    .rpc('log_subscription_price_change', {
      p_admin_user_id: user.id,
      p_plan_id: (planProvider as any).plan_id,
      p_provider: provider,
      p_action: action,
      p_old_price_minor: oldPriceMinor,
      p_new_price_minor: new_price_minor,
      p_old_provider_plan_id: (planProvider as any).provider_plan_id,
      p_new_provider_plan_id: newProviderPlanId,
      p_affected_subscriptions: 0,  // First release - no existing subscribers
      p_notes: notes || `Price updated from ${currency} ${oldPriceMinor / 100} to ${currency} ${new_price_minor / 100}`,
      p_metadata: {
        external_console_updated,
        first_release: true
      }
    })

  if (auditError) {
    console.error('[admin-subscriptions/price] Audit logging failed:', auditError)
  }

  // ========================================================================
  // Return Success Response
  // ========================================================================

  return json({
    success: true,
    provider,
    old_price_minor: oldPriceMinor,
    new_price_minor: new_price_minor,
    old_provider_plan_id: (planProvider as any).provider_plan_id,
    new_provider_plan_id: newProviderPlanId || (planProvider as any).provider_plan_id,
    sync_status: syncStatus || 'synced',
    audit_log_id: auditLog,
    warning
  } as UpdatePriceResponse, 200)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const url = new URL(req.url)
    // pathParts[0] is always this function's own name — base route = length 1.
    const pathParts = url.pathname.split('/').filter(Boolean)

    if (req.method === 'POST' && pathParts.length === 1) return await handleUpdateSubscription(auth, req)
    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'price') return await handleUpdatePrice(auth, req)

    return json({ error: 'Not found' }, 404)
  } catch (error) {
    console.error('Error in admin-subscriptions:', error)
    return json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error'
    }, 500)
  }
})
