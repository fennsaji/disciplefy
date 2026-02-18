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

  // Get daily verse data using injected service with language preference
  const verseData = await services.dailyVerseService.getDailyVerse(requestDate, language)

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
    fromCache: false, // TODO: Implement cache tracking
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