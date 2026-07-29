import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

const TIERS = ['free', 'standard', 'plus', 'premium'] as const
const ACTIVE_STATUSES = ['active', 'trial', 'in_progress', 'pending_cancellation']

/**
 * GET - Subscription counts across the WHOLE database.
 *
 * These are deliberately independent of the subscriptions page's search and
 * paging: the cards report the real totals, not a count of the rows on screen.
 */
export async function GET() {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
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

    // One COUNT per tier, plus total users — all computed by Postgres
    const [totalUsersRes, ...tierResults] = await Promise.all([
      supabaseAdmin.from('user_profiles').select('id', { count: 'exact', head: true }),
      ...TIERS.map(tier =>
        supabaseAdmin
          .from('subscriptions')
          .select('user_id, subscription_plans!inner(plan_code)', { count: 'exact', head: true })
          .eq('subscription_plans.plan_code', tier)
          .in('status', ACTIVE_STATUSES)
      ),
    ])

    const byTier = Object.fromEntries(
      TIERS.map((tier, i) => [tier, tierResults[i]?.count || 0])
    ) as Record<(typeof TIERS)[number], number>

    return NextResponse.json({
      total_users: totalUsersRes.count || 0,
      by_tier: byTier,
      active_statuses: ACTIVE_STATUSES,
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
