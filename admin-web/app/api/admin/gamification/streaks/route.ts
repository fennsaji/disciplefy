import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

// Valid columns for ordering user_study_streaks — prevents invalid sort param from reaching DB
const VALID_SORT_COLUMNS = ['current_streak', 'longest_streak', 'last_study_date', 'total_study_days']

/**
 * GET - Fetch streak analytics
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawSortBy = searchParams.get('sort_by') || 'current_streak'
    const sortBy = VALID_SORT_COLUMNS.includes(rawSortBy) ? rawSortBy : 'current_streak'
    const limit = parseInt(searchParams.get('limit') || '100')

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

    // Fetch all data sources in parallel
    const [
      { data: studyStreaks, error: studyStreaksError },
      { data: verseStreaks },
      { data: xpRows },
      { data: achievementXpRows },
      { data: allProfiles },
    ] = await Promise.all([
      supabaseAdmin
        .from('user_study_streaks')
        .select('*')
        .order(sortBy, { ascending: false })
        .limit(limit),
      supabaseAdmin
        .from('daily_verse_streaks')
        .select('user_id, current_streak, longest_streak, last_viewed_at, total_views'),
      // Study XP from user_topic_progress
      supabaseAdmin
        .from('user_topic_progress')
        .select('user_id, xp_earned'),
      // Achievement XP: join user_achievements with achievements to get xp_reward per unlock
      supabaseAdmin
        .from('user_achievements')
        .select('user_id, achievements(xp_reward)'),
      // All registered users for total count and profile lookup
      supabaseAdmin
        .from('user_profiles')
        .select('id, first_name, last_name'),
    ])

    if (studyStreaksError) {
      console.error('Failed to fetch streaks:', studyStreaksError)
      return NextResponse.json(
        { error: 'Failed to fetch streaks' },
        { status: 500 }
      )
    }

    // Aggregate XP per user: study XP (user_topic_progress) + achievement XP (user_achievements)
    const xpByUser: Record<string, number> = {}
    for (const row of xpRows || []) {
      xpByUser[row.user_id] = (xpByUser[row.user_id] || 0) + (row.xp_earned || 0)
    }
    for (const row of achievementXpRows || []) {
      const xp = Array.isArray(row.achievements)
        ? row.achievements[0]?.xp_reward ?? 0
        : (row.achievements as any)?.xp_reward ?? 0
      xpByUser[row.user_id] = (xpByUser[row.user_id] || 0) + xp
    }

    // Map daily verse streaks by user_id for quick lookup
    const verseStreakByUser: Record<string, { user_id: string; current_streak: number; longest_streak: number; last_viewed_at: string | null; total_views: number }> = {}
    for (const vs of verseStreaks || []) {
      verseStreakByUser[vs.user_id] = vs
    }

    // Build profile lookup map (covers all registered users)
    const profilesMap = Object.fromEntries(
      (allProfiles || []).map(p => [p.id, p])
    )

    // Collect ALL unique user IDs across all data sources for email lookup
    const studyUserIds = (studyStreaks || []).map(s => s.user_id)
    const verseUserIds = (verseStreaks || []).map(vs => vs.user_id)
    const xpUserIds = Object.keys(xpByUser)
    const allUserIds = [...new Set([...studyUserIds, ...verseUserIds, ...xpUserIds])]

    // Fetch emails — auth admin API required (service role bypasses RLS)
    const { data: authData } = await supabaseAdmin.auth.admin.listUsers()
    const emailsMap = Object.fromEntries(
      authData.users
        .filter(u => allUserIds.includes(u.id))
        .map(u => [u.id, u.email || ''])
    )

    const getUserName = (userId: string) => {
      const p = profilesMap[userId]
      return p ? `${p.first_name || ''} ${p.last_name || ''}`.trim() || 'N/A' : 'N/A'
    }

    // Combine study streak rows with user details, XP, and daily verse streak
    const streaksWithUserDetails = (studyStreaks || []).map(streak => ({
      ...streak,
      user_email: emailsMap[streak.user_id] || 'N/A',
      user_name: getUserName(streak.user_id),
      total_xp_earned: xpByUser[streak.user_id] || 0,
      verse_streak: verseStreakByUser[streak.user_id]?.current_streak || 0,
    }))

    // Active = studied today or yesterday; >= 2 days = streak is broken
    const now = new Date()
    const isActive = (lastStudyDate: string | null) => {
      if (!lastStudyDate) return false
      const daysDiff = Math.floor((now.getTime() - new Date(lastStudyDate).getTime()) / (1000 * 60 * 60 * 24))
      return daysDiff <= 1
    }

    const activeStreaks = streaksWithUserDetails.filter(s => isActive(s.last_study_date))

    // Daily verse streak summary stats
    const verseStreakList = verseStreaks || []
    const activeVerseStreaks = verseStreakList.filter(vs => {
      if (!vs.last_viewed_at) return false
      const daysDiff = Math.floor((now.getTime() - new Date(vs.last_viewed_at).getTime()) / (1000 * 60 * 60 * 24))
      return daysDiff <= 1
    })

    const stats = {
      // Total registered users (not just those with streak records)
      total_users: (allProfiles || []).length,
      // Study streak counts
      active_streakers: activeStreaks.length,
      inactive_streakers: streaksWithUserDetails.length - activeStreaks.length,
      users_with_study_streak: streaksWithUserDetails.length,
      // Daily verse streak counts
      users_with_verse_streak: verseStreakList.length,
      active_verse_streakers: activeVerseStreaks.length,
      // Study streak averages/records
      avg_current_streak: streaksWithUserDetails.length > 0
        ? Math.round(streaksWithUserDetails.reduce((sum, s) => sum + (s.current_streak || 0), 0) / streaksWithUserDetails.length)
        : 0,
      avg_longest_streak: streaksWithUserDetails.length > 0
        ? Math.round(streaksWithUserDetails.reduce((sum, s) => sum + (s.longest_streak || 0), 0) / streaksWithUserDetails.length)
        : 0,
      max_current_streak: streaksWithUserDetails.length > 0
        ? Math.max(...streaksWithUserDetails.map(s => s.current_streak || 0))
        : 0,
      max_longest_streak: streaksWithUserDetails.length > 0
        ? Math.max(...streaksWithUserDetails.map(s => s.longest_streak || 0))
        : 0,
      // XP from user_topic_progress (actual source)
      total_xp_earned: Object.values(xpByUser).reduce((sum, xp) => sum + xp, 0),
      streak_distribution: {
        '0 days': 0,
        '1-7 days': 0,
        '8-30 days': 0,
        '31-100 days': 0,
        '100+ days': 0,
      },
    }

    // Streak distribution buckets (by current study streak)
    streaksWithUserDetails.forEach(s => {
      const current = s.current_streak || 0
      if (current === 0) stats.streak_distribution['0 days']++
      else if (current <= 7) stats.streak_distribution['1-7 days']++
      else if (current <= 30) stats.streak_distribution['8-30 days']++
      else if (current <= 100) stats.streak_distribution['31-100 days']++
      else stats.streak_distribution['100+ days']++
    })

    // Top streak leaderboards (from user_study_streaks)
    const topCurrentStreaks = [...streaksWithUserDetails]
      .sort((a, b) => (b.current_streak || 0) - (a.current_streak || 0))
      .slice(0, 10)

    const topLongestStreaks = [...streaksWithUserDetails]
      .sort((a, b) => (b.longest_streak || 0) - (a.longest_streak || 0))
      .slice(0, 10)

    // Top XP leaderboard — all users with any XP, not only those with streak records
    const topXpEarners = xpUserIds
      .map(userId => ({
        id: userId,
        user_id: userId,
        user_name: getUserName(userId),
        user_email: emailsMap[userId] || 'N/A',
        total_xp_earned: xpByUser[userId] || 0,
      }))
      .sort((a, b) => b.total_xp_earned - a.total_xp_earned)
      .slice(0, 10)

    // Top daily verse streak leaderboard
    const topVerseStreaks = [...verseStreakList]
      .sort((a, b) => (b.current_streak || 0) - (a.current_streak || 0))
      .slice(0, 10)
      .map(vs => ({
        ...vs,
        user_name: getUserName(vs.user_id),
        user_email: emailsMap[vs.user_id] || 'N/A',
      }))

    return NextResponse.json({
      streaks: streaksWithUserDetails,
      stats,
      leaderboards: {
        top_current_streaks: topCurrentStreaks,
        top_longest_streaks: topLongestStreaks,
        top_xp_earners: topXpEarners,
        top_verse_streaks: topVerseStreaks,
      }
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
