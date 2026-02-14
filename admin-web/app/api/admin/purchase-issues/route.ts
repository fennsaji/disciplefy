import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch purchase issue reports with optional status filtering
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const status = searchParams.get('status') || ''

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

    // Fetch purchase issues without joins
    let query = supabaseAdmin
      .from('purchase_issue_reports')
      .select('*')

    // Apply status filter
    if (status) {
      query = query.eq('status', status)
    }

    // Execute query with ordering
    const { data: issues, error: issuesError } = await query
      .order('created_at', { ascending: false })

    if (issuesError) {
      console.error('Failed to fetch purchase issues:', issuesError)
      return NextResponse.json(
        { error: 'Failed to fetch purchase issues' },
        { status: 500 }
      )
    }

    if (!issues || issues.length === 0) {
      return NextResponse.json([])
    }

    // Extract unique user IDs
    const userIds = [...new Set(issues.map(issue => issue.user_id))]

    // Fetch emails from auth.users (same pattern as search-users API)
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
    const formattedIssues = issues.map(issue => ({
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

    return NextResponse.json(formattedIssues)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
