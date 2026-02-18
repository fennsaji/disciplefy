import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * POST /api/admin/system-config/memory-verses/practice-modes
 * Update practice mode availability for free and paid tiers
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
    const { free, paid } = body

    // Validation
    if (!Array.isArray(free) || !Array.isArray(paid)) {
      return NextResponse.json(
        { error: 'Both free and paid must be arrays of mode strings' },
        { status: 400 }
      )
    }

    if (free.length < 2) {
      return NextResponse.json(
        { error: 'Free tier should have at least 2 practice modes' },
        { status: 400 }
      )
    }

    // Validate that free modes are a subset of paid modes
    const invalidFreeModes = free.filter(mode => !paid.includes(mode))
    if (invalidFreeModes.length > 0) {
      return NextResponse.json(
        { error: 'Free tier modes must be a subset of paid tier modes' },
        { status: 400 }
      )
    }

    // Update practice mode configuration
    const updates = [
      { key: 'free_available_practice_modes', value: JSON.stringify(free) },
      { key: 'paid_available_practice_modes', value: JSON.stringify(paid) },
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
    await supabase.from('admin_actions').insert({
      admin_user_id: user.id,
      action_type: 'update_practice_modes',
      target_user_id: null,
      details: {
        free_modes: free,
        paid_modes: paid,
        admin_email: profile.email,
      },
    })

    return NextResponse.json({
      success: true,
      message: 'Practice modes updated successfully',
      data: { free, paid },
    })
  } catch (error) {
    console.error('POST /api/admin/system-config/memory-verses/practice-modes error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
