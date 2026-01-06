/**
 * Submit Memory Verse Review Edge Function
 * 
 * Processes a user's review of a memory verse and updates the SM-2 algorithm state.
 * Calculates the next review interval based on the quality rating.
 * 
 * Features:
 * - SM-2 spaced repetition algorithm implementation
 * - Records review session with quality rating
 * - Updates verse scheduling and statistics
 * - Aggregates daily review history
 * - Validates quality ratings (0-5)
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { getIntervalForReviewsSinceMastery } from '../_shared/memory-verse-intervals.ts'

/**
 * Request payload structure
 */
interface SubmitReviewRequest {
  readonly memory_verse_id: string
  readonly quality_rating: number // 0-5 SM-2 scale
  readonly time_spent_seconds?: number
}

/**
 * SM-2 algorithm input
 */
interface SM2Input {
  readonly quality: number // 0-5
  readonly easeFactor: number // Current ease factor
  readonly interval: number // Current interval in days
  readonly repetitions: number // Current repetition count
}

/**
 * SM-2 algorithm output
 */
interface SM2Result {
  readonly easeFactor: number // New ease factor
  readonly interval: number // New interval in days
  readonly repetitions: number // New repetition count
  readonly nextReviewDate: string // ISO 8601 timestamp
}

/**
 * Response data structure
 */
interface SubmitReviewData {
  readonly success: boolean
  readonly next_review_date: string
  readonly interval_days: number
  readonly ease_factor: number
  readonly repetitions: number
  readonly total_reviews: number
  readonly streak_maintained: boolean
}

/**
 * API response structure
 */
interface SubmitReviewResponse extends ApiSuccessResponse<SubmitReviewData> {}

/**
 * Implements the SM-2 spaced repetition algorithm.
 * 
 * Algorithm details:
 * - Quality rating 0-5:
 *   - 0: Complete blackout
 *   - 1: Incorrect response, correct answer seemed familiar
 *   - 2: Incorrect response, correct answer remembered
 *   - 3: Correct response, but required significant effort
 *   - 4: Correct response, after some hesitation
 *   - 5: Perfect recall
 * 
 * - If quality < 3: Reset interval to 1 day and repetitions to 0
 * - If quality >= 3: Increase interval based on repetitions
 * - Ease factor adjusts based on quality (harder/easier over time)
 * 
 * @param input - Current SM-2 state and quality rating
 * @returns New SM-2 state and next review date
 */
function calculateSM2(input: SM2Input): SM2Result {
  const { quality, easeFactor, interval, repetitions } = input

  // Constants
  const MAX_INTERVAL_DAYS = 180 // 6 months maximum
  const DAILY_REVIEW_PERIOD = 14 // First 14 successful reviews are daily

  // Validate quality rating
  if (quality < 0 || quality > 5) {
    throw new AppError('VALIDATION_ERROR', 'quality_rating must be between 0 and 5', 400)
  }

  // Calculate new ease factor
  // Formula: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
  let newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))

  // Ensure ease factor doesn't go below 1.3
  if (newEaseFactor < 1.3) {
    newEaseFactor = 1.3
  }

  // Round to 2 decimal places
  newEaseFactor = Math.round(newEaseFactor * 100) / 100

  let newInterval: number
  let newRepetitions: number

  // If quality < 3, reset to daily review
  if (quality < 3) {
    newInterval = 1
    newRepetitions = 0
  } else {
    // Successful recall - increase repetition count
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

  // Calculate next review date
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
 * Updates or creates daily review history record
 */
async function updateReviewHistory(
  supabaseClient: any,
  userId: string,
  memoryVerseId: string,
  qualityRating: number
): Promise<void> {
  const today = new Date().toISOString().split('T')[0] // YYYY-MM-DD

  // Check if history record exists for today
  const { data: existingHistory } = await supabaseClient
    .from('review_history')
    .select('*')
    .eq('user_id', userId)
    .eq('memory_verse_id', memoryVerseId)
    .eq('review_date', today)
    .maybeSingle()

  if (existingHistory) {
    // Update existing record
    const newCount = existingHistory.reviews_count + 1
    const newAverage = 
      (existingHistory.average_quality * existingHistory.reviews_count + qualityRating) / newCount

    await supabaseClient
      .from('review_history')
      .update({
        reviews_count: newCount,
        average_quality: Math.round(newAverage * 100) / 100
      })
      .eq('id', existingHistory.id)
  } else {
    // Create new record
    await supabaseClient
      .from('review_history')
      .insert({
        user_id: userId,
        memory_verse_id: memoryVerseId,
        review_date: today,
        reviews_count: 1,
        average_quality: qualityRating
      })
  }
}

/**
 * Main handler for submitting review
 */
async function handleSubmitMemoryVerseReview(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to submit reviews', 401)
  }

  // Parse request body
  let body: SubmitReviewRequest
  try {
    body = await req.json() as SubmitReviewRequest
  } catch (error) {
    throw new AppError('VALIDATION_ERROR', 'Invalid JSON payload', 400)
  }

  // Validate required fields
  if (!body.memory_verse_id) {
    throw new AppError('VALIDATION_ERROR', 'memory_verse_id is required', 400)
  }

  if (body.quality_rating === undefined || body.quality_rating === null) {
    throw new AppError('VALIDATION_ERROR', 'quality_rating is required', 400)
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

  // Validate time_spent_seconds if provided
  if (body.time_spent_seconds !== undefined) {
    if (!Number.isInteger(body.time_spent_seconds) || body.time_spent_seconds < 0) {
      throw new AppError('VALIDATION_ERROR', 'time_spent_seconds must be a positive integer', 400)
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
    console.error('[SubmitReview] Verse not found:', fetchError)
    throw new AppError('NOT_FOUND', 'Memory verse not found', 404)
  }

  // Calculate new SM-2 state
  const sm2Result = calculateSM2({
    quality: body.quality_rating,
    easeFactor: memoryVerse.ease_factor,
    interval: memoryVerse.interval_days,
    repetitions: memoryVerse.repetitions
  })

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
      updated_at: now
    })
    .eq('id', body.memory_verse_id)

  if (updateError) {
    console.error('[SubmitReview] Update error:', updateError)
    throw new AppError('DATABASE_ERROR', 'Failed to update memory verse', 500)
  }

  // Record the review session
  const { error: sessionError } = await services.supabaseServiceClient
    .from('review_sessions')
    .insert({
      user_id: userContext.userId,
      memory_verse_id: body.memory_verse_id,
      review_date: now,
      quality_rating: body.quality_rating,
      new_ease_factor: sm2Result.easeFactor,
      new_interval_days: sm2Result.interval,
      new_repetitions: sm2Result.repetitions,
      time_spent_seconds: body.time_spent_seconds || null
    })

  if (sessionError) {
    console.error('[SubmitReview] Session error:', sessionError)
    // Don't fail the request if session recording fails
  }

  // Update review history
  try {
    await updateReviewHistory(
      services.supabaseServiceClient,
      userContext.userId,
      body.memory_verse_id,
      body.quality_rating
    )
  } catch (historyError) {
    console.error('[SubmitReview] History error:', historyError)
    // Don't fail the request if history update fails
  }

  // Check if streak is maintained (quality >= 3)
  const streakMaintained = body.quality_rating >= 3

  // Log analytics event (non-fatal - don't fail the request if analytics fails)
  try {
    await services.analyticsLogger.logEvent('memory_verse_reviewed', {
      user_id: userContext.userId,
      memory_verse_id: body.memory_verse_id,
      quality_rating: body.quality_rating,
      new_interval_days: sm2Result.interval,
      new_repetitions: sm2Result.repetitions,
      streak_maintained: streakMaintained,
      time_spent_seconds: body.time_spent_seconds
    }, req.headers.get('x-forwarded-for'))
  } catch (analyticsError) {
    console.error('[SubmitReview] Analytics logging failed:', {
      error: analyticsError,
      user_id: userContext.userId,
      memory_verse_id: body.memory_verse_id,
      ip: req.headers.get('x-forwarded-for')
    })
    // Don't rethrow - analytics failures should not block the review submission
  }

  // Build response data
  const responseData: SubmitReviewData = {
    success: true,
    next_review_date: sm2Result.nextReviewDate,
    interval_days: sm2Result.interval,
    ease_factor: sm2Result.easeFactor,
    repetitions: sm2Result.repetitions,
    total_reviews: memoryVerse.total_reviews + 1,
    streak_maintained: streakMaintained
  }

  const response: SubmitReviewResponse = {
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
createAuthenticatedFunction(handleSubmitMemoryVerseReview, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
