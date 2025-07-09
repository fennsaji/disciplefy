import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

import { corsHeaders } from '../_shared/cors.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { RequestValidator } from '../_shared/request-validator.ts'
import { AnalyticsLogger } from '../_shared/analytics-logger.ts'
import { TopicsRepository } from './topics-repository.ts'

/**
 * Represents a recommended study guide topic for Bible study.
 * 
 * Based on structured Bible study methodology:
 * - Context: Historical and cultural background
 * - Scholar's Guide: Original meaning and interpretation  
 * - Group Discussion: Contemporary application questions
 * - Application: Personal life transformation steps
 */
interface RecommendedGuideTopic {
  readonly id: string
  readonly title: string
  readonly description: string
  readonly difficulty_level: 'beginner' | 'intermediate' | 'advanced'
  readonly estimated_duration: string
  readonly key_verses: readonly string[]
  readonly category: string
  readonly tags: readonly string[]
}

/**
 * Response structure for Recommended Guide topics API endpoint.
 */
interface RecommendedGuideTopicsResponse {
  readonly topics: readonly RecommendedGuideTopic[]
  readonly categories: readonly string[]
  readonly total: number
}

/**
 * Query parameters for filtering Recommended Guide topics.
 */
interface TopicsQueryParams {
  readonly category?: string
  readonly difficulty?: string
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
 * Edge Function: Recommended Guide Topics
 * 
 * Provides access to curated Bible study topics following structured methodology.
 * Supports filtering by category, difficulty, and pagination.
 * 
 * @param req - HTTP request object
 * @returns Response with topics data or error
 */
serve(async (req: Request): Promise<Response> => {
  // Handle preflight CORS requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Validate HTTP method
    validateHttpMethod(req.method)

    // Parse and validate query parameters
    const queryParams = parseQueryParameters(req.url)

    // Initialize dependencies
    const supabaseClient = createSupabaseClient()
    const topicsRepository = new TopicsRepository()
    const analyticsLogger = new AnalyticsLogger(supabaseClient)

    // Get filtered topics
    const topicsData = await getFilteredTopics(topicsRepository, queryParams)

    // Log analytics event
    await logTopicsAccess(analyticsLogger, req, queryParams, topicsData.total)

    // Build successful response
    const response: RecommendedGuideTopicsResponse = {
      topics: topicsData.topics,
      categories: topicsData.categories,
      total: topicsData.total
    }

    return createSuccessResponse(response)

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

/**
 * Validates that the HTTP method is allowed for this endpoint.
 * 
 * @param method - HTTP method from request
 * @throws {AppError} When method is not GET
 */
function validateHttpMethod(method: string): void {
  if (method !== 'GET') {
    throw new AppError(
      'METHOD_NOT_ALLOWED', 
      'Only GET requests are allowed for this endpoint', 
      405
    )
  }
}

/**
 * Parses and validates query parameters from the request URL.
 * 
 * @param url - Request URL string
 * @returns Validated query parameters
 * @throws {AppError} When parameters are invalid
 */
function parseQueryParameters(url: string): TopicsQueryParams {
  const urlObj = new URL(url)
  const searchParams = urlObj.searchParams

  const limit = parseInt(searchParams.get('limit') || String(DEFAULT_LIMIT))
  const offset = parseInt(searchParams.get('offset') || String(DEFAULT_OFFSET))

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

  return {
    category: searchParams.get('category') || undefined,
    difficulty: searchParams.get('difficulty') || undefined,
    language: searchParams.get('language') || DEFAULT_LANGUAGE,
    limit,
    offset
  }
}

/**
 * Creates a configured Supabase client instance.
 * 
 * @returns Initialized Supabase client
 * @throws {AppError} When environment variables are missing
 */
function createSupabaseClient() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new AppError(
      'CONFIGURATION_ERROR',
      'Missing required Supabase configuration',
      500
    )
  }

  return createClient(supabaseUrl, supabaseAnonKey)
}

/**
 * Retrieves and filters topics based on query parameters.
 * 
 * @param repository - Topics repository instance
 * @param params - Query parameters for filtering
 * @returns Filtered topics with metadata
 */
async function getFilteredTopics(
  repository: TopicsRepository, 
  params: TopicsQueryParams
): Promise<{
  topics: readonly RecommendedGuideTopic[]
  categories: readonly string[]
  total: number
}> {
  // Get all topics for the specified language
  const allTopics = await repository.getTopicsByLanguage(params.language)

  // Apply filters
  let filteredTopics = allTopics

  if (params.category) {
    filteredTopics = filterByCategory(filteredTopics, params.category)
  }

  if (params.difficulty) {
    filteredTopics = filterByDifficulty(filteredTopics, params.difficulty)
  }

  // Apply pagination
  const paginatedTopics = applyPagination(filteredTopics, params.limit, params.offset)

  // Extract unique categories
  const categories = extractUniqueCategories(allTopics)

  return {
    topics: paginatedTopics,
    categories,
    total: filteredTopics.length
  }
}

/**
 * Filters topics by category (case-insensitive).
 * 
 * @param topics - Topics to filter
 * @param category - Category to filter by
 * @returns Filtered topics array
 */
function filterByCategory(
  topics: readonly RecommendedGuideTopic[], 
  category: string
): readonly RecommendedGuideTopic[] {
  const normalizedCategory = category.toLowerCase()
  return topics.filter(topic => 
    topic.category.toLowerCase() === normalizedCategory
  )
}

/**
 * Filters topics by difficulty level.
 * 
 * @param topics - Topics to filter  
 * @param difficulty - Difficulty level to filter by
 * @returns Filtered topics array
 */
function filterByDifficulty(
  topics: readonly RecommendedGuideTopic[], 
  difficulty: string
): readonly RecommendedGuideTopic[] {
  return topics.filter(topic => topic.difficulty_level === difficulty)
}

/**
 * Applies pagination to the topics array.
 * 
 * @param topics - Topics to paginate
 * @param limit - Maximum number of topics to return
 * @param offset - Number of topics to skip
 * @returns Paginated topics array
 */
function applyPagination(
  topics: readonly RecommendedGuideTopic[], 
  limit: number, 
  offset: number
): readonly RecommendedGuideTopic[] {
  return topics.slice(offset, offset + limit)
}

/**
 * Extracts unique categories from topics array.
 * 
 * @param topics - Topics to extract categories from
 * @returns Array of unique category names
 */
function extractUniqueCategories(topics: readonly RecommendedGuideTopic[]): readonly string[] {
  return [...new Set(topics.map(topic => topic.category))]
}

/**
 * Logs analytics event for topics access.
 * 
 * @param logger - Analytics logger instance
 * @param req - HTTP request object
 * @param params - Query parameters
 * @param totalResults - Total number of results
 */
async function logTopicsAccess(
  logger: AnalyticsLogger,
  req: Request,
  params: TopicsQueryParams,
  totalResults: number
): Promise<void> {
  await logger.logEvent('recommended_guide_topics_accessed', {
    category: params.category,
    difficulty: params.difficulty,
    language: params.language,
    total_results: totalResults
  }, req.headers.get('x-forwarded-for'))
}

/**
 * Creates a successful HTTP response with topics data.
 * 
 * @param data - Response data to return
 * @returns HTTP response object
 */
function createSuccessResponse(data: RecommendedGuideTopicsResponse): Response {
  return new Response(
    JSON.stringify({
      success: true,
      data
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}