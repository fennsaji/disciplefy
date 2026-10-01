// Supabase client is now injected via DI container - no need to import createClient
import type { LLMService } from '../_shared/services/llm-service.ts'
import { isBibleApiCallsEnabled } from '../_shared/services/bible-availability.ts'
import { TtlCache, msUntilNextUtcMidnight } from '../_shared/utils/ttl-cache.ts'
import { fetchVerseAllLanguages } from '../_shared/services/bible-text-service.ts'

/** Fetches verse text per language for a reference (default: self-hosted BSB / IRV). */
export type VerseTextFetcher = (reference: string) => Promise<Record<'en' | 'hi' | 'ml', { text: string }>>

/**
 * daily_verses_cache.text_source of rows whose wording came from the current
 * Bible text source. Rows with any other value (e.g. 'bible_api', KJV wording
 * from API.Bible) are refreshed in place on read, keeping their reference.
 */
export const TEXT_SOURCE = 'bible_text_bsb_irv'

const defaultVerseTextFetcher: VerseTextFetcher = (reference) => fetchVerseAllLanguages(reference)

/** Strips paragraph marks and stray unbalanced quote marks around a single verse. */
export function tidyVerseText(text: string): string {
  let t = (text ?? '').replace(/¶/g, '').replace(/\s+/g, ' ').trim()
  const opens = (t.match(/“/g) ?? []).length
  const closes = (t.match(/”/g) ?? []).length
  if (opens > closes && t.startsWith('“')) t = t.slice(1).trim()
  if (closes > opens && t.endsWith('”')) t = t.slice(0, -1).trim()
  return t
}

/**
 * Verses read from daily_verses_cache, per worker, keyed by date_key.
 *
 * The row for a date is the same for every user and every language (it holds
 * all translations), so one read serves the rest of the day. An entry lives at
 * most until the next UTC midnight (date_key is a UTC date) and never past the
 * row's own expires_at, and at most an hour for dates other than today.
 * Only rows read back from the table are cached — never a freshly generated or
 * fallback verse — so every worker serves exactly what the table holds.
 */
const verseMemoryCache = new TtlCache<DailyVerseData>(60 * 60 * 1000, 64)
const MAX_OTHER_DATE_TTL_MS = 60 * 60 * 1000

/** Test hook: forget every verse held in memory. */
export function clearDailyVerseMemoryCache(): void {
  verseMemoryCache.clear()
}

/**
 * Daily Verse Service
 * 
 * Handles fetching, caching, and serving daily Bible verses
 * in multiple translations with fallback mechanisms.
 *
 * The LLM only chooses the reference. Verse wording always comes from the
 * self-hosted Bible text: BSB (public domain) for English, IRV for
 * Hindi/Malayalam — the same versions fetch-verse serves by default. The LLM
 * never writes Scripture text.
 */

interface DailyVerseData {
  id?: string // UUID from daily_verses_cache table (optional for generated verses)
  reference: string
  referenceTranslations: {
    en: string
    hi: string
    ml: string
  }
  translations: {
    // Key kept as `esv` for backward compatibility (installed apps and cached
    // rows read it). It holds Berean Standard Bible (BSB) text, not ESV
    // (KJV in rows written before TEXT_SOURCE, which are refreshed on read).
    esv: string
    hi: string // IRV Hindi
    ml: string // IRV Malayalam
  }
  date: string
  fromCache?: boolean // signals whether this came from cache (true) or was LLM-generated (false)
}

interface BibleApiResponse {
  reference: string
  text: string
  translation_id?: string
  translation_name?: string
}

export class DailyVerseService {
  private readonly CACHE_TABLE = 'daily_verses_cache'
  
  // Emergency fallback verses (LLM or Bible text unavailable). Text is exact
  // BSB (public domain) for English and IRV for Hindi/Malayalam, matching the
  // versions the app cites. Never put ESV or LLM wording here.
  private readonly EMERGENCY_FALLBACK_VERSES = [
    {
      reference: "John 3:16",
      referenceTranslations: {
        en: "John 3:16",
        hi: "यूहन्ना 3:16",
        ml: "യോഹന്നാൻ 3:16"
      },
      translations: {
        esv: "For God so loved the world that He gave His one and only Son, that everyone who believes in Him shall not perish but have eternal life.",
        hi: "क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे, वह नाश न हो, परन्तु अनन्त जीवन पाए।",
        ml: "തന്‍റെ ഏകജാതനായ പുത്രനിൽ വിശ്വസിക്കുന്ന ഏവനും നശിച്ചുപോകാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന് ദൈവം അവനെ നല്കുവാൻ തക്കവണ്ണം ലോകത്തെ സ്നേഹിച്ചു."
      }
    },
    {
      reference: "Psalm 23:1",
      referenceTranslations: {
        en: "Psalm 23:1",
        hi: "भजन संहिता 23:1",
        ml: "സങ്കീർത്തനം 23:1"
      },
      translations: {
        esv: "The LORD is my shepherd; I shall not want.",
        hi: "यहोवा मेरा चरवाहा है, मुझे कुछ घटी न होगी।",
        ml: "യഹോവ എന്‍റെ ഇടയനാകുന്നു; എനിക്ക് ഒരു കുറവും ഉണ്ടാകുകയില്ല."
      }
    },
    {
      reference: "Philippians 4:13",
      referenceTranslations: {
        en: "Philippians 4:13",
        hi: "फिलिप्पियों 4:13",
        ml: "ഫിലിപ്പിയർ 4:13"
      },
      translations: {
        esv: "I can do all things through Christ who gives me strength.",
        hi: "जो मुझे सामर्थ्य देता है उसमें मैं सब कुछ कर सकता हूँ।",
        ml: "എന്നെ ശക്തനാക്കുന്നവൻ മുഖാന്തരം എനിക്ക് എല്ലാം ചെയ്യുവാൻ കഴിയും."
      }
    },
    {
      reference: "Joshua 1:9",
      referenceTranslations: {
        en: "Joshua 1:9",
        hi: "यहोशू 1:9",
        ml: "യോശുവ 1:9"
      },
      translations: {
        esv: "Have I not commanded you to be strong and courageous? Do not be afraid; do not be discouraged, for the LORD your God is with you wherever you go.",
        hi: "क्या मैंने तुझे आज्ञा नहीं दी? हियाव बाँधकर दृढ़ हो जा; भय न खा, और तेरा मन कच्चा न हो; क्योंकि जहाँ-जहाँ तू जाएगा वहाँ-वहाँ तेरा परमेश्वर यहोवा तेरे संग रहेगा।",
        ml: "നിന്‍റെ ദൈവമായ യഹോവ നീ പോകുന്ന ഇടത്തൊക്കെയും നിന്നോടുകൂടെ ഉള്ളതുകൊണ്ട് ഉറപ്പും ധൈര്യവുമുള്ളവനായിരിക്ക; ഭയപ്പെടരുത്, ഭ്രമിക്കയും അരുത് ഞാൻ തന്നെ നിന്നോട് കല്പിച്ചുവല്ലോ."
      }
    },
    {
      reference: "Romans 8:28",
      referenceTranslations: {
        en: "Romans 8:28",
        hi: "रोमियों 8:28",
        ml: "റോമർ 8:28"
      },
      translations: {
        esv: "And we know that God works all things together for the good of those who love Him, who are called according to His purpose.",
        hi: "और हम जानते हैं, कि जो लोग परमेश्वर से प्रेम रखते हैं, उनके लिये सब बातें मिलकर भलाई ही को उत्पन्न करती हैं; अर्थात् उन्हीं के लिये जो उसकी इच्छा के अनुसार बुलाए हुए हैं।",
        ml: "എന്നാൽ ദൈവത്തെ സ്നേഹിക്കുന്നവർക്ക്, നിർണ്ണയപ്രകാരം വിളിക്കപ്പെട്ടവർക്കു തന്നെ, സകലവും നന്മയ്ക്കായി കൂടി വ്യാപരിക്കുന്നു എന്നു നാം അറിയുന്നു."
      }
    }
  ]

  constructor(
    private readonly supabase: any,
    private readonly getLlmService: () => Promise<LLMService>,
    private readonly fetchVerseText: VerseTextFetcher = defaultVerseTextFetcher,
    private readonly bibleApiCallsEnabled: () => Promise<boolean> = isBibleApiCallsEnabled
  ) {
    // Supabase client and LLM service injected via DI container
  }

  /**
   * Returns the Supabase client instance.
   */
  getSupabaseClient() {
    return this.supabase
  }

  /**
   * Get daily verse for a specific date (defaults to today)
   */
  async getDailyVerse(requestDate?: string | null, language: string = 'en'): Promise<DailyVerseData> {
    const targetDate = requestDate ? new Date(requestDate) : new Date()
    const dateKey = this.formatDateKey(targetDate)

    try {
      console.log(`Getting daily verse for date key: ${dateKey}`)
      
      // In-memory copy of the table row first, then the table itself.
      const memoryVerse = verseMemoryCache.get(dateKey)
      if (memoryVerse) {
        return { ...memoryVerse, fromCache: true }
      }

      // A row for this date fixes the reference for the whole day. If its
      // wording is legacy (LLM-written) or past its TTL, refresh only the
      // wording in place — never pick a new reference for an existing date.
      const cachedRow = await this.getCachedRow(dateKey)
      if (cachedRow) {
        if (!cachedRow.needsRefresh) {
          console.log(`Daily verse cache hit for date: ${dateKey}`)
          this.rememberVerse(dateKey, cachedRow.verse, cachedRow.expiresAt)
          return { ...cachedRow.verse, fromCache: true }
        }
        const refreshed = await this.refreshVerseText(dateKey, cachedRow.verse)
        if (refreshed) {
          this.rememberVerse(dateKey, refreshed)
          return { ...refreshed, fromCache: true }
        }
        // Refresh failed: keep serving the existing row (not held in memory,
        // so the next read retries the refresh).
        return { ...cachedRow.verse, fromCache: true }
      }

      console.log(`No cached verse found, generating new verse for date: ${dateKey}`)

      // Operational kill-switch: skip Bible text lookups, use deterministic fallback.
      if (!(await this.bibleApiCallsEnabled())) {
        console.warn('[DailyVerse] bible_api_calls_enabled is OFF — using fallback verse, no Bible text lookup')
        const fallback = this.getFallbackVerse(targetDate)
        // Keep the cached row's UUID on the verse: a verse handed to the client
        // without an id gets a synthetic `temp-<date>` id there, and every
        // feature that later resolves the verse by id (adding it to memory
        // verses) then fails for the rest of the day.
        try {
          fallback.id = await this.cacheVerse(dateKey, fallback)
        } catch (cacheError) {
          console.warn('Failed to cache fallback verse (continuing anyway):', cacheError)
        }
        return { ...fallback, fromCache: false }
      }

      // Generate new verse for the date with language preference
      const newVerse = await this.generateDailyVerse(targetDate, language)

      // Try to cache the new verse and get the UUID
      try {
        const fromBibleApi = !this.EMERGENCY_FALLBACK_VERSES.some(v => v.translations.esv === newVerse.translations.esv)
        const uuid = await this.cacheVerse(dateKey, newVerse, fromBibleApi ? TEXT_SOURCE : null)
        // Add the UUID to the verse data
        newVerse.id = uuid
        console.log(`Daily verse cached successfully for date: ${dateKey}, UUID: ${uuid}`)
      } catch (cacheError) {
        console.warn('Failed to cache verse (continuing anyway):', cacheError)
      }

      console.log(`Daily verse generated for date: ${dateKey}, reference: ${newVerse.reference}`)
      return { ...newVerse, fromCache: false }

    } catch (error) {
      console.error('Error getting daily verse:', error)
      console.log('Falling back to deterministic verse selection')

      // Cache the fallback too, so the response still carries a real id. This
      // path used to return an id-less verse, which the client stored for the
      // day under a synthetic `temp-<date>` id that no row could ever match.
      const fallback = this.getFallbackVerse(targetDate)
      try {
        fallback.id = await this.cacheVerse(dateKey, fallback)
      } catch (cacheError) {
        console.warn('Failed to cache fallback verse (continuing anyway):', cacheError)
      }
      return { ...fallback, fromCache: false }
    }
  }

  /**
   * Generate a new daily verse using LLM with anti-repetition logic
   */
  private async generateDailyVerse(date: Date, language: string = 'en'): Promise<DailyVerseData> {
    console.log('=== Starting daily verse generation ===')
    
    try {
      // Get recently used verses from the last 30 days (reduced for testing)
      const recentVerses = await this.getRecentlyUsedVerses(30)
      const recentReferences = recentVerses.map(v => v.verse_data.reference)
      
      console.log(`Found ${recentReferences.length} recently used verses to avoid:`, recentReferences)
      
      // Always attempt LLM generation first
      console.log('Attempting LLM verse generation...')
      const llmResponse = await this.generateVerseWithLLM(recentReferences, language)
      
      console.log('LLM generation successful:', llmResponse.reference)
      
      return { ...llmResponse, date: this.formatDateKey(date) }
      
    } catch (error) {
      console.error('Error generating daily verse with LLM:', error)
      console.log('Falling back to emergency verse selection')
      
      // Fall back to emergency verses if LLM fails
      return this.getEmergencyFallbackVerse(date)
    }
  }

  /**
   * Get recently used verses from the cache to avoid repetition
   */
  private async getRecentlyUsedVerses(days: number): Promise<Array<{verse_data: DailyVerseData}>> {
    try {
      const cutoffDate = new Date()
      cutoffDate.setDate(cutoffDate.getDate() - days)
      const cutoffKey = this.formatDateKey(cutoffDate)
      
      const { data, error } = await this.supabase
        .from(this.CACHE_TABLE)
        .select('verse_data')
        .gte('date_key', cutoffKey)
        .eq('is_active', true)
        .order('date_key', { ascending: false })
      
      if (error) {
        console.error('Error fetching recent verses:', error)
        return []
      }
      
      return data || []
    } catch (error) {
      console.error('Error in getRecentlyUsedVerses:', error)
      return []
    }
  }

  /**
   * LLM picks the reference only; the wording is fetched from the Bible text
   * service (BSB / IRV). Throws when any language's text is missing so the caller uses
   * the deterministic fallback instead of serving a partial verse.
   */
  private async generateVerseWithLLM(excludeReferences: string[], language: string = 'en'): Promise<DailyVerseData> {
    const choice = await (await this.getLlmService()).generateDailyVerse(excludeReferences, language)
    console.log(`LLM selected reference: ${choice.reference}`)

    const texts = await this.fetchVerseText(choice.reference)
    const translations = {
      esv: tidyVerseText(texts.en?.text ?? ''),
      hi: tidyVerseText(texts.hi?.text ?? ''),
      ml: tidyVerseText(texts.ml?.text ?? ''),
    }
    if (!translations.esv || !translations.hi || !translations.ml) {
      throw new Error(`Bible text service returned incomplete text for ${choice.reference}`)
    }

    return {
      reference: choice.reference,
      referenceTranslations: {
        en: choice.referenceTranslations.en,
        hi: choice.referenceTranslations.hi,
        ml: choice.referenceTranslations.ml
      },
      translations,
      date: '' // Will be set by caller
    }
  }

  // Removed the old callLLMForVerse and parseLLMVerseResponse methods
  // as they are no longer needed - we now use the dedicated LLM service method

  /**
   * Normalize verse reference for comparison
   */
  private normalizeReference(verse: string): string {
    const ref = this.extractReference(verse)
    return ref.toLowerCase().replace(/\s+/g, '').replace(/[.:]/g, '')
  }

  /**
   * Extract reference from verse string
   */
  private extractReference(verse: string): string {
    // Handle format: "Reference - Text" or just "Reference"
    const parts = verse.split(' - ')
    return parts[0].trim()
  }

  /**
   * Extract text from verse string
   */
  private extractText(verse: string): string {
    // Handle format: "Reference - Text" or just "Reference"
    const parts = verse.split(' - ')
    return parts.length > 1 ? parts.slice(1).join(' - ').trim() : ''
  }

  /**
   * Find fallback translations for a given verse reference
   */
  private findFallbackTranslations(reference: string): { esv: string; hi: string; ml: string } | null {
    // Normalize the reference for comparison
    const normalizedRef = this.normalizeReference(reference)
    
    for (const fallback of this.EMERGENCY_FALLBACK_VERSES) {
      const normalizedFallback = this.normalizeReference(fallback.reference)
      if (normalizedRef === normalizedFallback) {
        return fallback.translations
      }
    }
    
    return null
  }

  /**
   * Get deterministic verse index based on date for emergency fallback
   */
  private getDeterministicVerseIndex(date: Date): number {
    // Use year and day of year for consistency
    const year = date.getFullYear()
    const dayOfYear = Math.floor((date.getTime() - new Date(year, 0, 0).getTime()) / (1000 * 60 * 60 * 24))
    
    // Simple hash function to distribute verses evenly
    const hash = (year + dayOfYear) * 37
    return hash % this.EMERGENCY_FALLBACK_VERSES.length
  }

  /**
   * Get emergency fallback verse when LLM generation fails
   */
  private getEmergencyFallbackVerse(date: Date): DailyVerseData {
    const verseIndex = this.getDeterministicVerseIndex(date)
    const fallbackVerse = this.EMERGENCY_FALLBACK_VERSES[verseIndex]

    return {
      reference: fallbackVerse.reference,
      referenceTranslations: { ...fallbackVerse.referenceTranslations },
      translations: { ...fallbackVerse.translations },
      date: this.formatDateKey(date)
    }
  }

  /**
   * Reads the active row for a date, expired or not. needsRefresh is true when
   * its wording did not come from the current Bible text source (TEXT_SOURCE) or its TTL has passed.
   */
  private async getCachedRow(
    dateKey: string
  ): Promise<{ verse: DailyVerseData; expiresAt: string | null; needsRefresh: boolean } | null> {
    try {
      const { data, error } = await this.supabase
        .from(this.CACHE_TABLE)
        .select('uuid, verse_data, expires_at, text_source')
        .eq('date_key', dateKey)
        .eq('is_active', true)
        .maybeSingle()

      if (error) {
        console.log('No cached verse found or database error:', error.message)
        return null
      }
      if (!data?.verse_data) return null

      const cachedData = data.verse_data
      cachedData.id = data.uuid

      // Backward compatibility: Add referenceTranslations if missing from old cache
      if (!cachedData.referenceTranslations) {
        cachedData.referenceTranslations = {
          en: cachedData.reference,
          hi: cachedData.reference,
          ml: cachedData.reference
        }
      }

      // Backward compatibility: Map 'hindi'/'malayalam' keys to 'hi'/'ml' keys
      if (cachedData.translations) {
        const translations = cachedData.translations as Record<string, string>
        cachedData.translations = {
          esv: translations.esv || '',
          hi: translations.hi || translations.hindi || '',
          ml: translations.ml || translations.malayalam || ''
        }
      }

      const expired = !data.expires_at || new Date(data.expires_at).getTime() <= Date.now()
      return {
        verse: cachedData as DailyVerseData,
        expiresAt: data.expires_at ?? null,
        needsRefresh: expired || data.text_source !== TEXT_SOURCE,
      }
    } catch (error) {
      console.error('Error fetching cached verse:', error)
      return null
    }
  }

  /**
   * Re-fetches the wording for an existing row's reference and updates the row
   * in place (same uuid, new expires_at). Returns null on any failure so the
   * caller keeps serving the existing row and retries on a later read.
   */
  private async refreshVerseText(dateKey: string, verse: DailyVerseData): Promise<DailyVerseData | null> {
    try {
      if (!(await this.bibleApiCallsEnabled())) return null
      const texts = await this.fetchVerseText(verse.reference)
      const translations = {
        esv: tidyVerseText(texts.en?.text ?? ''),
        hi: tidyVerseText(texts.hi?.text ?? ''),
        ml: tidyVerseText(texts.ml?.text ?? ''),
      }
      if (!translations.esv || !translations.hi || !translations.ml) {
        throw new Error(`Bible text service returned incomplete text for ${verse.reference}`)
      }
      const { id, fromCache: _fromCache, ...stored } = verse
      const updated: DailyVerseData = { ...stored, translations }
      const { error } = await this.supabase
        .from(this.CACHE_TABLE)
        .update({
          verse_data: updated,
          text_source: TEXT_SOURCE,
          expires_at: this.getExpirationDate(),
          updated_at: new Date().toISOString(),
        })
        .eq('date_key', dateKey)
        .eq('uuid', id)
      if (error) throw error
      console.log(`Daily verse text refreshed for date: ${dateKey}, reference kept: ${verse.reference}`)
      return { ...updated, id }
    } catch (error) {
      console.warn(`Daily verse text refresh failed for ${dateKey} (serving existing row):`, error)
      return null
    }
  }

  /**
   * Holds a verse read from the table in memory until the date rolls over
   * (UTC), the row expires, or an hour passes for a date other than today.
   */
  private rememberVerse(dateKey: string, verse: DailyVerseData, rowExpiresAt?: string | null): void {
    const now = new Date()
    let ttlMs = dateKey === this.formatDateKey(now)
      ? msUntilNextUtcMidnight(now)
      : MAX_OTHER_DATE_TTL_MS
    if (rowExpiresAt) {
      const rowTtl = new Date(rowExpiresAt).getTime() - now.getTime()
      if (!Number.isNaN(rowTtl)) ttlMs = Math.min(ttlMs, rowTtl)
    }
    verseMemoryCache.set(dateKey, verse, ttlMs)
  }

  /**
   * Cache verse in database and return the UUID
   */
  private async cacheVerse(dateKey: string, verseData: DailyVerseData, textSource: typeof TEXT_SOURCE | null = null): Promise<string> {
    try {
      const { data, error } = await this.supabase
        .from(this.CACHE_TABLE)
        .upsert({
          date_key: dateKey,
          verse_data: verseData,
          text_source: textSource,
          is_active: true,
          created_at: new Date().toISOString(),
          expires_at: this.getExpirationDate()
        }, {
          onConflict: 'date_key',
          ignoreDuplicates: false  // Update existing record if conflict
        })
        .select('uuid')
        .single()

      if (error) {
        console.error('[Error] Error caching verse:', error)
        throw error
      }

      const uuid = data?.uuid
      if (!uuid) {
        throw new Error('Failed to get UUID from cached verse')
      }

      console.log(`[Info] Verse cached successfully for date: ${dateKey}, UUID: ${uuid}`)
      return uuid

    } catch (error) {
      console.error('[Error] Error in cacheVerse:', error)
      throw error
    }
  }

  /**
   * Get fallback verse when all else fails
   */
  private getFallbackVerse(date: Date): DailyVerseData {
    return this.getEmergencyFallbackVerse(date)
  }

  /**
   * Format date as YYYY-MM-DD for consistent caching
   */
  private formatDateKey(date: Date): string {
    return date.toISOString().split('T')[0]
  }

  /**
   * Get cache expiration date.
   * Rows are re-read from the Bible text source after 30 days.
   */
  private getExpirationDate(): string {
    const expirationDate = new Date()
    expirationDate.setDate(expirationDate.getDate() + 30)
    return expirationDate.toISOString()
  }

  /**
   * Future enhancement: Fetch verse from external Bible API
   * Currently commented out to avoid external dependencies
   */
  /*
  private async fetchFromBibleApi(date: Date): Promise<DailyVerseData> {
    // Implementation for api.bible or bible-api.com
    // Would require API keys and translation mapping
    throw new Error('External API integration not yet implemented')
  }
  */
}