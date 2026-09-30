/**
 * Get Memory Champions Leaderboard Edge Function
 * 
 * Returns ranked leaderboard of memory verse champions based on:
 * - Primary: Total verses at Master level
 * - Tiebreaker 1: Longest practice streak
 * - Tiebreaker 2: Total practice days
 * 
 * Features:
 * - Top 100 users displayed
 * - User's rank always visible (exact rank, even if not in top 100)
 * - Aggregation/ranking done in SQL (get_memory_champions_leaderboard,
 *   get_memory_champion_rank); top list cached 5 min per worker
 * - period param (weekly/monthly/all_time) is validated; rankings are all-time
 * - User profile data (display name, avatar)
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Leaderboard entry structure
 */
interface LeaderboardEntry {
  readonly user_id: string
  readonly display_name: string
  readonly rank: number
  readonly master_verses: number
  readonly longest_streak: number
  readonly total_practice_days: number
  readonly avatar_url: string | null
}

/**
 * User memory statistics
 */
interface UserMemoryStats {
  readonly rank: number
  readonly master_verses: number
  readonly current_streak: number
  readonly longest_streak: number
  readonly total_practice_days: number
}

/**
 * Response data structure
 */
interface LeaderboardData {
  readonly leaderboard: readonly LeaderboardEntry[]
  readonly user_stats: UserMemoryStats
  readonly period: string
}

/**
 * API response structure
 */
interface LeaderboardResponse extends ApiSuccessResponse<LeaderboardData> {}

/** Global top list is identical for every caller: cache it per worker. */
const LEADERBOARD_CACHE_TTL_MS = 5 * 60 * 1000
const leaderboardCache = new Map<number, { expiresAt: number; entries: LeaderboardEntry[] }>()

/**
 * Fetch the ranked top list (aggregated and ranked in SQL, see
 * get_memory_champions_leaderboard). Cached for 5 minutes per limit.
 */
async function getLeaderboard(
  supabaseClient: SupabaseClient,
  limit: number
): Promise<LeaderboardEntry[]> {
  const cached = leaderboardCache.get(limit)
  if (cached && cached.expiresAt > Date.now()) {
    return cached.entries
  }

  const { data, error } = await supabaseClient.rpc('get_memory_champions_leaderboard', {
    p_limit: limit
  })

  if (error) {
    console.error('[Leaderboard] Leaderboard RPC error:', error.message)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch leaderboard', 500)
  }

  const entries: LeaderboardEntry[] = (data ?? []).map((row: LeaderboardEntry) => ({
    user_id: row.user_id,
    display_name: row.display_name,
    rank: Number(row.rank),
    master_verses: row.master_verses,
    longest_streak: row.longest_streak,
    total_practice_days: row.total_practice_days,
    avatar_url: row.avatar_url
  }))

  leaderboardCache.set(limit, { expiresAt: Date.now() + LEADERBOARD_CACHE_TTL_MS, entries })
  return entries
}

/**
 * Get the caller's own rank and statistics (always fresh, never cached).
 */
async function getUserStats(
  supabaseClient: SupabaseClient,
  userId: string
): Promise<UserMemoryStats> {
  const { data, error } = await supabaseClient
    .rpc('get_memory_champion_rank', { p_user_id: userId })
    .maybeSingle()

  if (error) {
    console.error('[Leaderboard] User rank RPC error:', error.message)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch user statistics', 500)
  }

  const row = data as UserMemoryStats | null
  return {
    rank: Number(row?.rank ?? 1),
    master_verses: row?.master_verses ?? 0,
    current_streak: row?.current_streak ?? 0,
    longest_streak: row?.longest_streak ?? 0,
    total_practice_days: row?.total_practice_days ?? 0
  }
}

/**
 * Main handler for fetching leaderboard
 */
async function handleGetMemoryChampionsLeaderboard(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to access leaderboard', 401)
  }

  // Parse query parameters
  const url = new URL(req.url)
  const periodParam = url.searchParams.get('period') || 'all_time'
  const limitParam = url.searchParams.get('limit') || '100'

  // Validate period
  const allowedPeriods = ['weekly', 'monthly', 'all_time']
  if (!allowedPeriods.includes(periodParam)) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Invalid period. Allowed values: ${allowedPeriods.join(', ')}`,
      400
    )
  }

  // Validate limit
  const limit = parseInt(limitParam, 10)
  if (isNaN(limit) || limit < 1 || limit > 100) {
    throw new AppError('VALIDATION_ERROR', 'limit must be between 1 and 100', 400)
  }

  // Period is validated for API compatibility; rankings are all-time.
  const [leaderboard, userStats] = await Promise.all([
    getLeaderboard(services.supabaseServiceClient, limit),
    getUserStats(services.supabaseServiceClient, userContext.userId)
  ])

  // Log analytics event
  await services.analyticsLogger.logEvent('memory_leaderboard_viewed', {
    user_id: userContext.userId,
    period: periodParam,
    user_rank: userStats.rank
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const responseData: LeaderboardData = {
    leaderboard,
    user_stats: userStats,
    period: periodParam
  }

  const response: LeaderboardResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json',
      'Cache-Control': 'private, max-age=300' // Per-user payload (user_stats): browser-only cache, 5 minutes
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleGetMemoryChampionsLeaderboard, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 30000
})
