import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Repository for managing Recommended Guide Bible study topics.
 * 
 * Provides access to curated topics following structured 4-step methodology:
 * - Context: Historical and cultural background
 * - Scholar's Guide: Original meaning and interpretation
 * - Group Discussion: Contemporary application questions
 * - Application: Personal life transformation steps
 */

/**
 * Represents a Recommended Guide methodology topic for Bible study.
 */
interface RecommendedGuideTopic {
  readonly id: string
  readonly title: string
  readonly description: string
  readonly key_verses: readonly string[]
  readonly category: string
  readonly tags: readonly string[]
  // For non-English languages, include English data for better search functionality
  readonly english_title?: string
  readonly english_description?: string
  readonly english_category?: string
}

/**
 * Database response from get_recommended_topics function
 */
interface DatabaseRecommendedTopic {
  readonly id: string
  readonly title: string
  readonly description: string
  readonly category: string
  readonly tags: readonly string[]
  readonly display_order: number
  readonly created_at: string
}

/**
 * Repository for accessing Recommended Guide Bible study topics.
 * 
 * This repository provides a clean abstraction over the topics data,
 * following the Repository pattern for data access.
 */
export class TopicsRepository {
  /**
   * Constructor with dependency injection
   * @param supabaseClient - Shared SupabaseClient instance from service container
   */
  constructor(private readonly supabaseClient: SupabaseClient) {}
  
  /**
   * Retrieves all topics for a specific language.
   * 
   * @param language - Language code ('en', 'hi', 'ml', etc.)
   * @param limit - Maximum number of topics to return
   * @param offset - Number of topics to skip
   * @returns Promise resolving to array of topics
   */
  async getTopicsByLanguage(
    language: string,
    limit: number = 20,
    offset: number = 0
  ): Promise<readonly RecommendedGuideTopic[]> {
    if (language === 'en') {
      // For English, query the main table
      const { data, error } = await this.supabaseClient
        .rpc('get_recommended_topics', {
          p_category: null,
          p_difficulty: null,
          p_limit: limit,
          p_offset: offset
        })

      if (error) {
        console.error('Error fetching English topics:', error)
        return []
      }

      return this.mapDatabaseTopicsToInterface(data || [])
    }

    // For other languages, join with translations table and include English fallback
    const { data, error } = await this.supabaseClient
      .from('recommended_topics')
      .select(`
        id,
        title,
        description,
        category,
        tags,
        display_order,
        created_at,
        recommended_topics_translations!left(
          lang_code,
          title,
          description,
          category
        )
      `)
      .or(`lang_code.eq.${language},lang_code.eq.en`, { foreignTable: 'recommended_topics_translations' })
      .order('display_order', { ascending: true })
      .range(offset, offset + limit - 1)

    if (error) {
      console.error(`Error fetching topics for language ${language}:`, error)
      // Fallback to English
      return this.getTopicsByLanguage('en', limit, offset)
    }

    return this.mapTranslatedTopicsToInterface(data || [], language)
  }

  /**
   * Retrieves a specific topic by its ID.
   * 
   * @param id - Unique topic identifier
   * @param language - Language code
   * @returns Promise resolving to topic or undefined if not found
   */
  async getTopicById(id: string, language = 'en'): Promise<RecommendedGuideTopic | undefined> {
    const topics = await this.getTopicsByLanguage(language)
    return topics.find(topic => topic.id === id)
  }

  /**
   * Retrieves topics filtered by category.
   * 
   * @param category - Topic category (in English for filtering)
   * @param language - Language code
   * @param limit - Maximum number of topics to return
   * @param offset - Number of topics to skip
   * @returns Promise resolving to filtered topics array
   */
  async getTopicsByCategory(
    category: string,
    language = 'en',
    limit: number = 20,
    offset: number = 0
  ): Promise<readonly RecommendedGuideTopic[]> {
    if (language === 'en') {
      const { data, error } = await this.supabaseClient
        .rpc('get_recommended_topics', {
          p_category: category,
          p_difficulty: null,
          p_limit: limit,
          p_offset: offset
        })

      if (error) {
        console.error('Error fetching English topics by category:', error)
        return []
      }

      return this.mapDatabaseTopicsToInterface(data || [])
    }

    // For other languages, filter by English category and include translations
    const { data, error } = await this.supabaseClient
      .from('recommended_topics')
      .select(`
        id,
        title,
        description,
        category,
        tags,
        display_order,
        created_at,
        recommended_topics_translations!left(
          lang_code,
          title,
          description,
          category
        )
      `)
      .eq('category', category)
      .eq('recommended_topics_translations.lang_code', language)
      .order('display_order', { ascending: true })
      .range(offset, offset + limit - 1)

    if (error) {
      console.error(`Error fetching topics by category for language ${language}:`, error)
      // Fallback to English
      return this.getTopicsByCategory(category, 'en', limit, offset)
    }

    return this.mapTranslatedTopicsToInterface(data || [], language)
  }


  /**
   * Retrieves all unique categories from available topics.
   * 
   * @param language - Language code
   * @returns Promise resolving to array of category names
   */
  async getCategories(language = 'en'): Promise<readonly string[]> {
    if (language === 'en') {
      const { data, error } = await this.supabaseClient
        .rpc('get_recommended_topics_categories')

      if (error) {
        console.error('Error fetching English categories:', error)
        return []
      }

      return (data || []).map((row: any) => row.category)
    }

    // For other languages, get translated categories
    const { data, error } = await this.supabaseClient
      .from('recommended_topics_translations')
      .select('category')
      .eq('lang_code', language)

    if (error) {
      console.error(`Error fetching categories for language ${language}:`, error)
      // Fallback to English
      return this.getCategories('en')
    }

    // Get unique categories
    const categories = [...new Set((data || []).map((row: any) => row.category))]
    return categories
  }

  /**
   * Searches topics by title and description.
   * 
   * @param query - Search query string
   * @param language - Language code
   * @param limit - Maximum number of topics to return
   * @param offset - Number of topics to skip
   * @returns Promise resolving to matching topics
   */
  async searchTopics(
    query: string,
    language = 'en',
    limit: number = 20,
    offset: number = 0
  ): Promise<readonly RecommendedGuideTopic[]> {
    // For now, return all topics and filter client-side
    // In future, we can add a search function to the database
    const topics = await this.getTopicsByLanguage(language, limit, offset)
    const normalizedQuery = query.toLowerCase()

    return topics.filter(topic =>
      topic.title.toLowerCase().includes(normalizedQuery) ||
      topic.description.toLowerCase().includes(normalizedQuery) ||
      topic.tags.some(tag => tag.toLowerCase().includes(normalizedQuery))
    )
  }

  /**
   * Retrieves topics with combined filters and proper pagination.
   * 
   * @param options - Filter and pagination options
   * @returns Promise resolving to filtered topics array
   */
  async getTopics(options: {
    category?: string
    categories?: readonly string[]
    language?: string
    limit?: number
    offset?: number
  }): Promise<readonly RecommendedGuideTopic[]> {
    const {
      category,
      categories,
      language = 'en',
      limit = 20,
      offset = 0
    } = options

    // If multiple categories are specified, use the multi-category function
    if (categories && categories.length > 0) {
      return this.getTopicsByMultipleCategories(categories, language, limit, offset)
    }

    // For single category or all topics
    if (category) {
      return this.getTopicsByCategory(category, language, limit, offset)
    }

    // For all topics
    return this.getTopicsByLanguage(language, limit, offset)
  }

  /**
   * Retrieves topics filtered by multiple categories.
   * 
   * @param categories - Array of category names (in English for filtering)
   * @param language - Language code
   * @param limit - Maximum number of topics to return
   * @param offset - Number of topics to skip
   * @returns Promise resolving to filtered topics array
   */
  async getTopicsByMultipleCategories(
    categories: readonly string[],
    language = 'en',
    limit: number = 20,
    offset: number = 0
  ): Promise<readonly RecommendedGuideTopic[]> {
    if (categories.length === 0) {
      return []
    }

    if (language === 'en') {
      const { data, error } = await this.supabaseClient
        .rpc('get_recommended_topics_by_categories', {
          p_categories: categories as string[],
          p_limit: limit,
          p_offset: offset
        })

      if (error) {
        console.error('Error fetching English topics by multiple categories:', error)
        return []
      }

      return this.mapDatabaseTopicsToInterface(data || [])
    }

    // For other languages, filter by English categories and include translations
    const { data, error } = await this.supabaseClient
      .from('recommended_topics')
      .select(`
        id,
        title,
        description,
        category,
        tags,
        display_order,
        created_at,
        recommended_topics_translations!left(
          lang_code,
          title,
          description,
          category
        )
      `)
      .in('category', categories as string[])
      .or(`lang_code.eq.${language},lang_code.is.null`, { foreignTable: 'recommended_topics_translations' })
      .order('display_order', { ascending: true })
      .range(offset, offset + limit - 1)

    if (error) {
      console.error(`Error fetching topics by multiple categories for language ${language}:`, error)
      // Fallback to English
      return this.getTopicsByMultipleCategories(categories, 'en', limit, offset)
    }

    return this.mapTranslatedTopicsToInterface(data || [], language)
  }

  /**
   * Gets the total count of topics for pagination.
   * 
   * @param category - Optional category filter (in English)
   * @param language - Language code
   * @param categories - Optional multiple categories filter (in English)
   * @returns Promise resolving to total count
   */
  async getTopicsCount(
    category?: string,
    language = 'en',
    categories?: readonly string[]
  ): Promise<number> {
    // If multiple categories are specified, use the multi-category count function
    if (categories && categories.length > 0) {
      return this.getTopicsCountByMultipleCategories(categories, language)
    }

    if (language === 'en') {
      const { data, error } = await this.supabaseClient
        .rpc('get_recommended_topics_count', {
          p_category: category || null
        })

      if (error) {
        console.error('Error fetching English topics count:', error)
        return 0
      }

      return data || 0
    }

    // For other languages, count from translations table
    let query = this.supabaseClient
      .from('recommended_topics')
      .select('id', { count: 'exact' })
      .eq('recommended_topics_translations.lang_code', language)

    if (category) {
      query = query.eq('category', category)
    }

    const { count, error } = await query

    if (error) {
      console.error(`Error fetching topics count for language ${language}:`, error)
      // Fallback to English count
      return this.getTopicsCount(category, 'en', categories)
    }

    return count || 0
  }

  /**
   * Gets the total count of topics for multiple categories.
   * 
   * @param categories - Array of category names (in English)
   * @param language - Language code
   * @returns Promise resolving to total count
   */
  async getTopicsCountByMultipleCategories(
    categories: readonly string[],
    language = 'en'
  ): Promise<number> {
    if (categories.length === 0) {
      return 0
    }

    if (language === 'en') {
      const { data, error } = await this.supabaseClient
        .rpc('get_recommended_topics_count_by_categories', {
          p_categories: categories as string[]
        })

      if (error) {
        console.error('Error fetching English topics count by multiple categories:', error)
        return 0
      }

      return data || 0
    }

    // For other languages, count from translations table
    const { count, error } = await this.supabaseClient
      .from('recommended_topics')
      .select('id, recommended_topics_translations!inner(id)', { count: 'exact', head: true })
      .in('category', categories as string[])
      .eq('recommended_topics_translations.lang_code', language)

    if (error) {
      console.error(`Error fetching topics count by multiple categories for language ${language}:`, error)
      // Fallback to English count
      return this.getTopicsCountByMultipleCategories(categories, 'en')
    }

    return count || 0
  }

  /**
   * Maps database topics to interface format.
   * 
   * @param dbTopics - Database topics array
   * @returns Interface-compliant topics array
   */
  private mapDatabaseTopicsToInterface(
    dbTopics: DatabaseRecommendedTopic[]
  ): readonly RecommendedGuideTopic[] {
    return dbTopics.map(dbTopic => ({
      id: dbTopic.id,
      title: dbTopic.title,
      description: dbTopic.description,
      key_verses: [], // Empty for now - not stored in database
      category: dbTopic.category,
      tags: dbTopic.tags
    }))
  }

  /**
   * Maps translated database topics to interface format with English fallback.
   * 
   * @param dbTopics - Database topics with translations array
   * @param language - Target language code
   * @returns Interface-compliant topics array
   */
  private mapTranslatedTopicsToInterface(
    dbTopics: any[],
    language: string
  ): readonly RecommendedGuideTopic[] {
    return dbTopics.map(dbTopic => {
      const translations = dbTopic.recommended_topics_translations || []
      
      // Prefer requested language translation, fallback to English
      const preferredTranslation = translations.find((t: any) => t.lang_code === language)
      const englishTranslation = translations.find((t: any) => t.lang_code === 'en')
      const translation = preferredTranslation || englishTranslation
      
      return {
        id: dbTopic.id,
        title: translation?.title || dbTopic.title,
        description: translation?.description || dbTopic.description,
        category: translation?.category || dbTopic.category,
        key_verses: [], // Empty for now - not stored in database
        tags: dbTopic.tags,
        // Include English data for search functionality
        english_title: dbTopic.title,
        english_description: dbTopic.description,
        english_category: dbTopic.category
      }
    })
  }
}