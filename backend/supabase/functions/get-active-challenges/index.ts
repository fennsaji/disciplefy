/**
 * Get Active Challenges Edge Function
 * 
 * Retrieves all active memory verse challenges with user's progress.
 * 
 * Features:
 * - Fetches active challenges (within date range, is_active=true)
 * - Includes user's current progress for each challenge
 * - Creates progress records if they don't exist
 * - Returns challenge details, target, progress, and rewards
 * 
 * Version: 2.5.0 - Memory Verses Enhancement (Sprint 4)
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Challenge with user progress
 */
interface ChallengeWithProgress {
  readonly id: string
  readonly challenge_type: 'daily' | 'weekly' | 'monthly'
  readonly target_type: 'reviews_count' | 'new_verses' | 'mastery_level' | 
                        'perfect_recalls' | 'streak_days' | 'modes_tried'
  readonly target_value: number
  readonly xp_reward: number
  readonly badge_icon: string | null
  readonly start_date: string
  readonly end_date: string
  readonly current_progress: number
  readonly is_completed: boolean
  readonly completed_at: string | null
  readonly xp_claimed: boolean
  readonly time_remaining_seconds: number
}

/**
 * Response data structure
 */
interface ActiveChallengesData {
  readonly challenges: readonly ChallengeWithProgress[]
  readonly total_active: number
  readonly completed_count: number
  readonly total_xp_available: number
}

/**
 * API response structure
 */
interface GetActiveChallengesResponse extends ApiSuccessResponse<ActiveChallengesData> {}

/**
 * Main handler for fetching active challenges
 */
async function handleGetActiveChallenges(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to access challenges', 401)
  }

  const now = new Date().toISOString()

  // Fetch active challenges
  const { data: activeChallenges, error: fetchError } = await services.supabaseServiceClient
    .from('memory_challenges')
    .select('*')
    .eq('is_active', true)
    .lte('start_date', now)
    .gte('end_date', now)
    .order('end_date', { ascending: true })

  if (fetchError) {
    console.error('[GetActiveChallenges] Fetch error:', fetchError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch active challenges', 500)
  }

  if (!activeChallenges || activeChallenges.length === 0) {
    // No active challenges
    const response: GetActiveChallengesResponse = {
      success: true,
      data: {
        challenges: [],
        total_active: 0,
        completed_count: 0,
        total_xp_available: 0
      }
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  // Get user's progress for these challenges
  const challengeIds = activeChallenges.map(c => c.id)
  
  const { data: userProgress, error: progressError } = await services.supabaseServiceClient
    .from('user_challenge_progress')
    .select('*')
    .eq('user_id', userContext.userId)
    .in('challenge_id', challengeIds)

  if (progressError) {
    console.error('[GetActiveChallenges] Progress fetch error:', progressError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch challenge progress', 500)
  }

  // Create a map of challenge_id -> progress
  const progressMap = new Map<string, any>()
  if (userProgress) {
    for (const progress of userProgress) {
      progressMap.set(progress.challenge_id, progress)
    }
  }

  // Create progress records for challenges without them
  const challengesToCreate = activeChallenges.filter(
    c => !progressMap.has(c.id)
  )

  if (challengesToCreate.length > 0) {
    const newProgressRecords = challengesToCreate.map(challenge => ({
      user_id: userContext.userId,
      challenge_id: challenge.id,
      current_progress: 0,
      is_completed: false,
      xp_claimed: false
    }))

    const { data: createdProgress, error: createError } = await services.supabaseServiceClient
      .from('user_challenge_progress')
      .insert(newProgressRecords)
      .select()

    if (createError) {
      console.error('[GetActiveChallenges] Create progress error:', createError)
      // Continue even if creation fails - we'll use default values
    } else if (createdProgress) {
      // Add newly created records to the map
      for (const progress of createdProgress) {
        progressMap.set(progress.challenge_id, progress)
      }
    }
  }

  // Combine challenges with progress
  const challengesWithProgress: ChallengeWithProgress[] = activeChallenges.map(challenge => {
    const progress = progressMap.get(challenge.id) || {
      current_progress: 0,
      is_completed: false,
      completed_at: null,
      xp_claimed: false
    }

    // Calculate time remaining
    const endDate = new Date(challenge.end_date)
    const nowDate = new Date()
    const timeRemainingMs = endDate.getTime() - nowDate.getTime()
    const timeRemainingSeconds = Math.max(0, Math.floor(timeRemainingMs / 1000))

    return {
      id: challenge.id,
      challenge_type: challenge.challenge_type,
      target_type: challenge.target_type,
      target_value: challenge.target_value,
      xp_reward: challenge.xp_reward,
      badge_icon: challenge.badge_icon,
      start_date: challenge.start_date,
      end_date: challenge.end_date,
      current_progress: progress.current_progress,
      is_completed: progress.is_completed,
      completed_at: progress.completed_at,
      xp_claimed: progress.xp_claimed,
      time_remaining_seconds: timeRemainingSeconds
    }
  })

  // Calculate statistics
  const completedCount = challengesWithProgress.filter(c => c.is_completed).length
  const totalXpAvailable = challengesWithProgress
    .filter(c => !c.xp_claimed)
    .reduce((sum, c) => sum + c.xp_reward, 0)

  // Log analytics event
  await services.analyticsLogger.logEvent('active_challenges_fetched', {
    user_id: userContext.userId,
    total_active: challengesWithProgress.length,
    completed_count: completedCount
  }, req.headers.get('x-forwarded-for'))

  const response: GetActiveChallengesResponse = {
    success: true,
    data: {
      challenges: challengesWithProgress,
      total_active: challengesWithProgress.length,
      completed_count: completedCount,
      total_xp_available: totalXpAvailable
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store, no-cache, must-revalidate'
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleGetActiveChallenges, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
