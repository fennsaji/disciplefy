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
   * @param language - Language code (currently only 'en' is supported)
   * @param limit - Maximum number of topics to return
   * @param offset - Number of topics to skip
   * @returns Promise resolving to array of topics
   */
  async getTopicsByLanguage(
    language: string,
    limit: number = 20,
    offset: number = 0
  ): Promise<readonly RecommendedGuideTopic[]> {
    // For now, we only support English topics
    // In future iterations, this could be expanded to include translations
    if (language !== 'en') {
      return []
    }

    const { data, error } = await this.supabaseClient
      .rpc('get_recommended_topics', {
        p_category: null,
        p_difficulty: null,
        p_limit: limit,
        p_offset: offset
      })

    if (error) {
      console.error('Error fetching topics:', error)
      return []
    }

    return this.mapDatabaseTopicsToInterface(data || [])
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
   * @param category - Topic category
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
    if (language !== 'en') {
      return []
    }

    const { data, error } = await this.supabaseClient
      .rpc('get_recommended_topics', {
        p_category: category,
        p_difficulty: null,
        p_limit: limit,
        p_offset: offset
      })

    if (error) {
      console.error('Error fetching topics by category:', error)
      return []
    }

    return this.mapDatabaseTopicsToInterface(data || [])
  }


  /**
   * Retrieves all unique categories from available topics.
   * 
   * @param language - Language code
   * @returns Promise resolving to array of category names
   */
  async getCategories(language = 'en'): Promise<readonly string[]> {
    if (language !== 'en') {
      return []
    }

    const { data, error } = await this.supabaseClient
      .rpc('get_recommended_topics_categories')

    if (error) {
      console.error('Error fetching categories:', error)
      return []
    }

    return (data || []).map((row: any) => row.category)
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

    if (language !== 'en') {
      return []
    }

    // If multiple categories are specified, use the new multi-category function
    if (categories && categories.length > 0) {
      return this.getTopicsByMultipleCategories(categories, language, limit, offset)
    }

    // Otherwise use the existing single category logic
    const { data, error } = await this.supabaseClient
      .rpc('get_recommended_topics', {
        p_category: category || null,
        p_difficulty: null,
        p_limit: limit,
        p_offset: offset
      })

    if (error) {
      console.error('Error fetching topics with combined filters:', error)
      return []
    }

    return this.mapDatabaseTopicsToInterface(data || [])
  }

  /**
   * Retrieves topics filtered by multiple categories.
   * 
   * @param categories - Array of category names
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
    if (language !== 'en' || categories.length === 0) {
      return []
    }

    const { data, error } = await this.supabaseClient
      .rpc('get_recommended_topics_by_categories', {
        p_categories: categories as string[],
        p_limit: limit,
        p_offset: offset
      })

    if (error) {
      console.error('Error fetching topics by multiple categories:', error)
      return []
    }

    return this.mapDatabaseTopicsToInterface(data || [])
  }

  /**
   * Gets the total count of topics for pagination.
   * 
   * @param category - Optional category filter
   * @param categories - Optional multiple categories filter
   * @param language - Language code
   * @returns Promise resolving to total count
   */
  async getTopicsCount(
    category?: string,
    language = 'en',
    categories?: readonly string[]
  ): Promise<number> {
    if (language !== 'en') {
      return 0
    }

    // If multiple categories are specified, use the new multi-category count function
    if (categories && categories.length > 0) {
      return this.getTopicsCountByMultipleCategories(categories, language)
    }

    const { data, error } = await this.supabaseClient
      .rpc('get_recommended_topics_count', {
        p_category: category || null
      })

    if (error) {
      console.error('Error fetching topics count:', error)
      return 0
    }

    return data || 0
  }

  /**
   * Gets the total count of topics for multiple categories.
   * 
   * @param categories - Array of category names
   * @param language - Language code
   * @returns Promise resolving to total count
   */
  async getTopicsCountByMultipleCategories(
    categories: readonly string[],
    language = 'en'
  ): Promise<number> {
    if (language !== 'en' || categories.length === 0) {
      return 0
    }

    const { data, error } = await this.supabaseClient
      .rpc('get_recommended_topics_count_by_categories', {
        p_categories: categories as string[]
      })

    if (error) {
      console.error('Error fetching topics count by multiple categories:', error)
      return 0
    }

    return data || 0
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
}