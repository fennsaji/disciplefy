import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import type { SearchUsersRequest, SearchUsersResponse } from '@/types/admin'

export async function POST(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    console.log('[Search Users API] Auth check:', {
      hasUser: !!user,
      userId: user?.id,
      userError: userError?.message
    })

    if (userError || !user) {
      console.error('[Search Users API] Auth failed:', userError?.message || 'No user')
      return NextResponse.json(
        { error: 'Unauthorized', details: userError?.message },
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

    // Parse request body
    const body: SearchUsersRequest = await request.json()

    const limit = body.limit || 50
    const offset = body.offset || 0
    const query = body.query?.trim() || ''

    // Helper to check if string is valid UUID
    const isValidUUID = (str: string) => {
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      return uuidRegex.test(str)
    }

    // Build base query for user_profiles
    let userQuery = supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name, phone_number, created_at')
      .order('created_at', { ascending: false })
      .limit(limit)
      .range(offset, offset + limit - 1)

    let authUserIds: string[] = []

    // If query is provided, add search filters
    if (query.length > 0) {
      // Search auth.users for email matches - need to use auth admin API
      try {
        const { data: authData } = await supabaseAdmin.auth.admin.listUsers()
        const matchingUsers = authData.users.filter(u =>
          u.email?.toLowerCase().includes(query.toLowerCase())
        )
        authUserIds = matchingUsers.map(u => u.id).slice(0, 100)
      } catch (error) {
        console.error('[Search Users API] Error fetching auth users:', error)
        authUserIds = []
      }

      // Build OR conditions for search
      const searchConditions: string[] = []

      // Add email-matched user IDs
      if (authUserIds.length > 0) {
        searchConditions.push(`id.in.(${authUserIds.join(',')})`)
      }

      // Add name and phone searches
      searchConditions.push(`first_name.ilike.%${query}%`)
      searchConditions.push(`last_name.ilike.%${query}%`)
      searchConditions.push(`phone_number.ilike.%${query}%`)

      // Only add ID exact match if query is a valid UUID
      if (isValidUUID(query)) {
        searchConditions.push(`id.eq.${query}`)
      }

      // Apply search conditions
      userQuery = userQuery.or(searchConditions.join(','))
    }

    const { data: users, error: searchError } = await userQuery

    if (searchError) {
      console.error('[Search Users API] Query error:', searchError)
      return NextResponse.json(
        { error: 'Failed to search users', details: searchError.message },
        { status: 500 }
      )
    }

    if (!users || users.length === 0) {
      console.log('[Search Users API] No users found')
      return NextResponse.json({
        users: [],
        total: 0,
        limit,
        offset
      } as SearchUsersResponse)
    }

    // Get user IDs to fetch emails and subscriptions
    const userIds = users.map(u => u.id)

    // Fetch emails from auth.users using admin API
    let emailsMap: Record<string, string> = {}
    try {
      const { data: authData } = await supabaseAdmin.auth.admin.listUsers()
      emailsMap = Object.fromEntries(
        authData.users
          .filter(u => userIds.includes(u.id))
          .map(u => [u.id, u.email || ''])
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

    // Fetch admin status for users (to display "Premium (Admin)" for admins without subscriptions)
    const { data: userProfiles } = await supabaseAdmin
      .from('user_profiles')
      .select('id, is_admin')
      .in('id', userIds)

    const adminUsersMap: Record<string, boolean> = Object.fromEntries(
      (userProfiles || []).map(p => [p.id, p.is_admin || false])
    )

    // Combine users with their emails and subscriptions
    const usersWithSubscriptions = users.map(user => {
      const userEmail = emailsMap[user.id] || null
      const fullName = [user.first_name, user.last_name].filter(Boolean).join(' ') || 'Unknown'
      const isAdmin = adminUsersMap[user.id] || false

      // Map subscriptions to match frontend expectations
      let userSubscriptions = subscriptions
        ?.filter(s => s.user_id === user.id)
        .map(sub => ({
          id: sub.id,
          user_id: sub.user_id,
          tier: sub.subscription_plans?.plan_code, // Get plan_code from JOIN
          subscription_plan: sub.subscription_plans?.plan_code, // Use plan_code from JOIN
          plan_type: sub.plan_type,
          status: sub.status,
          start_date: sub.current_period_start, // Map current_period_start to start_date
          end_date: sub.current_period_end, // Map current_period_end to end_date
          current_period_start: sub.current_period_start,
          current_period_end: sub.current_period_end,
          subscription_plans: sub.subscription_plans ? {
            plan_name: sub.subscription_plans.plan_name,
            plan_code: sub.subscription_plans.plan_code,
            tier: sub.subscription_plans.tier,
            price_inr: 0, // Not available in new schema
            billing_cycle: 'monthly' // Default value
          } : null
        })) || []

      // For admin users WITHOUT a subscription, create a virtual "Premium (Admin)" subscription
      if (isAdmin && userSubscriptions.length === 0) {
        userSubscriptions = [{
          id: `admin-${user.id}`,
          user_id: user.id,
          tier: 'premium',
          subscription_plan: 'premium', // Frontend compatibility
          plan_type: 'premium_admin',
          status: 'active',
          start_date: user.created_at,
          end_date: null, // Admins have unlimited access
          current_period_start: user.created_at,
          current_period_end: null,
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
        id: user.id,
        email: userEmail,
        full_name: fullName,
        phone: user.phone_number,
        created_at: user.created_at,
        subscriptions: userSubscriptions,
        is_admin: isAdmin // Include admin status for reference
      }
    })

    // Get total count for pagination
    let countQuery = supabaseAdmin
      .from('user_profiles')
      .select('id', { count: 'exact', head: true })

    // Apply same search conditions if query was provided
    if (query.length > 0) {
      const countConditions: string[] = []

      if (authUserIds.length > 0) {
        countConditions.push(`id.in.(${authUserIds.join(',')})`)
      }

      countConditions.push(`first_name.ilike.%${query}%`)
      countConditions.push(`last_name.ilike.%${query}%`)
      countConditions.push(`phone_number.ilike.%${query}%`)

      if (isValidUUID(query)) {
        countConditions.push(`id.eq.${query}`)
      }

      countQuery = countQuery.or(countConditions.join(','))
    }

    const { count } = await countQuery

    console.log('[Search Users API] Success:', {
      usersFound: users.length,
      totalCount: count || 0,
      subscriptionsFound: subscriptions?.length || 0
    })

    // Return the search results
    return NextResponse.json({
      users: usersWithSubscriptions,
      total: count || 0,
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
