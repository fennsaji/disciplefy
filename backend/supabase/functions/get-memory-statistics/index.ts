/**
 * Get Memory Statistics Edge Function
 * 
 * Returns comprehensive memory verse statistics for the user:
 * - Activity heat map data (12 weeks of practice)
 * - Current and longest streaks
 * - Mastery level distribution (Beginner → Master)
 * - Practice mode statistics (success rates, counts)
 * - Overall statistics (total verses, reviews, perfect recalls, practice days)
 * 
 * Features:
 * - Complete statistics dashboard data
 * - Heat map calendar data for 12-week visualization
 * - Real-time metrics calculation
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Activity data for heat map (date → review count)
 */
interface ActivityData {
  [date: string]: number // YYYY-MM-DD → count of reviews
}

/**
 * Mastery distribution counts
 */
interface MasteryDistribution {
  beginner: number
  intermediate: number
  advanced: number
  expert: number
  master: number
}

/**
 * Practice mode statistics
 */
interface PracticeModeStats {
  readonly mode_type: string
  readonly times_practiced: number
  readonly success_rate: number // 0-100
  readonly average_time_seconds: number | null
}

/**
 * Complete statistics response
 */
interface MemoryStatistics {
  readonly activity_data: ActivityData
  readonly current_streak: number
  readonly longest_streak: number
  readonly total_practice_days: number
  readonly mastery_distribution: MasteryDistribution
  readonly practice_modes: readonly PracticeModeStats[]
  readonly total_verses: number
  readonly total_reviews: number
  readonly perfect_recalls: number // quality = 5
}

/**
 * Response data structure
 */
interface StatisticsData {
  readonly statistics: MemoryStatistics
}

/**
 * API response structure
 */
interface StatisticsResponse extends ApiSuccessResponse<StatisticsData> {}

/**
 * Get activity data for heat map (last 12 weeks)
 */
async function getActivityData(
  supabaseClient: SupabaseClient,
  userId: string
): Promise<ActivityData> {
  
  // Calculate date 12 weeks ago
  const now = new Date()
  const twelveWeeksAgo = new Date(now)
  twelveWeeksAgo.setDate(twelveWeeksAgo.getDate() - (12 * 7))
  const fromDate = twelveWeeksAgo.toISOString().split('T')[0] // YYYY-MM-DD

  // Fetch review sessions for the last 12 weeks
  const { data: sessions, error } = await supabaseClient
    .from('review_sessions')
    .select('review_date')
    .eq('user_id', userId)
    .gte('review_date', `${fromDate}T00:00:00.000Z`)
    .order('review_date', { ascending: true })

  if (error) {
    console.error('[Statistics] Activity data fetch error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch activity data', 500)
  }

  // Group by date and count reviews
  const activityMap: ActivityData = {}

  if (sessions && sessions.length > 0) {
    for (const session of sessions) {
      const date = session.review_date.split('T')[0] // Extract YYYY-MM-DD
      activityMap[date] = (activityMap[date] || 0) + 1
    }
  }

  return activityMap
}

/**
 * Get streak data from the memory_verse_streaks table via RPC (single source of truth)
 */
async function getStreakData(
  supabaseClient: SupabaseClient,
  userId: string
): Promise<{ current_streak: number; longest_streak: number; total_practice_days: number }> {

  const { data, error } = await supabaseClient
    .rpc('get_or_create_memory_streak', { p_user_id: userId })
    .single()

  if (error) {
    console.error('[Statistics] Streak RPC error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch streak data', 500)
  }

  return {
    current_streak: (data as { out_current_streak: number }).out_current_streak ?? 0,
    longest_streak: (data as { out_longest_streak: number }).out_longest_streak ?? 0,
    total_practice_days: (data as { out_total_practice_days: number }).out_total_practice_days ?? 0,
  }
}

/**
 * Get mastery distribution using actual mastery_level column
 */
async function getMasteryDistribution(
  supabaseClient: SupabaseClient,
  userId: string
): Promise<MasteryDistribution> {

  // Fetch actual mastery_level from memory_verses (set by submit-memory-practice)
  const { data: verses, error } = await supabaseClient
    .from('memory_verses')
    .select('mastery_level')
    .eq('user_id', userId)

  if (error) {
    console.error('[Statistics] Mastery distribution fetch error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch mastery distribution', 500)
  }

  const distribution: MasteryDistribution = {
    beginner: 0,
    intermediate: 0,
    advanced: 0,
    expert: 0,
    master: 0
  }

  if (verses && verses.length > 0) {
    for (const verse of verses) {
      const level = verse.mastery_level || 'beginner'

      if (level in distribution) {
        distribution[level as keyof MasteryDistribution]++
      } else {
        distribution.beginner++
      }
    }
  }

  return distribution
}

/**
 * Get practice mode statistics
 */
async function getPracticeModeStats(
  supabaseClient: SupabaseClient,
  userId: string
): Promise<PracticeModeStats[]> {
  
  // Check if the table exists first
  const { data: modes, error } = await supabaseClient
    .from('memory_practice_modes')
    .select('mode_type, times_practiced, success_rate, average_time_seconds')
    .eq('user_id', userId)
    .order('times_practiced', { ascending: false })

  if (error) {
    // If table doesn't exist yet, return empty array
    if (error.code === '42P01') { // Table does not exist
      console.log('[Statistics] memory_practice_modes table not found, returning empty stats')
      return []
    }
    console.error('[Statistics] Practice mode stats fetch error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch practice mode statistics', 500)
  }

  return modes || []
}

/**
 * Get overall statistics
 */
async function getOverallStatistics(
  supabaseClient: SupabaseClient,
  userId: string
): Promise<{
  total_verses: number
  total_reviews: number
  perfect_recalls: number
}> {
  
  // Total verses count
  const { count: totalVerses } = await supabaseClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)

  // Total reviews count
  const { count: totalReviews } = await supabaseClient
    .from('review_sessions')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)

  // Perfect recalls count (quality = 5)
  const { count: perfectRecalls } = await supabaseClient
    .from('review_sessions')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('quality_rating', 5)

  return {
    total_verses: totalVerses || 0,
    total_reviews: totalReviews || 0,
    perfect_recalls: perfectRecalls || 0
  }
}

/**
 * Main handler for fetching memory statistics
 */
async function handleGetMemoryStatistics(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to access statistics', 401)
  }

  // Fetch all statistics in parallel for better performance
  const [
    activityData,
    streakData,
    masteryDistribution,
    practiceModes,
    overallStats
  ] = await Promise.all([
    getActivityData(services.supabaseServiceClient, userContext.userId),
    getStreakData(services.supabaseServiceClient, userContext.userId),
    getMasteryDistribution(services.supabaseServiceClient, userContext.userId),
    getPracticeModeStats(services.supabaseServiceClient, userContext.userId),
    getOverallStatistics(services.supabaseServiceClient, userContext.userId)
  ])

  // Build complete statistics object
  const statistics: MemoryStatistics = {
    activity_data: activityData,
    current_streak: streakData.current_streak,
    longest_streak: streakData.longest_streak,
    total_practice_days: streakData.total_practice_days,
    mastery_distribution: masteryDistribution,
    practice_modes: practiceModes,
    total_verses: overallStats.total_verses,
    total_reviews: overallStats.total_reviews,
    perfect_recalls: overallStats.perfect_recalls
  }

  // Log analytics event
  await services.analyticsLogger.logEvent('memory_statistics_viewed', {
    user_id: userContext.userId,
    total_verses: statistics.total_verses,
    current_streak: statistics.current_streak
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const responseData: StatisticsData = {
    statistics
  }

  const response: StatisticsResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json',
      'Cache-Control': 'private, max-age=60' // Cache for 1 minute
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleGetMemoryStatistics, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 15000 // 15 seconds
})
