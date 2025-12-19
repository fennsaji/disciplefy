/**
 * Get Memory Practice Stats Edge Function
 * 
 * Retrieves comprehensive dashboard statistics for memory verse practice:
 * - Streak data (current, longest, milestones, freeze days)
 * - Daily goal progress (today's targets and completion)
 * - Mastery distribution (count per level)
 * - Practice mode statistics (success rates, favorite modes)
 * - Recent achievements unlocked
 * - Active challenges with progress
 * - Upcoming reviews count
 * - Total verses by mastery level
 * 
 * Version: 2.4.0 - Memory Verses Enhancement
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Streak statistics
 */
interface StreakStats {
  readonly current_streak: number
  readonly longest_streak: number
  readonly last_practice_date: string | null
  readonly total_practice_days: number
  readonly freeze_days_available: number
  readonly freeze_days_used: number
  readonly milestones_reached: Array<{
    readonly days: number
    readonly reached_date: string
  }>
  readonly next_milestone: number | null
  readonly days_until_next_milestone: number | null
}

/**
 * Daily goal progress
 */
interface DailyGoalStats {
  readonly target_reviews: number
  readonly completed_reviews: number
  readonly target_new_verses: number
  readonly added_new_verses: number
  readonly goal_achieved: boolean
  readonly bonus_xp_available: number
  readonly progress_percentage: number
}

/**
 * Mastery level distribution
 */
interface MasteryDistribution {
  readonly beginner: number
  readonly intermediate: number
  readonly advanced: number
  readonly expert: number
  readonly master: number
  readonly total_verses: number
}

/**
 * Practice mode statistics
 */
interface PracticeModeStats {
  readonly mode_type: string
  readonly times_practiced: number
  readonly success_rate: number
  readonly average_time_seconds: number | null
  readonly is_favorite: boolean
  readonly is_mastered: boolean
}

/**
 * Challenge with progress
 */
interface ChallengeProgress {
  readonly challenge_id: string
  readonly challenge_type: string
  readonly target_type: string
  readonly target_value: number
  readonly current_progress: number
  readonly progress_percentage: number
  readonly xp_reward: number
  readonly badge_icon: string
  readonly time_remaining_hours: number
  readonly is_completed: boolean
  readonly is_active: boolean
}

/**
 * Response data structure
 */
interface MemoryPracticeStatsData {
  readonly streak: StreakStats
  readonly daily_goal: DailyGoalStats
  readonly mastery_distribution: MasteryDistribution
  readonly practice_modes: PracticeModeStats[]
  readonly active_challenges: ChallengeProgress[]
  readonly upcoming_reviews_count: number
  readonly total_xp_earned: number
  readonly verses_due_today: number
}

/**
 * API response structure
 */
interface MemoryPracticeStatsResponse extends ApiSuccessResponse<MemoryPracticeStatsData> {}

/**
 * Get streak statistics
 */
async function getStreakStats(
  supabaseClient: any,
  userId: string
): Promise<StreakStats> {
  
  const { data: streak } = await supabaseClient
    .from('memory_verse_streaks')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle()
  
  if (!streak) {
    // No streak yet - return defaults
    return {
      current_streak: 0,
      longest_streak: 0,
      last_practice_date: null,
      total_practice_days: 0,
      freeze_days_available: 0,
      freeze_days_used: 0,
      milestones_reached: [],
      next_milestone: 10,
      days_until_next_milestone: 10
    }
  }
  
  // Parse milestones
  const milestones = [
    { days: 10, date: streak.milestone_10_date },
    { days: 30, date: streak.milestone_30_date },
    { days: 100, date: streak.milestone_100_date },
    { days: 365, date: streak.milestone_365_date }
  ]
  
  const milestonesReached = milestones
    .filter(m => m.date !== null)
    .map(m => ({
      days: m.days,
      reached_date: m.date
    }))
  
  // Find next milestone
  const standardMilestones = [10, 30, 100, 365]
  let nextMilestone: number | null = null
  let daysUntilNext: number | null = null
  
  for (const milestone of standardMilestones) {
    if (streak.current_streak < milestone) {
      nextMilestone = milestone
      daysUntilNext = milestone - streak.current_streak
      break
    }
  }
  
  return {
    current_streak: streak.current_streak,
    longest_streak: streak.longest_streak,
    last_practice_date: streak.last_practice_date,
    total_practice_days: streak.total_practice_days,
    freeze_days_available: streak.freeze_days_available,
    freeze_days_used: streak.freeze_days_used,
    milestones_reached: milestonesReached,
    next_milestone: nextMilestone,
    days_until_next_milestone: daysUntilNext
  }
}

/**
 * Get daily goal progress
 */
async function getDailyGoalStats(
  supabaseClient: any,
  userId: string
): Promise<DailyGoalStats> {
  
  const today = new Date().toISOString().split('T')[0]
  
  const { data: dailyGoal } = await supabaseClient
    .from('memory_daily_goals')
    .select('*')
    .eq('user_id', userId)
    .eq('goal_date', today)
    .maybeSingle()
  
  if (!dailyGoal) {
    // No goal set for today - return defaults
    return {
      target_reviews: 5,
      completed_reviews: 0,
      target_new_verses: 1,
      added_new_verses: 0,
      goal_achieved: false,
      bonus_xp_available: 0,
      progress_percentage: 0
    }
  }
  
  // Calculate overall progress (70% reviews, 30% new verses)
  const reviewProgress = dailyGoal.target_reviews > 0 
    ? dailyGoal.completed_reviews / dailyGoal.target_reviews 
    : 1.0
  const newVerseProgress = dailyGoal.target_new_verses > 0
    ? dailyGoal.added_new_verses / dailyGoal.target_new_verses
    : 1.0
  
  const overallProgress = (reviewProgress * 0.7 + newVerseProgress * 0.3) * 100
  
  return {
    target_reviews: dailyGoal.target_reviews,
    completed_reviews: dailyGoal.completed_reviews,
    target_new_verses: dailyGoal.target_new_verses,
    added_new_verses: dailyGoal.added_new_verses,
    goal_achieved: dailyGoal.goal_achieved,
    bonus_xp_available: dailyGoal.goal_achieved && !dailyGoal.bonus_xp_awarded ? 50 : 0,
    progress_percentage: Math.round(overallProgress)
  }
}

/**
 * Get mastery distribution
 */
async function getMasteryDistribution(
  supabaseClient: any,
  userId: string
): Promise<MasteryDistribution> {
  
  const { data: masteryData } = await supabaseClient
    .from('memory_verse_mastery')
    .select('mastery_level')
    .eq('user_id', userId)
  
  const distribution = {
    beginner: 0,
    intermediate: 0,
    advanced: 0,
    expert: 0,
    master: 0,
    total_verses: 0
  }
  
  if (masteryData) {
    for (const item of masteryData) {
      const level = item.mastery_level as keyof Omit<MasteryDistribution, 'total_verses'>
      if (level in distribution) {
        distribution[level]++
      }
    }
    distribution.total_verses = masteryData.length
  }
  
  return distribution
}

/**
 * Get practice mode statistics
 */
async function getPracticeModeStats(
  supabaseClient: any,
  userId: string
): Promise<PracticeModeStats[]> {
  
  const { data: modes } = await supabaseClient
    .from('memory_practice_modes')
    .select('mode_type, times_practiced, success_rate, average_time_seconds, is_favorite')
    .eq('user_id', userId)
  
  if (!modes || modes.length === 0) {
    return []
  }
  
  // Aggregate by mode type (sum across all verses)
  const modeMap = new Map<string, any>()
  
  for (const mode of modes) {
    if (!modeMap.has(mode.mode_type)) {
      modeMap.set(mode.mode_type, {
        mode_type: mode.mode_type,
        times_practiced: 0,
        total_success_rate: 0,
        count: 0,
        total_time: 0,
        time_count: 0,
        is_favorite: false,
        mastered_count: 0
      })
    }
    
    const existing = modeMap.get(mode.mode_type)
    existing.times_practiced += mode.times_practiced
    existing.total_success_rate += mode.success_rate
    existing.count++
    
    if (mode.average_time_seconds) {
      existing.total_time += mode.average_time_seconds
      existing.time_count++
    }
    
    if (mode.is_favorite) {
      existing.is_favorite = true
    }
    
    // Check if mastered (80%+ success rate, 5+ practices)
    if (mode.success_rate >= 80 && mode.times_practiced >= 5) {
      existing.mastered_count++
    }
  }
  
  // Calculate averages and build result
  const result: PracticeModeStats[] = []
  
  for (const [, data] of modeMap) {
    result.push({
      mode_type: data.mode_type,
      times_practiced: data.times_practiced,
      success_rate: Math.round((data.total_success_rate / data.count) * 100) / 100,
      average_time_seconds: data.time_count > 0 
        ? Math.round(data.total_time / data.time_count) 
        : null,
      is_favorite: data.is_favorite,
      is_mastered: data.mastered_count > 0
    })
  }
  
  // Sort by times practiced (most used first)
  result.sort((a, b) => b.times_practiced - a.times_practiced)
  
  return result
}

/**
 * Get active challenges with progress
 */
async function getActiveChallenges(
  supabaseClient: any,
  userId: string
): Promise<ChallengeProgress[]> {
  
  const now = new Date()
  
  // Get active challenges
  const { data: challenges } = await supabaseClient
    .from('memory_challenges')
    .select('*')
    .eq('is_active', true)
    .lte('start_date', now.toISOString())
    .gte('end_date', now.toISOString())
  
  if (!challenges || challenges.length === 0) {
    return []
  }
  
  // Get user progress for these challenges
  const challengeIds = challenges.map((c: any) => c.id)
  const { data: progressData } = await supabaseClient
    .from('user_challenge_progress')
    .select('*')
    .eq('user_id', userId)
    .in('challenge_id', challengeIds)
  
  // Build progress map
  const progressMap = new Map<string, any>()
  if (progressData) {
    for (const progress of progressData) {
      progressMap.set(progress.challenge_id, progress)
    }
  }
  
  // Build result
  const result: ChallengeProgress[] = []
  
  for (const challenge of challenges) {
    const progress = progressMap.get(challenge.id)
    const currentProgress = progress?.current_progress || 0
    const isCompleted = progress?.is_completed || false
    
    const progressPercentage = challenge.target_value > 0
      ? Math.round((currentProgress / challenge.target_value) * 100)
      : 0
    
    const timeRemaining = new Date(challenge.end_date).getTime() - now.getTime()
    const hoursRemaining = Math.max(0, Math.round(timeRemaining / (1000 * 60 * 60)))
    
    result.push({
      challenge_id: challenge.id,
      challenge_type: challenge.challenge_type,
      target_type: challenge.target_type,
      target_value: challenge.target_value,
      current_progress: currentProgress,
      progress_percentage: progressPercentage,
      xp_reward: challenge.xp_reward,
      badge_icon: challenge.badge_icon,
      time_remaining_hours: hoursRemaining,
      is_completed: isCompleted,
      is_active: true
    })
  }
  
  // Sort by time remaining (soonest first)
  result.sort((a, b) => a.time_remaining_hours - b.time_remaining_hours)
  
  return result
}

/**
 * Get upcoming reviews count
 */
async function getUpcomingReviewsCount(
  supabaseClient: any,
  userId: string
): Promise<{ upcoming: number; dueToday: number }> {
  
  const now = new Date()
  const endOfToday = new Date()
  endOfToday.setHours(23, 59, 59, 999)
  
  // Count verses due today
  const { count: dueTodayCount } = await supabaseClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .lte('next_review_date', endOfToday.toISOString())
  
  // Count all verses due (including overdue)
  const { count: upcomingCount } = await supabaseClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .lte('next_review_date', now.toISOString())
  
  return {
    upcoming: upcomingCount || 0,
    dueToday: dueTodayCount || 0
  }
}

/**
 * Calculate total XP earned from memory practice
 * This is a placeholder - real XP tracking should be in user_profiles or gamification tables
 */
function calculateTotalXP(
  dailyGoalStats: DailyGoalStats,
  masteryDistribution: MasteryDistribution
): number {
  
  // Rough estimate based on mastery levels
  let totalXP = 0
  
  // XP from mastery levels (each verse at each level earned XP to get there)
  totalXP += masteryDistribution.intermediate * 100
  totalXP += masteryDistribution.advanced * 300
  totalXP += masteryDistribution.expert * 600
  totalXP += masteryDistribution.master * 1000
  
  // XP from daily goals
  if (dailyGoalStats.goal_achieved) {
    totalXP += 50
  }
  
  return totalXP
}

/**
 * Main handler for getting memory practice stats
 */
async function handleGetMemoryPracticeStats(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to get stats', 401)
  }

  // Fetch all statistics in parallel for performance
  const [
    streakStats,
    dailyGoalStats,
    masteryDistribution,
    practiceModeStats,
    activeChallenges,
    reviewCounts
  ] = await Promise.all([
    getStreakStats(services.supabaseServiceClient, userContext.userId),
    getDailyGoalStats(services.supabaseServiceClient, userContext.userId),
    getMasteryDistribution(services.supabaseServiceClient, userContext.userId),
    getPracticeModeStats(services.supabaseServiceClient, userContext.userId),
    getActiveChallenges(services.supabaseServiceClient, userContext.userId),
    getUpcomingReviewsCount(services.supabaseServiceClient, userContext.userId)
  ])

  // Calculate total XP
  const totalXP = calculateTotalXP(dailyGoalStats, masteryDistribution)

  // Build response data
  const responseData: MemoryPracticeStatsData = {
    streak: streakStats,
    daily_goal: dailyGoalStats,
    mastery_distribution: masteryDistribution,
    practice_modes: practiceModeStats,
    active_challenges: activeChallenges,
    upcoming_reviews_count: reviewCounts.upcoming,
    verses_due_today: reviewCounts.dueToday,
    total_xp_earned: totalXP
  }

  const response: MemoryPracticeStatsResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json'
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleGetMemoryPracticeStats, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
