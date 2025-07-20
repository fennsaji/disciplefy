// Supabase client is now injected via DI container - no need to import createClient
import { LLMService } from '../_shared/services/llm-service.ts'

/**
 * Daily Verse Service
 * 
 * Handles fetching, caching, and serving daily Bible verses
 * in multiple translations with fallback mechanisms.
 * Uses LLM generation for dynamic verse selection.
 */

interface DailyVerseData {
  reference: string
  translations: {
    esv: string
    hi: string
    ml: string
  }
  date: string
}

interface BibleApiResponse {
  reference: string
  text: string
  translation_id?: string
  translation_name?: string
}

export class DailyVerseService {
  private readonly CACHE_TABLE = 'daily_verses_cache'
  
  // Emergency fallback verses for when LLM generation fails
  private readonly EMERGENCY_FALLBACK_VERSES = [
    {
      reference: "John 3:16",
      translations: {
        esv: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
        hi: "क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे वह नष्ट न हो, परन्तु अनन्त जीवन पाए।",
        ml: "കാരണം ദൈവം ലോകത്തെ ഇങ്ങനെ സ്നേഹിച്ചു, തന്റെ ഏകജാതനായ പുത്രനെ നൽകി, അവനിൽ വിശ്വസിക്കുന്നവൻ നശിക്കാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്."
      }
    },
    {
      reference: "Psalm 23:1",
      translations: {
        esv: "The Lord is my shepherd; I shall not want.",
        hi: "यहोवा मेरा चरवाहा है; मुझे कमी न होगी।",
        ml: "യഹോവ എന്റെ ഇടയൻ ആകുന്നു; എനിക്കു മുട്ടു വരികയില്ല."
      }
    },
    {
      reference: "Philippians 4:13",
      translations: {
        esv: "I can do all things through him who strengthens me.",
        hi: "मैं उसके द्वारा जो मुझे सामर्थ्य देता है, सब कुछ कर सकता हूँ।",
        ml: "എന്നെ ബലപ്പെടുത്തുന്ന ക്രിസ്തുവിൽ എനിക്കു സകലവും ചെയ്വാൻ കഴിയും."
      }
    },
    {
      reference: "Joshua 1:9",
      translations: {
        esv: "Have I not commanded you? Be strong and courageous. Do not be frightened, and do not be dismayed, for the Lord your God is with you wherever you go.",
        hi: "क्या मैं ने तुझे आज्ञा नहीं दी? हियाव बाँधकर दृढ़ हो जा; भयभीत न हो, और तेरा मन कच्चा न हो क्योंकि जहाँ कहीं तू जाएगा वहाँ तेरा परमेश्वर यहोवा तेरे संग रहेगा।",
        ml: "ഞാൻ നിന്നോടു കല്പിച്ചിട്ടില്ലയോ? ബലപ്പെടുകയും ധൈര്യപ്പെടുകയും ചെയ്ക; ഭയപ്പെടുകയോ ഭ്രമിക്കുകയോ ചെയ്യേണ്ടാ; നീ എവിടെ പോയാലും നിന്റെ ദൈവമായ യഹോവ നിന്നോടുകൂടെ ഉണ്ടു."
      }
    },
    {
      reference: "Romans 8:28",
      translations: {
        esv: "And we know that for those who love God all things work together for good, for those who are called according to his purpose.",
        hi: "और हम जानते हैं कि जो लोग परमेश्वर से प्रेम करते हैं, उनके लिये सब बातें मिलकर भलाई ही को उत्पन्न करती हैं; अर्थात् उन्हीं के लिये जो उसकी इच्छा के अनुसार बुलाए गए हैं।",
        ml: "ദൈവത്തെ സ്നേഹിക്കുന്നവർക്കു, അവന്റെ ഉദ്ദേശ്യത്തിന് അനുസാരമായി വിളിക്കപ്പെട്ടവർക്കു സർവ്വവും ഗുണത്തിന്നായി കൂടിവരുന്നു എന്നു നാം അറിയുന്നു."
      }
    }
  ]

  constructor(
    private readonly supabase: any,
    private readonly llmService: LLMService
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
  async getDailyVerse(requestDate?: string | null): Promise<DailyVerseData> {
    const targetDate = requestDate ? new Date(requestDate) : new Date()
    const dateKey = this.formatDateKey(targetDate)

    try {
      console.log(`Getting daily verse for date key: ${dateKey}`)
      
      // Try to get cached verse first
      const cachedVerse = await this.getCachedVerse(dateKey)
      if (cachedVerse) {
        console.log(`Daily verse cache hit for date: ${dateKey}`)
        return cachedVerse
      }

      console.log(`No cached verse found, generating new verse for date: ${dateKey}`)
      
      // Generate new verse for the date
      const newVerse = await this.generateDailyVerse(targetDate)
      
      // Try to cache the new verse (non-blocking)
      try {
        await this.cacheVerse(dateKey, newVerse)
        console.log(`Daily verse cached successfully for date: ${dateKey}`)
      } catch (cacheError) {
        console.warn('Failed to cache verse (continuing anyway):', cacheError)
      }
      
      console.log(`Daily verse generated for date: ${dateKey}, reference: ${newVerse.reference}`)
      return newVerse

    } catch (error) {
      console.error('Error getting daily verse:', error)
      console.log('Falling back to deterministic verse selection')
      
      // Return fallback verse based on date
      return this.getFallbackVerse(targetDate)
    }
  }

  /**
   * Generate a new daily verse using LLM with anti-repetition logic
   */
  private async generateDailyVerse(date: Date): Promise<DailyVerseData> {
    console.log('=== Starting daily verse generation ===')
    
    try {
      // Get recently used verses from the last 30 days (reduced for testing)
      const recentVerses = await this.getRecentlyUsedVerses(30)
      const recentReferences = recentVerses.map(v => v.verse_data.reference)
      
      console.log(`Found ${recentReferences.length} recently used verses to avoid:`, recentReferences)
      
      // Always attempt LLM generation first
      console.log('Attempting LLM verse generation...')
      const llmResponse = await this.generateVerseWithLLM(recentReferences)
      
      console.log('LLM generation successful:', llmResponse.reference)
      
      return {
        reference: llmResponse.reference,
        translations: llmResponse.translations,
        date: this.formatDateKey(date)
      }
      
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
   * Generate verse using LLM with proper verse content generation
   */
  private async generateVerseWithLLM(excludeReferences: string[]): Promise<DailyVerseData> {
    console.log('Generating daily verse using dedicated LLM method...')
    
    try {
      // Use the dedicated daily verse generation method from LLM service
      const llmResponse = await this.llmService.generateDailyVerse(excludeReferences, 'en')
      
      console.log(`LLM generated verse: ${llmResponse.reference}`)
      
      return {
        reference: llmResponse.reference,
        translations: {
          esv: llmResponse.translations.esv,
          hi: llmResponse.translations.hindi,
          ml: llmResponse.translations.malayalam
        },
        date: '' // Will be set by caller
      }
      
    } catch (llmError) {
      console.error('LLM generation failed:', llmError)
      throw new Error('Failed to generate verse with LLM')
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
      translations: fallbackVerse.translations,
      date: this.formatDateKey(date)
    }
  }

  /**
   * Get cached verse from database
   */
  private async getCachedVerse(dateKey: string): Promise<DailyVerseData | null> {
    try {
      console.log(`Attempting to fetch cached verse for date: ${dateKey}`)
      
      const { data, error } = await this.supabase
        .from(this.CACHE_TABLE)
        .select('verse_data')
        .eq('date_key', dateKey)
        .eq('is_active', true)
        .single()

      if (error) {
        console.log('No cached verse found or database error:', error.message)
        return null
      }

      if (!data) {
        console.log('No cached verse data found')
        return null
      }

      console.log(`Found cached verse for date: ${dateKey}`)
      return data.verse_data as DailyVerseData

    } catch (error) {
      console.error('Error fetching cached verse:', error)
      return null
    }
  }

  /**
   * Cache verse in database
   */
  private async cacheVerse(dateKey: string, verseData: DailyVerseData): Promise<void> {
    try {
      const { error } = await this.supabase
        .from(this.CACHE_TABLE)
        .upsert({
          date_key: dateKey,
          verse_data: verseData,
          is_active: true,
          created_at: new Date().toISOString(),
          expires_at: this.getExpirationDate()
        })

      if (error) {
        console.error('Error caching verse:', error)
      }

    } catch (error) {
      console.error('Error in cacheVerse:', error)
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
   * Get cache expiration date (7 days from now)
   */
  private getExpirationDate(): string {
    const expirationDate = new Date()
    expirationDate.setDate(expirationDate.getDate() + 7)
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