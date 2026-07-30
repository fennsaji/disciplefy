import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'

/**
 * GET - Fetch LLM security events with optional filtering
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const eventType = searchParams.get('event_type') || ''
    const minRiskScore = searchParams.get('min_risk_score') || ''
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

    // Filters are applied in SQL so the page, the counts and the stats all
    // describe the same row set — the UI never re-filters a truncated list.
    const applyFilters = (q: any) => {
      q = q.gte('created_at', dateFilter.toISOString())
      if (eventType) q = q.eq('event_type', eventType)
      if (minRiskScore) q = q.gte('risk_score', parseFloat(minRiskScore))
      return q
    }

    const [eventsRes, totalRes, highRiskRes, blockedRes, userIdRows] = await Promise.all([
      applyFilters(supabaseAdmin.from('llm_security_events').select('*'))
        .order('created_at', { ascending: false })
        .order('id', { ascending: true })
        .range(offset, offset + limit - 1),
      applyFilters(supabaseAdmin.from('llm_security_events').select('id', { count: 'exact', head: true })),
      applyFilters(
        supabaseAdmin.from('llm_security_events').select('id', { count: 'exact', head: true })
      ).gte('risk_score', 0.7),
      applyFilters(
        supabaseAdmin.from('llm_security_events').select('id', { count: 'exact', head: true })
      ).eq('action_taken', 'blocked'),
      // Distinct users needs the actual ids, so page past the 1000-row cap
      fetchAllRows<{ user_id: string | null }>((from, to) =>
        applyFilters(supabaseAdmin.from('llm_security_events').select('user_id'))
          .not('user_id', 'is', null)
          .order('user_id', { ascending: true })
          .range(from, to)
      ),
    ])

    const { data: events, error: eventsError } = eventsRes

    if (eventsError) {
      console.error('Failed to fetch security events:', eventsError)
      return NextResponse.json(
        { error: 'Failed to fetch security events' },
        { status: 500 }
      )
    }

    const stats = {
      total: totalRes.count || 0,
      high_risk: highRiskRes.count || 0,
      blocked: blockedRes.count || 0,
      unique_users: new Set((userIdRows.data || []).map(r => r.user_id).filter(Boolean)).size,
    }

    if (!events || events.length === 0) {
      return NextResponse.json({ events: [], total: stats.total, limit, offset, stats })
    }

    // Extract unique user IDs
    const userIds = [...new Set(events.map((e: any) => e.user_id).filter(Boolean))] as string[]

    // Fetch emails from auth.users (paginated past the admin API's page limit)
    let emailsMap: Record<string, string> = {}
    try {
      emailsMap = await getAuthEmailMap(supabaseAdmin, userIds)
    } catch (authError) {
      console.error('Failed to fetch auth users:', authError)
    }

    // Format response
    const formattedEvents = events.map((event: any) => ({
      id: event.id,
      user_id: event.user_id,
      user_email: event.user_id ? emailsMap[event.user_id] || 'Unknown' : 'Anonymous',
      session_id: event.session_id,
      ip_address: event.ip_address,
      event_type: event.event_type,
      input_text: event.input_text,
      risk_score: event.risk_score,
      action_taken: event.action_taken,
      detection_details: event.detection_details,
      created_at: event.created_at
    }))

    return NextResponse.json({
      events: formattedEvents,
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
