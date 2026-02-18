import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch comprehensive token statistics for admin dashboard
 */
export async function GET() {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    // Verify admin status
    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )
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

    // Fetch total users with tokens
    const { count: totalUsers } = await supabaseAdmin
      .from('user_tokens')
      .select('*', { count: 'exact', head: true })

    // Fetch total available and purchased tokens (excluding premium users who have unlimited)
    const { data: tokenSums } = await supabaseAdmin
      .from('user_tokens')
      .select('available_tokens, purchased_tokens, user_plan')
      .neq('user_plan', 'premium') // Exclude premium users from daily tokens calculation

    const totalAvailableTokens = tokenSums?.reduce((sum, row) => sum + (row.available_tokens || 0), 0) || 0
    const totalPurchasedTokens = tokenSums?.reduce((sum, row) => sum + (row.purchased_tokens || 0), 0) || 0

    // Fetch today's consumption
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const { data: todayUsage } = await supabaseAdmin
      .from('token_usage_history')
      .select('token_cost')
      .gte('created_at', today.toISOString())

    const totalConsumedToday = todayUsage?.reduce((sum, row) => sum + (row.token_cost || 0), 0) || 0

    // Fetch this month's consumption
    const monthStart = new Date()
    monthStart.setDate(1)
    monthStart.setHours(0, 0, 0, 0)
    const { data: monthUsage } = await supabaseAdmin
      .from('token_usage_history')
      .select('token_cost')
      .gte('created_at', monthStart.toISOString())

    const totalConsumedThisMonth = monthUsage?.reduce((sum, row) => sum + (row.token_cost || 0), 0) || 0

    // Fetch this month's revenue from completed token purchases
    const { data: monthPurchases } = await supabaseAdmin
      .from('purchase_history')
      .select('cost_rupees')
      .eq('status', 'completed')
      .gte('purchased_at', monthStart.toISOString())

    const totalRevenueThisMonth = monthPurchases?.reduce((sum, row) => sum + parseFloat(row.cost_rupees || '0'), 0) || 0

    // Fetch average tokens per user by plan
    const { data: tokensByPlan } = await supabaseAdmin
      .from('user_tokens')
      .select('user_plan, available_tokens, purchased_tokens')

    const planGroups = {
      free: [] as number[],
      standard: [] as number[],
      plus: [] as number[],
      premium: [] as number[]
    }

    tokensByPlan?.forEach(row => {
      const total = (row.available_tokens || 0) + (row.purchased_tokens || 0)
      const plan = row.user_plan as keyof typeof planGroups
      if (planGroups[plan]) {
        planGroups[plan].push(total)
      }
    })

    const avgTokensPerUserByPlan = {
      free: planGroups.free.length > 0
        ? Math.round(planGroups.free.reduce((a, b) => a + b, 0) / planGroups.free.length)
        : 0,
      standard: planGroups.standard.length > 0
        ? Math.round(planGroups.standard.reduce((a, b) => a + b, 0) / planGroups.standard.length)
        : 0,
      plus: planGroups.plus.length > 0
        ? Math.round(planGroups.plus.reduce((a, b) => a + b, 0) / planGroups.plus.length)
        : 0,
      premium: planGroups.premium.length > 0
        ? Math.round(planGroups.premium.reduce((a, b) => a + b, 0) / planGroups.premium.length)
        : 0
    }

    // Fetch top consuming features
    const { data: featureUsage } = await supabaseAdmin
      .from('token_usage_history')
      .select('feature_name, token_cost')

    const featureMap = new Map<string, { total_tokens: number; usage_count: number }>()

    featureUsage?.forEach(row => {
      const existing = featureMap.get(row.feature_name) || { total_tokens: 0, usage_count: 0 }
      featureMap.set(row.feature_name, {
        total_tokens: existing.total_tokens + (row.token_cost || 0),
        usage_count: existing.usage_count + 1
      })
    })

    const topConsumingFeatures = Array.from(featureMap.entries())
      .map(([feature_name, stats]) => ({
        feature_name,
        total_tokens: stats.total_tokens,
        usage_count: stats.usage_count
      }))
      .sort((a, b) => b.total_tokens - a.total_tokens)
      .slice(0, 10)

    return NextResponse.json({
      total_users_with_tokens: totalUsers || 0,
      total_available_tokens: totalAvailableTokens,
      total_purchased_tokens: totalPurchasedTokens,
      total_consumed_today: totalConsumedToday,
      total_consumed_this_month: totalConsumedThisMonth,
      total_revenue_this_month: totalRevenueThisMonth,
      avg_tokens_per_user_by_plan: avgTokensPerUserByPlan,
      top_consuming_features: topConsumingFeatures
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
