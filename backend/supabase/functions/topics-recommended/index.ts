/**
 * Recommended Topics Edge Function
 * 
 * Refactored to use the new clean architecture with:
 * - Function factory for boilerplate elimination
 * - Singleton services for performance
 * - Clean separation of concerns
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

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
}

/**
 * API response structure
 */
interface RecommendedGuideTopicsResponse extends ApiSuccessResponse<{
  readonly topics: readonly RecommendedGuideTopic[]
  readonly categories: readonly string[]
  readonly total: number
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
}

// Configuration constants
const DEFAULT_LANGUAGE = 'en' as const
const DEFAULT_LIMIT = 20 as const
const DEFAULT_OFFSET = 0 as const
const MAX_LIMIT = 100 as const

/**
 * Main handler for recommended topics
 */
async function handleTopicsRecommended(req: Request, services: ServiceContainer): Promise<Response> {
  // Parse and validate query parameters
  const queryParams = parseQueryParameters(req.url)

  // Get filtered topics
  const topicsData = await getFilteredTopics(services.topicsRepository, queryParams)

  // Log analytics event
  await services.analyticsLogger.logEvent('recommended_guide_topics_accessed', {
    category: queryParams.category,
    language: queryParams.language,
    total_results: topicsData.total
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: RecommendedGuideTopicsResponse = {
    success: true,
    data: {
      topics: topicsData.topics,
      categories: topicsData.categories,
      total: topicsData.total
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
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

  return {
    category: searchParams.get('category') || undefined,
    categories,
    language: searchParams.get('language') || DEFAULT_LANGUAGE,
    limit,
    offset
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
    total
  }
}

// Create the function with the factory
createSimpleFunction(handleTopicsRecommended, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 15000 // 15 seconds
})