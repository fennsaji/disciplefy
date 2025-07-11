import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../error-handler.ts'
import { SecurityValidator } from '../security-validator.ts'
import { RateLimiter } from '../rate-limiter.ts'
import { LLMService } from '../llm-service.ts'
import { AnalyticsLogger } from '../analytics-logger.ts'

/**
 * User context for unified operations.
 */
export interface UserContext {
  readonly userId?: string
  readonly sessionId?: string
  readonly userType: 'authenticated' | 'anonymous'
  readonly rateLimit?: RateLimitInfo
}

/**
 * Study guide input parameters.
 */
export interface StudyGuideInput {
  readonly type: 'scripture' | 'topic'
  readonly value: string
  readonly language: string
  readonly contentHash?: string
}

/**
 * Study guide generation options.
 */
export interface GenerationOptions {
  readonly skipCache?: boolean
  readonly includeMeta?: boolean
}

/**
 * Complete study guide request.
 */
export interface StudyGuideRequest {
  readonly input: StudyGuideInput
  readonly options?: GenerationOptions
}

/**
 * Study guide response structure.
 */
export interface StudyGuideResponse {
  readonly id: string
  readonly input: StudyGuideInput
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
  readonly language: string
  readonly isSaved: boolean
  readonly createdAt: string
  readonly updatedAt: string
  readonly metadata?: {
    readonly generationTime?: number
    readonly tokensUsed?: number
    readonly cacheHit?: boolean
  }
}

/**
 * Save/unsave request.
 */
export interface SaveRequest {
  readonly studyGuideId: string
  readonly action: 'save' | 'unsave'
}

/**
 * Save response.
 */
export interface SaveResponse {
  readonly success: boolean
  readonly message: string
  readonly studyGuide: StudyGuideResponse
}

/**
 * Rate limit information.
 */
export interface RateLimitInfo {
  readonly remaining: number
  readonly resetTime: number
}

/**
 * Generation metrics for monitoring.
 */
export interface GenerationMetrics {
  readonly totalGenerated: number
  readonly cacheHitRate: number
  readonly averageResponseTime: number
  readonly costSavings: number
}

/**
 * Unified Study Guide Service
 * 
 * Consolidates all study guide operations into a single service layer.
 * Handles both authenticated and anonymous users with consistent patterns.
 * Provides foundation for future caching optimizations.
 */
export class UnifiedStudyGuideService {
  private readonly securityValidator: SecurityValidator
  private readonly rateLimiter: RateLimiter
  private readonly llmService: LLMService
  private readonly analyticsLogger: AnalyticsLogger

  constructor(
    private readonly supabaseClient: SupabaseClient,
    private readonly repository: UnifiedStudyGuideRepository
  ) {
    this.securityValidator = new SecurityValidator()
    this.rateLimiter = new RateLimiter(supabaseClient)
    this.llmService = new LLMService()
    this.analyticsLogger = new AnalyticsLogger(supabaseClient)
  }

  /**
   * Generates a study guide with unified handling for all user types.
   * 
   * @param request - Study guide generation request
   * @param context - User context
   * @returns Promise resolving to study guide response
   */
  async generateStudyGuide(
    request: StudyGuideRequest,
    context: UserContext
  ): Promise<StudyGuideResponse> {
    const startTime = Date.now()

    try {
      // 1. Validate inputs
      this.validateGenerationRequest(request, context)

      // 2. Security validation
      await this.performSecurityValidation(request.input, context)

      // 3. Rate limiting
      const rateLimitInfo = await this.enforceRateLimit(context)

      // 4. Check for existing content
      const existingContent = await this.findExistingContent(request.input, context)
      if (existingContent && !request.options?.skipCache) {
        await this.logCacheHit(request.input, context)
        return {
          ...existingContent,
          metadata: {
            ...existingContent.metadata,
            cacheHit: true,
            generationTime: Date.now() - startTime
          }
        }
      }

      // 5. Generate new content
      const generatedContent = await this.generateNewContent(request.input)

      // 6. Save to database
      const savedStudyGuide = await this.repository.saveStudyGuide(
        generatedContent,
        request.input,
        context
      )

      // 7. Log generation
      await this.logGeneration(request.input, context, savedStudyGuide)

      // 8. Return response
      return {
        ...savedStudyGuide,
        metadata: {
          ...savedStudyGuide.metadata,
          cacheHit: false,
          generationTime: Date.now() - startTime
        }
      }

    } catch (error) {
      await this.logError(error, request.input, context)
      throw error
    }
  }

  /**
   * Saves or unsaves a study guide.
   * 
   * @param request - Save request
   * @param context - User context
   * @returns Promise resolving to save response
   */
  async saveStudyGuide(
    request: SaveRequest,
    context: UserContext
  ): Promise<SaveResponse> {
    try {
      this.validateSaveRequest(request, context)

      const studyGuide = await this.repository.updateSaveStatus(
        request.studyGuideId,
        request.action === 'save',
        context
      )

      await this.logSaveAction(request, context)

      return {
        success: true,
        message: `Study guide ${request.action}d successfully`,
        studyGuide
      }

    } catch (error) {
      await this.logError(error, undefined, context)
      throw error
    }
  }

  /**
   * Retrieves user's study guides.
   * 
   * @param context - User context
   * @param options - Query options
   * @returns Promise resolving to study guides
   */
  async getUserStudyGuides(
    context: UserContext,
    options: {
      savedOnly?: boolean
      limit?: number
      offset?: number
    } = {}
  ): Promise<StudyGuideResponse[]> {
    try {
      this.validateUserContext(context)

      const studyGuides = await this.repository.getUserStudyGuides(context, options)

      await this.logRetrievalAction(context, studyGuides.length)

      return studyGuides

    } catch (error) {
      await this.logError(error, undefined, context)
      throw error
    }
  }

  /**
   * Deletes a study guide.
   * 
   * @param studyGuideId - Study guide ID to delete
   * @param context - User context
   * @returns Promise that resolves when deletion is complete
   */
  async deleteStudyGuide(
    studyGuideId: string,
    context: UserContext
  ): Promise<void> {
    try {
      this.validateUserContext(context)

      if (!studyGuideId || typeof studyGuideId !== 'string') {
        throw new AppError('VALIDATION_ERROR', 'Study guide ID is required', 400)
      }

      await this.repository.deleteStudyGuide(studyGuideId, context)

      await this.logDeleteAction(studyGuideId, context)

    } catch (error) {
      await this.logError(error, undefined, context)
      throw error
    }
  }

  /**
   * Finds existing content across user boundaries.
   * 
   * @param input - Study guide input
   * @param context - User context
   * @returns Promise resolving to existing content or null
   */
  async findExistingContent(
    input: StudyGuideInput,
    context: UserContext
  ): Promise<StudyGuideResponse | null> {
    try {
      return await this.repository.findExistingContent(input, context)
    } catch (error) {
      // Don't throw on find errors - just return null
      console.warn('Error finding existing content:', error)
      return null
    }
  }

  /**
   * Gets generation metrics for monitoring.
   * 
   * @param context - User context
   * @returns Promise resolving to generation metrics
   */
  async getGenerationMetrics(context: UserContext): Promise<GenerationMetrics> {
    try {
      this.validateUserContext(context)

      return await this.repository.getGenerationMetrics(context)

    } catch (error) {
      await this.logError(error, undefined, context)
      throw error
    }
  }

  /**
   * Validates generation request.
   */
  private validateGenerationRequest(
    request: StudyGuideRequest,
    context: UserContext
  ): void {
    if (!request.input) {
      throw new AppError('VALIDATION_ERROR', 'Study guide input is required', 400)
    }

    if (!['scripture', 'topic'].includes(request.input.type)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Input type must be either "scripture" or "topic"',
        400
      )
    }

    if (!request.input.value || typeof request.input.value !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Input value is required', 400)
    }

    if (request.input.value.length > 500) {
      throw new AppError('VALIDATION_ERROR', 'Input value is too long', 400)
    }

    if (!request.input.language || typeof request.input.language !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Language is required', 400)
    }

    if (!['en', 'hi', 'ml'].includes(request.input.language)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Language must be one of: en, hi, ml',
        400
      )
    }

    this.validateUserContext(context)
  }

  /**
   * Validates save request.
   */
  private validateSaveRequest(request: SaveRequest, context: UserContext): void {
    if (!request.studyGuideId || typeof request.studyGuideId !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Study guide ID is required', 400)
    }

    if (!['save', 'unsave'].includes(request.action)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Action must be either "save" or "unsave"',
        400
      )
    }

    this.validateUserContext(context)
  }

  /**
   * Validates user context.
   */
  private validateUserContext(context: UserContext): void {
    if (!context.userType || !['authenticated', 'anonymous'].includes(context.userType)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'User type must be either "authenticated" or "anonymous"',
        400
      )
    }

    if (context.userType === 'authenticated' && !context.userId) {
      throw new AppError(
        'VALIDATION_ERROR',
        'User ID is required for authenticated users',
        400
      )
    }

    if (context.userType === 'anonymous' && !context.sessionId) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Session ID is required for anonymous users',
        400
      )
    }
  }

  /**
   * Performs security validation.
   */
  private async performSecurityValidation(
    input: StudyGuideInput,
    context: UserContext
  ): Promise<void> {
    const securityResult = await this.securityValidator.validateInput(
      input.value,
      input.type
    )

    if (!securityResult.isValid) {
      await this.logSecurityViolation(input, context, securityResult)
      throw new AppError('SECURITY_VIOLATION', securityResult.message, 400)
    }
  }

  /**
   * Enforces rate limiting.
   */
  private async enforceRateLimit(context: UserContext): Promise<RateLimitInfo> {
    const identifier = context.userType === 'authenticated' 
      ? context.userId! 
      : context.sessionId!

    await this.rateLimiter.enforceRateLimit(identifier, context.userType)
    return await this.rateLimiter.checkRateLimit(identifier, context.userType)
  }

  /**
   * Generates new content using LLM service.
   */
  private async generateNewContent(input: StudyGuideInput): Promise<any> {
    return await this.llmService.generateStudyGuide({
      inputType: input.type,
      inputValue: input.value,
      language: input.language
    })
  }

  /**
   * Logs cache hit event.
   */
  private async logCacheHit(input: StudyGuideInput, context: UserContext): Promise<void> {
    await this.analyticsLogger.logEvent('study_guide_cache_hit', {
      input_type: input.type,
      language: input.language,
      user_type: context.userType,
      user_id: context.userId,
      session_id: context.sessionId
    })
  }

  /**
   * Logs generation event.
   */
  private async logGeneration(
    input: StudyGuideInput,
    context: UserContext,
    studyGuide: StudyGuideResponse
  ): Promise<void> {
    await this.analyticsLogger.logEvent('study_guide_generated', {
      input_type: input.type,
      language: input.language,
      user_type: context.userType,
      user_id: context.userId,
      session_id: context.sessionId,
      study_guide_id: studyGuide.id
    })
  }

  /**
   * Logs save action.
   */
  private async logSaveAction(request: SaveRequest, context: UserContext): Promise<void> {
    await this.analyticsLogger.logEvent('study_guide_save_action', {
      action: request.action,
      study_guide_id: request.studyGuideId,
      user_type: context.userType,
      user_id: context.userId,
      session_id: context.sessionId
    })
  }

  /**
   * Logs retrieval action.
   */
  private async logRetrievalAction(
    context: UserContext,
    count: number
  ): Promise<void> {
    await this.analyticsLogger.logEvent('study_guide_retrieval', {
      count,
      user_type: context.userType,
      user_id: context.userId,
      session_id: context.sessionId
    })
  }

  /**
   * Logs delete action.
   */
  private async logDeleteAction(
    studyGuideId: string,
    context: UserContext
  ): Promise<void> {
    await this.analyticsLogger.logEvent('study_guide_deleted', {
      study_guide_id: studyGuideId,
      user_type: context.userType,
      user_id: context.userId,
      session_id: context.sessionId
    })
  }

  /**
   * Logs security violation.
   */
  private async logSecurityViolation(
    input: StudyGuideInput,
    context: UserContext,
    securityResult: any
  ): Promise<void> {
    await this.analyticsLogger.logEvent('security_violation', {
      event_type: securityResult.eventType,
      risk_score: securityResult.riskScore,
      action_taken: 'BLOCKED',
      input_type: input.type,
      language: input.language,
      user_type: context.userType,
      user_id: context.userId,
      session_id: context.sessionId
    })
  }

  /**
   * Logs error events.
   */
  private async logError(
    error: any,
    input: StudyGuideInput | undefined,
    context: UserContext
  ): Promise<void> {
    try {
      await this.analyticsLogger.logEvent('study_guide_error', {
        error_type: error.constructor.name,
        error_code: error.code,
        input_type: input?.type,
        language: input?.language,
        user_type: context.userType,
        user_id: context.userId,
        session_id: context.sessionId
      })
    } catch (logError) {
      // Don't throw on logging errors
      console.warn('Failed to log error:', logError)
    }
  }
}

/**
 * Unified repository interface for study guide operations.
 */
export interface UnifiedStudyGuideRepository {
  saveStudyGuide(
    content: any,
    input: StudyGuideInput,
    context: UserContext
  ): Promise<StudyGuideResponse>

  findExistingContent(
    input: StudyGuideInput,
    context: UserContext
  ): Promise<StudyGuideResponse | null>

  updateSaveStatus(
    studyGuideId: string,
    isSaved: boolean,
    context: UserContext
  ): Promise<StudyGuideResponse>

  getUserStudyGuides(
    context: UserContext,
    options: {
      savedOnly?: boolean
      limit?: number
      offset?: number
    }
  ): Promise<StudyGuideResponse[]>

  deleteStudyGuide(
    studyGuideId: string,
    context: UserContext
  ): Promise<void>

  getGenerationMetrics(context: UserContext): Promise<GenerationMetrics>
}