import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET /api/admin/system-config/memory-verses
 * Fetch all memory verse related system configuration
 */
export async function GET(request: NextRequest) {
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

    // Fetch all memory verse config entries
    const { data: configData, error: configError } = await supabaseAdmin
      .from('system_config')
      .select('key, value, description, is_active, metadata')
      .or(
        'key.like.%practice_unlock_limit%,' +
          'key.like.%memory_verses_limit%,' +
          'key.like.%available_practice_modes%,' +
          'key.like.memory_verse_%'
      )
      .order('key')

    if (configError) {
      console.error('Error fetching memory verse config:', configError)
      return NextResponse.json(
        { error: 'Failed to fetch configuration' },
        { status: 500 }
      )
    }

    // Organize by category
    const organized = {
      unlockLimits: {} as Record<string, any>,
      verseLimits: {} as Record<string, any>,
      practiceModes: {} as Record<string, any>,
      spacedRepetition: {} as Record<string, any>,
      gamification: {} as Record<string, any>,
    }

    configData?.forEach((item) => {
      if (item.key.includes('practice_unlock_limit')) {
        organized.unlockLimits[item.key] = item
      } else if (item.key.includes('memory_verses_limit')) {
        organized.verseLimits[item.key] = item
      } else if (item.key.includes('available_practice_modes')) {
        organized.practiceModes[item.key] = item
      } else if (item.key.startsWith('memory_verse_') && item.key.includes('ease') || item.key.includes('interval')) {
        organized.spacedRepetition[item.key] = item
      } else if (item.key.startsWith('memory_verse_') && (item.key.includes('xp') || item.key.includes('mastery'))) {
        organized.gamification[item.key] = item
      }
    })

    return NextResponse.json({
      success: true,
      data: organized,
    })
  } catch (error) {
    console.error('GET /api/admin/system-config/memory-verses error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * POST /api/admin/system-config/memory-verses
 * Update multiple memory verse configuration entries
 */
export async function POST(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser()

    if (authError || !user) {
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
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const body = await request.json()
    const { updates } = body

    if (!updates || !Array.isArray(updates)) {
      return NextResponse.json(
        { error: 'Invalid request body' },
        { status: 400 }
      )
    }

    // Update each config entry
    const updatePromises = updates.map(async (update: { key: string; value: string }) => {
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

      // Log admin action
      await supabaseAdmin.from('admin_actions').insert({
        admin_user_id: user.id,
        action_type: 'update_memory_verse_config',
        target_user_id: null,
        details: {
          config_key: update.key,
          new_value: update.value,
          admin_user_id: user.id,
        },
      })

      return { key: update.key, success: true }
    })

    const results = await Promise.all(updatePromises)

    return NextResponse.json({
      success: true,
      data: results,
    })
  } catch (error) {
    console.error('POST /api/admin/system-config/memory-verses error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
