/**
 * Fetch Verse Edge Function
 *
 * Fetches Bible verse text from API.Bible for manual verse addition.
 * Supports single verses and verse ranges in all three languages.
 *
 * Features:
 * - Fetches verse text in specified language
 * - Supports verse ranges (e.g., John 3:16-17)
 * - Uses existing Bible API service
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { fetchWithTimeout } from '../_shared/services/bible-api-service.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { HINDI_BOOK_NAMES, MALAYALAM_BOOK_NAMES, LOCALIZED_VARIANTS_TO_ENGLISH } from '../_shared/utils/bible-book-normalizer.ts'

/**
 * Request payload structure
 */
interface FetchVerseRequest {
  readonly book: string      // Book name (e.g., "John", "1 Corinthians")
  readonly chapter: number   // Chapter number
  readonly verse_start: number // Starting verse number
  readonly verse_end?: number  // Optional ending verse for ranges
  readonly language: 'en' | 'hi' | 'ml'
}

/**
 * API response structure
 */
interface FetchVerseResponse extends ApiSuccessResponse<{
  reference: string
  localizedReference: string
  text: string
  translation: string
  language: string
}> {}

// Bible book name mappings to API.Bible book codes
const BOOK_CODES: Record<string, string> = {
  // Old Testament
  'Genesis': 'GEN', 'Exodus': 'EXO', 'Leviticus': 'LEV', 'Numbers': 'NUM', 'Deuteronomy': 'DEU',
  'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT', '1 Samuel': '1SA', '2 Samuel': '2SA',
  '1 Kings': '1KI', '2 Kings': '2KI', '1 Chronicles': '1CH', '2 Chronicles': '2CH',
  'Ezra': 'EZR', 'Nehemiah': 'NEH', 'Esther': 'EST', 'Job': 'JOB', 'Psalms': 'PSA',
  'Proverbs': 'PRO', 'Ecclesiastes': 'ECC', 'Song of Solomon': 'SNG', 'Isaiah': 'ISA',
  'Jeremiah': 'JER', 'Lamentations': 'LAM', 'Ezekiel': 'EZK', 'Daniel': 'DAN',
  'Hosea': 'HOS', 'Joel': 'JOL', 'Amos': 'AMO', 'Obadiah': 'OBA', 'Jonah': 'JON',
  'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB', 'Zephaniah': 'ZEP', 'Haggai': 'HAG',
  'Zechariah': 'ZEC', 'Malachi': 'MAL',

  // New Testament
  'Matthew': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
  'Romans': 'ROM', '1 Corinthians': '1CO', '2 Corinthians': '2CO', 'Galatians': 'GAL',
  'Ephesians': 'EPH', 'Philippians': 'PHP', 'Colossians': 'COL', '1 Thessalonians': '1TH',
  '2 Thessalonians': '2TH', '1 Timothy': '1TI', '2 Timothy': '2TI', 'Titus': 'TIT',
  'Philemon': 'PHM', 'Hebrews': 'HEB', 'James': 'JAS', '1 Peter': '1PE', '2 Peter': '2PE',
  '1 John': '1JN', '2 John': '2JN', '3 John': '3JN', 'Jude': 'JUD', 'Revelation': 'REV',
}


// HINDI_BOOK_NAMES and MALAYALAM_BOOK_NAMES are imported from bible-book-normalizer.ts.
// They are the shared canonical source for localized book name display and reverse lookup.

// Bible version IDs from API.Bible
const BIBLE_VERSIONS = {
  en: 'de4e12af7f28f599-02', // King James Version (KJV)
  hi: '1e8ab327edbce67f-01', // Indian Revised Version Hindi 2019
  ml: '3ea0147e32eebe47-01', // Indian Revised Version Malayalam 2025
} as const


// Reverse mappings: Hindi/Malayalam book names -> English
const HINDI_TO_ENGLISH: Record<string, string> = Object.fromEntries(
  Object.entries(HINDI_BOOK_NAMES).map(([en, hi]) => [hi, en])
)

const MALAYALAM_TO_ENGLISH: Record<string, string> = Object.fromEntries(
  Object.entries(MALAYALAM_BOOK_NAMES).map(([en, ml]) => [ml, en])
)

// LOCALIZED_VARIANTS_TO_ENGLISH is imported from bible-book-normalizer.ts.
// It maps common LLM-generated and user-input variants to English canonical names.
// Add new variants there to fix them everywhere at once.

/**
 * Normalize book name to English for API lookup
 * Handles English, Hindi, and Malayalam book names
 */
function normalizeBookName(book: string): string {
  // Already English
  if (BOOK_CODES[book]) {
    return book
  }

  // Try Hindi
  if (HINDI_TO_ENGLISH[book]) {
    return HINDI_TO_ENGLISH[book]
  }

  // Try Malayalam
  if (MALAYALAM_TO_ENGLISH[book]) {
    return MALAYALAM_TO_ENGLISH[book]
  }

  // Try localized variant spellings (common variations from LLM output)
  if (LOCALIZED_VARIANTS_TO_ENGLISH[book]) {
    return LOCALIZED_VARIANTS_TO_ENGLISH[book]
  }

  // Return as-is (will fail validation later)
  return book
}

/**
 * Get localized book name based on language
 */
function getLocalizedBookName(book: string, language: 'en' | 'hi' | 'ml'): string {
  if (language === 'hi') {
    return HINDI_BOOK_NAMES[book] || book
  } else if (language === 'ml') {
    return MALAYALAM_BOOK_NAMES[book] || book
  }
  return book
}

/**
 * Get translation name for display
 */
function getTranslationName(language: 'en' | 'hi' | 'ml'): string {
  const names = {
    en: 'King James Version (KJV)',
    hi: 'Indian Revised Version Hindi 2019',
    ml: 'Indian Revised Version Malayalam 2025',
  }
  return names[language]
}

/**
 * Clean verse text from HTML, cross-references, and formatting
 */
function cleanVerseText(content: string): string {
  let cleaned = content

  // Remove HTML tags
  cleaned = cleaned.replace(/<[^>]*>/g, '')

  // Remove inline cross-references in parentheses
  // Matches patterns like: (नीति. 23:12), (Prov. 23:12), (Gen. 1:1; Ex. 3:14), (1 Cor. 13:4-7)
  // Pattern: parentheses containing chapter:verse reference(s)
  cleaned = cleaned.replace(/\s*\([^)]*\d+:\d+[^)]*\)/g, '')

  // Normalize whitespace
  cleaned = cleaned.replace(/\s+/g, ' ').trim()

  return cleaned
}

/**
 * Build URL with query parameters to get clean verse text
 */
function buildVerseUrl(bibleId: string, verseId: string): string {
  const baseUrl = `https://api.scripture.api.bible/v1/bibles/${bibleId}/verses/${verseId}`
  const params = new URLSearchParams({
    'content-type': 'text',           // Plain text format
    'include-notes': 'false',         // No footnotes
    'include-titles': 'false',        // No section titles/headings
    'include-chapter-numbers': 'false', // No chapter numbers
    'include-verse-numbers': 'false', // No verse numbers
  })
  return `${baseUrl}?${params.toString()}`
}

/**
 * Main handler for fetching verse
 */
async function handleFetchVerse(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  // Parse and validate request body
  const body = await req.json() as FetchVerseRequest

  if (!body.book || !body.chapter || !body.verse_start || !body.language) {
    throw new AppError('VALIDATION_ERROR', 'book, chapter, verse_start, and language are required', 400)
  }

  // Validate language
  if (!['en', 'hi', 'ml'].includes(body.language)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid language. Must be en, hi, or ml', 400)
  }

  // Normalize book name to English (handles Hindi/Malayalam book names)
  const englishBookName = normalizeBookName(body.book)

  // Validate book name
  if (!BOOK_CODES[englishBookName]) {
    throw new AppError('VALIDATION_ERROR', `Unknown book name: ${body.book}`, 400)
  }

  const apiKey = Deno.env.get('BIBLE_API')
  if (!apiKey) {
    throw new AppError('INTERNAL_ERROR', 'Bible API key not configured', 500)
  }

  const bibleId = BIBLE_VERSIONS[body.language]
  const bookCode = BOOK_CODES[englishBookName]

  // Build reference and fetch verse(s)
  let verseText = ''
  let reference: string
  let localizedReference: string

  // Check if this is a chapter-only request (verse_start: 1, verse_end: 999)
  const isChapterOnly = body.verse_start === 1 && body.verse_end === 999

  if (isChapterOnly) {
    // Fetch entire chapter using chapters endpoint
    reference = `${englishBookName} ${body.chapter}`
    const localizedBook = getLocalizedBookName(englishBookName, body.language)
    localizedReference = `${localizedBook} ${body.chapter}`

    const chapterId = `${bookCode}.${body.chapter}`
    const chapterUrl = `https://api.scripture.api.bible/v1/bibles/${bibleId}/chapters/${chapterId}`
    const params = new URLSearchParams({
      'content-type': 'text',
      'include-notes': 'false',
      'include-titles': 'false',
      'include-chapter-numbers': 'false',
      'include-verse-numbers': 'false',
    })

    const response = await fetchWithTimeout(
      `${chapterUrl}?${params.toString()}`,
      { headers: { 'api-key': apiKey } },
      15000 // 15 seconds for chapter
    )

    if (!response.ok) {
      const errorData = await response.json()
      console.error('[FetchVerse] Chapter API error:', errorData)
      throw new AppError('NOT_FOUND', `Chapter not found: ${reference}`, 404)
    }

    const data = await response.json()
    verseText = cleanVerseText(data.data.content)
  } else if (body.verse_end && body.verse_end > body.verse_start) {
    // Fetch verse range
    reference = `${englishBookName} ${body.chapter}:${body.verse_start}-${body.verse_end}`
    const localizedBook = getLocalizedBookName(englishBookName, body.language)
    localizedReference = `${localizedBook} ${body.chapter}:${body.verse_start}-${body.verse_end}`

    // Fetch each verse in the range
    const verseTexts: string[] = []
    for (let v = body.verse_start; v <= body.verse_end; v++) {
      const verseId = `${bookCode}.${body.chapter}.${v}`
      const url = buildVerseUrl(bibleId, verseId)

      try {
        const response = await fetchWithTimeout(
          url,
          { headers: { 'api-key': apiKey } },
          10000
        )

        if (response.ok) {
          const data = await response.json()
          const text = cleanVerseText(data.data.content)
          if (text) {
            verseTexts.push(text)
          }
        }
      } catch (error) {
        console.error(`[FetchVerse] Error fetching verse ${v}:`, error)
        // Continue with other verses
      }
    }

    if (verseTexts.length === 0) {
      throw new AppError('NOT_FOUND', `No verses found for ${reference}`, 404)
    }

    verseText = verseTexts.join(' ')
  } else {
    // Fetch single verse
    reference = `${englishBookName} ${body.chapter}:${body.verse_start}`
    const localizedBook = getLocalizedBookName(englishBookName, body.language)
    localizedReference = `${localizedBook} ${body.chapter}:${body.verse_start}`

    const verseId = `${bookCode}.${body.chapter}.${body.verse_start}`
    const url = buildVerseUrl(bibleId, verseId)

    const response = await fetchWithTimeout(
      url,
      { headers: { 'api-key': apiKey } },
      10000
    )

    if (!response.ok) {
      const errorData = await response.json()
      console.error('[FetchVerse] API error:', errorData)
      throw new AppError('NOT_FOUND', `Verse not found: ${reference}`, 404)
    }

    const data = await response.json()
    verseText = cleanVerseText(data.data.content)
  }

  const responseData: FetchVerseResponse = {
    success: true,
    data: {
      reference,
      localizedReference,
      text: verseText,
      translation: getTranslationName(body.language),
      language: body.language,
    }
  }

  return new Response(JSON.stringify(responseData), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// Create the simple function (no auth required for fetching verses)
createSimpleFunction(handleFetchVerse, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 30000 // 30 seconds for verse ranges
})
