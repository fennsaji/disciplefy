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

// Allowed language codes (BCP 47 subset)
const ALLOWED_LANGUAGES = new Set(['en', 'hi', 'ml'])

// BCP 47 language code validation regex (basic subset)
const LANGUAGE_CODE_REGEX = /^[a-z]{2}(-[A-Z]{2})?$/

/**
 * Builds a successful categories response.
 */
function buildSuccessResponse(categories: readonly string[]): Response {
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
 * Logs analytics event for categories access.
 */
async function logAccessEvent(
  services: ServiceContainer,
  req: Request,
  language: string,
  total: number
): Promise<void> {
  await services.analyticsLogger.logEvent('topics_categories_accessed', {
    language: language,
    total_categories: total
  }, req.headers.get('x-forwarded-for'))
}

/**
 * Main handler for topics categories
 */
async function handleTopicsCategories(req: Request, services: ServiceContainer): Promise<Response> {
  try {
    // Parse query parameters and fetch categories
    const queryParams = parseQueryParameters(req.url)
    const categories = await services.topicsRepository.getCategories(queryParams.language)

    // Log analytics event
    await logAccessEvent(services, req, queryParams.language, categories.length)

    // Return success response
    return buildSuccessResponse(categories)
  } catch (error) {
    console.error('Error in handleTopicsCategories:', error)
    
    return new Response(JSON.stringify({
      success: false,
      error: 'Failed to fetch categories'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}

/**
 * Validates and sanitizes a language code
 */
function validateLanguageCode(rawLanguage: string | null): string {
  if (!rawLanguage) {
    return DEFAULT_LANGUAGE
  }

  // Normalize: trim whitespace and convert to lowercase
  const normalized = rawLanguage.trim().toLowerCase()

  // Validate against allow-list
  if (ALLOWED_LANGUAGES.has(normalized as any)) {
    return normalized
  }

  // Fallback for any other value
  return DEFAULT_LANGUAGE
}

/**
 * Parses and validates query parameters from request URL
 */
function parseQueryParameters(url: string): CategoriesQueryParams {
  const urlObj = new URL(url)
  const searchParams = urlObj.searchParams

  const rawLanguage = searchParams.get('language')
  const validatedLanguage = validateLanguageCode(rawLanguage)

  return {
    language: validatedLanguage
  }
}

// Create the function with the factory
createSimpleFunction(handleTopicsCategories, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})