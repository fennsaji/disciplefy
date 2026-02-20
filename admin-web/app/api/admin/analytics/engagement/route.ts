import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch user engagement metrics
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const range = searchParams.get('range') || 'month'

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

    // Calculate date filter
    let dateFilter: Date
    const now = new Date()

    switch (range) {
      case 'week':
        dateFilter = new Date()
        dateFilter.setDate(now.getDate() - 7)
        break
      case 'month':
        dateFilter = new Date()
        dateFilter.setMonth(now.getMonth() - 1)
        break
      case 'quarter':
        dateFilter = new Date()
        dateFilter.setMonth(now.getMonth() - 3)
        break
      default:
        dateFilter = new Date()
        dateFilter.setMonth(now.getMonth() - 1)
    }

    // Fetch total users
    const { count: totalUsers } = await supabaseAdmin
      .from('user_profiles')
      .select('*', { count: 'exact', head: true })

    // Fetch active users (users who generated events in the time range)
    const { data: activeUsersData } = await supabaseAdmin
      .from('analytics_events')
      .select('user_id')
      .gte('created_at', dateFilter.toISOString())

    const activeUsers = new Set(
      (activeUsersData || []).map(e => e.user_id).filter(Boolean)
    ).size

    // Fetch study streaks data
    const { data: streaksData } = await supabaseAdmin
      .from('user_study_streaks')
      .select('current_streak, longest_streak, last_study_date')

    const avgCurrentStreak = streaksData && streaksData.length > 0
      ? Math.round(streaksData.reduce((sum, s) => sum + (s.current_streak || 0), 0) / streaksData.length)
      : 0

    const avgLongestStreak = streaksData && streaksData.length > 0
      ? Math.round(streaksData.reduce((sum, s) => sum + (s.longest_streak || 0), 0) / streaksData.length)
      : 0

    // Fetch completed topics
    const { data: topicsData } = await supabaseAdmin
      .from('user_topic_progress')
      .select('status, completed_at')
      .eq('status', 'completed')
      .gte('completed_at', dateFilter.toISOString())

    const completedTopics = topicsData?.length || 0

    // Fetch learning path enrollments
    const { data: enrollmentsData } = await supabaseAdmin
      .from('user_learning_path_progress')
      .select('progress_percentage, enrolled_at')
      .gte('enrolled_at', dateFilter.toISOString())

    const newEnrollments = enrollmentsData?.length || 0
    const avgPathProgress = enrollmentsData && enrollmentsData.length > 0
      ? Math.round(enrollmentsData.reduce((sum, e) => sum + (e.progress_percentage || 0), 0) / enrollmentsData.length)
      : 0

    // Fetch daily active users over time
    const { data: dailyEvents } = await supabaseAdmin
      .from('analytics_events')
      .select('user_id, created_at')
      .gte('created_at', dateFilter.toISOString())

    const dailyActiveUsers: Record<string, Set<string>> = {}
    ;(dailyEvents || []).forEach(event => {
      if (!event.user_id) return
      const date = new Date(event.created_at).toLocaleDateString()
      if (!dailyActiveUsers[date]) {
        dailyActiveUsers[date] = new Set()
      }
      dailyActiveUsers[date].add(event.user_id)
    })

    const dauTimeline = Object.entries(dailyActiveUsers)
      .map(([date, users]) => ({
        date,
        active_users: users.size
      }))
      .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())

    // Fetch user retention (users who studied on multiple days)
    const userActivityDays: Record<string, Set<string>> = {}
    ;(dailyEvents || []).forEach(event => {
      if (!event.user_id) return
      if (!userActivityDays[event.user_id]) {
        userActivityDays[event.user_id] = new Set()
      }
      const date = new Date(event.created_at).toLocaleDateString()
      userActivityDays[event.user_id].add(date)
    })

    const retentionData = {
      '1_day': 0,
      '3_days': 0,
      '7_days': 0,
      '14_days': 0
    }

    Object.values(userActivityDays).forEach(days => {
      const dayCount = days.size
      if (dayCount >= 1) retentionData['1_day']++
      if (dayCount >= 3) retentionData['3_days']++
      if (dayCount >= 7) retentionData['7_days']++
      if (dayCount >= 14) retentionData['14_days']++
    })

    return NextResponse.json({
      overview: {
        total_users: totalUsers || 0,
        active_users: activeUsers,
        engagement_rate: totalUsers ? ((activeUsers / totalUsers) * 100).toFixed(1) : '0',
        avg_current_streak: avgCurrentStreak,
        avg_longest_streak: avgLongestStreak,
        completed_topics: completedTopics,
        new_enrollments: newEnrollments,
        avg_path_progress: avgPathProgress
      },
      daily_active_users: dauTimeline,
      retention: retentionData
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
