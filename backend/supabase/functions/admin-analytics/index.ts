/**
 * Admin Analytics Edge Function
 *
 * Merges:
 * - admin-usage-analytics -> POST /usage  (aggregate usage stats by tier/feature/date)
 * - admin-usage-logs      -> POST /logs   (paginated individual usage_logs records)
 * - admin-pl-analytics    -> POST /pl     (P&L by plan, top heavy users)
 *
 * Auth: all three sources used the identical service-role-key + x-admin-user-id
 * header scheme (verify header matches SUPABASE_SERVICE_ROLE_KEY, then check
 * user_profiles.is_admin for the given admin user id). Deduped into requireAdmin().
 *
 * fetchAllRows: admin-usage-analytics and admin-pl-analytics each defined an
 * identical local helper (1000-row page size, 100-page safety cap, same loop
 * termination and error handling) to page past PostgREST's silent 1000-row cap.
 * Deduped into one shared module-private helper.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import type { AdminUsageAnalytics, UsageStats } from '../_shared/types/usage-types.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

/**
 * Read every row of a query past PostgREST's silent 1000-row response cap.
 * Cost/token/revenue totals are sums (or distinct-counts) over these rows, so a
 * truncated read would quietly plateau numbers at 1000 records.
 * `buildPage` must build a FRESH query per page (query builders are single-use).
 */
async function fetchAllRows(buildPage: (from: number, to: number) => any): Promise<any[]> {
  const PAGE = 1000
  const MAX_PAGES = 100 // safety cap: 100k rows
  const rows: any[] = []
  for (let page = 0; page < MAX_PAGES; page++) {
    const from = page * PAGE
    const { data, error } = await buildPage(from, from + PAGE - 1)
    if (error) throw new Error(error.message)
    rows.push(...(data || []))
    if (!data || data.length < PAGE) break
  }
  return rows
}

// Returns the authenticated admin context, or a Response if auth failed.
// Deduped verbatim from the identical auth blocks in admin-usage-analytics,
// admin-usage-logs, and admin-pl-analytics: service-role key passed via
// Authorization header, admin user id passed via x-admin-user-id, then
// user_profiles.is_admin is checked for that user id.
async function requireAdmin(
  req: Request
): Promise<{ supabase: any; adminUserId: string } | Response> {
  const authHeader = req.headers.get('Authorization')
  const adminUserId = req.headers.get('x-admin-user-id')

  if (!authHeader || !adminUserId) {
    return json({ error: 'Unauthorized - Missing credentials' }, 401)
  }

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (authHeader.replace('Bearer ', '') !== serviceRoleKey) {
    return json({ error: 'Unauthorized - Invalid credentials' }, 401)
  }

  const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceRoleKey)

  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select('is_admin')
    .eq('id', adminUserId)
    .single()

  if (profileError || !profile?.is_admin) {
    return json({ error: 'Forbidden - Admin access required' }, 403)
  }

  return { supabase, adminUserId }
}

// Copied verbatim from admin-usage-analytics/index.ts, adapted only to use the
// shared fetchAllRows helper and the shared auth-context shape.
async function handleUsageAnalytics(
  auth: { supabase: any; adminUserId: string },
  req: Request
) {
  const supabaseClient = auth.supabase

  // Parse request body (POST)
  const body = await req.json().catch(() => ({}))
  const startDate = body.start_date || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
  const endDate = body.end_date || new Date().toISOString()
  const tier = body.tier || null
  const feature = body.feature || null

  // Get overall stats
  const { data: overallStats, error: statsError } = await supabaseClient.rpc(
    'get_usage_stats',
    {
      p_start_date: startDate,
      p_end_date: endDate,
      p_tier: tier,
      p_feature_name: feature,
    }
  )

  if (statsError) {
    throw new Error(`Failed to get usage stats: ${statsError.message}`)
  }

  // Get stats by tier
  const tierStats: Record<string, UsageStats> = {}
  const tiers = ['free', 'standard', 'plus', 'premium']

  for (const t of tiers) {
    const { data: tierData, error: tierError } = await supabaseClient.rpc(
      'get_usage_stats',
      {
        p_start_date: startDate,
        p_end_date: endDate,
        p_tier: t,
        p_feature_name: feature,
      }
    )

    if (!tierError && tierData) {
      tierStats[t] = tierData
    }
  }

  // Get stats by feature
  const featureStats: Record<string, UsageStats> = {}
  const features = [
    'study_generate',
    'study_followup',
    'voice_conversation',
    'memory_practice',
    'memory_verse_add',
    'daily_verse',
  ]

  for (const f of features) {
    const { data: featureData, error: featureError } = await supabaseClient.rpc(
      'get_usage_stats',
      {
        p_start_date: startDate,
        p_end_date: endDate,
        p_tier: tier,
        p_feature_name: f,
      }
    )

    if (!featureError && featureData) {
      featureStats[f] = featureData
    }
  }

  // Get language breakdown
  const { data: languageData, error: languageError } = await supabaseClient.rpc(
    'get_language_breakdown',
    { p_start_date: startDate, p_end_date: endDate }
  )

  if (languageError) {
    console.error('Error fetching language breakdown:', languageError)
  }

  const transformedLanguageStats: Record<string, any> = {}
  if (languageData) {
    (languageData as any[]).forEach((row) => {
      transformedLanguageStats[row.language] = {
        operations: Number(row.operations) || 0,
        cost_usd: Number(row.cost_usd) || 0,
        avg_cost_per_operation: Number(row.avg_cost_per_operation) || 0,
        input_tokens: Number(row.input_tokens) || 0,
        output_tokens: Number(row.output_tokens) || 0,
      }
    })
  }

  // Get study mode breakdown
  const { data: studyModeData, error: studyModeError } = await supabaseClient.rpc(
    'get_study_mode_breakdown',
    { p_start_date: startDate, p_end_date: endDate }
  )

  if (studyModeError) {
    console.error('Error fetching study mode breakdown:', studyModeError)
  }

  const transformedStudyModeStats: Record<string, any> = {}
  if (studyModeData) {
    (studyModeData as any[]).forEach((row) => {
      transformedStudyModeStats[row.study_mode] = {
        operations: Number(row.operations) || 0,
        cost_usd: Number(row.cost_usd) || 0,
        avg_cost_per_operation: Number(row.avg_cost_per_operation) || 0,
        input_tokens: Number(row.input_tokens) || 0,
        output_tokens: Number(row.output_tokens) || 0,
      }
    })
  }

  // Get language × study mode cross-breakdown
  const { data: crossData, error: crossError } = await supabaseClient.rpc(
    'get_language_study_mode_breakdown',
    { p_start_date: startDate, p_end_date: endDate }
  )

  if (crossError) {
    console.error('Error fetching cross breakdown:', crossError)
  }

  const transformedCrossBreakdown: any[] = []
  if (crossData) {
    (crossData as any[]).forEach((row) => {
      transformedCrossBreakdown.push({
        language: row.language,
        study_mode: row.study_mode,
        operations: Number(row.operations) || 0,
        cost_usd: Number(row.cost_usd) || 0,
        avg_cost_per_operation: Number(row.avg_cost_per_operation) || 0,
      })
    })
  }

  // Get provider breakdown
  let providerData: any[] = []
  try {
    providerData = await fetchAllRows((from, to) =>
      supabaseClient
        .from('usage_logs')
        .select('llm_provider, llm_cost_usd, llm_input_tokens, llm_output_tokens')
        .gte('created_at', startDate)
        .lte('created_at', endDate)
        .not('llm_provider', 'is', null)
        .order('id', { ascending: true })
        .range(from, to)
    )
  } catch (providerError) {
    console.error('Error fetching provider breakdown:', providerError)
  }

  const transformedProviderStats: Record<string, any> = {}
  if (providerData) {
    (providerData as any[]).forEach((row) => {
      const key = row.llm_provider
      if (!transformedProviderStats[key]) {
        transformedProviderStats[key] = { operations: 0, cost_usd: 0, input_tokens: 0, output_tokens: 0, avg_cost_per_operation: 0 }
      }
      transformedProviderStats[key].operations += 1
      transformedProviderStats[key].cost_usd += Number(row.llm_cost_usd) || 0
      transformedProviderStats[key].input_tokens += Number(row.llm_input_tokens) || 0
      transformedProviderStats[key].output_tokens += Number(row.llm_output_tokens) || 0
    })
    Object.values(transformedProviderStats).forEach((v: any) => {
      v.avg_cost_per_operation = v.operations > 0 ? v.cost_usd / v.operations : 0
    })
  }

  // Get model breakdown
  let modelData: any[] = []
  try {
    modelData = await fetchAllRows((from, to) =>
      supabaseClient
        .from('usage_logs')
        .select('llm_model, llm_provider, llm_cost_usd, llm_input_tokens, llm_output_tokens')
        .gte('created_at', startDate)
        .lte('created_at', endDate)
        .not('llm_model', 'is', null)
        .order('id', { ascending: true })
        .range(from, to)
    )
  } catch (modelError) {
    console.error('Error fetching model breakdown:', modelError)
  }

  const transformedModelStats: Record<string, any> = {}
  if (modelData) {
    (modelData as any[]).forEach((row) => {
      const key = row.llm_model
      if (!transformedModelStats[key]) {
        transformedModelStats[key] = { operations: 0, cost_usd: 0, input_tokens: 0, output_tokens: 0, provider: row.llm_provider }
      }
      transformedModelStats[key].operations += 1
      transformedModelStats[key].cost_usd += Number(row.llm_cost_usd) || 0
      transformedModelStats[key].input_tokens += Number(row.llm_input_tokens) || 0
      transformedModelStats[key].output_tokens += Number(row.llm_output_tokens) || 0
    })
  }

  // Get daily breakdown (also used for total token sum)
  let dailyData: any[] = []
  try {
    dailyData = await fetchAllRows((from, to) =>
      supabaseClient
        .from('usage_logs')
        .select('created_at, llm_cost_usd, llm_input_tokens, llm_output_tokens, estimated_revenue_inr, profit_margin_inr')
        .gte('created_at', startDate)
        .lte('created_at', endDate)
        .order('id', { ascending: true })
        .range(from, to)
    )
  } catch (dailyError) {
    console.error('Error fetching daily data:', dailyError)
  }

  // Group by date
  const byDate: Record<string, { operations: number; cost: number; revenue: number; profit: number }> = {}

  let totalTokens = 0
  if (dailyData) {
    dailyData.forEach((log) => {
      const date = new Date(log.created_at).toISOString().split('T')[0]
      if (!byDate[date]) {
        byDate[date] = { operations: 0, cost: 0, revenue: 0, profit: 0 }
      }
      byDate[date].operations++
      byDate[date].cost += log.llm_cost_usd || 0
      byDate[date].revenue += log.estimated_revenue_inr || 0
      byDate[date].profit += log.profit_margin_inr || 0
      totalTokens += (log.llm_input_tokens || 0) + (log.llm_output_tokens || 0)
    })
  }

  // Convert to array and sort by date
  const byDateArray = Object.entries(byDate)
    .map(([date, stats]) => ({ date, ...stats }))
    .sort((a, b) => a.date.localeCompare(b.date))

  // Calculate average cost per operation
  const totalOps = overallStats?.total_operations || 0
  const totalCost = overallStats?.total_cost_usd || 0
  const avgCostPerOp = totalOps > 0 ? totalCost / totalOps : 0

  // Count distinct users via the RPC result (COUNT(DISTINCT user_id))
  const uniqueUsers: number = overallStats?.unique_users ?? 0

  // Transform daily data to match DailyCost interface
  const dailyCosts = byDateArray.map((day) => ({
    date: day.date,
    total_cost_usd: day.cost,
    operations: day.operations,
    total_tokens: 0, // daily breakdown doesn't track tokens per-day yet
  }))

  // Transform tier stats to match TierBreakdown interface
  const transformedTierStats: Record<string, any> = {}
  Object.entries(tierStats).forEach(([tier, stats]) => {
    const tierUsers = stats.unique_users || 0
    const tierCost = stats.total_cost_usd || 0
    transformedTierStats[tier] = {
      operations: stats.total_operations || 0,
      cost_usd: tierCost,
      unique_users: tierUsers,
      avg_cost_per_user: tierUsers > 0 ? tierCost / tierUsers : 0,
    }
  })

  // Transform feature stats to match FeatureBreakdown interface
  const transformedFeatureStats: Record<string, any> = {}
  Object.entries(featureStats).forEach(([feature, stats]) => {
    transformedFeatureStats[feature] = {
      operations: stats.total_operations || 0,
      cost_usd: stats.total_cost_usd || 0,
      input_tokens: 0, // TODO: Add token tracking
      output_tokens: 0,
      avg_cost_per_operation: stats.avg_cost_usd || 0,
    }
  })

  // Build response matching UsageAnalyticsResponse interface
  const analytics = {
    overview: {
      total_operations: totalOps,
      total_llm_cost_usd: totalCost,
      total_llm_tokens: totalTokens,
      avg_cost_per_operation: avgCostPerOp,
      unique_users: uniqueUsers,
    },
    by_tier: transformedTierStats,
    by_feature: transformedFeatureStats,
    by_provider: transformedProviderStats,
    by_model: transformedModelStats,
    daily_costs: dailyCosts,
    by_language: transformedLanguageStats,
    by_study_mode: transformedStudyModeStats,
    by_language_x_study_mode: transformedCrossBreakdown,
  }

  return json(analytics)
}

// Copied verbatim from admin-usage-logs/index.ts, adapted only to use the
// shared auth-context shape. Doesn't use fetchAllRows — already paginates via
// .range().
async function handleUsageLogs(
  auth: { supabase: any; adminUserId: string },
  req: Request
) {
  const supabaseClient = auth.supabase

  // Parse request body
  const body = await req.json().catch(() => ({}))
  const startDate = body.start_date || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
  const endDate = body.end_date || new Date().toISOString()
  const language: string | null = body.language || null
  const studyMode: string | null = body.study_mode || null
  const tier: string | null = body.tier || null
  const page: number = Math.max(1, parseInt(body.page) || 1)
  const limit: number = Math.min(100, Math.max(1, parseInt(body.limit) || 25))
  const offset = (page - 1) * limit

  // Build query
  let query = supabaseClient
    .from('usage_logs')
    .select(
      'id, created_at, user_id, tier, llm_model, llm_provider, llm_input_tokens, llm_output_tokens, llm_cost_usd, request_metadata',
      { count: 'exact' }
    )
    .eq('feature_name', 'study_generate')
    .gte('created_at', startDate)
    .lte('created_at', endDate)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (tier) {
    query = query.eq('tier', tier)
  }
  if (language) {
    query = query.filter('request_metadata->>language', 'eq', language)
  }
  if (studyMode) {
    query = query.filter('request_metadata->>study_mode', 'eq', studyMode)
  }

  const { data: rows, error: queryError, count } = await query

  if (queryError) {
    throw new Error(`Failed to fetch usage logs: ${queryError.message}`)
  }

  // Extract JSONB fields into flat response objects
  const items = (rows || []).map((row: any) => ({
    id: row.id,
    created_at: row.created_at,
    user_id: row.user_id,
    tier: row.tier,
    language: row.request_metadata?.language ?? null,
    study_mode: row.request_metadata?.study_mode ?? null,
    input_type: row.request_metadata?.input_type ?? null,
    llm_model: row.llm_model ?? null,
    llm_provider: row.llm_provider ?? null,
    llm_input_tokens: row.llm_input_tokens ?? null,
    llm_output_tokens: row.llm_output_tokens ?? null,
    llm_cost_usd: row.llm_cost_usd ?? null,
  }))

  return json({ items, total: count ?? 0, page, limit })
}

// Copied verbatim from admin-pl-analytics/index.ts, adapted only to use the
// shared fetchAllRows helper and the shared auth-context shape.
async function handlePlAnalytics(
  auth: { supabase: any; adminUserId: string },
  req: Request
) {
  const supabase = auth.supabase

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
    console.warn('[admin-analytics/pl] Exchange rate fetch failed, using fallback 84.0')
  }

  // ── LLM costs: from usage_logs.tier (stamped at call time — always accurate) ──
  const costRows = await fetchAllRows((from, to) =>
    supabase
      .from('usage_logs')
      .select('tier, llm_cost_usd')
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .not('user_id', 'is', null)
      .not('tier', 'is', null)
      .neq('tier', 'system')
      .order('id', { ascending: true })
      .range(from, to)
  ).catch((e) => {
    throw new Error(`Failed to fetch usage costs: ${e.message}`)
  })

  // Aggregate costs by tier in TS
  const costByTier: Record<string, number> = {}
  for (const row of costRows) {
    const t = row.tier as string
    costByTier[t] = (costByTier[t] ?? 0) + (Number(row.llm_cost_usd) || 0)
  }

  // ── Active users: from subscriptions (current status) ──
  const subRows = await fetchAllRows((from, to) =>
    supabase
      .from('subscriptions')
      .select('user_id, plan_id, subscription_plans!inner(plan_code)')
      .in('status', ['active', 'trial', 'in_progress', 'pending_cancellation', 'paused'])
      .order('user_id', { ascending: true })
      .range(from, to)
  ).catch((e) => {
    throw new Error(`Failed to fetch subscriptions: ${e.message}`)
  })

  // Count distinct users per plan_code
  const usersByPlan: Record<string, Set<string>> = {}
  for (const row of subRows) {
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
  const invoiceRows = await fetchAllRows((from, to) =>
    supabase
      .from('subscription_invoices')
      .select('user_id, amount_paise, paid_at')
      .eq('status', 'paid')
      .gte('paid_at', startDate)
      .lte('paid_at', endDate)
      .order('user_id', { ascending: true })
      .range(from, to)
  ).catch((e) => {
    throw new Error(`Failed to fetch invoices: ${e.message}`)
  })

  // Map user_id → plan_code from subscriptions, then accumulate revenue
  const userToPlan: Record<string, string> = {}
  for (const row of subRows) {
    const planCode = (row.subscription_plans as any)?.plan_code as string
    if (planCode) userToPlan[row.user_id] = planCode
  }

  const revenueByPlan: Record<string, number> = {}
  for (const row of invoiceRows) {
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
    console.error('[admin-analytics/pl] get_top_heavy_users error:', usersError)
  }

  return json({
    pl_by_tier: rows,
    top_heavy_users: topHeavyUsers ?? [],
    exchange_rate_used: exchangeRate,
    exchange_rate_is_live: exchangeRateIsLive,
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const url = new URL(req.url)
    // pathParts[0] is always this function's own name — action segment is pathParts[1].
    const pathParts = url.pathname.split('/').filter(Boolean)

    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'usage') {
      return await handleUsageAnalytics(auth, req)
    }
    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'logs') {
      return await handleUsageLogs(auth, req)
    }
    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'pl') {
      return await handlePlAnalytics(auth, req)
    }

    return json({ error: 'Not found' }, 404)
  } catch (error: unknown) {
    console.error('Error in admin-analytics:', error)
    const errorMessage = error instanceof Error ? error.message : 'Internal server error'
    return json({ error: errorMessage }, 500)
  }
})
