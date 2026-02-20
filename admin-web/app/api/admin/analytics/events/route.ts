import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch analytics events with aggregation and filtering
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const range = searchParams.get('range') || 'week'
    const eventType = searchParams.get('event_type') || ''
    const groupBy = searchParams.get('group_by') || 'day' // day, hour, week

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
      case 'quarter':
        dateFilter = new Date()
        dateFilter.setMonth(now.getMonth() - 3)
        break
      case 'year':
        dateFilter = new Date()
        dateFilter.setFullYear(now.getFullYear() - 1)
        break
      default:
        dateFilter = new Date()
        dateFilter.setDate(now.getDate() - 7)
    }

    // Fetch analytics events
    let query = supabaseAdmin
      .from('analytics_events')
      .select('*')
      .gte('created_at', dateFilter.toISOString())

    if (eventType) {
      query = query.eq('event_type', eventType)
    }

    const { data: events, error: eventsError } = await query
      .order('created_at', { ascending: true })

    if (eventsError) {
      console.error('Failed to fetch analytics events:', eventsError)
      return NextResponse.json(
        { error: 'Failed to fetch analytics events' },
        { status: 500 }
      )
    }

    if (!events || events.length === 0) {
      return NextResponse.json({
        events: [],
        timeline: [],
        by_type: {},
        total: 0,
        unique_users: 0,
        unique_sessions: 0
      })
    }

    // Aggregate by time
    const timeline: Record<string, number> = {}
    events.forEach(event => {
      const date = new Date(event.created_at)
      let key: string

      if (groupBy === 'hour') {
        key = `${date.toLocaleDateString()} ${date.getHours()}:00`
      } else if (groupBy === 'week') {
        const weekStart = new Date(date)
        weekStart.setDate(date.getDate() - date.getDay())
        key = weekStart.toLocaleDateString()
      } else {
        key = date.toLocaleDateString()
      }

      timeline[key] = (timeline[key] || 0) + 1
    })

    // Aggregate by event type
    const byType: Record<string, number> = {}
    events.forEach(event => {
      byType[event.event_type] = (byType[event.event_type] || 0) + 1
    })

    // Calculate metrics
    const uniqueUsers = new Set(events.map(e => e.user_id).filter(Boolean)).size
    const uniqueSessions = new Set(events.map(e => e.session_id).filter(Boolean)).size

    return NextResponse.json({
      events: events.slice(0, 100), // Return latest 100 events
      timeline: Object.entries(timeline).map(([date, count]) => ({ date, count })),
      by_type: byType,
      total: events.length,
      unique_users: uniqueUsers,
      unique_sessions: uniqueSessions
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
