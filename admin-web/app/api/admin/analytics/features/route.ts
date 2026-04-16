import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch feature adoption statistics
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

    const { count: totalUsers } = await supabaseAdmin
      .from('user_profiles')
      .select('*', { count: 'exact', head: true })

    // Helper: count distinct users from fetched rows
    const countDistinctUsers = (rows: { user_id: string }[] | null) =>
      new Set((rows || []).map(r => r.user_id).filter(Boolean)).size

    // Study Guides Feature
    const { data: studyGuideData } = await supabaseAdmin
      .from('user_study_guides')
      .select('user_id')
      .gte('created_at', dateFilter.toISOString())

    const studyGuideUsers = countDistinctUsers(studyGuideData)
    const totalStudyGuides = studyGuideData?.length || 0

    // Memory Verses Feature
    const { data: memoryVerseData } = await supabaseAdmin
      .from('memory_verses')
      .select('user_id')
      .gte('created_at', dateFilter.toISOString())

    const memoryVerseUsers = countDistinctUsers(memoryVerseData)
    const totalMemoryVerses = memoryVerseData?.length || 0

    // Learning Paths Feature (all enrollments, not just recent - users enrolled earlier are still active)
    const { data: learningPathData } = await supabaseAdmin
      .from('user_learning_path_progress')
      .select('user_id, progress_percentage')

    const learningPathUsers = countDistinctUsers(learningPathData as { user_id: string }[] | null)
    const pathCompletions = learningPathData

    const avgPathCompletion = pathCompletions && pathCompletions.length > 0
      ? Math.round(pathCompletions.reduce((sum, p) => sum + (p.progress_percentage || 0), 0) / pathCompletions.length)
      : 0

    // Voice Buddy Feature
    const { data: voiceBuddyData } = await supabaseAdmin
      .from('voice_conversations')
      .select('user_id')
      .gte('created_at', dateFilter.toISOString())

    const voiceBuddyUsers = countDistinctUsers(voiceBuddyData)
    const totalVoiceConversations = voiceBuddyData?.length || 0

    // Daily Verse Feature
    const { data: dailyVerseEvents } = await supabaseAdmin
      .from('analytics_events')
      .select('user_id')
      .eq('event_type', 'daily_verse_accessed')
      .gte('created_at', dateFilter.toISOString())

    const dailyVerseUsers = countDistinctUsers(dailyVerseEvents)

    // Achievements Feature
    const { data: achievementData } = await supabaseAdmin
      .from('user_achievements')
      .select('user_id')
      .gte('unlocked_at', dateFilter.toISOString())

    const achievementUsers = countDistinctUsers(achievementData)
    const totalAchievements = achievementData?.length || 0

    // Study Modes Usage
    const { data: studyModesData } = await supabaseAdmin
      .from('user_study_guides')
      .select('study_mode')
      .gte('created_at', dateFilter.toISOString())

    const studyModeBreakdown: Record<string, number> = {}
    ;(studyModesData || []).forEach(item => {
      const mode = item.study_mode || 'standard'
      studyModeBreakdown[mode] = (studyModeBreakdown[mode] || 0) + 1
    })

    // Calculate adoption rates
    const features = [
      {
        name: 'Study Guides',
        users: studyGuideUsers || 0,
        usage_count: totalStudyGuides || 0,
        adoption_rate: totalUsers ? ((studyGuideUsers || 0) / totalUsers * 100).toFixed(1) : '0',
        category: 'core'
      },
      {
        name: 'Learning Paths',
        users: learningPathUsers || 0,
        usage_count: pathCompletions?.length || 0,
        adoption_rate: totalUsers ? ((learningPathUsers || 0) / totalUsers * 100).toFixed(1) : '0',
        avg_completion: avgPathCompletion,
        category: 'core'
      },
      {
        name: 'Memory Verses',
        users: memoryVerseUsers || 0,
        usage_count: totalMemoryVerses || 0,
        adoption_rate: totalUsers ? ((memoryVerseUsers || 0) / totalUsers * 100).toFixed(1) : '0',
        category: 'engagement'
      },
      {
        name: 'Voice Buddy',
        users: voiceBuddyUsers || 0,
        usage_count: totalVoiceConversations || 0,
        adoption_rate: totalUsers ? ((voiceBuddyUsers || 0) / totalUsers * 100).toFixed(1) : '0',
        category: 'premium'
      },
      {
        name: 'Daily Verse',
        users: dailyVerseUsers,
        usage_count: dailyVerseEvents?.length || 0,
        adoption_rate: totalUsers ? (dailyVerseUsers / totalUsers * 100).toFixed(1) : '0',
        category: 'engagement'
      },
      {
        name: 'Achievements',
        users: achievementUsers || 0,
        usage_count: totalAchievements || 0,
        adoption_rate: totalUsers ? ((achievementUsers || 0) / totalUsers * 100).toFixed(1) : '0',
        category: 'gamification'
      }
    ].sort((a, b) => parseFloat(b.adoption_rate) - parseFloat(a.adoption_rate))

    return NextResponse.json({
      features,
      study_modes: studyModeBreakdown,
      total_users: totalUsers || 0
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
