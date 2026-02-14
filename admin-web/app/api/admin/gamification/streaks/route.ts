import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch streak analytics
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const sortBy = searchParams.get('sort_by') || 'current_streak'
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

    // Fetch all user streaks
    const { data: streaks, error: streaksError } = await supabaseAdmin
      .from('user_study_streaks')
      .select('*')
      .order(sortBy, { ascending: false })
      .limit(limit)

    if (streaksError) {
      console.error('Failed to fetch streaks:', streaksError)
      return NextResponse.json(
        { error: 'Failed to fetch streaks' },
        { status: 500 }
      )
    }

    // Get unique user IDs
    const userIds = [...new Set((streaks || []).map(s => s.user_id))]

    // Fetch user details using auth.admin.listUsers() pattern
    const { data: authData } = await supabaseAdmin.auth.admin.listUsers()
    const emailsMap = Object.fromEntries(
      authData.users
        .filter(u => userIds.includes(u.id))
        .map(u => [u.id, u.email || ''])
    )

    // Fetch user profiles for names
    const { data: userProfiles } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name')
      .in('id', userIds)

    const profilesMap = Object.fromEntries(
      (userProfiles || []).map(p => [p.id, p])
    )

    // Combine data
    const streaksWithUserDetails = (streaks || []).map(streak => {
      const profile = profilesMap[streak.user_id]

      return {
        ...streak,
        user_email: emailsMap[streak.user_id] || 'N/A',
        user_name: profile
          ? `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'N/A'
          : 'N/A',
      }
    })

    // Calculate comprehensive statistics
    const now = new Date()
    const activeStreaks = streaksWithUserDetails.filter(s => {
      if (!s.last_study_date) return false
      const lastStudy = new Date(s.last_study_date)
      const daysDiff = Math.floor((now.getTime() - lastStudy.getTime()) / (1000 * 60 * 60 * 24))
      return daysDiff <= 1 // Active if studied today or yesterday
    })

    const stats = {
      total_users: streaksWithUserDetails.length,
      active_streakers: activeStreaks.length,
      inactive_streakers: streaksWithUserDetails.length - activeStreaks.length,
      avg_current_streak: streaksWithUserDetails.length > 0
        ? Math.round(streaksWithUserDetails.reduce((sum, s) => sum + (s.current_streak || 0), 0) / streaksWithUserDetails.length)
        : 0,
      avg_longest_streak: streaksWithUserDetails.length > 0
        ? Math.round(streaksWithUserDetails.reduce((sum, s) => sum + (s.longest_streak || 0), 0) / streaksWithUserDetails.length)
        : 0,
      max_current_streak: Math.max(...streaksWithUserDetails.map(s => s.current_streak || 0), 0),
      max_longest_streak: Math.max(...streaksWithUserDetails.map(s => s.longest_streak || 0), 0),
      total_xp_earned: streaksWithUserDetails.reduce((sum, s) => sum + (s.total_xp_earned || 0), 0),
      streak_distribution: {
        '0_days': 0,
        '1-7_days': 0,
        '8-30_days': 0,
        '31-100_days': 0,
        '100+_days': 0,
      },
    }

    // Calculate streak distribution
    streaksWithUserDetails.forEach(s => {
      const current = s.current_streak || 0
      if (current === 0) stats.streak_distribution['0_days']++
      else if (current <= 7) stats.streak_distribution['1-7_days']++
      else if (current <= 30) stats.streak_distribution['8-30_days']++
      else if (current <= 100) stats.streak_distribution['31-100_days']++
      else stats.streak_distribution['100+_days']++
    })

    // Top performers
    const topCurrentStreaks = [...streaksWithUserDetails]
      .sort((a, b) => (b.current_streak || 0) - (a.current_streak || 0))
      .slice(0, 10)

    const topLongestStreaks = [...streaksWithUserDetails]
      .sort((a, b) => (b.longest_streak || 0) - (a.longest_streak || 0))
      .slice(0, 10)

    const topXpEarners = [...streaksWithUserDetails]
      .sort((a, b) => (b.total_xp_earned || 0) - (a.total_xp_earned || 0))
      .slice(0, 10)

    return NextResponse.json({
      streaks: streaksWithUserDetails,
      stats,
      leaderboards: {
        top_current_streaks: topCurrentStreaks,
        top_longest_streaks: topLongestStreaks,
        top_xp_earners: topXpEarners,
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
