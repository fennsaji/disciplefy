import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch user feedback with optional filtering
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const category = searchParams.get('category') || ''
    const helpful = searchParams.get('helpful') || ''

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

    // Fetch feedback without joins
    let query = supabaseAdmin
      .from('feedback')
      .select('*')

    // Apply category filter
    if (category) {
      query = query.eq('category', category)
    }

    // Apply helpful filter
    if (helpful === 'true') {
      query = query.eq('was_helpful', true)
    } else if (helpful === 'false') {
      query = query.eq('was_helpful', false)
    }

    // Execute query with ordering
    const { data: feedbackList, error: feedbackError } = await query
      .order('created_at', { ascending: false })
      .limit(500)

    if (feedbackError) {
      console.error('Failed to fetch feedback:', feedbackError)
      return NextResponse.json(
        { error: 'Failed to fetch feedback' },
        { status: 500 }
      )
    }

    if (!feedbackList || feedbackList.length === 0) {
      return NextResponse.json([])
    }

    // Extract unique user IDs
    const userIds = [...new Set(feedbackList.map(f => f.user_id).filter(Boolean))]

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

    // Format response
    const formattedFeedback = feedbackList.map(feedback => ({
      id: feedback.id,
      user_id: feedback.user_id,
      user_email: feedback.user_id ? emailsMap[feedback.user_id] || null : 'Anonymous',
      user_name: feedback.user_id ? profilesMap[feedback.user_id] || null : 'Anonymous',
      was_helpful: feedback.was_helpful,
      message: feedback.message,
      category: feedback.category,
      sentiment_score: feedback.sentiment_score,
      context_type: feedback.context_type,
      context_id: feedback.context_id,
      created_at: feedback.created_at
    }))

    return NextResponse.json(formattedFeedback)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
