import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch usage alerts
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const alertType = searchParams.get('alert_type') || ''
    const isActive = searchParams.get('is_active') || ''

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

    // Build query
    let query = supabaseAdmin
      .from('usage_alerts')
      .select('*')

    // Apply filters
    if (alertType) {
      query = query.eq('alert_type', alertType)
    }

    if (isActive === 'true') {
      query = query.eq('is_active', true)
    } else if (isActive === 'false') {
      query = query.eq('is_active', false)
    }

    // Execute query
    const { data: alerts, error: alertsError } = await query
      .order('created_at', { ascending: false })

    if (alertsError) {
      console.error('Failed to fetch usage alerts:', alertsError)
      return NextResponse.json(
        { error: 'Failed to fetch usage alerts' },
        { status: 500 }
      )
    }

    return NextResponse.json(alerts || [])
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * POST - Create or update usage alert
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { id, alert_type, threshold_value, notification_channel, is_active } = body

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

    if (id) {
      // Update existing alert
      const { data, error } = await supabaseAdmin
        .from('usage_alerts')
        .update({
          alert_type,
          threshold_value,
          notification_channel,
          is_active,
          updated_at: new Date().toISOString()
        })
        .eq('id', id)
        .select()
        .single()

      if (error) {
        console.error('Failed to update alert:', error)
        return NextResponse.json(
          { error: 'Failed to update alert' },
          { status: 500 }
        )
      }

      return NextResponse.json(data)
    } else {
      // Create new alert
      const { data, error } = await supabaseAdmin
        .from('usage_alerts')
        .insert({
          alert_type,
          threshold_value,
          notification_channel,
          is_active
        })
        .select()
        .single()

      if (error) {
        console.error('Failed to create alert:', error)
        return NextResponse.json(
          { error: 'Failed to create alert' },
          { status: 500 }
        )
      }

      return NextResponse.json(data)
    }
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
