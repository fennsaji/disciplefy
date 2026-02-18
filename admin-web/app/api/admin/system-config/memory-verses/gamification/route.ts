import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * POST /api/admin/system-config/memory-verses/gamification
 * Update gamification settings (XP and mastery thresholds)
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
    const { masteryThreshold, xpPerReview, xpMasteryBonus } = body

    // Validation
    if (
      typeof masteryThreshold !== 'number' ||
      typeof xpPerReview !== 'number' ||
      typeof xpMasteryBonus !== 'number'
    ) {
      return NextResponse.json(
        { error: 'All gamification values must be numbers' },
        { status: 400 }
      )
    }

    // Validate ranges
    if (masteryThreshold < 3 || masteryThreshold > 10) {
      return NextResponse.json(
        { error: 'Mastery threshold must be between 3 and 10' },
        { status: 400 }
      )
    }

    if (xpPerReview < 5 || xpPerReview > 50) {
      return NextResponse.json(
        { error: 'XP per review must be between 5 and 50' },
        { status: 400 }
      )
    }

    if (xpMasteryBonus < 25 || xpMasteryBonus > 200) {
      return NextResponse.json(
        { error: 'Mastery bonus must be between 25 and 200' },
        { status: 400 }
      )
    }

    // Update gamification settings
    const updates = [
      { key: 'memory_verse_mastery_threshold', value: masteryThreshold.toString() },
      { key: 'memory_verse_xp_per_review', value: xpPerReview.toString() },
      { key: 'memory_verse_xp_mastery_bonus', value: xpMasteryBonus.toString() },
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
      action_type: 'update_gamification_settings',
      target_user_id: null,
      details: {
        masteryThreshold,
        xpPerReview,
        xpMasteryBonus,
        admin_user_id: user.id,
      },
    })

    return NextResponse.json({
      success: true,
      message: 'Gamification settings updated successfully',
      data: { masteryThreshold, xpPerReview, xpMasteryBonus },
    })
  } catch (error) {
    console.error('POST /api/admin/system-config/memory-verses/gamification error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
