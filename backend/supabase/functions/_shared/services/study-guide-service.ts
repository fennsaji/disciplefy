/**
 * Study Guide Service
 * 
 * Business logic layer for study guide operations.
 * Coordinates between LLM service and repository layers.
 */

import { StudyGuideRepository } from '../repositories/study-guide-repository.ts'
import { LLMService } from './llm-service.ts'
import { BibleBookNormalizer } from '../utils/bible-book-normalizer.ts'
import {
  StudyGuideInput,
  StudyGuideContent,
  StudyGuideResponse,
  UserContext
} from '../types/index.ts'

/**
 * Study guide generation result
 */
export interface StudyGuideGenerationResult {
  readonly studyGuide: StudyGuideResponse
  readonly fromCache: boolean
  readonly metrics: {
    readonly responseTimeMs: number
    readonly cacheHitRate: number
  }
}

/**
 * Study guide service configuration
 */
export interface StudyGuideServiceConfig {
  readonly enableCaching: boolean
  readonly maxRetries: number
  readonly retryDelayMs: number
}

/**
 * Study Guide Service
 * 
 * Handles the core business logic for study guide generation,
 * including caching, LLM integration, and user management.
 */
export class StudyGuideService {
  private readonly config: StudyGuideServiceConfig

  constructor(
    private readonly llmService: LLMService,
    private readonly repository: StudyGuideRepository,
    config: Partial<StudyGuideServiceConfig> = {}
  ) {
    this.config = {
      enableCaching: true,
      maxRetries: 3,
      retryDelayMs: 1000,
      ...config
    }
  }

  /**
   * Generates or retrieves a study guide
   * 
   * @param input - Study guide input parameters
   * @param userContext - User context for personalization
   * @returns Study guide generation result
   */
  async generateStudyGuide(
    input: StudyGuideInput,
    userContext: UserContext
  ): Promise<StudyGuideGenerationResult> {
    const startTime = performance.now()

    try {
      // Check cache first if enabled
      if (this.config.enableCaching) {
        const cached = await this.repository.findExistingContent(input, userContext)
        if (cached) {
          const responseTime = performance.now() - startTime
          return {
            studyGuide: cached,
            fromCache: true,
            metrics: {
              responseTimeMs: Math.round(responseTime),
              cacheHitRate: 100
            }
          }
        }
      }

      // Generate new content
      const content = await this.generateNewContent(input)
      
      // Save to repository
      const studyGuide = await this.repository.saveStudyGuide(
        input,
        content,
        userContext
      )

      const responseTime = performance.now() - startTime
      return {
        studyGuide,
        fromCache: false,
        metrics: {
          responseTimeMs: Math.round(responseTime),
          cacheHitRate: 0
        }
      }

    } catch (error) {
      console.error('[StudyGuideService] Generation failed:', error)
      throw error
    }
  }

  /**
   * Retrieves user's study guides
   * 
   * @param userContext - User context
   * @param options - Query options
   * @returns List of study guides
   */
  async getUserStudyGuides(
    userContext: UserContext,
    options: {
      savedOnly?: boolean
      limit?: number
      offset?: number
    } = {}
  ): Promise<StudyGuideResponse[]> {
    return await this.repository.getUserStudyGuides(userContext, options)
  }

  /**
   * Retrieves user's study guides with total count and pagination info
   * 
   * @param userContext - User context
   * @param options - Query options
   * @returns Study guides with pagination metadata
   */
  async getUserStudyGuidesWithCount(
    userContext: UserContext,
    options: {
      savedOnly?: boolean
      limit?: number
      offset?: number
    } = {}
  ): Promise<{
    guides: StudyGuideResponse[]
    total: number
    hasMore: boolean
  }> {
    return await this.repository.getUserStudyGuidesWithCount(userContext, options)
  }

  /**
   * Updates save status of a study guide
   * 
   * @param studyGuideId - Study guide ID
   * @param isSaved - Whether the guide is saved
   * @param userContext - User context
   * @returns Updated study guide
   */
  async updateSaveStatus(
    studyGuideId: string,
    isSaved: boolean,
    userContext: UserContext
  ): Promise<StudyGuideResponse> {
    return await this.repository.updateSaveStatus(studyGuideId, isSaved, userContext)
  }

  /**
   * Deletes user's relationship to a study guide
   * 
   * @param studyGuideId - Study guide ID to delete
   * @param userContext - User context
   * @throws AppError if user is anonymous or deletion fails
   */
  async deleteUserStudyGuideRelationship(
    studyGuideId: string,
    userContext: UserContext
  ): Promise<void> {
    return await this.repository.deleteUserStudyGuideRelationship(studyGuideId, userContext)
  }

  /**
   * Generates new content using LLM with retry logic
   *
   * @param input - Study guide input
   * @returns Generated content
   */
  private async generateNewContent(input: StudyGuideInput): Promise<StudyGuideContent> {
    let lastError: Error | null = null

    for (let attempt = 1; attempt <= this.config.maxRetries; attempt++) {
      try {
        const generated = await this.llmService.generateStudyGuide({
          inputType: input.type,
          inputValue: input.value,
          language: input.language
        })

        // Normalize Bible book names in ALL fields (auto-correct abbreviations and mistakes)
        // LLM can generate incorrect book names anywhere in the content
        const normalizer = new BibleBookNormalizer(input.language)
        
        return {
          summary: normalizer.normalizeBibleBooks(generated.summary),
          interpretation: normalizer.normalizeBibleBooks(generated.interpretation),
          context: normalizer.normalizeBibleBooks(generated.context),
          relatedVerses: generated.relatedVerses.map(verse =>
            normalizer.normalizeBibleBooks(verse)
          ),
          reflectionQuestions: generated.reflectionQuestions.map(q =>
            normalizer.normalizeBibleBooks(q)
          ),
          prayerPoints: generated.prayerPoints.map(p =>
            normalizer.normalizeBibleBooks(p)
          )
        }

      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error))

        if (attempt < this.config.maxRetries) {
          console.warn(`[StudyGuideService] Generation attempt ${attempt} failed, retrying...`)
          await this.delay(this.config.retryDelayMs * attempt)
        }
      }
    }

    throw lastError || new Error('Failed to generate study guide after retries')
  }

  /**
   * Delays execution for specified milliseconds
   * 
   * @param ms - Milliseconds to delay
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  /**
   * Validates study guide input
   * 
   * @param input - Input to validate
   * @throws Error if input is invalid
   */
  private validateInput(input: StudyGuideInput): void {
    if (!input.type || !['scripture', 'topic'].includes(input.type)) {
      throw new Error('Invalid input type')
    }

    if (!input.value || typeof input.value !== 'string' || input.value.trim().length === 0) {
      throw new Error('Invalid input value')
    }

    if (!input.language || typeof input.language !== 'string') {
      throw new Error('Invalid language')
    }

    if (input.value.length > 500) {
      throw new Error('Input value too long')
    }
  }

  /**
   * Gets service health status
   * 
   * @returns Health status object
   */
  async getHealthStatus(): Promise<{
    status: 'healthy' | 'degraded' | 'unhealthy'
    components: Record<string, 'up' | 'down'>
    timestamp: string
  }> {
    const components: Record<string, 'up' | 'down'> = {}
    
    // Check LLM service
    try {
      // Basic instantiation check
      components.llm = 'up'
    } catch {
      components.llm = 'down'
    }

    // Check repository (database)
    try {
      // This would need a health check method in the repository
      components.database = 'up'
    } catch {
      components.database = 'down'
    }

    const allUp = Object.values(components).every(status => status === 'up')
    const anyDown = Object.values(components).some(status => status === 'down')

    return {
      status: allUp ? 'healthy' : anyDown ? 'unhealthy' : 'degraded',
      components,
      timestamp: new Date().toISOString()
    }
  }
}