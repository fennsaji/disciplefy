import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import type { SupabaseClient, User } from '@supabase/supabase-js'
import { listAllAuthUsers, getAuthEmailMap } from '@/lib/supabase/list-all-users'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 200
// PostgREST filters travel in the URL, so an unbounded id list can exceed the
// server's URL/header limits. Cap the email-matched id set we inline.
const MAX_INLINE_IDS = 500

/**
 * Apply the search + plan filters to a `user_tokens` query.
 *
 * Both filters run in SQL so paging and counting see the same row set the
 * caller is browsing — never a client-side slice of the first page.
 */
function applyFilters<T>(
  query: T,
  search: string,
  plan: string,
  emailMatchedIds: string[]
): T {
  let q = query as any

  if (plan) {
    q = q.eq('user_plan', plan)
  }

  if (search) {
    const conditions = [`identifier.ilike.%${search}%`]
    if (emailMatchedIds.length > 0) {
      conditions.push(`identifier.in.(${emailMatchedIds.join(',')})`)
    }
    q = q.or(conditions.join(','))
  }

  return q as T
}

/**
 * GET - Fetch a page of user token balances, filtered in the database.
 *
 * Query params: `search` (email or user id substring), `plan`, `limit`, `offset`.
 * Returns `{ balances, total, limit, offset }` where `total` counts ALL rows
 * matching the filters, not just the returned page.
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const search = searchParams.get('search') || ''
    const plan = searchParams.get('plan') || ''
    const limit = Math.min(
      Math.max(parseInt(searchParams.get('limit') || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT, 1),
      MAX_LIMIT
    )
    const offset = Math.max(parseInt(searchParams.get('offset') || '0', 10) || 0, 0)

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

    // Resolve matching user IDs by email first so the filter is applied in the
    // query, BEFORE paging — not against an already-truncated page of rows.
    let allAuthUsers: User[] | null = null
    let emailMatchedIds: string[] = []
    if (search) {
      try {
        allAuthUsers = await listAllAuthUsers(supabaseAdmin)
        emailMatchedIds = allAuthUsers
          .filter(u => u.email?.toLowerCase().includes(search.toLowerCase()))
          .map(u => u.id)
          .slice(0, MAX_INLINE_IDS)
      } catch (error) {
        console.error('Email query error:', error)
      }
    }

    // Count every row matching the filters (drives pagination + "N matching")
    const countQuery = applyFilters(
      supabaseAdmin.from('user_tokens').select('id', { count: 'exact', head: true }),
      search,
      plan,
      emailMatchedIds
    )
    const { count: total, error: countError } = await countQuery

    if (countError) {
      console.error('Failed to count token balances:', countError)
      return NextResponse.json(
        { error: 'Failed to fetch token balances' },
        { status: 500 }
      )
    }

    // Fetch the requested page
    const pageQuery = applyFilters(
      supabaseAdmin.from('user_tokens').select('*'),
      search,
      plan,
      emailMatchedIds
    )
      .order('updated_at', { ascending: false })
      .order('identifier', { ascending: true })
      .range(offset, offset + limit - 1)

    const { data: tokenBalances, error: balancesError } = await pageQuery

    if (balancesError) {
      console.error('Failed to fetch token balances:', balancesError)
      return NextResponse.json(
        { error: 'Failed to fetch token balances' },
        { status: 500 }
      )
    }

    if (!tokenBalances || tokenBalances.length === 0) {
      return NextResponse.json({ balances: [], total: total || 0, limit, offset })
    }

    // Get user IDs to fetch emails and names
    const userIds = tokenBalances.map(b => b.identifier)

    // Fetch emails from auth.users using admin API (same pattern as search-users)
    let emailsMap: Record<string, string> = {}
    try {
      emailsMap = allAuthUsers
        ? Object.fromEntries(
            allAuthUsers
              .filter(u => userIds.includes(u.id))
              .map(u => [u.id, u.email || ''])
          )
        : await getAuthEmailMap(supabaseAdmin, userIds)
    } catch (error) {
      console.error('Email query error:', error)
    }

    // Fetch user profiles for names
    const { data: userProfiles } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name')
      .in('id', userIds)

    const profilesMap: Record<string, { first_name: string | null; last_name: string | null }> = Object.fromEntries(
      (userProfiles || []).map(p => [p.id, { first_name: p.first_name, last_name: p.last_name }])
    )

    // Today's consumption for the whole page in ONE query (was N+1, one per row)
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const { data: todayUsage } = await supabaseAdmin
      .from('token_usage_history')
      .select('user_id, token_cost')
      .in('user_id', userIds)
      .gte('created_at', today.toISOString())

    const consumedTodayMap: Record<string, number> = {}
    for (const row of todayUsage || []) {
      consumedTodayMap[row.user_id] = (consumedTodayMap[row.user_id] || 0) + (row.token_cost || 0)
    }

    const balances = tokenBalances.map((balance) => {
      const profileRow = profilesMap[balance.identifier]
      const fullName = profileRow
        ? [profileRow.first_name, profileRow.last_name].filter(Boolean).join(' ')
        : null

      return {
        id: balance.id,
        identifier: balance.identifier,
        user_email: emailsMap[balance.identifier] || null,
        user_name: fullName,
        user_plan: balance.user_plan,
        available_tokens: balance.available_tokens,
        purchased_tokens: balance.purchased_tokens,
        daily_limit: balance.daily_limit,
        last_reset: balance.last_reset,
        total_consumed_today: consumedTodayMap[balance.identifier] || 0,
        created_at: balance.created_at,
        updated_at: balance.updated_at
      }
    })

    return NextResponse.json({ balances, total: total || 0, limit, offset })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
