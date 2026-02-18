/**
 * Get Suggested Verses Edge Function
 * 
 * Retrieves curated suggested Bible verses that users can add to their memory deck.
 * 
 * Features:
 * - Returns verses organized by category
 * - Multi-language support (EN, HI, ML)
 * - Optional category filtering
 * - Indicates which verses are already in user's deck (if authenticated)
 * - Returns available categories for filter chips
 * 
 * Version: 2.4.0 - Memory Verses Enhancement
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

/**
 * Suggested verse data structure
 */
interface SuggestedVerse {
  readonly id: string
  readonly reference: string
  readonly localized_reference: string
  readonly verse_text: string
  readonly book: string
  readonly chapter: number
  readonly verse_start: number
  readonly verse_end: number | null
  readonly category: string
  readonly tags: readonly string[]
  readonly is_already_added: boolean
}

/**
 * Available categories
 */
const CATEGORIES = [
  'salvation',
  'comfort', 
  'strength',
  'wisdom',
  'promise',
  'guidance',
  'faith',
  'love'
] as const

type Category = typeof CATEGORIES[number]

/**
 * API response structure
 */
interface GetSuggestedVersesResponse extends ApiSuccessResponse<{
  readonly verses: readonly SuggestedVerse[]
  readonly categories: readonly string[]
  readonly total: number
}> {}

/**
 * Query parameters for filtering verses
 */
interface QueryParams {
  readonly category?: Category
  readonly language: string
}

// Configuration constants
const DEFAULT_LANGUAGE = 'en' as const
const ALLOWED_LANGUAGES = ['en', 'hi', 'ml'] as const

/**
 * Parses and validates query parameters from request URL
 */
function parseQueryParameters(url: string): QueryParams {
  const urlObj = new URL(url)
  const searchParams = urlObj.searchParams

  // Validate language
  let language = searchParams.get('language') || DEFAULT_LANGUAGE
  if (!ALLOWED_LANGUAGES.includes(language as typeof ALLOWED_LANGUAGES[number])) {
    language = DEFAULT_LANGUAGE
  }

  // Validate category
  const categoryParam = searchParams.get('category')
  let category: Category | undefined
  if (categoryParam && CATEGORIES.includes(categoryParam as Category)) {
    category = categoryParam as Category
  }

  return {
    category,
    language
  }
}

/**
 * Gets suggested verses with translations
 */
async function getSuggestedVerses(
  supabaseClient: any,
  params: QueryParams
): Promise<Array<Omit<SuggestedVerse, 'is_already_added'>>> {
  
  // Build query for suggested verses with translations
  let query = supabaseClient
    .from('suggested_verses')
    .select(`
      id,
      reference,
      book,
      chapter,
      verse_start,
      verse_end,
      category,
      tags,
      display_order,
      suggested_verse_translations!inner (
        verse_text,
        localized_reference,
        language_code
      )
    `)
    .eq('is_active', true)
    .eq('suggested_verse_translations.language_code', params.language)
    .order('display_order', { ascending: true })

  // Apply category filter if specified
  if (params.category) {
    query = query.eq('category', params.category)
  }

  const { data: verses, error } = await query

  if (error) {
    console.error('[get-suggested-verses] Database error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch suggested verses', 500)
  }

  if (!verses || verses.length === 0) {
    return []
  }

  // Transform data structure
  return verses.map((verse: any) => {
    const translation = verse.suggested_verse_translations[0]
    return {
      id: verse.id,
      reference: verse.reference,
      localized_reference: translation?.localized_reference || verse.reference,
      verse_text: translation?.verse_text || '',
      book: verse.book,
      chapter: verse.chapter,
      verse_start: verse.verse_start,
      verse_end: verse.verse_end,
      category: verse.category,
      tags: verse.tags || []
    }
  })
}

/**
 * Gets the list of verses already in user's memory deck
 */
async function getUserExistingVerseReferences(
  supabaseClient: any,
  userId: string,
  language: string
): Promise<Set<string>> {
  
  const { data: existingVerses, error } = await supabaseClient
    .from('memory_verses')
    .select('verse_reference')
    .eq('user_id', userId)
    .eq('language', language)

  if (error) {
    console.error('[get-suggested-verses] Error fetching user verses:', error)
    // Don't fail the request, just return empty set
    return new Set()
  }

  if (!existingVerses || existingVerses.length === 0) {
    return new Set()
  }

  // Create a set of normalized references for quick lookup
  return new Set(
    existingVerses.map((v: any) => v.verse_reference.toLowerCase().trim())
  )
}

/**
 * Main handler for getting suggested verses
 */
async function handleGetSuggestedVerses(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  // Parse query parameters
  const params = parseQueryParameters(req.url)

  // Fetch suggested verses
  const verses = await getSuggestedVerses(services.supabaseServiceClient, params)

  // If user is authenticated, check which verses they already have
  let existingReferences = new Set<string>()
  if (userContext?.type === 'authenticated' && userContext.userId) {
    existingReferences = await getUserExistingVerseReferences(
      services.supabaseServiceClient,
      userContext.userId,
      params.language
    )
  }

  // Add is_already_added flag to each verse
  // Check against localized_reference for non-English languages
  const versesWithStatus: SuggestedVerse[] = verses.map(verse => ({
    ...verse,
    is_already_added: existingReferences.has(verse.localized_reference.toLowerCase().trim())
  }))

  // Log analytics event
  await services.analyticsLogger.logEvent(
    'suggested_verses_viewed',
    {
      category: params.category || 'all',
      language: params.language,
      total_results: versesWithStatus.length,
      user_authenticated: userContext?.type === 'authenticated'
    },
    req.headers.get('x-forwarded-for')
  )

  // Build response
  const response: GetSuggestedVersesResponse = {
    success: true,
    data: {
      verses: versesWithStatus,
      categories: [...CATEGORIES],
      total: versesWithStatus.length
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json'
    }
  })
}

// Create the function with optional authentication
// Users can view suggested verses without auth, but auth enables "already added" checking
createFunction(handleGetSuggestedVerses, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000, // 10 seconds
  requireAuth: false // Don't require auth, but allow it for "already added" check
})
