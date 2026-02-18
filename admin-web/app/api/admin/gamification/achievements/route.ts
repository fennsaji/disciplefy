import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch achievements catalog
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const category = searchParams.get('category') || ''
    const type = searchParams.get('type') || ''

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

    // Fetch all achievements
    let query = supabaseAdmin
      .from('achievements')
      .select('*')
      .order('category', { ascending: true })
      .order('tier', { ascending: true })

    if (category) {
      query = query.eq('category', category)
    }
    if (type) {
      query = query.eq('type', type)
    }

    const { data: achievements, error: achievementsError } = await query

    if (achievementsError) {
      console.error('Failed to fetch achievements:', achievementsError)
      return NextResponse.json(
        { error: 'Failed to fetch achievements' },
        { status: 500 }
      )
    }

    // Get unlock statistics for each achievement
    const { data: userAchievements } = await supabaseAdmin
      .from('user_achievements')
      .select('achievement_id, user_id')

    // Map unlock counts to achievements
    const achievementsWithStats = (achievements || []).map(achievement => {
      const unlocks = (userAchievements || []).filter(ua => ua.achievement_id === achievement.id)
      return {
        ...achievement,
        total_unlocks: unlocks.length,
        unique_users: new Set(unlocks.map(ua => ua.user_id)).size,
      }
    })

    // Calculate statistics
    const stats = {
      total: achievementsWithStats.length,
      by_category: {} as Record<string, number>,
      by_type: {} as Record<string, number>,
      by_tier: {} as Record<string, number>,
      total_unlocks: userAchievements?.length || 0,
    }

    achievementsWithStats.forEach(achievement => {
      stats.by_category[achievement.category] = (stats.by_category[achievement.category] || 0) + 1
      stats.by_type[achievement.type] = (stats.by_type[achievement.type] || 0) + 1
      stats.by_tier[achievement.tier] = (stats.by_tier[achievement.tier] || 0) + 1
    })

    return NextResponse.json({
      achievements: achievementsWithStats,
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

/**
 * POST - Create a new achievement
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      title,
      description,
      category,
      type,
      tier,
      icon,
      xp_reward,
      requirement_value
    } = body

    if (!title || !category || !type) {
      return NextResponse.json(
        { error: 'title, category, and type are required' },
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

    // Create achievement
    const { data, error } = await supabaseAdmin
      .from('achievements')
      .insert({
        title,
        description,
        category,
        type,
        tier: tier || 'bronze',
        icon: icon || '🏆',
        xp_reward: xp_reward || 0,
        requirement_value: requirement_value || 0
      })
      .select()
      .single()

    if (error) {
      console.error('Failed to create achievement:', error)
      return NextResponse.json(
        { error: 'Failed to create achievement' },
        { status: 500 }
      )
    }

    return NextResponse.json({ achievement: data })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PATCH - Update an achievement
 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json()
    const { id, ...updates } = body

    if (!id) {
      return NextResponse.json(
        { error: 'Achievement ID is required' },
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

    // Update achievement
    const { data, error } = await supabaseAdmin
      .from('achievements')
      .update(updates)
      .eq('id', id)
      .select()
      .single()

    if (error) {
      console.error('Failed to update achievement:', error)
      return NextResponse.json(
        { error: 'Failed to update achievement' },
        { status: 500 }
      )
    }

    return NextResponse.json({ achievement: data })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * DELETE - Delete an achievement
 */
export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json(
        { error: 'Achievement ID is required' },
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

    // Delete achievement
    const { error } = await supabaseAdmin
      .from('achievements')
      .delete()
      .eq('id', id)

    if (error) {
      console.error('Failed to delete achievement:', error)
      return NextResponse.json(
        { error: 'Failed to delete achievement' },
        { status: 500 }
      )
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
