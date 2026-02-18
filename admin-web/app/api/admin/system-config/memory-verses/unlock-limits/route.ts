import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * POST /api/admin/system-config/memory-verses/unlock-limits
 * Update practice mode unlock limits for all tiers
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
    const { free, standard, plus, premium } = body

    // Validation
    if (
      typeof free !== 'number' ||
      typeof standard !== 'number' ||
      typeof plus !== 'number' ||
      typeof premium !== 'number'
    ) {
      return NextResponse.json(
        { error: 'All tier limits must be numbers' },
        { status: 400 }
      )
    }

    // Validate logical progression (except premium which can be unlimited)
    if (premium !== -1 && (standard < free || plus < standard || premium < plus)) {
      return NextResponse.json(
        { error: 'Limits should increase with tier (Standard ≥ Free, Plus ≥ Standard, Premium ≥ Plus)' },
        { status: 400 }
      )
    }

    // Update all unlock limits
    const updates = [
      { key: 'free_practice_unlock_limit', value: free.toString() },
      { key: 'standard_practice_unlock_limit', value: standard.toString() },
      { key: 'plus_practice_unlock_limit', value: plus.toString() },
      { key: 'premium_practice_unlock_limit', value: premium.toString() },
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
      action_type: 'update_unlock_limits',
      target_user_id: null,
      details: {
        free,
        standard,
        plus,
        premium,
        admin_user_id: user.id,
      },
    })

    return NextResponse.json({
      success: true,
      message: 'Unlock limits updated successfully',
      data: { free, standard, plus, premium },
    })
  } catch (error) {
    console.error('POST /api/admin/system-config/memory-verses/unlock-limits error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
