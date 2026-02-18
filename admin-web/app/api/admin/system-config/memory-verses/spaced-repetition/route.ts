import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * POST /api/admin/system-config/memory-verses/spaced-repetition
 * Update spaced repetition (SM-2 algorithm) parameters
 */
export async function POST(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
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

    const body = await request.json()
    const { initialEaseFactor, initialIntervalDays, minEaseFactor, maxIntervalDays } = body

    // Validation
    if (
      typeof initialEaseFactor !== 'number' ||
      typeof initialIntervalDays !== 'number' ||
      typeof minEaseFactor !== 'number' ||
      typeof maxIntervalDays !== 'number'
    ) {
      return NextResponse.json(
        { error: 'All spaced repetition parameters must be numbers' },
        { status: 400 }
      )
    }

    // Validate ranges
    if (initialEaseFactor < 1.3 || initialEaseFactor > 3.0) {
      return NextResponse.json(
        { error: 'Initial ease factor must be between 1.3 and 3.0' },
        { status: 400 }
      )
    }

    if (initialIntervalDays < 1 || initialIntervalDays > 7) {
      return NextResponse.json(
        { error: 'Initial interval must be between 1 and 7 days' },
        { status: 400 }
      )
    }

    if (minEaseFactor < 1.0 || minEaseFactor > 2.0) {
      return NextResponse.json(
        { error: 'Min ease factor must be between 1.0 and 2.0' },
        { status: 400 }
      )
    }

    if (maxIntervalDays < 30 || maxIntervalDays > 730) {
      return NextResponse.json(
        { error: 'Max interval must be between 30 and 730 days' },
        { status: 400 }
      )
    }

    // Update spaced repetition settings
    const updates = [
      { key: 'memory_verse_initial_ease_factor', value: initialEaseFactor.toString() },
      { key: 'memory_verse_initial_interval_days', value: initialIntervalDays.toString() },
      { key: 'memory_verse_min_ease_factor', value: minEaseFactor.toString() },
      { key: 'memory_verse_max_interval_days', value: maxIntervalDays.toString() },
    ]

    for (const update of updates) {
      const { error } = await supabaseAdmin
        .from('system_config')
        .update({
          value: update.value,
          updated_at: new Date().toISOString(),
        })
        .eq('key', update.key)

      if (error) {
        console.error(`Error updating ${update.key}:`, error)
        throw error
      }
    }

    // Log admin action
    await supabaseAdmin.from('admin_actions').insert({
      admin_user_id: user.id,
      action_type: 'update_spaced_repetition_settings',
      target_user_id: null,
      details: {
        initialEaseFactor,
        initialIntervalDays,
        minEaseFactor,
        maxIntervalDays,
        admin_user_id: user.id,
      },
    })

    return NextResponse.json({
      success: true,
      message: 'Spaced repetition settings updated successfully',
      data: { initialEaseFactor, initialIntervalDays, minEaseFactor, maxIntervalDays },
    })
  } catch (error) {
    console.error('POST /api/admin/system-config/memory-verses/spaced-repetition error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
