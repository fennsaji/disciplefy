import { createAdminClient } from '@/lib/supabase/admin'
import { NextResponse } from 'next/server'

export async function GET() {
  try {
    const supabase = await createAdminClient()

    // Get LLM costs for last 30 days
    const thirtyDaysAgo = new Date()
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

    const { data: llmCosts } = await supabase
      .from('llm_api_costs')
      .select('total_cost')
      .gte('created_at', thirtyDaysAgo.toISOString())

    const totalLLMCost = llmCosts?.reduce((sum, record) => sum + (record.total_cost || 0), 0) || 0

    // Get LLM costs for previous 30 days for comparison
    const sixtyDaysAgo = new Date()
    sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60)

    const { data: previousLLMCosts } = await supabase
      .from('llm_api_costs')
      .select('total_cost')
      .gte('created_at', sixtyDaysAgo.toISOString())
      .lt('created_at', thirtyDaysAgo.toISOString())

    const previousTotalLLMCost = previousLLMCosts?.reduce((sum, record) => sum + (record.total_cost || 0), 0) || 0
    const llmCostChange = previousTotalLLMCost > 0
      ? ((totalLLMCost - previousTotalLLMCost) / previousTotalLLMCost) * 100
      : 0

    // Get active subscriptions
    const { count: activeSubscriptions } = await supabase
      .from('subscriptions')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'active')

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
    const { data: tokenUsage } = await supabase
      .from('token_usage_history')
      .select('amount')
      .gte('created_at', thirtyDaysAgo.toISOString())

    const totalTokens = tokenUsage?.reduce((sum, record) => sum + Math.abs(record.amount || 0), 0) || 0

    // Get tokens for previous 30 days
    const { data: previousTokenUsage } = await supabase
      .from('token_usage_history')
      .select('amount')
      .gte('created_at', sixtyDaysAgo.toISOString())
      .lt('created_at', thirtyDaysAgo.toISOString())

    const previousTotalTokens = previousTokenUsage?.reduce((sum, record) => sum + Math.abs(record.amount || 0), 0) || 0
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
