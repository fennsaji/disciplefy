import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import type { User } from '@supabase/supabase-js'
import { listAllAuthUsers, getAuthEmailMap } from '@/lib/supabase/list-all-users'

/**
 * GET - Fetch user token balances with optional search and filtering
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const search = searchParams.get('search') || ''
    const plan = searchParams.get('plan') || ''

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

    // If searching, resolve matching user IDs by email first so the filter
    // is applied BEFORE the row limit (not after fetching the latest 100 rows)
    let allAuthUsers: User[] | null = null
    let emailMatchedIds: string[] = []
    if (search) {
      try {
        allAuthUsers = await listAllAuthUsers(supabaseAdmin)
        emailMatchedIds = allAuthUsers
          .filter(u => u.email?.toLowerCase().includes(search.toLowerCase()))
          .map(u => u.id)
      } catch (error) {
        console.error('Email query error:', error)
      }
    }

    // Fetch user tokens
    let query = supabaseAdmin
      .from('user_tokens')
      .select('*')

    // Apply plan filter
    if (plan) {
      query = query.eq('user_plan', plan)
    }

    // Apply search filter in the query (email-matched user IDs or identifier substring)
    if (search) {
      const searchConditions = [`identifier.ilike.%${search}%`]
      if (emailMatchedIds.length > 0) {
        searchConditions.push(`identifier.in.(${emailMatchedIds.join(',')})`)
      }
      query = query.or(searchConditions.join(','))
    }

    // Execute query with ordering; limit only applies to the unfiltered browse case
    query = query.order('updated_at', { ascending: false })
    if (!search) {
      query = query.limit(100)
    }
    const { data: tokenBalances, error: balancesError } = await query

    if (balancesError) {
      console.error('Failed to fetch token balances:', balancesError)
      return NextResponse.json(
        { error: 'Failed to fetch token balances' },
        { status: 500 }
      )
    }

    if (!tokenBalances || tokenBalances.length === 0) {
      return NextResponse.json([])
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

    // Calculate today's consumption for each user
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const enrichedBalances = await Promise.all(
      tokenBalances.map(async (balance) => {
        const userEmail = emailsMap[balance.identifier] || null
        const profile = profilesMap[balance.identifier]
        const fullName = profile
          ? [profile.first_name, profile.last_name].filter(Boolean).join(' ')
          : null

        const { data: todayUsage } = await supabaseAdmin
          .from('token_usage_history')
          .select('token_cost')
          .eq('user_id', balance.identifier)
          .gte('created_at', today.toISOString())

        const totalConsumedToday = todayUsage?.reduce((sum, row) => sum + (row.token_cost || 0), 0) || 0

        return {
          id: balance.id,
          identifier: balance.identifier,
          user_email: userEmail,
          user_name: fullName,
          user_plan: balance.user_plan,
          available_tokens: balance.available_tokens,
          purchased_tokens: balance.purchased_tokens,
          daily_limit: balance.daily_limit,
          last_reset: balance.last_reset,
          total_consumed_today: totalConsumedToday,
          created_at: balance.created_at,
          updated_at: balance.updated_at
        }
      })
    )

    // Filter out null values (from search filter)
    const filteredBalances = enrichedBalances.filter(b => b !== null)

    return NextResponse.json(filteredBalances)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
