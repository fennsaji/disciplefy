import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'

/**
 * GET - Fetch admin activity logs from both admin_logs and admin_actions tables
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const actionFilter = searchParams.get('action') || ''
    const adminUserId = searchParams.get('admin_user_id') || ''
    const range = searchParams.get('range') || 'week'
    const limit = Math.min(
      Math.max(parseInt(searchParams.get('limit') || '50', 10) || 50, 1),
      200
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

    // Calculate date filter
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
        break
      case 'month':
        dateFilter = new Date()
        dateFilter.setMonth(now.getMonth() - 1)
        break
      case 'all':
      default:
        dateFilter = new Date(0)
        break
    }

    // The feed is a union of two tables. Both sides are filtered in SQL; to page
    // the merged result we over-fetch offset+limit from each side, merge, sort
    // and slice — the classic merge-paging technique for a UNION ALL feed.
    const overFetch = offset + limit

    const applyLogFilters = (q: any) => {
      q = q.gte('created_at', dateFilter.toISOString())
      if (actionFilter) q = q.eq('action', actionFilter)
      if (adminUserId) q = q.eq('admin_user_id', adminUserId)
      return q
    }

    const applyActionFilters = (q: any) => {
      q = q.gte('created_at', dateFilter.toISOString())
      if (actionFilter) q = q.eq('action_type', actionFilter)
      if (adminUserId) q = q.eq('admin_user_id', adminUserId)
      return q
    }

    // "Today" uses the same UTC day boundary as the `today` range option
    const utcDayStart = new Date()
    utcDayStart.setUTCHours(0, 0, 0, 0)

    const [
      logsRes,
      actionsRes,
      logsCountRes,
      actionsCountRes,
      logsTodayRes,
      actionsTodayRes,
      logAdminIds,
      actionAdminIds,
    ] = await Promise.all([
      applyLogFilters(supabaseAdmin.from('admin_logs').select('*'))
        .order('created_at', { ascending: false })
        .range(0, Math.max(overFetch - 1, 0)),
      applyActionFilters(supabaseAdmin.from('admin_actions').select('*'))
        .order('created_at', { ascending: false })
        .range(0, Math.max(overFetch - 1, 0)),
      applyLogFilters(supabaseAdmin.from('admin_logs').select('id', { count: 'exact', head: true })),
      applyActionFilters(supabaseAdmin.from('admin_actions').select('id', { count: 'exact', head: true })),
      applyLogFilters(
        supabaseAdmin.from('admin_logs').select('id', { count: 'exact', head: true })
      ).gte('created_at', utcDayStart.toISOString()),
      applyActionFilters(
        supabaseAdmin.from('admin_actions').select('id', { count: 'exact', head: true })
      ).gte('created_at', utcDayStart.toISOString()),
      fetchAllRows<{ admin_user_id: string | null }>((from, to) =>
        applyLogFilters(supabaseAdmin.from('admin_logs').select('admin_user_id'))
          .order('admin_user_id', { ascending: true })
          .range(from, to)
      ),
      fetchAllRows<{ admin_user_id: string | null }>((from, to) =>
        applyActionFilters(supabaseAdmin.from('admin_actions').select('admin_user_id'))
          .order('admin_user_id', { ascending: true })
          .range(from, to)
      ),
    ])

    const { data: adminLogs, error: logsError } = logsRes
    const { data: adminActions, error: actionsError } = actionsRes

    if (logsError && actionsError) {
      console.error('Failed to fetch admin logs:', logsError, actionsError)
      return NextResponse.json(
        { error: 'Failed to fetch admin logs' },
        { status: 500 }
      )
    }

    // Stats counted by Postgres across BOTH tables, not from the page on screen
    const stats = {
      total: (logsCountRes.count || 0) + (actionsCountRes.count || 0),
      today: (logsTodayRes.count || 0) + (actionsTodayRes.count || 0),
      unique_admins: new Set(
        [...(logAdminIds.data || []), ...(actionAdminIds.data || [])]
          .map(r => r.admin_user_id)
          .filter(Boolean)
      ).size,
    }

    // Combine and normalize both sources
    const allLogs = [
      ...(adminLogs || []).map((log: any) => ({
        id: log.id,
        admin_user_id: log.admin_user_id,
        action: log.action,
        action_type: log.action,
        target_table: log.target_table,
        target_id: log.target_id,
        target_user_id: null,
        ip_address: log.ip_address,
        user_agent: log.user_agent,
        details: log.details,
        created_at: log.created_at,
        source: 'admin_logs'
      })),
      ...(adminActions || []).map((action: any) => ({
        id: action.id,
        admin_user_id: action.admin_user_id,
        action: action.action_type,
        action_type: action.action_type,
        target_table: null,
        target_id: null,
        target_user_id: action.target_user_id,
        ip_address: null,
        user_agent: null,
        details: action.details,
        created_at: action.created_at,
        source: 'admin_actions'
      }))
    ]
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
      .slice(offset, offset + limit)

    if (allLogs.length === 0) {
      return NextResponse.json({ logs: [], total: stats.total, limit, offset, stats })
    }

    // Extract unique admin user IDs
    const adminUserIds = [...new Set(allLogs.map(log => log.admin_user_id).filter(Boolean))]

    // Fetch admin emails (paginated past the admin API's page limit)
    let emailsMap: Record<string, string> = {}
    try {
      emailsMap = await getAuthEmailMap(supabaseAdmin, adminUserIds as string[])
    } catch (authError) {
      console.error('Failed to fetch auth users:', authError)
    }

    // Fetch admin names
    const { data: userProfiles } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name')
      .in('id', adminUserIds)

    const namesMap = Object.fromEntries(
      (userProfiles || []).map(p => [
        p.id,
        [p.first_name, p.last_name].filter(Boolean).join(' ') || 'Unknown',
      ])
    )

    // Format response
    const formattedLogs = allLogs.map(log => ({
      ...log,
      admin_email: emailsMap[log.admin_user_id] || 'Unknown',
      admin_name: namesMap[log.admin_user_id] || 'Unknown',
    }))

    return NextResponse.json({
      logs: formattedLogs,
      total: stats.total,
      limit,
      offset,
      stats
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
