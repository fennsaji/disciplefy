import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

interface UpdateIssueRequest {
  issue_id: string
  status: string
  admin_notes: string
}

/**
 * POST - Update purchase issue status and admin notes
 */
export async function POST(request: NextRequest) {
  try {
    // Parse request body
    const body: UpdateIssueRequest = await request.json()
    const { issue_id, status, admin_notes } = body

    // Validate input
    if (!issue_id || !status) {
      return NextResponse.json(
        { error: 'Missing required fields: issue_id, status' },
        { status: 400 }
      )
    }

    const validStatuses = ['pending', 'investigating', 'resolved', 'closed']
    if (!validStatuses.includes(status)) {
      return NextResponse.json(
        { error: 'Invalid status. Must be one of: pending, investigating, resolved, closed' },
        { status: 400 }
      )
    }

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

    // Fetch current issue state
    const { data: currentIssue, error: fetchError } = await supabaseAdmin
      .from('purchase_issue_reports')
      .select('id, user_id, status')
      .eq('id', issue_id)
      .single()

    if (fetchError || !currentIssue) {
      return NextResponse.json(
        { error: 'Issue not found' },
        { status: 404 }
      )
    }

    // Update issue
    const updateData: any = {
      status,
      updated_at: new Date().toISOString()
    }

    // Add admin notes if provided
    if (admin_notes) {
      updateData.admin_notes = admin_notes
    }

    // Set resolved_at timestamp if status is resolved
    if (status === 'resolved' && currentIssue.status !== 'resolved') {
      updateData.resolved_at = new Date().toISOString()
    }

    const { data: updatedIssue, error: updateError } = await supabaseAdmin
      .from('purchase_issue_reports')
      .update(updateData)
      .eq('id', issue_id)
      .select()
      .single()

    if (updateError) {
      console.error('Failed to update issue:', updateError)
      return NextResponse.json(
        { error: 'Failed to update issue' },
        { status: 500 }
      )
    }

    // Log admin action for audit trail
    const { error: logError } = await supabaseAdmin
      .from('admin_actions')
      .insert({
        admin_user_id: user.id,
        action_type: 'update_issue',
        target_user_id: currentIssue.user_id,
        details: {
          issue_id,
          previous_status: currentIssue.status,
          new_status: status,
          admin_notes: admin_notes || null
        }
      })

    if (logError) {
      console.error('Failed to log admin action:', logError)
      // Don't fail the request if logging fails
    }

    return NextResponse.json({
      success: true,
      updated_issue: updatedIssue,
      message: 'Issue updated successfully'
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
