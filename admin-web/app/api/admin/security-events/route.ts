import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

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

    // Fetch security events
    let query = supabaseAdmin
      .from('llm_security_events')
      .select('*')
      .gte('created_at', dateFilter.toISOString())

    // Apply event type filter
    if (eventType) {
      query = query.eq('event_type', eventType)
    }

    // Apply risk score filter
    if (minRiskScore) {
      query = query.gte('risk_score', parseFloat(minRiskScore))
    }

    // Execute query with ordering
    const { data: events, error: eventsError } = await query
      .order('created_at', { ascending: false })
      .limit(500)

    if (eventsError) {
      console.error('Failed to fetch security events:', eventsError)
      return NextResponse.json(
        { error: 'Failed to fetch security events' },
        { status: 500 }
      )
    }

    if (!events || events.length === 0) {
      return NextResponse.json([])
    }

    // Extract unique user IDs
    const userIds = [...new Set(events.map(e => e.user_id).filter(Boolean))]

    // Fetch emails from auth.users
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.listUsers()
    if (authError) {
      console.error('Failed to fetch auth users:', authError)
    }

    const emailsMap = Object.fromEntries(
      (authData?.users || [])
        .filter(u => userIds.includes(u.id))
        .map(u => [u.id, u.email || ''])
    )

    // Format response
    const formattedEvents = events.map(event => ({
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

    return NextResponse.json(formattedEvents)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
