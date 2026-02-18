import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch token usage history with filtering options
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const range = searchParams.get('range') || 'today'
    const feature = searchParams.get('feature') || ''
    const search = searchParams.get('search') || ''

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

    // Calculate date filter based on range
    let dateFilter: Date
    const now = new Date()

    switch (range) {
      case 'today':
        dateFilter = new Date()
        dateFilter.setHours(0, 0, 0, 0)
        break
      case 'week':
        dateFilter = new Date()
        dateFilter.setDate(now.getDate() - 7)
        dateFilter.setHours(0, 0, 0, 0)
        break
      case 'month':
        dateFilter = new Date()
        dateFilter.setMonth(now.getMonth() - 1)
        dateFilter.setHours(0, 0, 0, 0)
        break
      case 'all':
      default:
        dateFilter = new Date(0) // Epoch
        break
    }

    // Fetch usage history without joins
    let query = supabaseAdmin
      .from('token_usage_history')
      .select('*')
      .gte('created_at', dateFilter.toISOString())

    // Apply feature filter
    if (feature) {
      query = query.eq('feature_name', feature)
    }

    // Execute query with ordering and limit
    const { data: usageHistory, error: historyError } = await query
      .order('created_at', { ascending: false })
      .limit(500)

    if (historyError) {
      console.error('Failed to fetch usage history:', historyError)
      return NextResponse.json(
        { error: 'Failed to fetch usage history' },
        { status: 500 }
      )
    }

    if (!usageHistory || usageHistory.length === 0) {
      return NextResponse.json({
        usage_history: [],
        summary: {
          total_entries: 0,
          total_tokens: 0
        }
      })
    }

    // Extract unique user IDs
    const userIds = [...new Set(usageHistory.map(h => h.user_id))]

    // Fetch emails from auth.users
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.listUsers()
    if (authError) {
      console.error('Failed to fetch auth users:', authError)
      return NextResponse.json(
        { error: 'Failed to fetch user emails' },
        { status: 500 }
      )
    }

    const emailsMap = Object.fromEntries(
      authData.users
        .filter(u => userIds.includes(u.id))
        .map(u => [u.id, u.email || ''])
    )

    // Fetch user profiles for names
    const { data: userProfiles, error: profilesError } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name')
      .in('id', userIds)

    if (profilesError) {
      console.error('Failed to fetch user profiles:', profilesError)
    }

    const profilesMap = Object.fromEntries(
      (userProfiles || []).map(p => [
        p.id,
        [p.first_name, p.last_name].filter(Boolean).join(' ') || 'Unknown',
      ])
    )

    // Apply search filter manually (user email)
    let filteredHistory = usageHistory
    if (search) {
      const searchLower = search.toLowerCase()
      filteredHistory = usageHistory.filter(h =>
        emailsMap[h.user_id]?.toLowerCase().includes(searchLower)
      )
    }

    // Format response
    const formattedHistory = filteredHistory.map(record => ({
      id: record.id,
      user_id: record.user_id,
      user_email: emailsMap[record.user_id] || null,
      user_name: profilesMap[record.user_id] || null,
      feature_name: record.feature_name,
      token_cost: record.token_cost,
      source_type: record.source_type,
      created_at: record.created_at,
      study_mode: record.study_mode,
      language: record.language,
      context: record.context
    }))

    // Calculate summary
    const totalTokens = formattedHistory.reduce((sum, record) => sum + (record.token_cost || 0), 0)

    return NextResponse.json({
      usage_history: formattedHistory,
      summary: {
        total_entries: formattedHistory.length,
        total_tokens: totalTokens
      }
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
