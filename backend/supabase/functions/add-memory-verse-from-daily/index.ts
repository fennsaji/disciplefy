/**
 * Add Memory Verse from Daily Verse Edge Function
 * 
 * Allows authenticated users to add a daily verse to their memory deck
 * for spaced repetition practice.
 * 
 * Features:
 * - Links Daily Verse to memory verses table
 * - Prevents duplicate verses per user
 * - Initializes SM-2 algorithm state
 * - Tracks source for analytics
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { checkFeatureAccess } from '../_shared/middleware/feature-access-middleware.ts'

/**
 * Request payload structure
 */
interface AddFromDailyRequest {
  readonly daily_verse_id: string
  readonly language?: string // Optional: 'en', 'hi', 'ml' - if not provided, auto-detects
}

/**
 * Verse data structure (JSON stored in daily_verses_cache.verse_data)
 */
interface VerseData {
  readonly reference: string
  readonly translations?: {
    readonly esv?: string
    readonly hi?: string
    readonly ml?: string
  }
  readonly referenceTranslations?: {
    readonly en?: string
    readonly hi?: string
    readonly ml?: string
  }
}

/**
 * Daily verses cache row structure
 */
interface DailyVersesCacheRow {
  readonly uuid: string
  readonly verse_data: VerseData
}

/**
 * Memory verse data structure
 */
interface MemoryVerseData {
  readonly id: string
  readonly verse_reference: string
  readonly verse_text: string
  readonly language: string
  readonly source_type: 'daily_verse'
  readonly source_id: string
  readonly ease_factor: number
  readonly interval_days: number
  readonly repetitions: number
  readonly next_review_date: string
  readonly added_date: string
  readonly created_at: string
  readonly total_reviews: number
}

/**
 * API response structure
 */
interface AddMemoryVerseResponse extends ApiSuccessResponse<MemoryVerseData> {}

/**
 * Main handler for adding verse from Daily Verse
 */
async function handleAddMemoryVerseFromDaily(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to save memory verses', 401)
  }

  // Validate feature access for memory verses
  const userPlan = await services.authService.getUserPlan(req)
  await checkFeatureAccess(userContext.userId, userPlan, 'memory_verses')
  console.log(`✅ [AddMemoryVerseFromDaily] Feature access validated for user ${userContext.userId}`)

  // Parse and validate request body
  const body = await req.json() as AddFromDailyRequest
  
  if (!body.daily_verse_id) {
    throw new AppError('VALIDATION_ERROR', 'daily_verse_id is required', 400)
  }

  // Check if it's a temporary ID (format: temp-YYYY-MM-DD)
  const isTempId = body.daily_verse_id.startsWith('temp-')
  let dailyVerse: DailyVersesCacheRow

  if (isTempId) {
    // Extract date from temp ID and query by date_key
    const dateKey = body.daily_verse_id.replace('temp-', '')
    const { data, error: fetchError } = await services.supabaseServiceClient
      .from('daily_verses_cache')
      .select('uuid, verse_data')
      .eq('date_key', dateKey)
      .single()

    if (fetchError || !data) {
      console.error('[AddMemoryVerse] Daily verse not found for temp ID:', fetchError)
      throw new AppError('NOT_FOUND', `Daily verse not found for date: ${dateKey}. Please refresh the daily verse.`, 404)
    }
    dailyVerse = data as DailyVersesCacheRow
  } else {
    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    if (!uuidRegex.test(body.daily_verse_id)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid daily_verse_id format', 400)
    }

    // Fetch by UUID
    const { data, error: fetchError } = await services.supabaseServiceClient
      .from('daily_verses_cache')
      .select('uuid, verse_data')
      .eq('uuid', body.daily_verse_id)
      .single()

    if (fetchError || !data) {
      console.error('[AddMemoryVerse] Daily verse not found. Error:', JSON.stringify(fetchError))
      console.error('[AddMemoryVerse] Data:', data)
      throw new AppError('NOT_FOUND', `Daily verse not found: ${fetchError?.message || 'No data returned'}`, 404)
    }
    dailyVerse = data as DailyVersesCacheRow
  }

  // Parse verse_data JSON
  const verseData: VerseData = dailyVerse.verse_data

  // Get verse text from translations
  let verseText: string
  let verseReference: string
  let language: string

  // Check if a specific language was requested
  const requestedLanguage = body.language
  
  if (requestedLanguage) {
    // Validate requested language
    if (!['en', 'hi', 'ml'].includes(requestedLanguage)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid language. Must be en, hi, or ml', 400)
    }
    
    // Get the requested language translation and reference
    if (requestedLanguage === 'en' && verseData.translations?.esv) {
      verseText = verseData.translations.esv
      verseReference = verseData.referenceTranslations?.en || verseData.reference
      language = 'en'
    } else if (requestedLanguage === 'hi' && verseData.translations?.hi) {
      verseText = verseData.translations.hi
      verseReference = verseData.referenceTranslations?.hi || verseData.reference
      language = 'hi'
    } else if (requestedLanguage === 'ml' && verseData.translations?.ml) {
      verseText = verseData.translations.ml
      verseReference = verseData.referenceTranslations?.ml || verseData.reference
      language = 'ml'
    } else {
      throw new AppError('NOT_FOUND', `Translation not available in ${requestedLanguage} for this verse`, 404)
    }
  } else {
    // Auto-detect: Default to English (ESV) if available
    if (verseData.translations?.esv) {
      verseText = verseData.translations.esv
      verseReference = verseData.referenceTranslations?.en || verseData.reference
      language = 'en'
    } else if (verseData.translations?.hi) {
      verseText = verseData.translations.hi
      verseReference = verseData.referenceTranslations?.hi || verseData.reference
      language = 'hi'
    } else if (verseData.translations?.ml) {
      verseText = verseData.translations.ml
      verseReference = verseData.referenceTranslations?.ml || verseData.reference
      language = 'ml'
    } else {
      throw new AppError('INTERNAL_ERROR', 'No valid translation found for this verse', 500)
    }
  }

  // Validate verse content
  if (!verseReference || !verseText) {
    console.error('[AddMemoryVerse] Incomplete verse data:', verseData)
    throw new AppError('INTERNAL_ERROR', 'Daily verse data is incomplete', 500)
  }

  // Validate verse text length (max 5000 characters to support full chapters)
  if (verseText.length > 5000) {
    throw new AppError('VALIDATION_ERROR', 'Verse text too long for memorization (max 5000 characters)', 400)
  }

  // Check if verse already exists in user's memory deck
  const { data: existingVerse } = await services.supabaseServiceClient
    .from('memory_verses')
    .select('id')
    .eq('user_id', userContext.userId)
    .eq('verse_reference', verseReference)
    .eq('language', language)
    .maybeSingle()

  if (existingVerse) {
    throw new AppError('CONFLICT', 'This verse is already in your memory deck', 409)
  }

  // Get SM-2 initial state from database config
  const memoryConfig = await services.memoryVerseConfigService.getMemoryVerseConfig()
  const initialEaseFactor = memoryConfig.spacedRepetition.initialEaseFactor
  const initialIntervalDays = memoryConfig.spacedRepetition.initialIntervalDays

  console.log(`[AddMemoryVerseFromDaily] Using SM-2 initial state from config: ease=${initialEaseFactor}, interval=${initialIntervalDays}`)

  // Add verse to memory_verses table with SM-2 initial state
  const now = new Date().toISOString()
  const { data: memoryVerse, error: insertError } = await services.supabaseServiceClient
    .from('memory_verses')
    .insert({
      user_id: userContext.userId,
      verse_reference: verseReference,
      verse_text: verseText,
      language: language,
      source_type: 'daily_verse',
      source_id: dailyVerse.uuid, // Use the real UUID from the database
      // SM-2 initial state from database config
      ease_factor: initialEaseFactor,
      interval_days: initialIntervalDays,
      repetitions: 0,
      next_review_date: now, // Available for immediate review
      added_date: now,
      created_at: now,
      updated_at: now
    })
    .select()
    .single()

  if (insertError || !memoryVerse) {
    console.error('[AddMemoryVerse] Insert error:', insertError)
    throw new AppError('DATABASE_ERROR', 'Failed to add verse to memory deck', 500)
  }

  // Log analytics event
  await services.analyticsLogger.logEvent('memory_verse_added', {
    user_id: userContext.userId,
    verse_reference: verseReference,
    source_type: 'daily_verse',
    source_id: body.daily_verse_id,
    language: language,
    verse_length: verseText.length
  }, req.headers.get('x-forwarded-for'))

  // Build response data
  const responseData: MemoryVerseData = {
    id: memoryVerse.id,
    verse_reference: memoryVerse.verse_reference,
    verse_text: memoryVerse.verse_text,
    language: memoryVerse.language,
    source_type: 'daily_verse',
    source_id: memoryVerse.source_id,
    ease_factor: memoryVerse.ease_factor,
    interval_days: memoryVerse.interval_days,
    repetitions: memoryVerse.repetitions,
    next_review_date: memoryVerse.next_review_date,
    added_date: memoryVerse.added_date,
    created_at: memoryVerse.created_at,
    total_reviews: 0
  }

  const response: AddMemoryVerseResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 201,
    headers: { 
      'Content-Type': 'application/json'
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleAddMemoryVerseFromDaily, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
