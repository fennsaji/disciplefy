/**
 * Add Memory Verse Manually Edge Function
 * 
 * Allows authenticated users to manually add custom verses to their memory deck
 * for spaced repetition practice.
 * 
 * Features:
 * - Accepts custom verse reference and text
 * - Input validation and sanitization
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
interface AddManualVerseRequest {
  readonly verse_reference: string
  readonly verse_text: string
  readonly language?: string
}

/**
 * Memory verse data structure
 */
interface MemoryVerseData {
  readonly id: string
  readonly verse_reference: string
  readonly verse_text: string
  readonly language: string
  readonly source_type: 'manual'
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
 * Validates and sanitizes verse reference
 */
function validateVerseReference(reference: string): string {
  if (!reference || typeof reference !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'verse_reference is required and must be a string', 400)
  }

  const trimmed = reference.trim()
  
  if (trimmed.length === 0) {
    throw new AppError('VALIDATION_ERROR', 'verse_reference cannot be empty', 400)
  }

  if (trimmed.length > 100) {
    throw new AppError('VALIDATION_ERROR', 'verse_reference too long (max 100 characters)', 400)
  }

  // Basic sanitization - remove excessive whitespace
  return trimmed.replace(/\s+/g, ' ')
}

/**
 * Validates and sanitizes verse text
 */
function validateVerseText(text: string): string {
  if (!text || typeof text !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'verse_text is required and must be a string', 400)
  }

  const trimmed = text.trim()
  
  if (trimmed.length === 0) {
    throw new AppError('VALIDATION_ERROR', 'verse_text cannot be empty', 400)
  }

  if (trimmed.length < 10) {
    throw new AppError('VALIDATION_ERROR', 'verse_text too short (min 10 characters)', 400)
  }

  if (trimmed.length > 5000) {
    throw new AppError('VALIDATION_ERROR', 'verse_text too long (max 5000 characters)', 400)
  }

  // Basic sanitization - remove excessive whitespace but preserve line breaks
  return trimmed.replace(/[ \t]+/g, ' ')
}

/**
 * Validates language code
 */
function validateLanguage(language?: string): string {
  const allowedLanguages = ['en', 'hi', 'ml']
  
  if (!language) {
    return 'en' // Default to English
  }

  const normalized = language.toLowerCase().trim()
  
  if (!allowedLanguages.includes(normalized)) {
    throw new AppError(
      'VALIDATION_ERROR', 
      `Invalid language. Allowed values: ${allowedLanguages.join(', ')}`, 
      400
    )
  }

  return normalized
}

/**
 * Main handler for adding manual verse
 */
async function handleAddMemoryVerseManual(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {

  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to save memory verses', 401)
  }

  // Feature flag validation - Check if memory_verses is enabled for user's plan
  const userPlan = await services.authService.getUserPlan(req)
  console.log(`👤 [AddMemoryVerse] User plan: ${userPlan}`)

  // Validate feature access using middleware
  const userId = userContext.userId!
  await checkFeatureAccess(userId, userPlan, 'memory_verses')
  console.log(`✅ [AddMemoryVerse] Feature access granted: memory_verses available for plan ${userPlan}`)

  // Enforce per-plan verse count limit (DB-driven)
  const verseLimit = await services.memoryVerseConfigService.getVerseLimits(userPlan)
  if (verseLimit !== -1) {
    const { count, error: countError } = await services.supabaseServiceClient
      .from('memory_verses')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)

    if (countError) {
      console.error('[AddMemoryVerse] Failed to count existing verses:', countError)
      throw new AppError('DATABASE_ERROR', 'Failed to check verse limit', 500)
    }

    const currentCount = count ?? 0
    console.log(`📊 [AddMemoryVerse] Verse count: ${currentCount}/${verseLimit} (plan: ${userPlan})`)

    if (currentCount >= verseLimit) {
      throw new AppError(
        'VERSE_LIMIT_EXCEEDED',
        `You have reached your limit of ${verseLimit} memory verse${verseLimit > 1 ? 's' : ''} on the ${userPlan} plan. Upgrade to add more.`,
        403
      )
    }
  }

  // Parse request body
  let body: AddManualVerseRequest
  try {
    body = await req.json() as AddManualVerseRequest
  } catch (error) {
    throw new AppError('VALIDATION_ERROR', 'Invalid JSON payload', 400)
  }

  // Validate and sanitize inputs
  const verseReference = validateVerseReference(body.verse_reference)
  const verseText = validateVerseText(body.verse_text)
  const language = validateLanguage(body.language)

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

  console.log(`[AddMemoryVerse] Using SM-2 initial state from config: ease=${initialEaseFactor}, interval=${initialIntervalDays}`)

  // Add verse to memory_verses table with SM-2 initial state
  const now = new Date().toISOString()
  const { data: memoryVerse, error: insertError } = await services.supabaseServiceClient
    .from('memory_verses')
    .insert({
      user_id: userContext.userId,
      verse_reference: verseReference,
      verse_text: verseText,
      language: language,
      source_type: 'manual',
      source_id: null, // No source_id for manual entries
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
    console.error('[AddMemoryVerseManual] Insert error:', insertError)
    
    // Check for specific database constraints
    if (insertError?.code === '23505') {
      throw new AppError('CONFLICT', 'This verse is already in your memory deck', 409)
    }
    
    throw new AppError('DATABASE_ERROR', 'Failed to add verse to memory deck', 500)
  }

  // Log analytics event (non-fatal - don't fail the request if analytics fails)
  try {
    await services.analyticsLogger.logEvent('memory_verse_added', {
      user_id: userContext.userId,
      verse_reference: verseReference,
      source_type: 'manual',
      language: language,
      verse_length: verseText.length
    }, req.headers.get('x-forwarded-for'))
  } catch (analyticsError) {
    console.error('[AddManualVerse] Analytics logging failed:', {
      error: analyticsError,
      event: 'memory_verse_added',
      user_id: userContext.userId,
      verse_reference: verseReference,
      ip: req.headers.get('x-forwarded-for')
    })
    // Don't rethrow - analytics failures should not block verse addition
  }

  // Build response data
  const responseData: MemoryVerseData = {
    id: memoryVerse.id,
    verse_reference: memoryVerse.verse_reference,
    verse_text: memoryVerse.verse_text,
    language: memoryVerse.language,
    source_type: 'manual',
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
createAuthenticatedFunction(handleAddMemoryVerseManual, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
