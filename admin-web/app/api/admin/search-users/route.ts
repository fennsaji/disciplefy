import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import type { SupabaseClient, User } from '@supabase/supabase-js'
import { listAllAuthUsers } from '@/lib/supabase/list-all-users'
import type { SearchUsersRequest, SearchUsersResponse } from '@/types/admin'

// PostgREST filters travel in the URL, so an unbounded id list can exceed the
// server's URL/header limits. Cap inlined id sets and log when we truncate.
const MAX_INLINE_IDS = 500

const isValidUUID = (str: string) =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)

/** Build the PostgREST `or` conditions that express the free-text user search. */
function buildSearchConditions(query: string, authUserIds: string[], idColumn: string): string {
  const conditions: string[] = []
  if (authUserIds.length > 0) {
    conditions.push(`${idColumn}.in.(${authUserIds.join(',')})`)
  }
  conditions.push(`first_name.ilike.%${query}%`)
  conditions.push(`last_name.ilike.%${query}%`)
  conditions.push(`phone_number.ilike.%${query}%`)
  if (isValidUUID(query)) {
    conditions.push(`${idColumn}.eq.${query}`)
  }
  return conditions.join(',')
}

export async function POST(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      console.error('[Search Users API] Auth failed:', userError?.message || 'No user')
      return NextResponse.json(
        { error: 'Unauthorized', details: userError?.message },
        { status: 401 }
      )
    }

    // Verify admin status
    const supabaseAdmin: SupabaseClient = createAdminClient(
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

    // Parse request body
    const body: SearchUsersRequest = await request.json()

    const limit = body.limit || 50
    const offset = body.offset || 0
    const query = body.query?.trim() || ''
    // Tier/status are applied in SQL so paging and counts cover every matching
    // user, not just the rows that happened to land on the current page.
    const tier = body.tier && body.tier !== 'all' ? body.tier : ''
    const status = body.status && body.status !== 'all' ? body.status : ''

    let allAuthUsers: User[] | null = null
    let authUserIds: string[] = []

    // Resolve email matches once; reused for both the filter and the email map
    if (query.length > 0) {
      try {
        allAuthUsers = await listAllAuthUsers(supabaseAdmin)
        const matchingUsers = allAuthUsers.filter(u =>
          u.email?.toLowerCase().includes(query.toLowerCase())
        )
        if (matchingUsers.length > MAX_INLINE_IDS) {
          console.warn(
            `[Search Users API] ${matchingUsers.length} email matches truncated to ${MAX_INLINE_IDS}`
          )
        }
        authUserIds = matchingUsers.map(u => u.id).slice(0, MAX_INLINE_IDS)
      } catch (error) {
        console.error('[Search Users API] Error fetching auth users:', error)
        authUserIds = []
      }
    }

    let pagedUserIds: string[] = []
    let total = 0

    if (tier || status) {
      // Text search matches name/phone on user_profiles and email on auth.users,
      // so resolve those ids first and intersect the subscription query by user_id.
      let textMatchedIds: string[] = []
      if (query.length > 0) {
        const { data: matchedProfiles } = await supabaseAdmin
          .from('user_profiles')
          .select('id')
          .or(buildSearchConditions(query, authUserIds, 'id'))
          .limit(MAX_INLINE_IDS)
        textMatchedIds = (matchedProfiles || []).map(p => p.id)
        if (textMatchedIds.length === 0) {
          return NextResponse.json({ users: [], total: 0, limit, offset } as SearchUsersResponse)
        }
      }

      // Tier/status filtering drives paging from `subscriptions`, which has a
      // UNIQUE index on user_id (one row per user) so pages can't duplicate a user.
      const buildSubscriptionQuery = (select: string, opts?: { count: 'exact'; head: true }) => {
        let q = supabaseAdmin
          .from('subscriptions')
          .select(select, opts as any)

        if (status) q = q.eq('status', status)
        if (tier) q = q.eq('subscription_plans.plan_code', tier)
        if (query.length > 0) q = q.in('user_id', textMatchedIds)

        return q
      }

      // `!inner` makes the plan join a filterable INNER JOIN
      const countRes = await buildSubscriptionQuery('user_id, subscription_plans!inner(plan_code)', {
        count: 'exact',
        head: true,
      })
      if (countRes.error) {
        console.error('[Search Users API] Subscription count error:', countRes.error)
        return NextResponse.json(
          { error: 'Failed to search users', details: countRes.error.message },
          { status: 500 }
        )
      }
      total = countRes.count || 0

      const pageRes = await buildSubscriptionQuery('user_id, created_at, subscription_plans!inner(plan_code)')
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1)

      if (pageRes.error) {
        console.error('[Search Users API] Subscription page error:', pageRes.error)
        return NextResponse.json(
          { error: 'Failed to search users', details: pageRes.error.message },
          { status: 500 }
        )
      }
      pagedUserIds = ((pageRes.data as any[]) || []).map(r => r.user_id)
    } else {
      // No subscription filter: page over user_profiles directly
      let userQuery = supabaseAdmin
        .from('user_profiles')
        .select('id')
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1)

      let countQuery = supabaseAdmin
        .from('user_profiles')
        .select('id', { count: 'exact', head: true })

      if (query.length > 0) {
        const conditions = buildSearchConditions(query, authUserIds, 'id')
        userQuery = userQuery.or(conditions)
        countQuery = countQuery.or(conditions)
      }

      const [pageRes, countRes] = await Promise.all([userQuery, countQuery])

      if (pageRes.error) {
        console.error('[Search Users API] Query error:', pageRes.error)
        return NextResponse.json(
          { error: 'Failed to search users', details: pageRes.error.message },
          { status: 500 }
        )
      }

      pagedUserIds = (pageRes.data || []).map(u => u.id)
      total = countRes.count || 0
    }

    if (pagedUserIds.length === 0) {
      return NextResponse.json({ users: [], total, limit, offset } as SearchUsersResponse)
    }

    // Hydrate the page: profiles, emails, subscriptions
    const { data: users, error: profilesError } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name, phone_number, created_at, is_admin')
      .in('id', pagedUserIds)

    if (profilesError) {
      console.error('[Search Users API] Profile hydration error:', profilesError)
      return NextResponse.json(
        { error: 'Failed to search users', details: profilesError.message },
        { status: 500 }
      )
    }

    // Preserve the page ordering established by the driving query
    const orderIndex = new Map(pagedUserIds.map((id, i) => [id, i]))
    const orderedUsers = (users || []).sort(
      (a, b) => (orderIndex.get(a.id) ?? 0) - (orderIndex.get(b.id) ?? 0)
    )
    const userIds = orderedUsers.map(u => u.id)

    // Fetch emails from auth.users using admin API
    let emailsMap: Record<string, string> = {}
    try {
      const authUsers = allAuthUsers ?? await listAllAuthUsers(supabaseAdmin)
      const idFilter = new Set(userIds)
      emailsMap = Object.fromEntries(
        authUsers.filter(u => idFilter.has(u.id)).map(u => [u.id, u.email || ''])
      )
    } catch (error) {
      console.error('[Search Users API] Email query error:', error)
    }

    // Fetch subscriptions for these users with correct column names
    const { data: subscriptions, error: subsError } = await supabaseAdmin
      .from('subscriptions')
      .select(`
        id,
        user_id,
        plan_type,
        status,
        current_period_start,
        current_period_end,
        next_billing_at,
        cancelled_at,
        provider,
        amount_paise,
        currency,
        plan_id,
        subscription_plans!inner (
          id,
          plan_name,
          plan_code,
          tier
        )
      `)
      .in('user_id', userIds)

    if (subsError) {
      console.error('[Search Users API] Subscriptions query error:', subsError)
      // Continue without subscriptions rather than failing
    }

    // Combine users with their emails and subscriptions
    const usersWithSubscriptions = orderedUsers.map(profileRow => {
      const userEmail = emailsMap[profileRow.id] || null
      const fullName = [profileRow.first_name, profileRow.last_name].filter(Boolean).join(' ') || 'Unknown'
      const isAdmin = profileRow.is_admin || false

      // Note: subscription_plans is returned as an array by Supabase joins
      let userSubscriptions = subscriptions
        ?.filter(s => s.user_id === profileRow.id)
        .map(sub => {
          const plan = Array.isArray(sub.subscription_plans)
            ? sub.subscription_plans[0]
            : sub.subscription_plans
          return {
            id: sub.id,
            user_id: sub.user_id,
            tier: plan?.plan_code, // Get plan_code from JOIN
            subscription_plan: plan?.plan_code, // Use plan_code from JOIN
            plan_type: sub.plan_type,
            status: sub.status,
            start_date: sub.current_period_start, // Map current_period_start to start_date
            end_date: sub.current_period_end, // Map current_period_end to end_date
            current_period_start: sub.current_period_start,
            current_period_end: sub.current_period_end,
            next_billing_at: sub.next_billing_at,
            cancelled_at: sub.cancelled_at,
            provider: sub.provider,
            amount_paise: sub.amount_paise,
            currency: sub.currency,
            subscription_plans: plan ? {
              plan_name: plan.plan_name,
              plan_code: plan.plan_code,
              tier: plan.tier,
              price_inr: sub.amount_paise ? sub.amount_paise / 100 : 0,
              billing_cycle: sub.plan_type?.endsWith('_yearly') ? 'yearly' : 'monthly'
            } : null
          }
        }) || []

      // For admin users WITHOUT a subscription, create a virtual "Premium (Admin)" subscription
      if (isAdmin && userSubscriptions.length === 0) {
        userSubscriptions = [{
          id: `admin-${profileRow.id}`,
          user_id: profileRow.id,
          tier: 'premium',
          subscription_plan: 'premium', // Frontend compatibility
          plan_type: 'premium_admin',
          status: 'active',
          start_date: profileRow.created_at,
          end_date: null, // Admins have unlimited access
          current_period_start: profileRow.created_at,
          current_period_end: null,
          next_billing_at: null,
          cancelled_at: null,
          provider: 'system',
          amount_paise: null,
          currency: 'INR',
          subscription_plans: {
            plan_name: 'Premium (Admin)',
            plan_code: 'premium',
            tier: 3,
            price_inr: 0,
            billing_cycle: 'lifetime'
          }
        }]
      }

      return {
        id: profileRow.id,
        email: userEmail,
        full_name: fullName,
        phone: profileRow.phone_number,
        created_at: profileRow.created_at,
        subscriptions: userSubscriptions,
        is_admin: isAdmin // Include admin status for reference
      }
    })

    return NextResponse.json({
      users: usersWithSubscriptions,
      total,
      limit,
      offset
    } as SearchUsersResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
