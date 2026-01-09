/**
 * Token Usage History Edge Function
 *
 * Retrieves detailed token usage history for authenticated users with
 * optional aggregated statistics for analytics.
 *
 * Features:
 * - Paginated usage history retrieval
 * - Optional date range filtering
 * - Aggregate statistics (total tokens, feature breakdown, etc.)
 * - Security: RLS enforced, authenticated users only
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { UserContext } from '../_shared/types/index.ts'

// ============================================================================
// Types
// ============================================================================

interface UsageHistoryQueryParams {
  limit?: string
  offset?: string
  start_date?: string
  end_date?: string
  include_statistics?: string
}

interface TokenUsageRecord {
  id: string
  token_cost: number
  feature_name: string
  operation_type: string
  study_mode: string | null
  language: string
  content_title: string | null
  content_reference: string | null
  input_type: string | null
  user_plan: string
  session_id: string | null
  daily_tokens_used: number
  purchased_tokens_used: number
  created_at: string
}

interface UsageStatistics {
  total_tokens: number
  total_operations: number
  daily_tokens_consumed: number
  purchased_tokens_consumed: number
  most_used_feature: string | null
  most_used_language: string | null
  most_used_mode: string | null
  feature_breakdown: Array<{ feature_name: string; token_count: number; operation_count: number }>
  language_breakdown: Array<{ language: string; token_count: number }>
  study_mode_breakdown: Array<{ study_mode: string; token_count: number }>
  first_usage_date: string | null
  last_usage_date: string | null
}

interface UsageHistoryResponse {
  success: boolean
  data: {
    history: TokenUsageRecord[]
    statistics: UsageStatistics | null
    pagination: {
      limit: number
      offset: number
      returned: number
      has_more: boolean
    }
  }
}

// ============================================================================
// Validation & Parsing
// ============================================================================

/**
 * Validates and parses integer query parameter
 */
function parseIntParam(
  value: string | undefined,
  defaultValue: number,
  min: number,
  max: number
): number {
  if (!value) return defaultValue

  const parsed = parseInt(value, 10)
  if (isNaN(parsed)) return defaultValue
  if (parsed < min) return min
  if (parsed > max) return max

  return parsed
}

/**
 * Validates ISO8601 date string
 */
function validateDateParam(value: string | undefined): string | null {
  if (!value) return null

  try {
    const date = new Date(value)
    if (isNaN(date.getTime())) {
      throw new Error('Invalid date')
    }
    return date.toISOString()
  } catch {
    return null
  }
}

/**
 * Extracts and validates query parameters
 */
function extractQueryParams(req: Request): {
  limit: number
  offset: number
  startDate: string | null
  endDate: string | null
  includeStatistics: boolean
} {
  const url = new URL(req.url)

  const limit = parseIntParam(url.searchParams.get('limit') || undefined, 20, 1, 100)
  const offset = parseIntParam(url.searchParams.get('offset') || undefined, 0, 0, 999999)
  const startDate = validateDateParam(url.searchParams.get('start_date') || undefined)
  const endDate = validateDateParam(url.searchParams.get('end_date') || undefined)
  const includeStatistics = url.searchParams.get('include_statistics') === 'true'

  return { limit, offset, startDate, endDate, includeStatistics }
}

// ============================================================================
// Handler
// ============================================================================

/**
 * Token usage history handler
 */
async function handleTokenUsageHistory(
  req: Request,
  { supabaseServiceClient, authService }: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  // Only authenticated users can access usage history
  if (!userContext.userId) {
    throw new AppError(
      'AUTHENTICATION_REQUIRED',
      'Usage history is only available for authenticated users',
      401
    )
  }

  // Extract and validate query parameters
  const { limit, offset, startDate, endDate, includeStatistics } = extractQueryParams(req)

  console.log('📊 [USAGE-HISTORY] Fetching usage history:', {
    userId: userContext.userId,
    limit,
    offset,
    startDate,
    endDate,
    includeStatistics
  })

  // Fetch usage history using RPC function
  const { data: historyData, error: historyError } = await supabaseServiceClient.rpc(
    'get_user_token_usage_history',
    {
      p_user_id: userContext.userId,
      p_limit: limit,
      p_offset: offset,
      p_start_date: startDate,
      p_end_date: endDate
    }
  )

  if (historyError) {
    console.error('❌ [USAGE-HISTORY] Failed to fetch history:', historyError)
    throw new AppError(
      'DATABASE_ERROR',
      'Failed to retrieve token usage history',
      500
    )
  }

  const history: TokenUsageRecord[] = historyData || []

  console.log(`✅ [USAGE-HISTORY] Retrieved ${history.length} records`)

  // Optionally fetch statistics
  let statistics: UsageStatistics | null = null

  if (includeStatistics) {
    const { data: statsData, error: statsError } = await supabaseServiceClient.rpc(
      'get_user_token_usage_stats',
      {
        p_user_id: userContext.userId,
        p_start_date: startDate,
        p_end_date: endDate
      }
    )

    if (statsError) {
      console.error('⚠️  [USAGE-HISTORY] Failed to fetch statistics:', statsError)
      // Non-blocking - continue without statistics
    } else if (statsData && Array.isArray(statsData) && statsData.length > 0) {
      statistics = statsData[0] as UsageStatistics
      console.log('📈 [USAGE-HISTORY] Statistics retrieved')
    }
  }

  // Build response
  const response: UsageHistoryResponse = {
    success: true,
    data: {
      history,
      statistics,
      pagination: {
        limit,
        offset,
        returned: history.length,
        has_more: history.length === limit
      }
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// ============================================================================
// Export
// ============================================================================

createAuthenticatedFunction(handleTokenUsageHistory, {
  requireAuth: true,
  allowedMethods: ['GET']
})
