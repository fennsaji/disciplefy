/**
 * Submit Memory Practice Edge Function
 * 
 * Enhanced version of submit-memory-verse-review that includes:
 * - Multiple practice modes (typing, cloze, flip_card, etc.)
 * - Mode-specific performance tracking
 * - Mastery level progression
 * - Daily goal updates
 * - Memory streak tracking
 * - Challenge progress updates
 * - XP rewards and achievement checks
 * - Confidence rating (separate from SM-2 quality)
 * 
 * Version: 2.4.0 - Memory Verses Enhancement
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { getIntervalForReviewsSinceMastery } from '../_shared/memory-verse-intervals.ts'
import { PracticeModeUnlockService } from '../_shared/services/practice-mode-unlock-service.ts'
import { checkFeatureAccess } from '../_shared/middleware/feature-access-middleware.ts'

/**
 * Practice mode types (aligned with frontend)
 */
type PracticeModeType =
  | 'flip_card'
  | 'type_it_out'  // Was 'typing'
  | 'cloze'
  | 'first_letter'
  | 'progressive'
  | 'word_scramble'
  | 'word_bank'    // Was 'word_order'
  | 'audio'

/**
 * Request payload structure
 */
interface SubmitPracticeRequest {
  readonly memory_verse_id: string
  readonly practice_mode: PracticeModeType
  readonly quality_rating: number // 0-5 SM-2 scale
  readonly confidence_rating?: number // 1-5 user self-assessment
  readonly accuracy_percentage?: number // 0-100 for typing/cloze modes
  readonly time_spent_seconds?: number
  readonly hints_used?: number
}

/**
 * SM-2 algorithm input
 */
interface SM2Input {
  readonly quality: number
  readonly easeFactor: number
  readonly interval: number
  readonly repetitions: number
}

/**
 * SM-2 algorithm output
 */
interface SM2Result {
  readonly easeFactor: number
  readonly interval: number
  readonly repetitions: number
  readonly nextReviewDate: string
}

/**
 * New achievements unlocked
 */
interface NewAchievement {
  readonly achievement_name: string
  readonly xp_reward: number
}

/**
 * Response data structure
 */
interface SubmitPracticeData {
  readonly success: boolean
  readonly next_review_date: string
  readonly interval_days: number
  readonly ease_factor: number
  readonly repetitions: number
  readonly total_reviews: number
  readonly mastery_level: string
  readonly mastery_percentage: number
  readonly xp_earned: number
  readonly streak_maintained: boolean
  readonly current_streak: number
  readonly daily_goal_progress: {
    readonly reviews_completed: number
    readonly target_reviews: number
    readonly goal_achieved: boolean
  }
  readonly new_achievements: NewAchievement[]
  readonly challenge_updates?: Array<{
    readonly challenge_id: string
    readonly progress: number
    readonly completed: boolean
  }>
}

/**
 * API response structure
 */
interface SubmitPracticeResponse extends ApiSuccessResponse<SubmitPracticeData> {}

/**
 * Implements the SM-2 spaced repetition algorithm
 * Modified for Bible verse memorization with daily cementing period
 */
function calculateSM2(input: SM2Input, minEaseFactor: number = 1.3, maxIntervalDays: number = 180): SM2Result {
  const { quality, easeFactor, interval, repetitions } = input

  // Constants - now using config parameters
  const MAX_INTERVAL_DAYS = maxIntervalDays
  const DAILY_REVIEW_PERIOD = 14 // First 14 successful reviews are daily

  if (quality < 0 || quality > 5) {
    throw new AppError('VALIDATION_ERROR', 'quality_rating must be between 0 and 5', 400)
  }

  // Calculate new ease factor
  let newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
  if (newEaseFactor < minEaseFactor) newEaseFactor = minEaseFactor
  newEaseFactor = Math.round(newEaseFactor * 100) / 100

  let newInterval: number
  let newRepetitions: number

  if (quality < 3) {
    // Reset on failure
    newInterval = 1
    newRepetitions = 0
  } else {
    // Successful recall
    newRepetitions = repetitions + 1

    // NEW ALGORITHM: Daily reviews for first 2 weeks, then adaptive spacing
    if (newRepetitions <= DAILY_REVIEW_PERIOD) {
      // First 14 successful reviews: Daily review (cementing the verse in memory)
      newInterval = 1
    } else {
      // After 14 reviews, check if verse is mastered (quality 5 = perfect recall)
      if (quality === 5) {
        // Verse is MASTERED - use progressive spacing for efficient long-term retention
        // Progression: 3, 7, 14, 21, 30, 45, 60, 90, 120, 150, 180 (cap)
        const reviewsSinceMastery = newRepetitions - DAILY_REVIEW_PERIOD
        newInterval = getIntervalForReviewsSinceMastery(reviewsSinceMastery, MAX_INTERVAL_DAYS)
      } else {
        // Verse NOT mastered yet (quality 3-4) - increment by just 1 day
        // This keeps practice frequent until user achieves perfect recall
        // Progression: 1→2→3→4→5→6... (gradual increase)
        newInterval = interval + 1
      }
    }

    // Safety cap: Never exceed 6 months
    if (newInterval > MAX_INTERVAL_DAYS) {
      newInterval = MAX_INTERVAL_DAYS
    }
  }

  const nextReviewDate = new Date()
  nextReviewDate.setDate(nextReviewDate.getDate() + newInterval)

  return {
    easeFactor: newEaseFactor,
    interval: newInterval,
    repetitions: newRepetitions,
    nextReviewDate: nextReviewDate.toISOString()
  }
}

/**
 * Calculate mastery level based on performance metrics
 */
function calculateMasteryLevel(
  modesMastered: number,
  perfectRecalls: number,
  confidenceRating: number | null
): { level: string; percentage: number } {
  
  // Mastery level requirements:
  // Beginner: Default starting level
  // Intermediate: 2+ modes mastered, 5+ perfect recalls
  // Advanced: 4+ modes mastered, 15+ perfect recalls
  // Expert: 6+ modes mastered, 30+ perfect recalls
  // Master: 8 modes mastered, 50+ perfect recalls
  
  let level = 'beginner'
  let percentage = 0
  
  // Calculate base progress
  const modeProgress = (modesMastered / 8) * 50 // 50% weight
  const recallProgress = Math.min(perfectRecalls / 50, 1.0) * 40 // 40% weight
  const confidenceProgress = confidenceRating ? (confidenceRating / 5.0) * 10 : 0 // 10% weight
  
  percentage = Math.round(modeProgress + recallProgress + confidenceProgress)
  
  // Determine level based on criteria
  if (modesMastered >= 8 && perfectRecalls >= 50) {
    level = 'master'
    percentage = 100
  } else if (modesMastered >= 6 && perfectRecalls >= 30) {
    level = 'expert'
    percentage = Math.max(75, Math.min(99, percentage))
  } else if (modesMastered >= 4 && perfectRecalls >= 15) {
    level = 'advanced'
    percentage = Math.max(50, Math.min(74, percentage))
  } else if (modesMastered >= 2 && perfectRecalls >= 5) {
    level = 'intermediate'
    percentage = Math.max(25, Math.min(49, percentage))
  } else {
    level = 'beginner'
    percentage = Math.min(24, percentage)
  }
  
  return { level, percentage }
}

/**
 * Calculate XP earned based on performance
 */
function calculateXP(
  qualityRating: number,
  practiceMode: string,
  accuracyPercentage: number | undefined,
  isPerfectRecall: boolean
): number {
  let xp = 0
  
  // Base XP from quality rating
  if (qualityRating <= 2) xp = 5
  else if (qualityRating <= 4) xp = 10
  else xp = 20
  
  // Perfect recall bonus
  if (isPerfectRecall) xp += 10
  
  // Mode difficulty bonus (aligned with frontend difficulty levels)
  // Hard: audio, type_it_out
  // Medium: cloze, word_scramble, word_bank
  // Easy: flip_card, first_letter, progressive
  if (['audio', 'type_it_out'].includes(practiceMode)) {
    xp += 5 // Hard modes
  } else if (['cloze', 'word_scramble', 'word_bank'].includes(practiceMode)) {
    xp += 2 // Medium modes
  }
  // Easy modes get no bonus
  
  // Accuracy bonus (for modes that track it)
  if (accuracyPercentage !== undefined) {
    if (accuracyPercentage >= 95) xp += 5
    else if (accuracyPercentage >= 80) xp += 2
  }
  
  return xp
}

/**
 * Update or create practice mode statistics
 *
 * success_rate is calculated from accuracy_percentage when available,
 * otherwise falls back to quality_rating >= 3 (successful recall)
 */
async function updatePracticeModeStats(
  supabaseClient: any,
  userId: string,
  memoryVerseId: string,
  practiceMode: string,
  qualityRating: number,
  accuracyPercentage: number | undefined,
  timeSpentSeconds: number | undefined
): Promise<{ modesMastered: number }> {

  // Use accuracy_percentage if available, otherwise use quality-based success
  // This ensures 100% accuracy always counts as 100% success rate
  const sessionSuccessRate = accuracyPercentage !== undefined
    ? accuracyPercentage
    : (qualityRating >= 3 ? 100.0 : 0.0)

  // Fetch existing stats
  const { data: existingMode } = await supabaseClient
    .from('memory_practice_modes')
    .select('*')
    .eq('user_id', userId)
    .eq('memory_verse_id', memoryVerseId)
    .eq('mode_type', practiceMode)
    .maybeSingle()

  if (existingMode) {
    // Update existing mode stats with weighted average
    const newTimePracticed = existingMode.times_practiced + 1
    const totalSuccessRate = existingMode.success_rate * existingMode.times_practiced + sessionSuccessRate
    const newSuccessRate = totalSuccessRate / newTimePracticed

    let newAvgTime = existingMode.average_time_seconds
    if (timeSpentSeconds !== undefined) {
      if (existingMode.average_time_seconds) {
        newAvgTime = Math.round(
          (existingMode.average_time_seconds * existingMode.times_practiced + timeSpentSeconds) / newTimePracticed
        )
      } else {
        newAvgTime = timeSpentSeconds
      }
    }

    await supabaseClient
      .from('memory_practice_modes')
      .update({
        times_practiced: newTimePracticed,
        success_rate: Math.round(newSuccessRate * 100) / 100,
        average_time_seconds: newAvgTime
      })
      .eq('id', existingMode.id)
  } else {
    // Create new mode stats - use session's success rate directly
    await supabaseClient
      .from('memory_practice_modes')
      .insert({
        user_id: userId,
        memory_verse_id: memoryVerseId,
        mode_type: practiceMode,
        times_practiced: 1,
        success_rate: Math.round(sessionSuccessRate * 100) / 100,
        average_time_seconds: timeSpentSeconds || null
      })
  }
  
  // Count modes mastered (80%+ success rate, 5+ practices)
  const { data: allModes } = await supabaseClient
    .from('memory_practice_modes')
    .select('success_rate, times_practiced')
    .eq('user_id', userId)
    .eq('memory_verse_id', memoryVerseId)
  
  const modesMastered = (allModes || []).filter(
    (m: any) => m.success_rate >= 80 && m.times_practiced >= 5
  ).length
  
  return { modesMastered }
}

/**
 * Update or create mastery progress
 */
async function updateMasteryProgress(
  supabaseClient: any,
  userId: string,
  memoryVerseId: string,
  modesMastered: number,
  isPerfectRecall: boolean,
  confidenceRating: number | null
): Promise<{ level: string; percentage: number }> {
  
  // Fetch existing mastery
  const { data: existingMastery } = await supabaseClient
    .from('memory_verse_mastery')
    .select('*')
    .eq('user_id', userId)
    .eq('memory_verse_id', memoryVerseId)
    .maybeSingle()
  
  const currentPerfectRecalls = existingMastery?.perfect_recalls || 0
  const newPerfectRecalls = currentPerfectRecalls + (isPerfectRecall ? 1 : 0)
  
  // Calculate average confidence if rating provided
  let newConfidenceRating = confidenceRating
  if (confidenceRating && existingMastery?.confidence_rating) {
    // Running average
    const oldRating = existingMastery.confidence_rating
    newConfidenceRating = (oldRating + confidenceRating) / 2
  }
  
  const mastery = calculateMasteryLevel(modesMastered, newPerfectRecalls, newConfidenceRating)
  
  if (existingMastery) {
    await supabaseClient
      .from('memory_verse_mastery')
      .update({
        mastery_level: mastery.level,
        mastery_percentage: mastery.percentage,
        modes_mastered: modesMastered,
        perfect_recalls: newPerfectRecalls,
        confidence_rating: newConfidenceRating
      })
      .eq('id', existingMastery.id)
  } else {
    await supabaseClient
      .from('memory_verse_mastery')
      .insert({
        user_id: userId,
        memory_verse_id: memoryVerseId,
        mastery_level: mastery.level,
        mastery_percentage: mastery.percentage,
        modes_mastered: modesMastered,
        perfect_recalls: newPerfectRecalls,
        confidence_rating: newConfidenceRating
      })
  }
  
  // Update memory_verses table with mastery level and perfect recalls
  // Note: mastery_level and times_perfectly_recalled updated, preferred_practice_mode set in main handler
  await supabaseClient
    .from('memory_verses')
    .update({
      mastery_level: mastery.level,
      times_perfectly_recalled: newPerfectRecalls
    })
    .eq('id', memoryVerseId)
  
  return mastery
}

/**
 * Update daily goal progress
 */
async function updateDailyGoal(
  supabaseClient: any,
  userId: string
): Promise<{ reviewsCompleted: number; targetReviews: number; goalAchieved: boolean }> {
  
  const today = new Date().toISOString().split('T')[0]
  
  // Get or create today's goal
  const { data: dailyGoal } = await supabaseClient
    .from('memory_daily_goals')
    .select('*')
    .eq('user_id', userId)
    .eq('goal_date', today)
    .maybeSingle()
  
  if (dailyGoal) {
    const newCompleted = dailyGoal.completed_reviews + 1
    const newGoalAchieved = newCompleted >= dailyGoal.target_reviews && 
                             dailyGoal.added_new_verses >= dailyGoal.target_new_verses
    
    // Award bonus XP if goal just achieved
    const bonusXp = (!dailyGoal.goal_achieved && newGoalAchieved) ? 50 : dailyGoal.bonus_xp_awarded
    
    await supabaseClient
      .from('memory_daily_goals')
      .update({
        completed_reviews: newCompleted,
        goal_achieved: newGoalAchieved,
        bonus_xp_awarded: bonusXp
      })
      .eq('id', dailyGoal.id)
    
    return {
      reviewsCompleted: newCompleted,
      targetReviews: dailyGoal.target_reviews,
      goalAchieved: newGoalAchieved
    }
  } else {
    // Create new daily goal with default targets
    const defaultTargetReviews = 5
    const defaultTargetNewVerses = 1
    
    await supabaseClient
      .from('memory_daily_goals')
      .insert({
        user_id: userId,
        goal_date: today,
        target_reviews: defaultTargetReviews,
        completed_reviews: 1,
        target_new_verses: defaultTargetNewVerses,
        added_new_verses: 0,
        goal_achieved: false,
        bonus_xp_awarded: 0
      })
    
    return {
      reviewsCompleted: 1,
      targetReviews: defaultTargetReviews,
      goalAchieved: false
    }
  }
}

/**
 * Update memory streak
 */
async function updateMemoryStreak(
  supabaseClient: any,
  userId: string,
  isSuccessfulPractice: boolean
): Promise<{ currentStreak: number; streakMaintained: boolean }> {
  
  if (!isSuccessfulPractice) {
    return { currentStreak: 0, streakMaintained: false }
  }
  
  const today = new Date().toISOString().split('T')[0]
  
  // Get existing streak
  const { data: streak } = await supabaseClient
    .from('memory_verse_streaks')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle()
  
  if (streak) {
    const lastPractice = streak.last_practice_date
    
    // Check if already practiced today
    if (lastPractice === today) {
      return { currentStreak: streak.current_streak, streakMaintained: true }
    }
    
    // Check if streak continues (practiced yesterday)
    const yesterday = new Date()
    yesterday.setDate(yesterday.getDate() - 1)
    const yesterdayStr = yesterday.toISOString().split('T')[0]
    
    const streakContinues = lastPractice === yesterdayStr
    const newStreak = streakContinues ? streak.current_streak + 1 : 1
    const newLongest = Math.max(newStreak, streak.longest_streak)
    
    await supabaseClient
      .from('memory_verse_streaks')
      .update({
        current_streak: newStreak,
        longest_streak: newLongest,
        last_practice_date: today,
        total_practice_days: streak.total_practice_days + 1
      })
      .eq('user_id', userId)
    
    return { currentStreak: newStreak, streakMaintained: true }
  } else {
    // Create new streak
    await supabaseClient
      .from('memory_verse_streaks')
      .insert({
        user_id: userId,
        current_streak: 1,
        longest_streak: 1,
        last_practice_date: today,
        total_practice_days: 1,
        freeze_days_available: 0,
        freeze_days_used: 0
      })
    
    return { currentStreak: 1, streakMaintained: true }
  }
}

/**
 * Main handler for submitting practice session
 */
async function handleSubmitMemoryPractice(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to submit practice', 401)
  }

  // Validate feature access for memory verses
  const userPlan = await services.authService.getUserPlan(req)
  await checkFeatureAccess(userContext.userId, userPlan, 'memory_verses')

  // Parse request body
  let body: SubmitPracticeRequest
  try {
    body = await req.json() as SubmitPracticeRequest
  } catch (error) {
    throw new AppError('VALIDATION_ERROR', 'Invalid JSON payload', 400)
  }

  // Validate required fields
  if (!body.memory_verse_id) {
    throw new AppError('VALIDATION_ERROR', 'memory_verse_id is required', 400)
  }

  if (!body.practice_mode) {
    throw new AppError('VALIDATION_ERROR', 'practice_mode is required', 400)
  }

  if (body.quality_rating === undefined || body.quality_rating === null) {
    throw new AppError('VALIDATION_ERROR', 'quality_rating is required', 400)
  }

  // Validate practice mode
  // Updated mode names to match frontend: word_bank (was word_order), type_it_out (was typing)
  const validModes = ['flip_card', 'type_it_out', 'cloze', 'first_letter', 'progressive', 'word_scramble', 'word_bank', 'audio']
  if (!validModes.includes(body.practice_mode)) {
    throw new AppError('VALIDATION_ERROR', `Invalid practice_mode. Must be one of: ${validModes.join(', ')}`, 400)
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(body.memory_verse_id)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid memory_verse_id format', 400)
  }

  // Validate quality rating
  if (!Number.isInteger(body.quality_rating) || body.quality_rating < 0 || body.quality_rating > 5) {
    throw new AppError('VALIDATION_ERROR', 'quality_rating must be an integer between 0 and 5', 400)
  }

  // Validate confidence rating if provided
  if (body.confidence_rating !== undefined) {
    if (!Number.isInteger(body.confidence_rating) || body.confidence_rating < 1 || body.confidence_rating > 5) {
      throw new AppError('VALIDATION_ERROR', 'confidence_rating must be an integer between 1 and 5', 400)
    }
  }

  // Validate accuracy percentage if provided
  if (body.accuracy_percentage !== undefined) {
    if (body.accuracy_percentage < 0 || body.accuracy_percentage > 100) {
      throw new AppError('VALIDATION_ERROR', 'accuracy_percentage must be between 0 and 100', 400)
    }
  }

  // Fetch the memory verse
  const { data: memoryVerse, error: fetchError } = await services.supabaseServiceClient
    .from('memory_verses')
    .select('*')
    .eq('id', body.memory_verse_id)
    .eq('user_id', userContext.userId)
    .single()

  if (fetchError || !memoryVerse) {
    console.error('[SubmitPractice] Verse not found:', fetchError)
    throw new AppError('NOT_FOUND', 'Memory verse not found', 404)
  }

  // ========== NEW: Check practice mode unlock status ==========
  // Get user's subscription tier
  const { data: subscription } = await services.supabaseServiceClient
    .from('user_subscriptions')
    .select('tier')
    .eq('user_id', userContext.userId)
    .eq('status', 'active')
    .maybeSingle()

  const userTier = subscription?.tier || 'free'

  // Initialize unlock service
  const unlockService = new PracticeModeUnlockService(services.supabaseServiceClient)

  // 1. Check if mode is available in user's tier (tier-lock check)
  const tierAvailability = await unlockService.checkModeTierAvailability(userTier, body.practice_mode)

  if (!tierAvailability.available) {
    console.log(`[SubmitPractice] Mode ${body.practice_mode} is tier-locked for ${userTier} user`)

    // Return tier-locked error
    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: 'PRACTICE_MODE_TIER_LOCKED',
          message: unlockService.getTierLockedMessage(body.practice_mode, userTier),
          mode: body.practice_mode,
          tier: userTier,
          available_modes: tierAvailability.availableModes,
          required_tier: unlockService.getRecommendedUpgradeTier(userTier)
        }
      }),
      {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }

  // 2. Check daily unlock status for this mode
  try {
    const unlockStatus = await unlockService.getModeUnlockStatus(
      userContext.userId,
      body.memory_verse_id,
      body.practice_mode,
      userTier
    )

    // If mode is already unlocked, allow practice (unlimited attempts)
    if (unlockStatus.status === 'unlocked') {
      console.log(`[SubmitPractice] Mode ${body.practice_mode} already unlocked for verse ${body.memory_verse_id}`)
      // Continue to SM-2 calculation below
    }
    // If mode can be unlocked, unlock it now
    else if (unlockStatus.status === 'can_unlock') {
      console.log(`[SubmitPractice] Unlocking mode ${body.practice_mode} for verse ${body.memory_verse_id}`)

      // Unlock mode (fire-and-forget, non-blocking)
      unlockService.unlockMode(
        userContext.userId,
        body.memory_verse_id,
        body.practice_mode,
        userTier
      ).catch(err => {
        console.error('[SubmitPractice] Failed to unlock mode (non-critical):', err)
        // Don't block practice submission - mode will unlock on retry
      })

      // Continue to SM-2 calculation below
    }
    // If unlock limit reached, return error
    else if (unlockStatus.status === 'unlock_limit_reached') {
      console.log(`[SubmitPractice] Unlock limit reached for verse ${body.memory_verse_id}`)

      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'PRACTICE_UNLOCK_LIMIT_EXCEEDED',
            message: unlockService.getUnlockLimitMessage(
              unlockStatus.unlockedModes,
              unlockStatus.unlockLimit || 1,
              userTier
            ),
            details: {
              unlocked_modes: unlockStatus.unlockedModes,
              unlocked_count: unlockStatus.unlockedModes.length,
              unlock_limit: unlockStatus.unlockLimit,
              unlock_slots_remaining: 0,
              tier: userTier,
              verse_id: body.memory_verse_id,
              date: new Date().toISOString().split('T')[0]
            }
          }
        }),
        {
          status: 403,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }
  } catch (error) {
    console.error('[SubmitPractice] Unlock status check failed (fail-open):', error)
    // Continue with practice submission (fail-open pattern for non-critical error)
  }
  // ========== END NEW CODE ==========

  // Get SM-2 algorithm parameters from database config
  const memoryConfig = await services.memoryVerseConfigService.getMemoryVerseConfig()
  const minEaseFactor = memoryConfig.spacedRepetition.minEaseFactor
  const maxIntervalDays = memoryConfig.spacedRepetition.maxIntervalDays

  console.log(`[SubmitPractice] Using SM-2 config: minEase=${minEaseFactor}, maxInterval=${maxIntervalDays}`)

  // Calculate new SM-2 state using database config
  const sm2Result = calculateSM2({
    quality: body.quality_rating,
    easeFactor: memoryVerse.ease_factor,
    interval: memoryVerse.interval_days,
    repetitions: memoryVerse.repetitions
  }, minEaseFactor, maxIntervalDays)

  // Determine if this is a perfect recall
  const isPerfectRecall = body.quality_rating === 5
  const isSuccessfulPractice = body.quality_rating >= 3

  // Update practice mode statistics
  const { modesMastered } = await updatePracticeModeStats(
    services.supabaseServiceClient,
    userContext.userId,
    body.memory_verse_id,
    body.practice_mode,
    body.quality_rating,
    body.accuracy_percentage,
    body.time_spent_seconds
  )

  // Update mastery progress
  const mastery = await updateMasteryProgress(
    services.supabaseServiceClient,
    userContext.userId,
    body.memory_verse_id,
    modesMastered,
    isPerfectRecall,
    body.confidence_rating || null
  )

  // Update daily goal progress
  const dailyGoalProgress = await updateDailyGoal(
    services.supabaseServiceClient,
    userContext.userId
  )

  // Update memory streak
  const streakUpdate = await updateMemoryStreak(
    services.supabaseServiceClient,
    userContext.userId,
    isSuccessfulPractice
  )

  // Calculate XP earned
  const xpEarned = calculateXP(
    body.quality_rating,
    body.practice_mode,
    body.accuracy_percentage,
    isPerfectRecall
  )

  // Add bonus XP if daily goal just achieved
  let totalXP = xpEarned
  if (dailyGoalProgress.goalAchieved) {
    totalXP += 50 // Daily goal bonus
  }

  // Update memory verse with new SM-2 state
  const now = new Date().toISOString()
  const { error: updateError } = await services.supabaseServiceClient
    .from('memory_verses')
    .update({
      ease_factor: sm2Result.easeFactor,
      interval_days: sm2Result.interval,
      repetitions: sm2Result.repetitions,
      next_review_date: sm2Result.nextReviewDate,
      last_reviewed: now,
      total_reviews: memoryVerse.total_reviews + 1,
      preferred_practice_mode: body.practice_mode, // Track preferred mode
      updated_at: now
    })
    .eq('id', body.memory_verse_id)

  if (updateError) {
    console.error('[SubmitPractice] Failed to update verse:', updateError)
    throw new AppError('DATABASE_ERROR', 'Failed to save practice result', 500)
  }

  // Record the review session with enhanced data
  await services.supabaseServiceClient
    .from('review_sessions')
    .insert({
      user_id: userContext.userId,
      memory_verse_id: body.memory_verse_id,
      review_date: now,
      quality_rating: body.quality_rating,
      confidence_rating: body.confidence_rating || null,
      accuracy_percentage: body.accuracy_percentage || null,
      practice_mode: body.practice_mode,
      hints_used: body.hints_used || 0,
      new_ease_factor: sm2Result.easeFactor,
      new_interval_days: sm2Result.interval,
      new_repetitions: sm2Result.repetitions,
      time_spent_seconds: body.time_spent_seconds || null
    })

  // Check for new achievements
  const { data: achievementResults } = await services.supabaseServiceClient
    .rpc('check_memory_achievements', { p_user_id: userContext.userId })

  const newAchievements: NewAchievement[] = (achievementResults || [])
    .filter((a: any) => a.is_new === true)
    .map((a: any) => ({
      achievement_name: a.achievement_name,
      xp_reward: a.xp_reward
    }))

  // Check challenge progress (reviews_count type challenges)
  const { data: activeChallenges } = await services.supabaseServiceClient
    .from('memory_challenges')
    .select('id, target_type, target_value')
    .eq('is_active', true)
    .lte('start_date', now)
    .gte('end_date', now)

  const challengeUpdates: any[] = []

  for (const challenge of (activeChallenges || [])) {
    if (challenge.target_type === 'reviews_count') {
      // Get current progress
      const { data: progress } = await services.supabaseServiceClient
        .from('user_challenge_progress')
        .select('current_progress')
        .eq('user_id', userContext.userId)
        .eq('challenge_id', challenge.id)
        .maybeSingle()

      const newProgress = (progress?.current_progress || 0) + 1
      const completed = newProgress >= challenge.target_value

      // Upsert progress
      await services.supabaseServiceClient
        .from('user_challenge_progress')
        .upsert({
          user_id: userContext.userId,
          challenge_id: challenge.id,
          current_progress: newProgress,
          is_completed: completed,
          completed_at: completed ? now : null
        }, {
          onConflict: 'user_id,challenge_id'
        })

      challengeUpdates.push({
        challenge_id: challenge.id,
        progress: newProgress,
        completed
      })
    }
  }

  // Build response data
  const responseData: SubmitPracticeData = {
    success: true,
    next_review_date: sm2Result.nextReviewDate,
    interval_days: sm2Result.interval,
    ease_factor: sm2Result.easeFactor,
    repetitions: sm2Result.repetitions,
    total_reviews: memoryVerse.total_reviews + 1,
    mastery_level: mastery.level,
    mastery_percentage: mastery.percentage,
    xp_earned: totalXP,
    streak_maintained: streakUpdate.streakMaintained,
    current_streak: streakUpdate.currentStreak,
    daily_goal_progress: {
      reviews_completed: dailyGoalProgress.reviewsCompleted,
      target_reviews: dailyGoalProgress.targetReviews,
      goal_achieved: dailyGoalProgress.goalAchieved
    },
    new_achievements: newAchievements,
    challenge_updates: challengeUpdates.length > 0 ? challengeUpdates : undefined
  }

  const response: SubmitPracticeResponse = {
    success: true,
    data: responseData
  }

  // Log usage for profitability tracking (non-LLM feature)
  try {
    await services.usageLoggingService.logMemoryPractice(
      userContext.userId,
      userTier,
      body.practice_mode,
      body.memory_verse_id,
      isSuccessfulPractice,
      body.quality_rating
    )
  } catch (usageLogError) {
    console.error('Usage logging failed:', usageLogError)
    // Don't fail the request if usage logging fails
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type': 'application/json'
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleSubmitMemoryPractice, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000 // 15 seconds (longer due to multiple database operations)
})
