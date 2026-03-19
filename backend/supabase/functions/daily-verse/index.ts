/**
 * Daily Verse Edge Function
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
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { DailyVerseService } from './daily-verse-service.ts'

// Lazy singleton — created once per worker lifetime, not at module load
let _dailyVerseService: DailyVerseService | null = null
function getDailyVerseService(services: ServiceContainer): DailyVerseService {
  if (!_dailyVerseService) {
    _dailyVerseService = new DailyVerseService(services.supabaseServiceClient, services.llmService)
  }
  return _dailyVerseService
}

/**
 * Daily verse data structure
 */
interface DailyVerseData {
  readonly id?: string // UUID from daily_verses_cache table
  readonly reference: string
  readonly referenceTranslations: {
    readonly en: string
    readonly hi: string
    readonly ml: string
  }
  readonly date: string
  readonly translations: {
    readonly esv?: string
    readonly hindi?: string
    readonly malayalam?: string
  }
  readonly fromCache: boolean
  readonly timestamp: string
}

/**
 * Complete API response structure
 */
interface DailyVerseApiResponse extends ApiSuccessResponse<DailyVerseData> {}

/**
 * Main handler for daily verse
 */
async function handleDailyVerse(req: Request, services: ServiceContainer): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  // Parse query parameters
  const url = new URL(req.url)
  const requestDate = url.searchParams.get('date')
  const requestLanguage = url.searchParams.get('language')

  // Validate date parameter if provided
  if (requestDate && isNaN(new Date(requestDate).getTime())) {
    throw new AppError('VALIDATION_ERROR', 'Invalid date format. Please use YYYY-MM-DD.', 400)
  }

  // Validate and normalize language parameter
  const allowedLanguages = ['en', 'hi', 'ml']
  const language = allowedLanguages.includes(requestLanguage || '') ? requestLanguage! : 'en'

  // Get daily verse data using locally-scoped service (not in shared container)
  const verseData = await getDailyVerseService(services).getDailyVerse(requestDate, language)

  // Validate that referenceTranslations exists
  if (!verseData.referenceTranslations) {
    console.error('[API] Verse data missing referenceTranslations:', verseData)
    throw new AppError('INTERNAL_ERROR', 'Verse data is incomplete', 500)
  }

  // Log translation data for debugging
  console.log('[API] Verse translations received:', {
    esv: !!verseData.translations.esv,
    hi: !!verseData.translations.hi,
    ml: !!verseData.translations.ml
  })

  // Log to usage_logs when LLM was actually invoked (cache miss, successful generation).
  // Use strict equality === false to avoid logging on cache hits or undefined fromCache.
  // Token counts are not surfaced by DailyVerseService; logged as null until threading is added.
  if (verseData.fromCache === false) {
    try {
      await services.supabaseServiceClient.from('usage_logs').insert({
        user_id: null,              // system-level call; no requesting user
        feature_name: 'daily_verse',
        operation_type: 'create',
        tier: 'system',             // sentinel for system operations (no CHECK constraint)
        llm_model: null,
        llm_provider: null,
        llm_input_tokens: null,
        llm_output_tokens: null,
        llm_cost_usd: null,
        language: language,
      })
      console.log('[daily-verse] Logged cache-miss LLM call to usage_logs')
    } catch (logErr) {
      // Non-fatal: analytics failure must never break the verse response
      console.warn('[daily-verse] Failed to log usage_logs entry:', logErr)
    }
  }

  // Create response data with additional fields
  // Only include translations that have content (non-empty strings)
  const responseData: DailyVerseData = {
    id: verseData.id, // UUID from daily_verses_cache table
    reference: verseData.reference,
    referenceTranslations: {
      en: verseData.referenceTranslations.en,
      hi: verseData.referenceTranslations.hi,
      ml: verseData.referenceTranslations.ml
    },
    date: verseData.date,
    translations: {
      ...(verseData.translations.esv ? { esv: verseData.translations.esv } : {}),
      ...(verseData.translations.hi ? { hindi: verseData.translations.hi } : {}),
      ...(verseData.translations.ml ? { malayalam: verseData.translations.ml } : {})
    },
    fromCache: verseData.fromCache ?? false,
    timestamp: new Date().toISOString()
  }

  // Log analytics event
  await services.analyticsLogger.logEvent('daily_verse_accessed', {
    date: verseData.date,
    reference: verseData.reference,
    from_cache: responseData.fromCache,
    requested_date: requestDate,
    user_agent: req.headers.get('user-agent') || 'unknown'
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: DailyVerseApiResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600' // Cache for 1 hour
    }
  })
}

// Create the function with the factory
createSimpleFunction(handleDailyVerse, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 15000 // 15 seconds
})