import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch feature flags from database
 */
export async function GET(request: NextRequest) {
  try {
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

    // Fetch feature flags from database
    const { data: featureFlags, error: flagsError } = await supabaseAdmin
      .from('feature_flags')
      .select('*')
      .order('feature_key', { ascending: true })

    if (flagsError) {
      console.error('[FeatureFlags API] Error fetching flags:', flagsError)
      throw flagsError
    }

    // Transform to expected format
    const transformedFlags = featureFlags.map(flag => ({
      id: flag.id,
      feature_key: flag.feature_key,
      name: flag.feature_name,
      description: flag.description,
      category: flag.metadata?.category || 'features',
      enabled: flag.is_enabled,
      enabled_for_plans: flag.enabled_for_plans || [],
      display_mode: flag.display_mode || 'hide',
      rollout_percentage: flag.rollout_percentage,
      metadata: flag.metadata
    }))

    // Calculate statistics
    const stats = {
      total_flags: transformedFlags.length,
      enabled_flags: transformedFlags.filter(f => f.enabled).length,
      disabled_flags: transformedFlags.filter(f => !f.enabled).length,
      by_category: {} as Record<string, { total: number; enabled: number }>,
    }

    transformedFlags.forEach(flag => {
      if (!stats.by_category[flag.category]) {
        stats.by_category[flag.category] = { total: 0, enabled: 0 }
      }
      stats.by_category[flag.category].total++
      if (flag.enabled) {
        stats.by_category[flag.category].enabled++
      }
    })

    return NextResponse.json({
      feature_flags: transformedFlags,
      stats
    })
  } catch (error) {
    console.error('[FeatureFlags API] GET error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * POST - Toggle feature flag enabled/disabled
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { flag_id, enabled } = body

    if (!flag_id || enabled === undefined) {
      return NextResponse.json(
        { error: 'flag_id and enabled are required' },
        { status: 400 }
      )
    }

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

    console.log('[FeatureFlags POST] Checking admin status for user:', user.id, user.email)

    const { data: profile, error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    console.log('[FeatureFlags POST] Profile query result:', { profile, profileError })

    if (!profile?.is_admin) {
      console.warn('[FeatureFlags POST] Admin check failed:', {
        hasProfile: !!profile,
        isAdmin: profile?.is_admin,
        userId: user.id
      })
      return NextResponse.json(
        { error: 'Unauthorized - Admin access required' },
        { status: 403 }
      )
    }

    // Update feature flag in database
    const { error: updateError } = await supabaseAdmin
      .from('feature_flags')
      .update({
        is_enabled: enabled,
        updated_at: new Date().toISOString(),
        updated_by: user.email
      })
      .eq('id', flag_id)

    if (updateError) {
      console.error('[FeatureFlags API] Error toggling flag:', updateError)
      throw updateError
    }

    return NextResponse.json({
      message: `Feature flag ${enabled ? 'enabled' : 'disabled'} successfully!`,
      flag_id,
      enabled
    })
  } catch (error) {
    console.error('[FeatureFlags API] POST error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PATCH - Update feature flag properties
 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      flag_id,
      feature_name,
      description,
      is_enabled,
      enabled_for_plans,
      display_mode,
      rollout_percentage
    } = body

    if (!flag_id) {
      return NextResponse.json(
        { error: 'flag_id is required' },
        { status: 400 }
      )
    }

    // Validate display_mode if provided
    if (display_mode && !['hide', 'lock'].includes(display_mode)) {
      return NextResponse.json(
        { error: 'display_mode must be "hide" or "lock"' },
        { status: 400 }
      )
    }

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

    // Build update object (only include provided fields)
    const updateData: any = {
      updated_at: new Date().toISOString(),
      updated_by: user.email  // user.email comes from auth.users, not user_profiles
    }

    if (feature_name !== undefined) updateData.feature_name = feature_name
    if (description !== undefined) updateData.description = description
    if (is_enabled !== undefined) updateData.is_enabled = is_enabled
    if (enabled_for_plans !== undefined) updateData.enabled_for_plans = enabled_for_plans
    if (display_mode !== undefined) updateData.display_mode = display_mode
    if (rollout_percentage !== undefined) updateData.rollout_percentage = rollout_percentage

    // Update feature flag in database
    const { error: updateError } = await supabaseAdmin
      .from('feature_flags')
      .update(updateData)
      .eq('id', flag_id)

    if (updateError) {
      console.error('[FeatureFlags API] Error updating flag:', updateError)
      throw updateError
    }

    return NextResponse.json({
      message: 'Feature flag updated successfully!',
      flag_id
    })
  } catch (error) {
    console.error('[FeatureFlags API] PATCH error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
