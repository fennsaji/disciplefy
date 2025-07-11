import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../error-handler.ts'
import { SecurityValidator } from '../security-validator.ts'
import { 
  UnifiedStudyGuideRepository,
  StudyGuideInput,
  StudyGuideResponse,
  UserContext,
  GenerationMetrics
} from '../services/unified-study-guide-service.ts'

/**
 * Database record structure for study guides.
 */
interface StudyGuideRecord {
  readonly id: string
  readonly user_id?: string
  readonly session_id?: string
  readonly input_type: string
  readonly input_value?: string
  readonly input_value_hash?: string
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly related_verses: readonly string[]
  readonly reflection_questions: readonly string[]
  readonly prayer_points: readonly string[]
  readonly language: string
  readonly is_saved: boolean
  readonly created_at: string
  readonly updated_at: string
}

/**
 * Content data for saving.
 */
interface StudyGuideContent {
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
}

/**
 * Unified Study Guide Repository Implementation
 * 
 * Provides unified data access for study guides across authenticated and anonymous users.
 * Maintains existing database schema while providing consistent interface.
 */
export class UnifiedStudyGuideRepositoryImpl implements UnifiedStudyGuideRepository {
  private readonly securityValidator: SecurityValidator

  constructor(private readonly supabaseClient: SupabaseClient) {
    this.securityValidator = new SecurityValidator()
  }

  /**
   * Saves a study guide based on user context.
   * 
   * @param content - Generated study guide content
   * @param input - Original input parameters
   * @param context - User context
   * @returns Promise resolving to saved study guide
   */
  async saveStudyGuide(
    content: StudyGuideContent,
    input: StudyGuideInput,
    context: UserContext
  ): Promise<StudyGuideResponse> {
    this.validateContent(content)
    this.validateInput(input)
    this.validateContext(context)

    if (context.userType === 'authenticated') {
      return await this.saveAuthenticatedStudyGuide(content, input, context.userId!)
    } else {
      return await this.saveAnonymousStudyGuide(content, input, context.sessionId!)
    }
  }

  /**
   * Finds existing content based on input and context.
   * 
   * @param input - Study guide input
   * @param context - User context
   * @returns Promise resolving to existing content or null
   */
  async findExistingContent(
    input: StudyGuideInput,
    context: UserContext
  ): Promise<StudyGuideResponse | null> {
    this.validateInput(input)
    this.validateContext(context)

    if (context.userType === 'authenticated') {
      return await this.findExistingAuthenticatedContent(input, context.userId!)
    } else {
      return await this.findExistingAnonymousContent(input, context.sessionId!)
    }
  }

  /**
   * Updates the save status of a study guide.
   * 
   * @param studyGuideId - Study guide ID
   * @param isSaved - Whether the guide should be saved
   * @param context - User context
   * @returns Promise resolving to updated study guide
   */
  async updateSaveStatus(
    studyGuideId: string,
    isSaved: boolean,
    context: UserContext
  ): Promise<StudyGuideResponse> {
    this.validateStudyGuideId(studyGuideId)
    this.validateContext(context)

    if (context.userType === 'authenticated') {
      return await this.updateAuthenticatedSaveStatus(studyGuideId, isSaved, context.userId!)
    } else {
      return await this.updateAnonymousSaveStatus(studyGuideId, isSaved, context.sessionId!)
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
    this.validateContext(context)

    const limit = Math.min(options.limit ?? 20, 100)
    const offset = Math.max(options.offset ?? 0, 0)

    if (context.userType === 'authenticated') {
      return await this.getAuthenticatedStudyGuides(
        context.userId!,
        options.savedOnly,
        limit,
        offset
      )
    } else {
      return await this.getAnonymousStudyGuides(
        context.sessionId!,
        options.savedOnly,
        limit,
        offset
      )
    }
  }

  /**
   * Deletes a study guide.
   * 
   * @param studyGuideId - Study guide ID
   * @param context - User context
   * @returns Promise that resolves when deletion is complete
   */
  async deleteStudyGuide(
    studyGuideId: string,
    context: UserContext
  ): Promise<void> {
    this.validateStudyGuideId(studyGuideId)
    this.validateContext(context)

    if (context.userType === 'authenticated') {
      await this.deleteAuthenticatedStudyGuide(studyGuideId, context.userId!)
    } else {
      await this.deleteAnonymousStudyGuide(studyGuideId, context.sessionId!)
    }
  }

  /**
   * Gets generation metrics for the user.
   * 
   * @param context - User context
   * @returns Promise resolving to generation metrics
   */
  async getGenerationMetrics(context: UserContext): Promise<GenerationMetrics> {
    this.validateContext(context)

    const tableName = context.userType === 'authenticated' 
      ? 'study_guides' 
      : 'anonymous_study_guides'

    const userField = context.userType === 'authenticated' 
      ? 'user_id' 
      : 'session_id'

    const userValue = context.userType === 'authenticated' 
      ? context.userId! 
      : context.sessionId!

    try {
      // Get basic counts
      const { data: guides, error } = await this.supabaseClient
        .from(tableName)
        .select('id, created_at')
        .eq(userField, userValue)

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to get generation metrics: ${error.message}`,
          500
        )
      }

      const totalGenerated = guides?.length ?? 0

      // For Phase 1, return basic metrics
      // TODO: Implement actual cache metrics in Phase 2
      return {
        totalGenerated,
        cacheHitRate: 0, // Will be implemented in Phase 2
        averageResponseTime: 0, // Will be implemented with analytics
        costSavings: 0 // Will be calculated based on cache hits
      }

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to get generation metrics',
        500
      )
    }
  }

  /**
   * Saves study guide for authenticated user.
   */
  private async saveAuthenticatedStudyGuide(
    content: StudyGuideContent,
    input: StudyGuideInput,
    userId: string
  ): Promise<StudyGuideResponse> {
    try {
      const { data, error } = await this.supabaseClient
        .from('study_guides')
        .insert({
          user_id: userId,
          input_type: input.type,
          input_value: input.value,
          summary: content.summary,
          interpretation: content.interpretation,
          context: content.context,
          related_verses: content.relatedVerses,
          reflection_questions: content.reflectionQuestions,
          prayer_points: content.prayerPoints,
          language: input.language,
          is_saved: false,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .select()
        .single()

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to save authenticated study guide: ${error.message}`,
          500
        )
      }

      return this.formatStudyGuideResponse(data)

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to save authenticated study guide',
        500
      )
    }
  }

  /**
   * Saves study guide for anonymous user.
   */
  private async saveAnonymousStudyGuide(
    content: StudyGuideContent,
    input: StudyGuideInput,
    sessionId: string
  ): Promise<StudyGuideResponse> {
    try {
      // Ensure anonymous session exists
      await this.ensureAnonymousSession(sessionId)

      // Hash the input value for privacy
      const inputValueHash = await this.securityValidator.hashSensitiveData(input.value)

      const { data, error } = await this.supabaseClient
        .from('anonymous_study_guides')
        .insert({
          session_id: sessionId,
          input_type: input.type,
          input_value_hash: inputValueHash,
          summary: content.summary,
          interpretation: content.interpretation,
          context: content.context,
          related_verses: content.relatedVerses,
          reflection_questions: content.reflectionQuestions,
          prayer_points: content.prayerPoints,
          language: input.language,
          is_saved: false,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .select()
        .single()

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to save anonymous study guide: ${error.message}`,
          500
        )
      }

      // Update session activity
      await this.updateSessionActivity(sessionId)

      return this.formatStudyGuideResponse(data)

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to save anonymous study guide',
        500
      )
    }
  }

  /**
   * Finds existing authenticated content.
   */
  private async findExistingAuthenticatedContent(
    input: StudyGuideInput,
    userId: string
  ): Promise<StudyGuideResponse | null> {
    try {
      const { data, error } = await this.supabaseClient
        .from('study_guides')
        .select('*')
        .eq('user_id', userId)
        .eq('input_type', input.type)
        .eq('input_value', input.value)
        .eq('language', input.language)
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

      if (error) {
        if (error.code === 'PGRST116') {
          return null
        }
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to find existing authenticated content: ${error.message}`,
          500
        )
      }

      return this.formatStudyGuideResponse(data)

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      return null
    }
  }

  /**
   * Finds existing anonymous content.
   */
  private async findExistingAnonymousContent(
    input: StudyGuideInput,
    sessionId: string
  ): Promise<StudyGuideResponse | null> {
    try {
      const inputValueHash = await this.securityValidator.hashSensitiveData(input.value)

      const { data, error } = await this.supabaseClient
        .from('anonymous_study_guides')
        .select('*')
        .eq('session_id', sessionId)
        .eq('input_type', input.type)
        .eq('input_value_hash', inputValueHash)
        .eq('language', input.language)
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

      if (error) {
        if (error.code === 'PGRST116') {
          return null
        }
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to find existing anonymous content: ${error.message}`,
          500
        )
      }

      return this.formatStudyGuideResponse(data)

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      return null
    }
  }

  /**
   * Updates save status for authenticated user.
   */
  private async updateAuthenticatedSaveStatus(
    studyGuideId: string,
    isSaved: boolean,
    userId: string
  ): Promise<StudyGuideResponse> {
    try {
      const { data, error } = await this.supabaseClient
        .from('study_guides')
        .update({
          is_saved: isSaved,
          updated_at: new Date().toISOString()
        })
        .eq('id', studyGuideId)
        .eq('user_id', userId)
        .select()
        .single()

      if (error) {
        if (error.code === 'PGRST116') {
          throw new AppError(
            'NOT_FOUND',
            'Study guide not found or access denied',
            404
          )
        }
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to update save status: ${error.message}`,
          500
        )
      }

      return this.formatStudyGuideResponse(data)

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to update save status',
        500
      )
    }
  }

  /**
   * Updates save status for anonymous user.
   */
  private async updateAnonymousSaveStatus(
    studyGuideId: string,
    isSaved: boolean,
    sessionId: string
  ): Promise<StudyGuideResponse> {
    try {
      const { data, error } = await this.supabaseClient
        .from('anonymous_study_guides')
        .update({
          is_saved: isSaved,
          updated_at: new Date().toISOString()
        })
        .eq('id', studyGuideId)
        .eq('session_id', sessionId)
        .select()
        .single()

      if (error) {
        if (error.code === 'PGRST116') {
          throw new AppError(
            'NOT_FOUND',
            'Study guide not found or access denied',
            404
          )
        }
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to update save status: ${error.message}`,
          500
        )
      }

      return this.formatStudyGuideResponse(data)

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to update save status',
        500
      )
    }
  }

  /**
   * Gets study guides for authenticated user.
   */
  private async getAuthenticatedStudyGuides(
    userId: string,
    savedOnly?: boolean,
    limit = 20,
    offset = 0
  ): Promise<StudyGuideResponse[]> {
    try {
      let query = this.supabaseClient
        .from('study_guides')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1)

      if (savedOnly) {
        query = query.eq('is_saved', true)
      }

      const { data, error } = await query

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to get authenticated study guides: ${error.message}`,
          500
        )
      }

      return (data ?? []).map(guide => this.formatStudyGuideResponse(guide))

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to get authenticated study guides',
        500
      )
    }
  }

  /**
   * Gets study guides for anonymous user.
   */
  private async getAnonymousStudyGuides(
    sessionId: string,
    savedOnly?: boolean,
    limit = 20,
    offset = 0
  ): Promise<StudyGuideResponse[]> {
    try {
      let query = this.supabaseClient
        .from('anonymous_study_guides')
        .select('*')
        .eq('session_id', sessionId)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1)

      if (savedOnly) {
        query = query.eq('is_saved', true)
      }

      const { data, error } = await query

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to get anonymous study guides: ${error.message}`,
          500
        )
      }

      return (data ?? []).map(guide => this.formatStudyGuideResponse(guide))

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to get anonymous study guides',
        500
      )
    }
  }

  /**
   * Deletes authenticated study guide.
   */
  private async deleteAuthenticatedStudyGuide(
    studyGuideId: string,
    userId: string
  ): Promise<void> {
    try {
      const { error } = await this.supabaseClient
        .from('study_guides')
        .delete()
        .eq('id', studyGuideId)
        .eq('user_id', userId)

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to delete authenticated study guide: ${error.message}`,
          500
        )
      }

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to delete authenticated study guide',
        500
      )
    }
  }

  /**
   * Deletes anonymous study guide.
   */
  private async deleteAnonymousStudyGuide(
    studyGuideId: string,
    sessionId: string
  ): Promise<void> {
    try {
      const { error } = await this.supabaseClient
        .from('anonymous_study_guides')
        .delete()
        .eq('id', studyGuideId)
        .eq('session_id', sessionId)

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to delete anonymous study guide: ${error.message}`,
          500
        )
      }

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to delete anonymous study guide',
        500
      )
    }
  }

  /**
   * Ensures anonymous session exists.
   */
  private async ensureAnonymousSession(sessionId: string): Promise<void> {
    try {
      const { data, error } = await this.supabaseClient
        .from('anonymous_sessions')
        .select('session_id')
        .eq('session_id', sessionId)
        .single()

      if (error && error.code !== 'PGRST116') {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to check anonymous session: ${error.message}`,
          500
        )
      }

      if (!data) {
        await this.createAnonymousSession(sessionId)
      }

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      throw new AppError(
        'DATABASE_ERROR',
        'Failed to ensure anonymous session',
        500
      )
    }
  }

  /**
   * Creates anonymous session.
   */
  private async createAnonymousSession(sessionId: string): Promise<void> {
    const { error } = await this.supabaseClient
      .from('anonymous_sessions')
      .insert({
        session_id: sessionId,
        created_at: new Date().toISOString(),
        last_activity: new Date().toISOString(),
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        study_guides_count: 0,
        recommended_guide_sessions_count: 0,
        is_migrated: false
      })

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to create anonymous session: ${error.message}`,
        500
      )
    }
  }

  /**
   * Updates session activity.
   */
  private async updateSessionActivity(sessionId: string): Promise<void> {
    try {
      await this.supabaseClient
        .from('anonymous_sessions')
        .update({
          last_activity: new Date().toISOString()
        })
        .eq('session_id', sessionId)

    } catch (error) {
      // Don't fail on session update errors
      console.warn('Failed to update session activity:', error)
    }
  }

  /**
   * Formats database record to response format.
   */
  private formatStudyGuideResponse(record: StudyGuideRecord): StudyGuideResponse {
    return {
      id: record.id,
      input: {
        type: record.input_type as 'scripture' | 'topic',
        value: record.input_value || '[Hidden]',
        language: record.language
      },
      summary: record.summary,
      interpretation: record.interpretation,
      context: record.context,
      relatedVerses: record.related_verses,
      reflectionQuestions: record.reflection_questions,
      prayerPoints: record.prayer_points,
      language: record.language,
      isSaved: record.is_saved,
      createdAt: record.created_at,
      updatedAt: record.updated_at
    }
  }

  /**
   * Validation methods
   */
  private validateContent(content: StudyGuideContent): void {
    if (!content.summary || typeof content.summary !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Summary is required', 400)
    }

    if (!content.interpretation || typeof content.interpretation !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Interpretation is required', 400)
    }

    if (!content.context || typeof content.context !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Context is required', 400)
    }

    if (!Array.isArray(content.relatedVerses)) {
      throw new AppError('VALIDATION_ERROR', 'Related verses must be an array', 400)
    }

    if (!Array.isArray(content.reflectionQuestions)) {
      throw new AppError('VALIDATION_ERROR', 'Reflection questions must be an array', 400)
    }

    if (!Array.isArray(content.prayerPoints)) {
      throw new AppError('VALIDATION_ERROR', 'Prayer points must be an array', 400)
    }
  }

  private validateInput(input: StudyGuideInput): void {
    if (!input.type || !['scripture', 'topic'].includes(input.type)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid input type', 400)
    }

    if (!input.value || typeof input.value !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Input value is required', 400)
    }

    if (!input.language || typeof input.language !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Language is required', 400)
    }
  }

  private validateContext(context: UserContext): void {
    if (!context.userType || !['authenticated', 'anonymous'].includes(context.userType)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid user type', 400)
    }

    if (context.userType === 'authenticated' && !context.userId) {
      throw new AppError('VALIDATION_ERROR', 'User ID required for authenticated users', 400)
    }

    if (context.userType === 'anonymous' && !context.sessionId) {
      throw new AppError('VALIDATION_ERROR', 'Session ID required for anonymous users', 400)
    }
  }

  private validateStudyGuideId(studyGuideId: string): void {
    if (!studyGuideId || typeof studyGuideId !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'Study guide ID is required', 400)
    }
  }
}