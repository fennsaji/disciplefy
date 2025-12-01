/**
 * Bible API Service
 *
 * Provides access to authentic Bible translations via API.Bible (American Bible Society)
 *
 * Supported Translations:
 * - English: King James Version (KJV)
 * - Hindi: Indian Revised Version (IRV) 2019
 * - Malayalam: Indian Revised Version (IRV) 2025
 *
 * API Documentation: https://scripture.api.bible/
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// Bible Version IDs from API.Bible
const BIBLE_VERSIONS = {
  en: 'de4e12af7f28f599-02', // King James Version (KJV)
  hi: '1e8ab327edbce67f-01', // Indian Revised Version Hindi 2019
  ml: '3ea0147e32eebe47-01', // Indian Revised Version Malayalam 2025
} as const;

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

  // Common aliases (singular/plural variations and alternative names)
  'Psalm': 'PSA',
  'Song of Songs': 'SNG',
  'Canticle of Canticles': 'SNG',
  'Canticles': 'SNG',
  '1 Sam': '1SA', '2 Sam': '2SA',
  '1 Kgs': '1KI', '2 Kgs': '2KI',
  '1 Chr': '1CH', '2 Chr': '2CH',
  '1 Cor': '1CO', '2 Cor': '2CO',
  '1 Thess': '1TH', '2 Thess': '2TH',
  '1 Tim': '1TI', '2 Tim': '2TI',
  '1 Pet': '1PE', '2 Pet': '2PE',
  'Rev': 'REV',
  'Revelations': 'REV', // Common mistake
};

export interface BibleVerse {
  reference: string;
  text: string;
  translation: string;
  language: string;
}

export interface BibleApiError {
  error: string;
  details?: string;
}

/**
 * Retry configuration for API calls
 */
interface RetryConfig {
  maxAttempts: number;
  initialDelayMs: number;
  maxDelayMs: number;
  backoffMultiplier: number;
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxAttempts: 3,
  initialDelayMs: 500,
  maxDelayMs: 5000,
  backoffMultiplier: 2,
};

/**
 * Delays execution for specified milliseconds
 */
function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Fetch with timeout support
 *
 * @param url - URL to fetch
 * @param options - Fetch options
 * @param timeoutMs - Timeout in milliseconds (default: 30000ms = 30s)
 * @returns Promise<Response>
 * @throws Error if request times out
 */
export async function fetchWithTimeout(
  url: string,
  options: RequestInit = {},
  timeoutMs: number = 30000
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    return response;
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`Request timeout after ${timeoutMs}ms: ${url}`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Retries an async operation with exponential backoff
 *
 * @param operation - The async function to retry
 * @param config - Retry configuration
 * @returns Result of the operation
 * @throws Error if all retry attempts fail
 */
async function withRetry<T>(
  operation: () => Promise<T>,
  config: RetryConfig = DEFAULT_RETRY_CONFIG
): Promise<T> {
  let lastError: Error | undefined;
  let delayMs = config.initialDelayMs;

  for (let attempt = 1; attempt <= config.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));

      // Don't retry on the last attempt
      if (attempt === config.maxAttempts) {
        break;
      }

      // Check if error is retryable (network errors, rate limits, server errors)
      const isRetryable = lastError.message.includes('500') ||
                         lastError.message.includes('502') ||
                         lastError.message.includes('503') ||
                         lastError.message.includes('504') ||
                         lastError.message.includes('429') ||
                         lastError.message.includes('fetch');

      if (!isRetryable) {
        // Don't retry on client errors (400, 401, 404, etc.)
        break;
      }

      console.warn(
        `[Bible API] Attempt ${attempt}/${config.maxAttempts} failed: ${lastError.message}. ` +
        `Retrying in ${delayMs}ms...`
      );

      await delay(delayMs);

      // Exponential backoff with max cap
      delayMs = Math.min(delayMs * config.backoffMultiplier, config.maxDelayMs);
    }
  }

  throw lastError || new Error('Operation failed without error details');
}

/**
 * Parses a Bible reference string into API.Bible verse ID format
 *
 * @param reference - Bible reference (e.g., "John 3:16", "Philippians 4:13")
 * @returns Verse ID in format "BBB.C.V" (e.g., "JHN.3.16")
 * @throws Error if reference format is invalid
 */
export function parseReference(reference: string): string {
  // Match patterns like "John 3:16", "1 Corinthians 13:4-8", "Psalm 23:1"
  const match = reference.match(/^((?:\d\s)?[A-Za-z\s]+)\s+(\d+):(\d+)(?:-\d+)?$/);

  if (!match) {
    throw new Error(`Invalid Bible reference format: ${reference}`);
  }

  const [, bookName, chapter, verse] = match;
  const bookCode = BOOK_CODES[bookName.trim()];

  if (!bookCode) {
    throw new Error(`Unknown book name: ${bookName}`);
  }

  return `${bookCode}.${chapter}.${verse}`;
}

/**
 * Fetches a Bible verse from API.Bible
 *
 * @param reference - Bible reference (e.g., "John 3:16")
 * @param language - Language code ('en', 'hi', 'ml')
 * @returns Promise<BibleVerse> - Verse data with text and metadata
 * @throws Error if API request fails or verse not found
 */
export async function fetchBibleVerse(
  reference: string,
  language: 'en' | 'hi' | 'ml'
): Promise<BibleVerse> {
  const apiKey = Deno.env.get('BIBLE_API');

  if (!apiKey) {
    throw new Error('BIBLE_API key not configured in environment variables');
  }

  const bibleId = BIBLE_VERSIONS[language];
  const verseId = parseReference(reference);

  const params = new URLSearchParams({
    'content-type': 'text',           // Plain text format
    'include-notes': 'false',         // No footnotes
    'include-titles': 'false',        // No section titles/headings
    'include-chapter-numbers': 'false', // No chapter numbers
    'include-verse-numbers': 'false', // No verse numbers
  });

  const url = `https://api.scripture.api.bible/v1/bibles/${bibleId}/verses/${verseId}?${params.toString()}`;

  // Wrap the fetch operation with retry logic
  return withRetry(async () => {
    try {
      // Fetch with 10 second timeout (Bible API should respond quickly)
      const response = await fetchWithTimeout(
        url,
        {
          headers: {
            'api-key': apiKey,
          },
        },
        10000 // 10 second timeout
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(
          `API.Bible request failed: ${response.status} - ${JSON.stringify(errorData)}`
        );
      }

      const data = await response.json();

      // Extract clean text (remove HTML tags, verse numbers, footnotes)
      const verseText = cleanVerseText(data.data.content);

      return {
        reference,
        text: verseText,
        translation: getTranslationName(language),
        language,
      };
    } catch (error) {
      console.error(`[Bible API] Error fetching verse ${reference} (${language}):`, error);
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to fetch Bible verse: ${errorMessage}`);
    }
  });
}

/**
 * Fetches a Bible verse in all three languages with graceful fallback
 *
 * @param reference - Bible reference (e.g., "John 3:16")
 * @returns Promise<Record<string, BibleVerse>> - Verses in all languages (falls back to empty string if a language fails)
 */
export async function fetchVerseAllLanguages(
  reference: string
): Promise<Record<'en' | 'hi' | 'ml', BibleVerse>> {
  console.log(`[Bible API] Fetching verse in all languages: ${reference}`);

  // Fetch all languages with individual error handling
  const results = await Promise.allSettled([
    fetchBibleVerse(reference, 'en'),
    fetchBibleVerse(reference, 'hi'),
    fetchBibleVerse(reference, 'ml'),
  ]);

  // Extract results with detailed logging
  const en = results[0].status === 'fulfilled' 
    ? results[0].value 
    : (() => {
        console.error(`[Bible API] ❌ Failed to fetch English translation:`, results[0].reason);
        throw new Error(`English translation required but failed: ${results[0].reason}`);
      })();

  const hi = results[1].status === 'fulfilled'
    ? results[1].value
    : (() => {
        console.error(`[Bible API] ⚠️ Failed to fetch Hindi translation:`, results[1].reason);
        console.error(`[Bible API] Hindi version ID: ${BIBLE_VERSIONS.hi}`);
        console.error(`[Bible API] Using empty fallback for Hindi`);
        return {
          reference,
          text: '',
          translation: getTranslationName('hi'),
          language: 'hi',
        } as BibleVerse;
      })();

  const ml = results[2].status === 'fulfilled'
    ? results[2].value
    : (() => {
        console.error(`[Bible API] ⚠️ Failed to fetch Malayalam translation:`, results[2].reason);
        console.error(`[Bible API] Malayalam version ID: ${BIBLE_VERSIONS.ml}`);
        console.error(`[Bible API] Using empty fallback for Malayalam`);
        return {
          reference,
          text: '',
          translation: getTranslationName('ml'),
          language: 'ml',
        } as BibleVerse;
      })();

  console.log('[Bible API] ✅ Fetch results:', {
    en_success: results[0].status === 'fulfilled',
    hi_success: results[1].status === 'fulfilled',
    ml_success: results[2].status === 'fulfilled',
    en_length: en.text.length,
    hi_length: hi.text.length,
    ml_length: ml.text.length,
  });

  return { en, hi, ml };
}

/**
 * Removes HTML tags, verse numbers, and formatting from API.Bible verse content
 *
 * @param content - Raw HTML content from API.Bible
 * @returns Clean verse text
 */
function cleanVerseText(content: string): string {
  // Remove HTML tags
  let cleaned = content.replace(/<[^>]*>/g, '');

  // Remove verse numbers in brackets [1], [2], etc.
  cleaned = cleaned.replace(/\[\d+\]/g, '');

  // Remove verse numbers at the start (e.g., "13I can do..." -> "I can do...")
  cleaned = cleaned.replace(/^\d+\s*/g, '');

  // Remove footnote markers
  cleaned = cleaned.replace(/\s*\*+\s*/g, ' ');

  // Normalize whitespace
  cleaned = cleaned.replace(/\s+/g, ' ').trim();

  return cleaned;
}

/**
 * Gets the full translation name for display
 *
 * @param language - Language code
 * @returns Full translation name
 */
function getTranslationName(language: 'en' | 'hi' | 'ml'): string {
  const names = {
    en: 'King James Version (KJV)',
    hi: 'Indian Revised Version Hindi 2019',
    ml: 'Indian Revised Version Malayalam 2025',
  };

  return names[language];
}

/**
 * Validates if a Bible reference is in the correct format
 *
 * @param reference - Bible reference string
 * @returns boolean - True if valid format
 */
export function isValidReference(reference: string): boolean {
  try {
    parseReference(reference);
    return true;
  } catch {
    return false;
  }
}

/**
 * Caches Bible verses in Supabase database (all languages together)
 *
 * @param verses - Record of BibleVerse objects by language
 * @param verseDate - Date for which this verse is displayed
 */
export async function cacheVerses(
  verses: Record<'en' | 'hi' | 'ml', BibleVerse>,
  verseDate: Date
): Promise<void> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseKey) {
    console.warn('[Bible API] Supabase credentials not available, skipping cache');
    return;
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  const dateKey = verseDate.toISOString().split('T')[0];
  // Cache for 6 months (same as daily verse cache)
  const expiresAt = new Date();
  expiresAt.setMonth(expiresAt.getMonth() + 6);

  const verseData = {
    reference: verses.en.reference,
    translations: {
      esv: verses.en.text,
      hi: verses.hi.text,
      ml: verses.ml.text,
    },
    referenceTranslations: {
      en: verses.en.reference,
      hi: verses.hi.reference,
      ml: verses.ml.reference,
    }
  };

  const { error } = await supabase
    .from('daily_verses_cache')
    .upsert({
      date_key: dateKey,
      verse_data: verseData,
      is_active: true,
      expires_at: expiresAt.toISOString(),
    }, {
      onConflict: 'date_key',
    });

  if (error) {
    console.error('[Bible API] Failed to cache verses:', error);
  }
}

/**
 * Retrieves cached Bible verses from Supabase database
 *
 * @param verseDate - Date for which to retrieve cached verses
 * @returns Promise<Record<'en' | 'hi' | 'ml', BibleVerse> | null> - Cached verses or null if not found
 */
export async function getCachedVerses(
  verseDate: Date
): Promise<Record<'en' | 'hi' | 'ml', BibleVerse> | null> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseKey) {
    return null;
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  const dateKey = verseDate.toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('daily_verses_cache')
    .select('verse_data')
    .eq('date_key', dateKey)
    .eq('is_active', true)
    .gt('expires_at', new Date().toISOString())
    .single();

  if (error || !data) {
    return null;
  }

  const verseData = data.verse_data as {
    reference: string;
    translations: { esv: string; hi?: string; ml?: string; hindi?: string; malayalam?: string };
    referenceTranslations: { en: string; hi: string; ml: string };
  };

  // Handle both old ('hindi'/'malayalam') and new ('hi'/'ml') key formats for backward compatibility
  return {
    en: {
      reference: verseData.referenceTranslations.en,
      text: verseData.translations.esv,
      translation: 'King James Version (KJV)',
      language: 'en',
    },
    hi: {
      reference: verseData.referenceTranslations.hi,
      text: verseData.translations.hi || verseData.translations.hindi || '',
      translation: 'Indian Revised Version Hindi 2019',
      language: 'hi',
    },
    ml: {
      reference: verseData.referenceTranslations.ml,
      text: verseData.translations.ml || verseData.translations.malayalam || '',
      translation: 'Indian Revised Version Malayalam 2025',
      language: 'ml',
    }
  };
}
