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

// Hindi book names for localization
const HINDI_BOOK_NAMES: Record<string, string> = {
  'Genesis': 'उत्पत्ति', 'Exodus': 'निर्गमन', 'Leviticus': 'लैव्यव्यवस्था', 'Numbers': 'गिनती', 'Deuteronomy': 'व्यवस्थाविवरण',
  'Joshua': 'यहोशू', 'Judges': 'न्यायियों', 'Ruth': 'रूत', '1 Samuel': '1 शमूएल', '2 Samuel': '2 शमूएल',
  '1 Kings': '1 राजा', '2 Kings': '2 राजा', '1 Chronicles': '1 इतिहास', '2 Chronicles': '2 इतिहास',
  'Ezra': 'एज्रा', 'Nehemiah': 'नहेमायाह', 'Esther': 'एस्तेर', 'Job': 'अय्यूब', 'Psalms': 'भजन संहिता',
  'Proverbs': 'नीतिवचन', 'Ecclesiastes': 'सभोपदेशक', 'Song of Solomon': 'श्रेष्ठगीत', 'Isaiah': 'यशायाह',
  'Jeremiah': 'यिर्मयाह', 'Lamentations': 'विलापगीत', 'Ezekiel': 'यहेजकेल', 'Daniel': 'दानिय्येल',
  'Hosea': 'होशे', 'Joel': 'योएल', 'Amos': 'आमोस', 'Obadiah': 'ओबद्याह', 'Jonah': 'योना',
  'Micah': 'मीका', 'Nahum': 'नहूम', 'Habakkuk': 'हबक्कूक', 'Zephaniah': 'सपन्याह', 'Haggai': 'हाग्गै',
  'Zechariah': 'जकर्याह', 'Malachi': 'मलाकी',
  'Matthew': 'मत्ती', 'Mark': 'मरकुस', 'Luke': 'लूका', 'John': 'यूहन्ना', 'Acts': 'प्रेरितों के काम',
  'Romans': 'रोमियों', '1 Corinthians': '1 कुरिन्थियों', '2 Corinthians': '2 कुरिन्थियों', 'Galatians': 'गलातियों',
  'Ephesians': 'इफिसियों', 'Philippians': 'फिलिप्पियों', 'Colossians': 'कुलुस्सियों', '1 Thessalonians': '1 थिस्सलुनीकियों',
  '2 Thessalonians': '2 थिस्सलुनीकियों', '1 Timothy': '1 तीमुथियुस', '2 Timothy': '2 तीमुथियुस', 'Titus': 'तीतुस',
  'Philemon': 'फिलेमोन', 'Hebrews': 'इब्रानियों', 'James': 'याकूब', '1 Peter': '1 पतरस', '2 Peter': '2 पतरस',
  '1 John': '1 यूहन्ना', '2 John': '2 यूहन्ना', '3 John': '3 यूहन्ना', 'Jude': 'यहूदा', 'Revelation': 'प्रकाशितवाक्य',
}

// Malayalam book names for localization
const MALAYALAM_BOOK_NAMES: Record<string, string> = {
  'Genesis': 'ഉല്പത്തി', 'Exodus': 'പുറപ്പാട്', 'Leviticus': 'ലേവ്യപുസ്തകം', 'Numbers': 'സംഖ്യാപുസ്തകം', 'Deuteronomy': 'ആവര്‍ത്തനം',
  'Joshua': 'യോശുവ', 'Judges': 'ന്യായാധിപന്മാര്‍', 'Ruth': 'രൂത്ത്', '1 Samuel': '1 ശമൂവേല്‍', '2 Samuel': '2 ശമൂവേല്‍',
  '1 Kings': '1 രാജാക്കന്മാര്‍', '2 Kings': '2 രാജാക്കന്മാര്‍', '1 Chronicles': '1 ദിനവൃത്താന്തം', '2 Chronicles': '2 ദിനവൃത്താന്തം',
  'Ezra': 'എസ്രാ', 'Nehemiah': 'നെഹെമ്യാവ്', 'Esther': 'എസ്ഥേര്‍', 'Job': 'ഇയ്യോബ്', 'Psalms': 'സങ്കീര്‍ത്തനങ്ങള്‍',
  'Proverbs': 'സദൃശവാക്യങ്ങള്‍', 'Ecclesiastes': 'സഭാപ്രസംഗി', 'Song of Solomon': 'ഉത്തമഗീതം', 'Isaiah': 'യശായാ',
  'Jeremiah': 'യിരെമ്യാവ്', 'Lamentations': 'വിലാപങ്ങള്‍', 'Ezekiel': 'യെഹെസ്കേല്‍', 'Daniel': 'ദാനീയേല്‍',
  'Hosea': 'ഹോശേയ', 'Joel': 'യോവേല്‍', 'Amos': 'ആമോസ്', 'Obadiah': 'ഓബദ്യാവ്', 'Jonah': 'യോനാ',
  'Micah': 'മീഖാ', 'Nahum': 'നഹൂം', 'Habakkuk': 'ഹബക്കൂക്ക്', 'Zephaniah': 'സെഫന്യാവ്', 'Haggai': 'ഹഗ്ഗായി',
  'Zechariah': 'സെഖര്യാവ്', 'Malachi': 'മലാഖി',
  'Matthew': 'മത്തായി', 'Mark': 'മര്‍ക്കൊസ്', 'Luke': 'ലൂക്കൊസ്', 'John': 'യോഹന്നാന്‍', 'Acts': 'അപ്പൊസ്തലപ്രവൃത്തികള്‍',
  'Romans': 'റോമാക്കാര്‍', '1 Corinthians': '1 കൊരിന്ത്യര്‍', '2 Corinthians': '2 കൊരിന്ത്യര്‍', 'Galatians': 'ഗലാത്യര്‍',
  'Ephesians': 'എഫെസ്യര്‍', 'Philippians': 'ഫിലിപ്പിയര്‍', 'Colossians': 'കൊലൊസ്സ്യര്‍', '1 Thessalonians': '1 തെസ്സലൊനീക്യര്‍',
  '2 Thessalonians': '2 തെസ്സലൊനീക്യര്‍', '1 Timothy': '1 തിമൊഥെയൊസ്', '2 Timothy': '2 തിമൊഥെയൊസ്', 'Titus': 'തീത്തൊസ്',
  'Philemon': 'ഫിലേമോന്‍', 'Hebrews': 'എബ്രായര്‍', 'James': 'യാക്കോബ്', '1 Peter': '1 പത്രൊസ്', '2 Peter': '2 പത്രൊസ്',
  '1 John': '1 യോഹന്നാന്‍', '2 John': '2 യോഹന്നാന്‍', '3 John': '3 യോഹന്നാന്‍', 'Jude': 'യൂദാ', 'Revelation': 'വെളിപ്പാട്',
}

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

// Alternate spellings for book names (common variations from LLM output)
const ALTERNATE_SPELLINGS: Record<string, string> = {
  // Malayalam alternates
  'റോമർ': 'Romans',
  'റോമര്‍': 'Romans',
  'കൊരിന്ത്യർ': 'Corinthians',
  '1 കൊരിന്ത്യർ': '1 Corinthians',
  '2 കൊരിന്ത്യർ': '2 Corinthians',
  'ഗലാത്യർ': 'Galatians',
  'എഫെസ്യർ': 'Ephesians',
  'ഫിലിപ്പിയർ': 'Philippians',
  'കൊലൊസ്സ്യർ': 'Colossians',
  'തെസ്സലൊനീക്യർ': 'Thessalonians',
  '1 തെസ്സലൊനീക്യർ': '1 Thessalonians',
  '2 തെസ്സലൊനീക്യർ': '2 Thessalonians',
  'എബ്രായർ': 'Hebrews',
  'യോഹന്നാൻ': 'John',
  '1 യോഹന്നാൻ': '1 John',
  '2 യോഹന്നാൻ': '2 John',
  '3 യോഹന്നാൻ': '3 John',
  '1 പത്രോസ്': '1 Peter',
  '2 പത്രോസ്': '2 Peter',
  'സങ്കീർത്തനം': 'Psalms',
  'സങ്കീര്‍ത്തനം': 'Psalms',
  'സങ്കീർത്തനങ്ങൾ': 'Psalms',
  'ലൂക്കാ': 'Luke',
  'ലൂക്കോസ്': 'Luke',
  'മത്തായി': 'Matthew',
  'മർക്കോസ്': 'Mark',
  'എഫേസ്യർ': 'Ephesians',
  'ജോൺ': 'John',
  // Hindi alternates
  'रोमियो': 'Romans',
  'यूहन्ना': 'John',
  '1 यूहन्ना': '1 John',
  '2 यूहन्ना': '2 John',
  '3 यूहन्ना': '3 John',
}

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

  // Try alternate spellings (common variations from LLM output)
  if (ALTERNATE_SPELLINGS[book]) {
    return ALTERNATE_SPELLINGS[book]
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
  _services: ServiceContainer
): Promise<Response> {

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
