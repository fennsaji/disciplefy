import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    const adminUserId = req.headers.get('x-admin-user-id')

    if (!authHeader || !adminUserId) {
      return new Response(JSON.stringify({ error: 'Unauthorized - Missing credentials' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (authHeader.replace('Bearer ', '') !== serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Unauthorized - Invalid credentials' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceRoleKey)

    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', adminUserId)
      .single()

    if (profileError || !profile?.is_admin) {
      return new Response(JSON.stringify({ error: 'Forbidden - Admin access required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json().catch(() => ({}))
    const startDate = body.start_date ?? new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
    const endDate = body.end_date ?? new Date().toISOString()

    // Fetch live USD→INR exchange rate
    let exchangeRate = 84.0
    let exchangeRateIsLive = false
    try {
      const rateRes = await fetch('https://open.er-api.com/v6/latest/USD', {
        signal: AbortSignal.timeout(3000),
      })
      if (rateRes.ok) {
        const rateData = await rateRes.json()
        const inrRate = rateData?.rates?.INR
        if (typeof inrRate === 'number' && inrRate > 0) {
          exchangeRate = inrRate
          exchangeRateIsLive = true
        }
      }
    } catch {
      console.warn('[admin-pl-analytics] Exchange rate fetch failed, using fallback 84.0')
    }

    // ── LLM costs: from usage_logs.tier (stamped at call time — always accurate) ──
    const { data: costRows, error: costError } = await supabase
      .from('usage_logs')
      .select('tier, llm_cost_usd')
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .not('user_id', 'is', null)
      .not('tier', 'is', null)
      .neq('tier', 'system')

    if (costError) throw new Error(`Failed to fetch usage costs: ${costError.message}`)

    // Aggregate costs by tier in TS
    const costByTier: Record<string, number> = {}
    for (const row of costRows ?? []) {
      const t = row.tier as string
      costByTier[t] = (costByTier[t] ?? 0) + (Number(row.llm_cost_usd) || 0)
    }

    // ── Active users: from subscriptions (current status) ──
    const { data: subRows, error: subError } = await supabase
      .from('subscriptions')
      .select('user_id, plan_id, subscription_plans!inner(plan_code)')
      .in('status', ['active', 'trial', 'in_progress', 'pending_cancellation', 'paused'])

    if (subError) throw new Error(`Failed to fetch subscriptions: ${subError.message}`)

    // Count distinct users per plan_code
    const usersByPlan: Record<string, Set<string>> = {}
    for (const row of subRows ?? []) {
      const planCode = (row.subscription_plans as any)?.plan_code as string
      if (!planCode) continue
      if (!usersByPlan[planCode]) usersByPlan[planCode] = new Set()
      usersByPlan[planCode].add(row.user_id)
    }
    const activeUsersByPlan: Record<string, number> = {}
    for (const [plan, users] of Object.entries(usersByPlan)) {
      activeUsersByPlan[plan] = users.size
    }

    // ── Revenue: from subscription_invoices (cash-basis) ──
    const { data: invoiceRows, error: invoiceError } = await supabase
      .from('subscription_invoices')
      .select('user_id, amount_paise, paid_at')
      .eq('status', 'paid')
      .gte('paid_at', startDate)
      .lte('paid_at', endDate)

    if (invoiceError) throw new Error(`Failed to fetch invoices: ${invoiceError.message}`)

    // Map user_id → plan_code from subscriptions, then accumulate revenue
    const userToPlan: Record<string, string> = {}
    for (const row of subRows ?? []) {
      const planCode = (row.subscription_plans as any)?.plan_code as string
      if (planCode) userToPlan[row.user_id] = planCode
    }

    const revenueByPlan: Record<string, number> = {}
    for (const row of invoiceRows ?? []) {
      const planCode = userToPlan[row.user_id]
      if (!planCode) continue
      revenueByPlan[planCode] = (revenueByPlan[planCode] ?? 0) + (Number(row.amount_paise) || 0) / 100
    }

    // ── Combine into P&L rows ──
    const allPlans = new Set([
      ...Object.keys(costByTier),
      ...Object.keys(activeUsersByPlan),
    ])

    const rows = Array.from(allPlans).map((planCode) => {
      const llmCostInr = (costByTier[planCode] ?? 0) * exchangeRate
      const revenueInr = revenueByPlan[planCode] ?? 0
      const grossProfitInr = revenueInr - llmCostInr
      const marginPct = revenueInr > 0 ? (grossProfitInr / revenueInr) * 100 : null
      return {
        plan_code: planCode,
        active_users: activeUsersByPlan[planCode] ?? 0,
        revenue_inr: Math.round(revenueInr * 100) / 100,
        llm_cost_inr: Math.round(llmCostInr * 100) / 100,
        gross_profit_inr: Math.round(grossProfitInr * 100) / 100,
        margin_pct: marginPct !== null ? Math.round(marginPct * 10) / 10 : null,
      }
    })

    // Total row
    const totalLlmCost = rows.reduce((s, r) => s + r.llm_cost_inr, 0)
    const totalRevenue = rows.reduce((s, r) => s + r.revenue_inr, 0)
    const totalProfit = totalRevenue - totalLlmCost
    rows.push({
      plan_code: 'total',
      active_users: rows.reduce((s, r) => s + r.active_users, 0),
      revenue_inr: Math.round(totalRevenue * 100) / 100,
      llm_cost_inr: Math.round(totalLlmCost * 100) / 100,
      gross_profit_inr: Math.round(totalProfit * 100) / 100,
      margin_pct: totalRevenue > 0 ? Math.round((totalProfit / totalRevenue) * 1000) / 10 : null,
    })

    // ── Top heavy users: still via RPC ──
    const { data: topHeavyUsers, error: usersError } = await supabase.rpc('get_top_heavy_users', {
      p_start_date: startDate,
      p_end_date: endDate,
      p_exchange_rate: exchangeRate,
      p_limit: 10,
    })

    if (usersError) {
      console.error('[admin-pl-analytics] get_top_heavy_users error:', usersError)
    }

    return new Response(
      JSON.stringify({
        pl_by_tier: rows,
        top_heavy_users: topHeavyUsers ?? [],
        exchange_rate_used: exchangeRate,
        exchange_rate_is_live: exchangeRateIsLive,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('[admin-pl-analytics] Unexpected error:', err)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
