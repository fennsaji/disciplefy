import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 200

/**
 * GET - Fetch user feedback with optional filtering
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id') || ''
    const category = searchParams.get('category') || ''
    const helpful = searchParams.get('helpful') || ''
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

    // Every filter is applied in SQL, so the page, the count and the stats all
    // describe the same row set — no client-side filtering of a truncated list.
    const applyFilters = (q: any) => {
      if (id) q = q.eq('id', id) // single row, used by the detail page
      if (category) q = q.eq('category', category)
      if (helpful === 'true') q = q.eq('was_helpful', true)
      else if (helpful === 'false') q = q.eq('was_helpful', false)
      return q
    }

    const { data: feedbackRows, error: feedbackError } = await applyFilters(
      supabaseAdmin.from('feedback').select('*')
    )
      .order('created_at', { ascending: false })
      .order('id', { ascending: true })
      .range(offset, offset + limit - 1)

    if (feedbackError) {
      console.error('Failed to fetch feedback:', feedbackError)
      return NextResponse.json(
        { error: 'Failed to fetch feedback' },
        { status: 500 }
      )
    }

    // Stats are computed by Postgres over EVERY matching row, not the page
    const [totalRes, helpfulRes, notHelpfulRes, sentimentRows] = await Promise.all([
      applyFilters(supabaseAdmin.from('feedback').select('id', { count: 'exact', head: true })),
      applyFilters(supabaseAdmin.from('feedback').select('id', { count: 'exact', head: true })).eq('was_helpful', true),
      applyFilters(supabaseAdmin.from('feedback').select('id', { count: 'exact', head: true })).eq('was_helpful', false),
      fetchAllRows<{ sentiment_score: number | null }>((from, to) =>
        applyFilters(supabaseAdmin.from('feedback').select('sentiment_score'))
          .not('sentiment_score', 'is', null)
          .order('id', { ascending: true })
          .range(from, to)
      ),
    ])

    const scores = (sentimentRows.data || [])
      .map(r => r.sentiment_score)
      .filter((v): v is number => typeof v === 'number')
    const stats = {
      total: totalRes.count || 0,
      helpful: helpfulRes.count || 0,
      not_helpful: notHelpfulRes.count || 0,
      avg_sentiment: scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0,
      sentiment_sample_size: scores.length,
    }

    const feedbackList: any[] = feedbackRows || []

    if (feedbackList.length === 0) {
      return NextResponse.json({ feedback: [], total: stats.total, limit, offset, stats })
    }

    // Extract unique user IDs
    const userIds: string[] = [...new Set(feedbackList.map((f: any) => f.user_id).filter(Boolean))] as string[]

    // Fetch emails from auth.users (paginated past the admin API's page limit)
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
    const formattedFeedback = feedbackList.map((feedback: any) => ({
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

    return NextResponse.json({
      feedback: formattedFeedback,
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
