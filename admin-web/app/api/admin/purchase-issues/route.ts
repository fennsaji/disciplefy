import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'

/**
 * GET - Fetch purchase issue reports with optional status filtering
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const status = searchParams.get('status') || ''
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

    // Filter and page in SQL. Without an explicit range PostgREST silently caps
    // the response at 1000 rows, which quietly hides older issues.
    const applyFilter = (q: any) => (status ? q.eq('status', status) : q)

    const [issuesRes, countRes, statusRows] = await Promise.all([
      applyFilter(supabaseAdmin.from('purchase_issue_reports').select('*'))
        .order('created_at', { ascending: false })
        .order('id', { ascending: true })
        .range(offset, offset + limit - 1),
      applyFilter(
        supabaseAdmin.from('purchase_issue_reports').select('id', { count: 'exact', head: true })
      ),
      // Status breakdown over the whole table, independent of the status filter
      Promise.all(
        ['pending', 'investigating', 'resolved', 'closed'].map(async s => ({
          status: s,
          count:
            (
              await supabaseAdmin
                .from('purchase_issue_reports')
                .select('id', { count: 'exact', head: true })
                .eq('status', s)
            ).count || 0,
        }))
      ),
    ])

    const { data: issueRows, error: issuesError } = issuesRes

    if (issuesError) {
      console.error('Failed to fetch purchase issues:', issuesError)
      return NextResponse.json(
        { error: 'Failed to fetch purchase issues' },
        { status: 500 }
      )
    }

    const stats = {
      total: countRes.count || 0,
      by_status: Object.fromEntries(statusRows.map(r => [r.status, r.count])),
    }

    const issues: any[] = issueRows || []

    if (issues.length === 0) {
      return NextResponse.json({ issues: [], total: stats.total, limit, offset, stats })
    }

    // Extract unique user IDs
    const userIds: string[] = [...new Set(issues.map((issue: any) => issue.user_id))] as string[]

    // Fetch emails from auth.users (same pattern as search-users API)
    let emailsMap: Record<string, string>
    try {
      emailsMap = await getAuthEmailMap(supabaseAdmin, userIds)
    } catch (authError) {
      console.error('Failed to fetch auth users:', authError)
      return NextResponse.json(
        { error: 'Failed to fetch user emails' },
        { status: 500 }
      )
    }

    // Fetch user profiles for names and phone
    const { data: userProfiles, error: profilesError } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name, phone_number')
      .in('id', userIds)

    if (profilesError) {
      console.error('Failed to fetch user profiles:', profilesError)
    }

    const profilesMap = Object.fromEntries(
      (userProfiles || []).map(p => [
        p.id,
        {
          name: [p.first_name, p.last_name].filter(Boolean).join(' ') || 'Unknown',
          phone: p.phone_number || null,
        },
      ])
    )

    // Format response
    const formattedIssues = issues.map((issue: any) => ({
      id: issue.id,
      user_id: issue.user_id,
      user_email: emailsMap[issue.user_id] || null,
      user_name: profilesMap[issue.user_id]?.name || null,
      user_phone: profilesMap[issue.user_id]?.phone || null,
      issue_type: issue.issue_type,
      description: issue.description,
      payment_id: issue.payment_id,
      order_id: issue.order_id,
      receipt_data: issue.receipt_data,
      status: issue.status,
      admin_notes: issue.admin_notes,
      resolved_at: issue.resolved_at,
      created_at: issue.created_at,
      updated_at: issue.updated_at
    }))

    return NextResponse.json({
      issues: formattedIssues,
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
