import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'
import { NextResponse } from 'next/server'

export async function GET() {
  try {
    // 1. Verify user authentication (validates JWT via getUser)
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // 2. Verify admin status
    const supabaseAdmin = await createAdminClient()
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json(
        { error: 'Unauthorized - Admin access required' },
        { status: 403 }
      )
    }

    // 3. Query stats with the service-role client (bypasses RLS)
    const supabase = supabaseAdmin

    // Get LLM costs for last 30 days
    const thirtyDaysAgo = new Date()
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

    const sixtyDaysAgo = new Date()
    sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60)

    /**
     * Sum LLM spend over a window using the same source as the LLM Costs page:
     * `usage_logs.llm_cost_usd`, aggregated by Postgres via `get_usage_stats`.
     *
     * This previously read `llm_api_costs.total_cost`. That table has no
     * `total_cost` column (it is `cost_usd`) AND nothing in the codebase ever
     * inserts into it, so the query errored, the error was discarded, and the
     * card silently showed $0 forever.
     */
    const sumLlmCost = async (start: Date, end: Date): Promise<number> => {
      const { data, error } = await supabase.rpc('get_usage_stats', {
        p_start_date: start.toISOString(),
        p_end_date: end.toISOString(),
      })
      if (error) {
        console.error('Failed to fetch LLM cost stats:', error)
        return 0
      }
      return Number((data as { total_cost_usd?: number } | null)?.total_cost_usd) || 0
    }

    const [totalLLMCost, previousTotalLLMCost] = await Promise.all([
      sumLlmCost(thirtyDaysAgo, new Date()),
      sumLlmCost(sixtyDaysAgo, thirtyDaysAgo),
    ])
    const llmCostChange = previousTotalLLMCost > 0
      ? ((totalLLMCost - previousTotalLLMCost) / previousTotalLLMCost) * 100
      : 0

    // Get active subscriptions (includes trial status)
    const { count: activeSubscriptions } = await supabase
      .from('subscriptions')
      .select('*', { count: 'exact', head: true })
      .in('status', ['active', 'trial'])

    // Get subscriptions created today
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const { count: subscriptionsToday } = await supabase
      .from('subscriptions')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', today.toISOString())

    // Get active promo codes
    const now = new Date().toISOString()
    const { count: activePromoCodes } = await supabase
      .from('promotional_campaigns')
      .select('*', { count: 'exact', head: true })
      .eq('is_active', true)
      .or(`valid_until.is.null,valid_until.gte.${now}`)

    // Get promo codes expiring in next 7 days
    const sevenDaysLater = new Date()
    sevenDaysLater.setDate(sevenDaysLater.getDate() + 7)

    const { count: expiringPromoCodes } = await supabase
      .from('promotional_campaigns')
      .select('*', { count: 'exact', head: true })
      .eq('is_active', true)
      .gte('valid_until', now)
      .lte('valid_until', sevenDaysLater.toISOString())

    // Get total tokens consumed in last 30 days
    const { data: tokenUsage } = await fetchAllRows((from, to) =>
      supabase
        .from('token_usage_history')
        .select('token_cost')
        .gte('created_at', thirtyDaysAgo.toISOString())
        .order('created_at', { ascending: true })
        .range(from, to)
    )

    const totalTokens = tokenUsage?.reduce((sum, record) => sum + (record.token_cost || 0), 0) || 0

    // Get tokens for previous 30 days
    const { data: previousTokenUsage } = await fetchAllRows((from, to) =>
      supabase
        .from('token_usage_history')
        .select('token_cost')
        .gte('created_at', sixtyDaysAgo.toISOString())
        .lt('created_at', thirtyDaysAgo.toISOString())
        .order('created_at', { ascending: true })
        .range(from, to)
    )

    const previousTotalTokens = previousTokenUsage?.reduce((sum, record) => sum + (record.token_cost || 0), 0) || 0
    const tokenChange = previousTotalTokens > 0
      ? ((totalTokens - previousTotalTokens) / previousTotalTokens) * 100
      : 0

    return NextResponse.json({
      llmCost: {
        value: totalLLMCost,
        change: llmCostChange,
      },
      subscriptions: {
        total: activeSubscriptions || 0,
        todayCount: subscriptionsToday || 0,
      },
      promoCodes: {
        active: activePromoCodes || 0,
        expiringSoon: expiringPromoCodes || 0,
      },
      tokens: {
        total: totalTokens,
        change: tokenChange,
      },
    })
  } catch (error) {
    console.error('Error fetching dashboard stats:', error)
    return NextResponse.json(
      { error: 'Failed to fetch dashboard stats' },
      { status: 500 }
    )
  }
}
