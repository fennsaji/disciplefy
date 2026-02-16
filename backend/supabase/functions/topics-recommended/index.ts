/**
 * Recommended Topics Edge Function
 *
 * Refactored to use the new clean architecture with:
 * - Function factory for boilerplate elimination
 * - Singleton services for performance
 * - Clean separation of concerns
 * - Optional progress data for authenticated users (Phase 1 Enhancement)
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

/**
 * Represents a recommended study guide topic
 */
interface RecommendedGuideTopic {
  readonly id: string
  readonly title: string
  readonly description: string
  readonly key_verses: readonly string[]
  readonly category: string
  readonly tags: readonly string[]
  readonly xp_value?: number
}

/**
 * Progress data for a topic
 */
interface TopicProgressData {
  readonly topic_id: string
  readonly started_at: string | null
  readonly completed_at: string | null
  readonly time_spent_seconds: number
  readonly xp_earned: number
  readonly is_completed: boolean
}

/**
 * Topic with optional progress data
 */
interface TopicWithProgress extends RecommendedGuideTopic {
  readonly progress?: TopicProgressData
}

/**
 * API response structure
 */
interface RecommendedGuideTopicsResponse extends ApiSuccessResponse<{
  readonly topics: readonly TopicWithProgress[]
  readonly categories: readonly string[]
  readonly total: number
  readonly progress_included?: boolean
}> {}

/**
 * Query parameters for filtering topics
 */
interface TopicsQueryParams {
  readonly category?: string
  readonly categories?: readonly string[]
  readonly language: string
  readonly limit: number
  readonly offset: number
  readonly include_progress?: boolean
}

// Configuration constants
const DEFAULT_LANGUAGE = 'en' as const
const DEFAULT_LIMIT = 20 as const
const DEFAULT_OFFSET = 0 as const
const MAX_LIMIT = 100 as const

/**
 * Main handler for recommended topics
 * Now supports optional progress data when include_progress=true and user is authenticated
 */
async function handleTopicsRecommended(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  // Parse and validate query parameters
  const queryParams = parseQueryParameters(req.url)

  // Get filtered topics
  const topicsData = await getFilteredTopics(services.topicsRepository, queryParams)

  // If progress is requested and user is authenticated, fetch progress data
  let topicsWithProgress: TopicWithProgress[] = topicsData.topics.map((t) => ({ ...t }))
  let progressIncluded = false

  if (
    queryParams.include_progress &&
    userContext?.type === 'authenticated' &&
    userContext.userId
  ) {
    const topicIds = topicsData.topics.map((t) => t.id)
    const progressData = await getUserProgressForTopics(
      services,
      userContext.userId,
      topicIds
    )

    // Merge progress data into topics
    topicsWithProgress = topicsData.topics.map((topic) => ({
      ...topic,
      progress: progressData.get(topic.id),
    }))
    progressIncluded = true
  }

  // Log analytics event
  await services.analyticsLogger.logEvent(
    'recommended_guide_topics_accessed',
    {
      category: queryParams.category,
      language: queryParams.language,
      total_results: topicsData.total,
      include_progress: progressIncluded,
    },
    req.headers.get('x-forwarded-for')
  )

  // Build response
  const response: RecommendedGuideTopicsResponse = {
    success: true,
    data: {
      topics: topicsWithProgress,
      categories: topicsData.categories,
      total: topicsData.total,
      progress_included: progressIncluded,
    },
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

/**
 * Parses and validates query parameters from request URL
 */
function parseQueryParameters(url: string): TopicsQueryParams {
  const urlObj = new URL(url)
  const searchParams = urlObj.searchParams

  const limit = parseInt(searchParams.get('limit') || String(DEFAULT_LIMIT))
  const offset = parseInt(searchParams.get('offset') || String(DEFAULT_OFFSET))

  // Parse categories parameter (comma-separated values)
  const categoriesParam = searchParams.get('categories')
  let categories: readonly string[] | undefined
  if (categoriesParam) {
    categories = categoriesParam.split(',').map(cat => cat.trim()).filter(cat => cat.length > 0)
    if (categories.length === 0) {
      categories = undefined
    }
  }

  // Validate limit parameter
  if (limit > MAX_LIMIT) {
    throw new AppError(
      'INVALID_PARAMETER', 
      `Limit cannot exceed ${MAX_LIMIT}`,
      400
    )
  }

  // Validate numeric parameters
  if (isNaN(limit) || limit < 1) {
    throw new AppError('INVALID_PARAMETER', 'Limit must be a positive integer', 400)
  }

  if (isNaN(offset) || offset < 0) {
    throw new AppError('INVALID_PARAMETER', 'Offset must be a non-negative integer', 400)
  }

  // Validate that only one of category or categories is provided
  if (searchParams.get('category') && categories) {
    throw new AppError(
      'INVALID_PARAMETER', 
      'Cannot specify both "category" and "categories" parameters. Use only one.',
      400
    )
  }

  // Parse include_progress parameter
  const includeProgress = searchParams.get('include_progress') === 'true'

  return {
    category: searchParams.get('category') || undefined,
    categories,
    language: searchParams.get('language') || DEFAULT_LANGUAGE,
    limit,
    offset,
    include_progress: includeProgress,
  }
}

/**
 * Retrieves and filters topics based on query parameters
 */
async function getFilteredTopics(
  repository: ServiceContainer['topicsRepository'], 
  params: TopicsQueryParams
): Promise<{
  topics: readonly RecommendedGuideTopic[]
  categories: readonly string[]
  total: number
}> {
  // Use the enhanced getTopics method that handles both single and multi-category filtering
  const topics = await repository.getTopics({
    category: params.category,
    categories: params.categories,
    language: params.language,
    limit: params.limit,
    offset: params.offset
  })

  // Get categories and total count
  const [categories, total] = await Promise.all([
    repository.getCategories(params.language),
    repository.getTopicsCount(params.category, params.language, params.categories)
  ])

  return {
    topics,
    categories,
    total,
  }
}

/**
 * Fetches user progress for a list of topic IDs
 */
async function getUserProgressForTopics(
  services: ServiceContainer,
  userId: string,
  topicIds: string[]
): Promise<Map<string, TopicProgressData>> {
  const progressMap = new Map<string, TopicProgressData>()

  if (topicIds.length === 0) {
    return progressMap
  }

  // Use the database function to get progress data
  const { data, error } = await services.supabaseServiceClient.rpc('get_user_topic_progress', {
    p_user_id: userId,
    p_topic_ids: topicIds,
  })

  if (error) {
    console.error('[topics-recommended] Error fetching progress:', error)
    // Don't fail the request, just return empty progress
    return progressMap
  }

  // Map progress data by topic_id
  if (data && Array.isArray(data)) {
    for (const progress of data) {
      progressMap.set(progress.topic_id, {
        topic_id: progress.topic_id,
        started_at: progress.started_at,
        completed_at: progress.completed_at,
        time_spent_seconds: progress.time_spent_seconds,
        xp_earned: progress.xp_earned,
        is_completed: progress.is_completed,
      })
    }
  }

  return progressMap
}

// Create the function with the factory
// Using createFunction to support optional user context for progress data
createFunction(handleTopicsRecommended, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 15000, // 15 seconds
  requireAuth: false, // Don't require auth, but allow it for progress data
})