/**
 * Get Due Memory Verses Edge Function
 * 
 * Fetches all memory verses that are due for review based on SM-2 scheduling.
 * Returns verses ordered by priority (most overdue first).
 * 
 * Features:
 * - Retrieves verses due for review (next_review_date <= now)
 * - Orders by review priority (most overdue first)
 * - Includes review statistics (total due, reviewed today)
 * - Supports pagination for large decks
 * - Optional language filtering
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Memory verse structure
 */
interface MemoryVerse {
  readonly id: string
  readonly verse_reference: string
  readonly verse_text: string
  readonly language: string
  readonly source_type: string
  readonly source_id: string | null
  readonly ease_factor: number
  readonly interval_days: number
  readonly repetitions: number
  readonly next_review_date: string
  readonly last_reviewed: string | null
  readonly total_reviews: number
  readonly added_date: string
}

/**
 * Review statistics
 */
interface ReviewStatistics {
  readonly total_verses: number
  readonly due_verses: number
  readonly reviewed_today: number
  readonly upcoming_reviews: number
  readonly mastered_verses: number // repetitions >= 5
}

/**
 * Response data structure
 */
interface DueVersesData {
  readonly verses: readonly MemoryVerse[]
  readonly statistics: ReviewStatistics
  readonly pagination: {
    readonly limit: number
    readonly offset: number
    readonly has_more: boolean
  }
}

/**
 * API response structure
 */
interface DueVersesResponse extends ApiSuccessResponse<DueVersesData> {}

/**
 * Fetches review statistics for the user
 */
async function getReviewStatistics(
  supabaseClient: any,
  userId: string
): Promise<ReviewStatistics> {
  const now = new Date().toISOString()
  const today = new Date().toISOString().split('T')[0] // YYYY-MM-DD format

  // Get total verses count
  const { count: totalCount } = await supabaseClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)

  // Get due verses count (next_review_date <= now)
  const { count: dueCount } = await supabaseClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .lte('next_review_date', now)

  // Get reviewed today count from review_sessions
  const { count: reviewedTodayCount } = await supabaseClient
    .from('review_sessions')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('review_date', `${today}T00:00:00.000Z`)
    .lte('review_date', `${today}T23:59:59.999Z`)

  // Get upcoming reviews count (next_review_date > now AND next_review_date <= now + 7 days)
  const nextWeek = new Date()
  nextWeek.setDate(nextWeek.getDate() + 7)
  const nextWeekStr = nextWeek.toISOString()

  const { count: upcomingCount } = await supabaseClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gt('next_review_date', now)
    .lte('next_review_date', nextWeekStr)

  // Get mastered verses count (repetitions >= 5)
  const { count: masteredCount } = await supabaseClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('repetitions', 5)

  return {
    total_verses: totalCount || 0,
    due_verses: dueCount || 0,
    reviewed_today: reviewedTodayCount || 0,
    upcoming_reviews: upcomingCount || 0,
    mastered_verses: masteredCount || 0
  }
}

/**
 * Main handler for fetching due verses
 */
async function handleGetDueMemoryVerses(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to access memory verses', 401)
  }

  // Parse query parameters
  const url = new URL(req.url)
  const limitParam = url.searchParams.get('limit')
  const offsetParam = url.searchParams.get('offset')
  const languageParam = url.searchParams.get('language')
  const showAll = url.searchParams.get('show_all') === 'true'

  // Validate and parse pagination parameters
  let limit = 20 // Default limit
  let offset = 0 // Default offset

  if (limitParam) {
    const parsedLimit = parseInt(limitParam, 10)
    if (isNaN(parsedLimit) || parsedLimit < 1 || parsedLimit > 100) {
      throw new AppError('VALIDATION_ERROR', 'limit must be between 1 and 100', 400)
    }
    limit = parsedLimit
  }

  if (offsetParam) {
    const parsedOffset = parseInt(offsetParam, 10)
    if (isNaN(parsedOffset) || parsedOffset < 0) {
      throw new AppError('VALIDATION_ERROR', 'offset must be >= 0', 400)
    }
    offset = parsedOffset
  }

  // Validate language parameter
  const allowedLanguages = ['en', 'hi', 'ml']
  if (languageParam && !allowedLanguages.includes(languageParam)) {
    throw new AppError(
      'VALIDATION_ERROR', 
      `Invalid language. Allowed values: ${allowedLanguages.join(', ')}`, 
      400
    )
  }

  // Build query for verses
  const now = new Date().toISOString()
  let query = services.supabaseServiceClient
    .from('memory_verses')
    .select('*')
    .eq('user_id', userContext.userId)

  // Apply due date filter only if not showing all verses
  if (!showAll) {
    query = query.lte('next_review_date', now)
  }

  // Apply language filter if provided
  if (languageParam) {
    query = query.eq('language', languageParam)
  }

  // Order by next_review_date (most overdue first, then upcoming)
  query = query.order('next_review_date', { ascending: true })

  // Apply pagination
  query = query.range(offset, offset + limit - 1)

  // Execute query
  const { data: verses, error: fetchError } = await query

  if (fetchError) {
    console.error('[GetDueVerses] Fetch error:', fetchError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch due verses', 500)
  }

  // Check if there are more verses beyond the current page
  let countQuery = services.supabaseServiceClient
    .from('memory_verses')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userContext.userId)

  // Apply same filter as main query
  if (!showAll) {
    countQuery = countQuery.lte('next_review_date', now)
  }

  const { count: totalCount } = await countQuery
  const hasMore = (offset + limit) < (totalCount || 0)

  // Get review statistics
  const statistics = await getReviewStatistics(
    services.supabaseServiceClient,
    userContext.userId
  )

  // Log analytics event
  await services.analyticsLogger.logEvent('memory_verses_due_fetched', {
    user_id: userContext.userId,
    verses_count: verses?.length || 0,
    limit,
    offset,
    language: languageParam || 'all'
  }, req.headers.get('x-forwarded-for'))

  // Build response data
  const responseData: DueVersesData = {
    verses: verses || [],
    statistics,
    pagination: {
      limit,
      offset,
      has_more: hasMore
    }
  }

  const response: DueVersesResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store, no-cache, must-revalidate' // Don't cache review data
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleGetDueMemoryVerses, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
