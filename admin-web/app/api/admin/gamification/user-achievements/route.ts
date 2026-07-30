import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'

/**
 * GET - Fetch user achievements with user details
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const userId = searchParams.get('user_id') || ''
    const achievementId = searchParams.get('achievement_id') || ''
    const limit = Math.min(Math.max(parseInt(searchParams.get('limit') || '50', 10) || 50, 1), 200)
    const offset = Math.max(parseInt(searchParams.get('offset') || '0', 10) || 0, 0)

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

    // Filters run in SQL so the page, the total and the stats describe the same
    // row set. Stats are computed over EVERY matching unlock, not the page.
    const applyFilters = (q: any) => {
      if (userId) q = q.eq('user_id', userId)
      if (achievementId) q = q.eq('achievement_id', achievementId)
      return q
    }

    const [pageRes, totalRes, allUnlocks] = await Promise.all([
      applyFilters(supabaseAdmin.from('user_achievements').select('*'))
        .order('unlocked_at', { ascending: false })
        .order('id', { ascending: true })
        .range(offset, offset + limit - 1),
      applyFilters(
        supabaseAdmin.from('user_achievements').select('id', { count: 'exact', head: true })
      ),
      fetchAllRows<{ user_id: string; achievement_id: string }>((from, to) =>
        applyFilters(supabaseAdmin.from('user_achievements').select('user_id, achievement_id'))
          .order('id', { ascending: true })
          .range(from, to)
      ),
    ])

    const { data: userAchievements, error: achievementsError } = pageRes

    if (achievementsError) {
      console.error('Failed to fetch user achievements:', achievementsError)
      return NextResponse.json(
        { error: 'Failed to fetch user achievements' },
        { status: 500 }
      )
    }

    // Get unique user IDs and achievement IDs
    const userIds = [...new Set((userAchievements || []).map((ua: any) => ua.user_id))] as string[]
    const achievementIds = [...new Set((userAchievements || []).map((ua: any) => ua.achievement_id))] as string[]

    // Fetch user emails (paginated past the admin API's page limit)
    const emailsMap = await getAuthEmailMap(supabaseAdmin, userIds)

    // Fetch user profiles for names
    const { data: userProfiles } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name')
      .in('id', userIds)

    const profilesMap = Object.fromEntries(
      (userProfiles || []).map(p => [p.id, p])
    )

    // Fetch achievement details
    const { data: achievements } = await supabaseAdmin
      .from('achievements')
      .select('*')
      .in('id', achievementIds)

    const achievementsMap = Object.fromEntries(
      (achievements || []).map(a => [a.id, a])
    )

    // Derive tier from xp_reward since the DB has no tier column
    const getTierFromXP = (xp: number): string => {
      if (xp <= 25) return 'bronze'
      if (xp <= 75) return 'silver'
      if (xp <= 200) return 'gold'
      if (xp <= 500) return 'platinum'
      return 'diamond'
    }

    // Combine data — DB uses name_en (not title) and has no tier column
    const userAchievementsWithDetails = (userAchievements || []).map((ua: any) => {
      const profile = profilesMap[ua.user_id]
      const achievement = achievementsMap[ua.achievement_id]

      return {
        ...ua,
        user_email: emailsMap[ua.user_id] || 'N/A',
        user_name: profile
          ? `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'N/A'
          : 'N/A',
        achievement_title: achievement?.name_en || 'N/A',
        achievement_category: achievement?.category || 'N/A',
        achievement_tier: achievement ? getTierFromXP(achievement.xp_reward || 0) : 'N/A',
        achievement_icon: achievement?.icon || '🏆',
        xp_reward: achievement?.xp_reward || 0,
      }
    })

    // Statistics cover every matching unlock in the database. The unlock rows
    // only carry ids, so category/tier/XP are resolved from the (small)
    // achievements table rather than from the page of rows above.
    const unlockRows = allUnlocks.data || []
    const { data: allAchievements } = await supabaseAdmin
      .from('achievements')
      .select('id, category, xp_reward')

    const achievementMetaMap: Record<string, { category: string; xp_reward: number }> =
      Object.fromEntries(
        (allAchievements || []).map((a: any) => [
          a.id,
          { category: a.category, xp_reward: a.xp_reward || 0 },
        ])
      )

    const byCategory: Record<string, number> = {}
    const byTier: Record<string, number> = {}
    let totalXpAwarded = 0

    for (const row of unlockRows) {
      const meta = achievementMetaMap[row.achievement_id]
      if (!meta) continue
      totalXpAwarded += meta.xp_reward
      if (meta.category) byCategory[meta.category] = (byCategory[meta.category] || 0) + 1
      const tier = getTierFromXP(meta.xp_reward)
      byTier[tier] = (byTier[tier] || 0) + 1
    }

    const stats = {
      total_unlocks: totalRes.count || 0,
      unique_users: new Set(unlockRows.map(r => r.user_id)).size,
      unique_achievements: new Set(unlockRows.map(r => r.achievement_id)).size,
      total_xp_awarded: totalXpAwarded,
      by_category: byCategory,
      by_tier: byTier,
    }

    return NextResponse.json({
      user_achievements: userAchievementsWithDetails,
      total: stats.total_unlocks,
      limit,
      offset,
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
 * POST - Manually grant an achievement to a user
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { user_id, achievement_id } = body

    if (!user_id || !achievement_id) {
      return NextResponse.json(
        { error: 'user_id and achievement_id are required' },
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

    // Check if already unlocked
    const { data: existing } = await supabaseAdmin
      .from('user_achievements')
      .select('id')
      .eq('user_id', user_id)
      .eq('achievement_id', achievement_id)
      .single()

    if (existing) {
      return NextResponse.json(
        { error: 'User already has this achievement' },
        { status: 400 }
      )
    }

    // Grant achievement
    const { data, error } = await supabaseAdmin
      .from('user_achievements')
      .insert({
        user_id,
        achievement_id,
        unlocked_at: new Date().toISOString()
      })
      .select()
      .single()

    if (error) {
      console.error('Failed to grant achievement:', error)
      return NextResponse.json(
        { error: 'Failed to grant achievement' },
        { status: 500 }
      )
    }

    return NextResponse.json({ user_achievement: data })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * DELETE - Revoke an achievement from a user
 */
export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json(
        { error: 'User achievement ID is required' },
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

    // Revoke achievement
    const { error } = await supabaseAdmin
      .from('user_achievements')
      .delete()
      .eq('id', id)

    if (error) {
      console.error('Failed to revoke achievement:', error)
      return NextResponse.json(
        { error: 'Failed to revoke achievement' },
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
