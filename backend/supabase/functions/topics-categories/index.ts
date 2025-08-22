/**
 * Topics Categories Edge Function
 * 
 * Provides a dedicated API endpoint for fetching available categories
 * of recommended Bible study topics.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * API response structure for categories
 */
interface CategoriesResponse extends ApiSuccessResponse<{
  readonly categories: readonly string[]
  readonly total: number
}> {}

/**
 * Query parameters for categories API
 */
interface CategoriesQueryParams {
  readonly language: string
}

// Configuration constants
const DEFAULT_LANGUAGE = 'en' as const

/**
 * Main handler for topics categories
 */
async function handleTopicsCategories(req: Request, services: ServiceContainer): Promise<Response> {
  // Parse and validate query parameters
  const queryParams = parseQueryParameters(req.url)

  // Get all available categories
  const categories = await services.topicsRepository.getCategories(queryParams.language)

  // Log analytics event
  await services.analyticsLogger.logEvent('topics_categories_accessed', {
    language: queryParams.language,
    total_categories: categories.length
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: CategoriesResponse = {
    success: true,
    data: {
      categories,
      total: categories.length
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
function parseQueryParameters(url: string): CategoriesQueryParams {
  const urlObj = new URL(url)
  const searchParams = urlObj.searchParams

  return {
    language: searchParams.get('language') || DEFAULT_LANGUAGE
  }
}

// Create the function with the factory
createSimpleFunction(handleTopicsCategories, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})