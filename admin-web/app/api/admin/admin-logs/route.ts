import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

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

    // Fetch from admin_logs table
    let logsQuery = supabaseAdmin
      .from('admin_logs')
      .select('*')
      .gte('created_at', dateFilter.toISOString())

    if (actionFilter) {
      logsQuery = logsQuery.eq('action', actionFilter)
    }

    if (adminUserId) {
      logsQuery = logsQuery.eq('admin_user_id', adminUserId)
    }

    const { data: adminLogs, error: logsError } = await logsQuery
      .order('created_at', { ascending: false })
      .limit(250)

    // Fetch from admin_actions table
    let actionsQuery = supabaseAdmin
      .from('admin_actions')
      .select('*')
      .gte('created_at', dateFilter.toISOString())

    if (actionFilter) {
      actionsQuery = actionsQuery.eq('action_type', actionFilter)
    }

    if (adminUserId) {
      actionsQuery = actionsQuery.eq('admin_user_id', adminUserId)
    }

    const { data: adminActions, error: actionsError } = await actionsQuery
      .order('created_at', { ascending: false })
      .limit(250)

    if (logsError && actionsError) {
      console.error('Failed to fetch admin logs:', logsError, actionsError)
      return NextResponse.json(
        { error: 'Failed to fetch admin logs' },
        { status: 500 }
      )
    }

    // Combine and normalize both sources
    const allLogs = [
      ...(adminLogs || []).map(log => ({
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
      ...(adminActions || []).map(action => ({
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
    ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

    if (allLogs.length === 0) {
      return NextResponse.json([])
    }

    // Extract unique admin user IDs
    const adminUserIds = [...new Set(allLogs.map(log => log.admin_user_id).filter(Boolean))]

    // Fetch admin emails
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.listUsers()
    if (authError) {
      console.error('Failed to fetch auth users:', authError)
    }

    const emailsMap = Object.fromEntries(
      (authData?.users || [])
        .filter(u => adminUserIds.includes(u.id))
        .map(u => [u.id, u.email || ''])
    )

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

    return NextResponse.json(formattedLogs.slice(0, 500))
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
