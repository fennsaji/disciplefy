/**
 * Update Memory Streak Edge Function
 * 
 * Manages memory verse practice streaks:
 * - Updates streak after successful practice session
 * - Detects streak milestones (10, 30, 100, 365 days)
 * - Awards freeze days for weekly consistency (5+ practice days)
 * - Triggers achievement unlocks for streak milestones
 * - Handles streak breaks and resets
 * 
 * Version: 2.4.0 - Memory Verses Enhancement
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Milestone achievement
 */
interface MilestoneAchievement {
  readonly milestone_days: number
  readonly achievement_name: string
  readonly xp_reward: number
}

/**
 * Response data structure
 */
interface UpdateStreakData {
  readonly success: boolean
  readonly current_streak: number
  readonly longest_streak: number
  readonly streak_maintained: boolean
  readonly streak_continued: boolean
  readonly milestone_reached?: MilestoneAchievement
  readonly freeze_day_earned: boolean
  readonly freeze_days_available: number
  readonly total_practice_days: number
  readonly last_practice_date: string
}

/**
 * API response structure
 */
interface UpdateStreakResponse extends ApiSuccessResponse<UpdateStreakData> {}

/**
 * Check if two dates are the same day
 */
function isSameDay(date1: Date, date2: Date): boolean {
  return date1.getFullYear() === date2.getFullYear() &&
         date1.getMonth() === date2.getMonth() &&
         date1.getDate() === date2.getDate()
}

/**
 * Check if date2 is exactly one day after date1
 */
function isConsecutiveDay(date1: Date, date2: Date): boolean {
  const nextDay = new Date(date1)
  nextDay.setDate(nextDay.getDate() + 1)
  return isSameDay(nextDay, date2)
}

/**
 * Get the start of the current week (Monday)
 */
function getWeekStart(date: Date): Date {
  const d = new Date(date)
  const day = d.getDay()
  const diff = d.getDate() - day + (day === 0 ? -6 : 1) // Adjust when day is Sunday
  return new Date(d.setDate(diff))
}

/**
 * Count practice days in current week
 */
async function countWeekPracticeDays(
  supabaseClient: any,
  userId: string,
  currentDate: Date
): Promise<number> {
  
  const weekStart = getWeekStart(currentDate)
  const weekStartStr = weekStart.toISOString().split('T')[0]
  const currentDateStr = currentDate.toISOString().split('T')[0]
  
  // Count unique review dates in current week
  const { data: reviews } = await supabaseClient
    .from('review_sessions')
    .select('review_date')
    .eq('user_id', userId)
    .gte('review_date', weekStartStr)
    .lte('review_date', currentDateStr)
  
  if (!reviews || reviews.length === 0) {
    return 0
  }
  
  // Get unique dates
  const uniqueDates = new Set<string>()
  for (const review of reviews) {
    const dateOnly = review.review_date.split('T')[0]
    uniqueDates.add(dateOnly)
  }
  
  return uniqueDates.size
}

/**
 * Check which milestone was just reached
 */
function checkMilestoneReached(
  previousStreak: number,
  newStreak: number,
  existingMilestones: any
): MilestoneAchievement | null {
  
  const milestones = [
    { days: 10, name: 'daily_devotion', xp: 50 },
    { days: 30, name: 'month_of_memory', xp: 150 },
    { days: 100, name: 'century_streak', xp: 500 },
    { days: 365, name: 'annual_devotion', xp: 1000 }
  ]
  
  for (const milestone of milestones) {
    // Check if we just crossed this milestone
    if (previousStreak < milestone.days && newStreak >= milestone.days) {
      // Check if milestone wasn't already reached
      const milestoneKey = `milestone_${milestone.days}_date`
      if (!existingMilestones[milestoneKey]) {
        return {
          milestone_days: milestone.days,
          achievement_name: milestone.name,
          xp_reward: milestone.xp
        }
      }
    }
  }
  
  return null
}

/**
 * Update milestone dates in database
 */
async function updateMilestoneDate(
  supabaseClient: any,
  userId: string,
  milestoneDays: number,
  date: string
): Promise<void> {
  
  const milestoneColumn = `milestone_${milestoneDays}_date`
  
  await supabaseClient
    .from('memory_verse_streaks')
    .update({
      [milestoneColumn]: date
    })
    .eq('user_id', userId)
}

/**
 * Award freeze day if earned
 */
async function checkAndAwardFreezeDay(
  supabaseClient: any,
  userId: string,
  weekPracticeDays: number,
  currentFreezeDays: number
): Promise<boolean> {
  
  // Earn freeze day if practiced 5+ days this week and haven't maxed out
  const maxFreezeDays = 5
  
  if (weekPracticeDays >= 5 && currentFreezeDays < maxFreezeDays) {
    // Award one freeze day
    await supabaseClient
      .from('memory_verse_streaks')
      .update({
        freeze_days_available: currentFreezeDays + 1
      })
      .eq('user_id', userId)
    
    return true
  }
  
  return false
}

/**
 * Main handler for updating memory streak
 */
async function handleUpdateMemoryStreak(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to update streak', 401)
  }

  const today = new Date()
  const todayStr = today.toISOString().split('T')[0]
  const nowIso = today.toISOString()

  // Get existing streak
  const { data: existingStreak } = await services.supabaseServiceClient
    .from('memory_verse_streaks')
    .select('*')
    .eq('user_id', userContext.userId)
    .maybeSingle()

  // If no streak exists, create one
  if (!existingStreak) {
    const newStreakData = {
      user_id: userContext.userId,
      current_streak: 1,
      longest_streak: 1,
      last_practice_date: todayStr,
      total_practice_days: 1,
      freeze_days_available: 0,
      freeze_days_used: 0,
      milestone_10_date: null,
      milestone_30_date: null,
      milestone_100_date: null,
      milestone_365_date: null
    }

    await services.supabaseServiceClient
      .from('memory_verse_streaks')
      .insert(newStreakData)

    const responseData: UpdateStreakData = {
      success: true,
      current_streak: 1,
      longest_streak: 1,
      streak_maintained: true,
      streak_continued: false,
      freeze_day_earned: false,
      freeze_days_available: 0,
      total_practice_days: 1,
      last_practice_date: todayStr
    }

    const response: UpdateStreakResponse = {
      success: true,
      data: responseData
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  // Check if already practiced today
  if (existingStreak.last_practice_date === todayStr) {
    // Already practiced today - streak is maintained but not continued
    const responseData: UpdateStreakData = {
      success: true,
      current_streak: existingStreak.current_streak,
      longest_streak: existingStreak.longest_streak,
      streak_maintained: true,
      streak_continued: false,
      freeze_day_earned: false,
      freeze_days_available: existingStreak.freeze_days_available,
      total_practice_days: existingStreak.total_practice_days,
      last_practice_date: existingStreak.last_practice_date
    }

    const response: UpdateStreakResponse = {
      success: true,
      data: responseData
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  // Parse last practice date
  const lastPractice = new Date(existingStreak.last_practice_date + 'T00:00:00Z')
  
  // Check if streak continues (practiced yesterday)
  const streakContinues = isConsecutiveDay(lastPractice, today)
  
  // Calculate new streak
  const previousStreak = existingStreak.current_streak
  const newStreak = streakContinues ? previousStreak + 1 : 1
  const newLongest = Math.max(newStreak, existingStreak.longest_streak)
  const newTotalDays = existingStreak.total_practice_days + 1

  // Check for milestone
  const milestone = checkMilestoneReached(previousStreak, newStreak, existingStreak)

  // Update streak in database
  await services.supabaseServiceClient
    .from('memory_verse_streaks')
    .update({
      current_streak: newStreak,
      longest_streak: newLongest,
      last_practice_date: todayStr,
      total_practice_days: newTotalDays,
      updated_at: nowIso
    })
    .eq('user_id', userContext.userId)

  // Update milestone date if milestone reached
  if (milestone) {
    await updateMilestoneDate(
      services.supabaseServiceClient,
      userContext.userId,
      milestone.milestone_days,
      nowIso
    )
  }

  // Check if freeze day should be earned
  const weekPracticeDays = await countWeekPracticeDays(
    services.supabaseServiceClient,
    userContext.userId,
    today
  )

  const freezeDayEarned = await checkAndAwardFreezeDay(
    services.supabaseServiceClient,
    userContext.userId,
    weekPracticeDays,
    existingStreak.freeze_days_available
  )

  // Get updated freeze days count
  const finalFreezeDays = freezeDayEarned 
    ? existingStreak.freeze_days_available + 1 
    : existingStreak.freeze_days_available

  // Build response
  const responseData: UpdateStreakData = {
    success: true,
    current_streak: newStreak,
    longest_streak: newLongest,
    streak_maintained: true,
    streak_continued: streakContinues,
    milestone_reached: milestone || undefined,
    freeze_day_earned: freezeDayEarned,
    freeze_days_available: finalFreezeDays,
    total_practice_days: newTotalDays,
    last_practice_date: todayStr
  }

  const response: UpdateStreakResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleUpdateMemoryStreak, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
