/**
 * Get Memory Streak Edge Function
 * 
 * Retrieves the user's memory verse practice streak data.
 * Creates a new streak record if one doesn't exist.
 * 
 * Features:
 * - Gets or creates memory streak record
 * - Returns current and longest streaks
 * - Includes milestone achievement dates
 * - Shows freeze days available and used
 * - Provides total practice days count
 * 
 * Version: 2.4.0 - Memory Verses Enhancement (Sprint 3)
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Database function output structure (with out_ prefix to avoid SQL ambiguity)
 */
interface MemoryStreakDbResult {
  readonly out_user_id: string
  readonly out_current_streak: number
  readonly out_longest_streak: number
  readonly out_last_practice_date: string | null
  readonly out_total_practice_days: number
  readonly out_freeze_days_available: number
  readonly out_freeze_days_used: number
  readonly out_milestone_10_date: string | null
  readonly out_milestone_30_date: string | null
  readonly out_milestone_100_date: string | null
  readonly out_milestone_365_date: string | null
  readonly out_created_at: string
  readonly out_updated_at: string
}

/**
 * API response structure (without out_ prefix for clean API)
 */
interface MemoryStreak {
  readonly user_id: string
  readonly current_streak: number
  readonly longest_streak: number
  readonly last_practice_date: string | null
  readonly total_practice_days: number
  readonly freeze_days_available: number
  readonly freeze_days_used: number
  readonly milestone_10_date: string | null
  readonly milestone_30_date: string | null
  readonly milestone_100_date: string | null
  readonly milestone_365_date: string | null
  readonly created_at: string
  readonly updated_at: string
}

/**
 * API response structure
 */
interface GetMemoryStreakResponse extends ApiSuccessResponse<MemoryStreak> {}

/**
 * Main handler for fetching memory streak
 */
async function handleGetMemoryStreak(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to access memory streak', 401)
  }

  // Call RPC function to get or create streak
  const { data: rpcData, error: rpcError } = await services.supabaseServiceClient
    .rpc('get_or_create_memory_streak', {
      p_user_id: userContext.userId
    })
    .single()

  if (rpcError) {
    console.error('[GetMemoryStreak] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch memory streak', 500)
  }

  if (!rpcData) {
    throw new AppError('DATABASE_ERROR', 'No streak data returned', 500)
  }

  // Cast to typed streak data from database function
  const streakData = rpcData as MemoryStreakDbResult

  // Log analytics event
  await services.analyticsLogger.logEvent('memory_streak_fetched', {
    user_id: userContext.userId,
    current_streak: streakData.out_current_streak,
    longest_streak: streakData.out_longest_streak,
    freeze_days_available: streakData.out_freeze_days_available
  }, req.headers.get('x-forwarded-for'))

  // Map database function output to API response format (remove out_ prefix)
  const response: GetMemoryStreakResponse = {
    success: true,
    data: {
      user_id: streakData.out_user_id,
      current_streak: streakData.out_current_streak,
      longest_streak: streakData.out_longest_streak,
      last_practice_date: streakData.out_last_practice_date,
      total_practice_days: streakData.out_total_practice_days,
      freeze_days_available: streakData.out_freeze_days_available,
      freeze_days_used: streakData.out_freeze_days_used,
      milestone_10_date: streakData.out_milestone_10_date,
      milestone_30_date: streakData.out_milestone_30_date,
      milestone_100_date: streakData.out_milestone_100_date,
      milestone_365_date: streakData.out_milestone_365_date,
      created_at: streakData.out_created_at,
      updated_at: streakData.out_updated_at
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store, no-cache, must-revalidate' // Don't cache streak data
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleGetMemoryStreak, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
