import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../utils/error-handler.ts'
import { SecurityValidator } from '../utils/security-validator.ts'

/**
 * Study guide content for caching.
 * All 15 fields are required to ensure complete study guide generation.
 */
export interface StudyGuideContent {
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly passage?: string | null  // LLM-generated Scripture passage (3-8 verses) for Standard mode
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
  // Reflect Mode fields - insights and answers
  readonly interpretationInsights: readonly string[]  // 2-5 theological insights for Reflect Mode multi-select
  readonly summaryInsights: readonly string[]  // 2-5 resonance themes for Summary card (Reflect Mode)
  readonly reflectionAnswers: readonly string[]  // 2-5 actionable life application responses for Reflection card (Reflect Mode)
  // Reflect Mode fields - dynamic questions
  readonly contextQuestion: string  // Yes/no question from historical context for Reflect Mode
  readonly summaryQuestion: string  // Engaging question about the summary (8-12 words)
  readonly relatedVersesQuestion: string  // Question prompting verse selection/memorization (8-12 words)
  readonly reflectionQuestion: string  // Question connecting study to daily life (8-12 words)
  readonly prayerQuestion: string  // Question inviting personal prayer response (6-10 words)
}

/**
 * Valid study modes
 */
export type StudyMode = 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon'

/**
 * Study guide input parameters
 */
export interface StudyGuideInput {
  readonly type: 'scripture' | 'topic' | 'question'
  readonly value: string
  readonly language: string
  readonly study_mode: StudyMode
}

/**
 * User context for operations
 */
export interface UserContext {
  readonly type: 'authenticated' | 'anonymous'
  readonly userId?: string
  readonly sessionId?: string
}

/**
 * Complete study guide response
 */
export interface StudyGuideResponse {
  readonly id: string
  readonly input: StudyGuideInput
  readonly content: StudyGuideContent
  readonly isSaved: boolean
  readonly createdAt: string
  readonly updatedAt: string
  readonly creatorUserId?: string | null
  readonly creatorSessionId?: string | null
  personal_notes?: string | null
}

/**
 * Study Guide Repository
 * 
 * Implements content-centric caching with ownership separation.
 * Handles both authenticated and anonymous users efficiently.
 */
export class StudyGuideRepository {
  private readonly securityValidator: SecurityValidator

  constructor(private readonly supabase: SupabaseClient) {
    this.securityValidator = new SecurityValidator()
  }

  /**
   * Main save method - handles content caching and user linking
   */
  async saveStudyGuide(
    input: StudyGuideInput,
    content: StudyGuideContent,
    userContext: UserContext
  ): Promise<StudyGuideResponse> {
    // 1. Generate consistent hash for content deduplication
    const inputHash = await this.generateInputHash(input)

    // 2. Find or create cached content (with creator tracking)
    const cachedContent = await this.findOrCreateCachedContent(
      input,
      inputHash,
      content,
      userContext
    )

    // 3. Link user to content
    await this.linkUserToContent(cachedContent.id, userContext)

    // 4. Return unified response
    return {
      id: cachedContent.id,
      input: {
        type: input.type,
        value: input.value, // Show original input value
        language: input.language,
        study_mode: input.study_mode
      },
      content: {
        summary: cachedContent.summary,
        interpretation: cachedContent.interpretation,
        context: cachedContent.context,
        passage: cachedContent.passage || null,
        relatedVerses: cachedContent.related_verses,
        reflectionQuestions: cachedContent.reflection_questions,
        prayerPoints: cachedContent.prayer_points,
        interpretationInsights: cachedContent.interpretation_insights || [],
        summaryInsights: cachedContent.summary_insights || [],
        reflectionAnswers: cachedContent.reflection_answers || [],
        contextQuestion: cachedContent.context_question || '',
        summaryQuestion: cachedContent.summary_question || '',
        relatedVersesQuestion: cachedContent.related_verses_question || '',
        reflectionQuestion: cachedContent.reflection_question || '',
        prayerQuestion: cachedContent.prayer_question || ''
      },
      isSaved: false, // Newly generated content is not saved by default
      createdAt: cachedContent.created_at,
      updatedAt: cachedContent.updated_at,
      creatorUserId: cachedContent.creator_user_id,
      creatorSessionId: cachedContent.creator_session_id
    }
  }

  /**
   * Find existing cached content or create new
   *
   * Uses INSERT with ON CONFLICT DO NOTHING to preserve original creator.
   * If INSERT succeeds, this user is the creator. If conflict, SELECT existing.
   * This ensures the original creator is never overwritten.
   *
   * Creator tracking: Sets creator_user_id/creator_session_id on INSERT only.
   */
  private async findOrCreateCachedContent(
    input: StudyGuideInput,
    inputHash: string,
    content: StudyGuideContent,
    userContext: UserContext
  ): Promise<any> {
    // First, try to INSERT with creator info (ON CONFLICT DO NOTHING)
    const { data: insertedContent, error: insertError } = await this.supabase
      .from('study_guides')
      .insert({
        input_type: input.type,
        input_value: input.value,
        input_value_hash: inputHash,
        language: input.language,
        study_mode: input.study_mode, // Include study_mode for mode-specific caching
        summary: content.summary,
        interpretation: content.interpretation,
        context: content.context,
        passage: content.passage || null, // LLM-generated Scripture passage for Standard mode
        related_verses: content.relatedVerses,
        reflection_questions: content.reflectionQuestions,
        prayer_points: content.prayerPoints,
        interpretation_insights: content.interpretationInsights, // NEW: For Reflect Mode multi-select
        summary_insights: content.summaryInsights, // NEW: For Summary card resonance themes
        reflection_answers: content.reflectionAnswers, // NEW: For Reflection card actionable life application responses
        context_question: content.contextQuestion, // NEW: For Reflect Mode yes/no question
        summary_question: content.summaryQuestion, // NEW: Dynamic question for summary card
        related_verses_question: content.relatedVersesQuestion, // NEW: Dynamic question for related verses card
        reflection_question: content.reflectionQuestion, // NEW: Dynamic question for reflection card
        prayer_question: content.prayerQuestion, // NEW: Dynamic question for prayer card
        updated_at: new Date().toISOString(),
        // Creator tracking - set on INSERT
        creator_user_id: userContext.type === 'authenticated' ? userContext.userId : null,
        creator_session_id: userContext.type === 'anonymous' ? userContext.sessionId : null
      })
      .select()
      .single()

    // If INSERT succeeded, return the new content (this user is the creator)
    if (!insertError && insertedContent) {
      console.log(`[StudyGuideRepository] New content created with creator: ${insertedContent.id}`)
      return insertedContent
    }

    // If conflict (content already exists), SELECT the existing record
    // This preserves the original creator
    if (insertError && insertError.code === '23505') { // Unique constraint violation
      const { data: existingContent, error: selectError } = await this.supabase
        .from('study_guides')
        .select('*')
        .eq('input_type', input.type)
        .eq('input_value_hash', inputHash)
        .eq('language', input.language)
        .eq('study_mode', input.study_mode) // Include study_mode for mode-specific caching
        .single()

      if (selectError || !existingContent) {
        throw new AppError(
          'CACHE_CORRUPTION',
          `Content conflict detected but unable to retrieve: ${selectError?.message}`,
          500
        )
      }

      console.log(`[StudyGuideRepository] Existing content found (race condition): ${existingContent.id}`)
      return existingContent
    }

    // Other errors
    console.error('[StudyGuideRepository] INSERT failed:', insertError)
    throw new AppError(
      'CACHE_CREATION_ERROR',
      `Failed to create cached content: ${insertError?.message}`,
      500
    )
  }

  /**
   * Link user to cached content
   */
  async linkUserToContent(
    contentId: string,
    userContext: UserContext
  ): Promise<void> {
    if (userContext.type === 'authenticated') {
      await this.linkAuthenticatedUser(contentId, userContext.userId!)
    }
  }

  /**
   * Link authenticated user to content
   */
  private async linkAuthenticatedUser(
    contentId: string,
    userId: string
  ): Promise<void> {
    // Use UPSERT with proper conflict resolution to handle race conditions gracefully
    const { error } = await this.supabase
      .from('user_study_guides')
      .upsert({
        user_id: userId,
        study_guide_id: contentId,
        is_saved: false,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,study_guide_id',
        ignoreDuplicates: false  // Always update on conflict
      })

    if (error) {
      // If upsert still fails, try a manual check-and-insert approach
      if (error.code === '23505') { // Unique constraint violation
        // Check if relationship already exists
        const { data: existing, error: selectError } = await this.supabase
          .from('user_study_guides')
          .select('id')
          .eq('user_id', userId)
          .eq('study_guide_id', contentId)
          .single()

        if (selectError && selectError.code !== 'PGRST116') {
          throw new AppError(
            'DATABASE_ERROR',
            `Failed to check existing user relationship: ${selectError.message}`,
            500
          )
        }

        // If relationship doesn't exist, this is an unexpected error
        if (!existing) {
          throw new AppError(
            'DATABASE_ERROR',
            `Unexpected constraint violation: ${error.message}`,
            500
          )
        }
        
        // Relationship already exists, which is fine - no error needed
        return
      }

      throw new AppError(
        'DATABASE_ERROR',
        `Failed to link authenticated user to content: ${error.message}`,
        500
      )
    }
  }

  /**
   * Get user's study guides with total count
   */
  async getUserStudyGuides(
    userContext: UserContext,
    options: {
      savedOnly?: boolean
      limit?: number
      offset?: number
    } = {}
  ): Promise<StudyGuideResponse[]> {
    const result = await this.getUserStudyGuidesWithCount(userContext, options)
    return result.guides
  }

  /**
   * Get user's study guides with total count and pagination info
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
    const limit = Math.min(options.limit ?? 20, 100)
    const offset = Math.max(options.offset ?? 0, 0)

    if (userContext.type === 'authenticated') {
      const [guides, total] = await Promise.all([
        this.getAuthenticatedUserGuides(
          userContext.userId!,
          options.savedOnly,
          limit,
          offset
        ),
        this.getAuthenticatedUserGuidesCount(
          userContext.userId!,
          options.savedOnly
        )
      ])

      return {
        guides,
        total,
        hasMore: total > offset + guides.length
      }
    } else {
      // Anonymous users cannot have saved guides
      throw new AppError(
        'BAD_REQUEST',
        'Anonymous users cannot have saved guides',
        400
      )
    }
  }

  /**
   * Get authenticated user's study guides
   */
  private async getAuthenticatedUserGuides(
    userId: string,
    savedOnly?: boolean,
    limit = 20,
    offset = 0
  ): Promise<StudyGuideResponse[]> {
    let query = this.supabase
      .from('user_study_guides')
      .select(`
        id,
        is_saved,
        personal_notes,
        created_at,
        updated_at,
        study_guides (
          id,
          input_type,
          input_value,
          input_value_hash,
          study_mode,
          language,
          summary,
          interpretation,
          context,
          passage,
          related_verses,
          reflection_questions,
          prayer_points,
          interpretation_insights,
          summary_insights,
          reflection_answers,
          context_question,
          summary_question,
          related_verses_question,
          reflection_question,
          prayer_question,
          created_at,
          updated_at
        )
      `)
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
        `Failed to get authenticated user guides: ${error.message}`,
        500
      )
    }

    return (data ?? []).map(item => this.formatStudyGuideResponse(item, true))
  }

  /**
   * Get total count of authenticated user's study guides
   */
  private async getAuthenticatedUserGuidesCount(
    userId: string,
    savedOnly?: boolean
  ): Promise<number> {
    let query = this.supabase
      .from('user_study_guides')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)

    if (savedOnly) {
      query = query.eq('is_saved', true)
    }

    const { count, error } = await query

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to get authenticated user guides count: ${error.message}`,
        500
      )
    }

    return count ?? 0
  }

  /**
   * Update save status
   */
  async updateSaveStatus(
    studyGuideId: string,
    isSaved: boolean,
    userContext: UserContext
  ): Promise<StudyGuideResponse> {
    if (userContext.type === 'authenticated') {
      return await this.updateAuthenticatedSaveStatus(
        studyGuideId,
        isSaved,
        userContext.userId!
      )
    } else {
      // Anonymous users cannot save guides
      throw new AppError(
        'BAD_REQUEST',
        'Anonymous users cannot save guides',
        400
      )
    }
  }

  /**
   * Update authenticated user's save status
   */
  private async updateAuthenticatedSaveStatus(
    studyGuideId: string,
    isSaved: boolean,
    userId: string
  ): Promise<StudyGuideResponse> {
    // First verify the study guide exists
    const { data: studyGuide, error: studyGuideError } = await this.supabase
      .from('study_guides')
      .select('*')
      .eq('id', studyGuideId)
      .single()

    if (studyGuideError || !studyGuide) {
      throw new AppError('NOT_FOUND', 'Study guide not found', 404)
    }

    // Use UPSERT with explicit conflict resolution to handle missing relationship records
    const { data, error } = await this.supabase
      .from('user_study_guides')
      .upsert({
        user_id: userId,
        study_guide_id: studyGuideId,
        is_saved: isSaved,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,study_guide_id',
        ignoreDuplicates: false  // Always update the record on conflict
      })
      .select(`
        id,
        is_saved,
        personal_notes,
        created_at,
        updated_at,
        study_guides (
          id,
          input_type,
          input_value,
          input_value_hash,
          language,
          summary,
          interpretation,
          context,
          passage,
          related_verses,
          reflection_questions,
          prayer_points,
          interpretation_insights,
          summary_insights,
          reflection_answers,
          context_question,
          summary_question,
          related_verses_question,
          reflection_question,
          prayer_question,
          created_at,
          updated_at
        )
      `)
      .single()

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to update save status: ${error.message}`,
        500
      )
    }

    return this.formatStudyGuideResponse(data, true)
  }

  /**
   * Delete user's relationship to a study guide
   */
  async deleteUserStudyGuideRelationship(
    studyGuideId: string,
    userContext: UserContext
  ): Promise<void> {
    if (userContext.type === 'authenticated') {
      const { error } = await this.supabase
        .from('user_study_guides')
        .delete()
        .eq('study_guide_id', studyGuideId)
        .eq('user_id', userContext.userId!)

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to delete user study guide relationship: ${error.message}`,
          500
        )
      }
    } else {
      // Anonymous users don't have saved guides
      throw new AppError(
        'BAD_REQUEST',
        'Anonymous users do not have saved study guides',
        400
      )
    }
  }

  /**
   * Check if content already exists for caching
   */
  async findExistingContent(
    input: StudyGuideInput,
    userContext: UserContext
  ): Promise<StudyGuideResponse | null> {
    const inputHash = await this.generateInputHash(input)

    // Check if content exists in cache (including study_mode for mode-specific caching)
    const { data: content, error } = await this.supabase
      .from('study_guides')
      .select('*')
      .eq('input_type', input.type)
      .eq('input_value_hash', inputHash)
      .eq('language', input.language)
      .eq('study_mode', input.study_mode)
      .single()

    if (error || !content) {
      return null
    }

    if (userContext.type === 'authenticated') {
      // Check if user already has this content
      const hasContent = await this.userHasContent(content.id, userContext)

      if (hasContent) {
        // User already has this content, return existing relationship
        return await this.getUserContentRelation(content.id, userContext)
      }

      // Content exists but user doesn't have it - create relationship
      // Use try-catch to handle race conditions gracefully
      try {
        await this.linkUserToContent(content.id, userContext)
      } catch (error) {
        // If linking fails due to constraint violation, it means another request
        // created the relationship concurrently - this is acceptable
        if (error instanceof AppError && error.message.includes('constraint violation')) {
          console.warn(`[StudyGuideRepository] Race condition detected while linking user ${userContext.userId} to content ${content.id} - relationship may already exist`)
          // Continue with returning the content since the relationship exists now
        } else {
          throw error
        }
      }
    }

    // Return cached content (for both authenticated and anonymous users)
    // Include creator info so caller can determine if token should be charged
    return {
      id: content.id,
      input: {
        type: input.type,
        value: content.input_value || input.value, // Use stored input value from database
        language: input.language,
        study_mode: input.study_mode
      },
      content: {
        summary: content.summary,
        interpretation: content.interpretation,
        context: content.context,
        passage: content.passage || null,
        relatedVerses: content.related_verses,
        reflectionQuestions: content.reflection_questions,
        prayerPoints: content.prayer_points,
        interpretationInsights: content.interpretation_insights || [],
        summaryInsights: content.summary_insights || [],
        reflectionAnswers: content.reflection_answers || [],
        contextQuestion: content.context_question || '',
        summaryQuestion: content.summary_question || '',
        relatedVersesQuestion: content.related_verses_question || '',
        reflectionQuestion: content.reflection_question || '',
        prayerQuestion: content.prayer_question || ''
      },
      isSaved: false, // Anonymous users can't save, authenticated users get it linked above
      createdAt: content.created_at,
      updatedAt: content.updated_at,
      creatorUserId: content.creator_user_id,
      creatorSessionId: content.creator_session_id
    }
  }

  // Removed duplicate private userHasContent method - using public version instead

  /**
   * Get user's relationship to content
   */
  private async getUserContentRelation(
    contentId: string,
    userContext: UserContext
  ): Promise<StudyGuideResponse> {
    if (userContext.type === 'authenticated') {
      const { data, error } = await this.supabase
        .from('user_study_guides')
        .select(`
          id,
          is_saved,
          personal_notes,
          created_at,
          updated_at,
          study_guides (
            id,
            input_type,
            input_value,
            input_value_hash,
            language,
            study_mode,
            summary,
            interpretation,
            context,
            passage,
            related_verses,
            reflection_questions,
            prayer_points,
            interpretation_insights,
            summary_insights,
            reflection_answers,
            context_question,
            summary_question,
            related_verses_question,
            reflection_question,
            prayer_question,
            created_at,
            updated_at,
            creator_user_id,
            creator_session_id
          )
        `)
        .eq('study_guide_id', contentId)
        .eq('user_id', userContext.userId!)
        .single()

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to get user content relation: ${error.message}`,
          500
        )
      }

      return this.formatStudyGuideResponse(data, true)
    } else {
      // Anonymous users cannot have saved guides
      throw new AppError(
        'BAD_REQUEST',
        'Anonymous users cannot have saved guides',
        400
      )
    }
  }

  /**
   * Updates personal notes for a user's study guide
   * 
   * @param studyGuideId - Study guide ID
   * @param notes - Personal notes content (null to delete)
   * @param userContext - User context
   * @returns Updated timestamp
   */
  async updatePersonalNotes(
    studyGuideId: string,
    notes: string | null,
    userContext: UserContext
  ): Promise<string> {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Personal notes are only available for authenticated users',
        401
      )
    }

    const updatedAt = new Date().toISOString()

    const { error } = await this.supabase
      .from('user_study_guides')
      .update({
        personal_notes: notes,
        updated_at: updatedAt
      })
      .eq('user_id', userContext.userId)
      .eq('study_guide_id', studyGuideId)

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to update personal notes: ${error.message}`,
        500
      )
    }

    return updatedAt
  }

  /**
   * Retrieves personal notes for a user's study guide
   * 
   * @param studyGuideId - Study guide ID
   * @param userContext - User context
   * @returns Personal notes data or null if not found
   */
  async getPersonalNotes(
    studyGuideId: string,
    userContext: UserContext
  ): Promise<{ notes: string | null; updatedAt: string } | null> {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Personal notes are only available for authenticated users',
        401
      )
    }

    const { data, error } = await this.supabase
      .from('user_study_guides')
      .select('personal_notes, updated_at')
      .eq('user_id', userContext.userId)
      .eq('study_guide_id', studyGuideId)
      .single()

    if (error) {
      if (error.code === 'PGRST116') {
        return null // No relationship exists
      }
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to retrieve personal notes: ${error.message}`,
        500
      )
    }

    return {
      notes: data.personal_notes,
      updatedAt: data.updated_at
    }
  }

  /**
   * Public method to check if user has access to content
   * Exposes the private userHasContent method for the PersonalNotesService
   * 
   * @param contentId - Study guide content ID
   * @param userContext - User context
   * @returns Whether user has access to the content
   */
  async userHasContent(
    contentId: string,
    userContext: UserContext
  ): Promise<boolean> {
    if (userContext.type === 'authenticated') {
      const { data, error } = await this.supabase
        .from('user_study_guides')
        .select('id')
        .eq('study_guide_id', contentId)
        .eq('user_id', userContext.userId!)
        .single()

      return !error && !!data
    } else {
      // Anonymous users can access cached content but don't have saved relationships
      return false
    }
  }

  /**
   * Generate consistent hash for input value
   */
  /**
   * Generate hash for study guide input
   *
   * Includes type, language, and study_mode to prevent collisions where same value
   * means different things (e.g., "Faith" as topic vs "Faith" as scripture reference)
   * and to allow different cached content for each study mode.
   */
  private async generateInputHash(input: StudyGuideInput): Promise<string> {
    // Normalize the value for consistent hashing
    const normalizedValue = input.value.toLowerCase().trim().replace(/\s+/g, ' ')

    // Include type, language, and study_mode to prevent collisions and allow per-mode caching
    const hashInput = `${input.type}:${input.language}:${input.study_mode}:${normalizedValue}`

    return await this.securityValidator.hashSensitiveData(hashInput)
  }

  /**
   * Format database response to API format
   */
  private formatStudyGuideResponse(
    data: any,
    isAuthenticated: boolean,
    originalInputValue?: string
  ): StudyGuideResponse {
    const studyGuide = data.study_guides

    const response: StudyGuideResponse = {
      id: studyGuide.id,
      input: {
        type: studyGuide.input_type as 'scripture' | 'topic',
        value: studyGuide.input_value || originalInputValue || '[Content]', // Use stored input value from database
        language: studyGuide.language,
        study_mode: studyGuide.study_mode || 'standard' // Default to 'standard' for legacy records
      },
      content: {
        summary: studyGuide.summary,
        interpretation: studyGuide.interpretation,
        context: studyGuide.context,
        passage: studyGuide.passage || null,
        relatedVerses: studyGuide.related_verses,
        reflectionQuestions: studyGuide.reflection_questions,
        prayerPoints: studyGuide.prayer_points,
        interpretationInsights: studyGuide.interpretation_insights || [],
        summaryInsights: studyGuide.summary_insights || [],
        reflectionAnswers: studyGuide.reflection_answers || [],
        contextQuestion: studyGuide.context_question || '',
        summaryQuestion: studyGuide.summary_question || '',
        relatedVersesQuestion: studyGuide.related_verses_question || '',
        reflectionQuestion: studyGuide.reflection_question || '',
        prayerQuestion: studyGuide.prayer_question || ''
      },
      isSaved: data.is_saved,
      createdAt: data.created_at,
      updatedAt: data.updated_at
    }

    // Only include personal_notes for authenticated users who have this data
    if (isAuthenticated && data.personal_notes !== undefined) {
      response.personal_notes = data.personal_notes
    }

    return response
  }

  /**
   * Update in-progress study sections progressively
   *
   * This method merges new sections into the existing JSONB sections field,
   * allowing progressive updates as each multi-pass completes.
   *
   * @param inProgressId - In-progress record ID
   * @param newSections - New sections to merge
   */
  async updateInProgressSections(
    inProgressId: string,
    newSections: Record<string, any>
  ): Promise<void> {
    try {
      // Fetch current sections
      const { data: current } = await this.supabase
        .from('study_guides_in_progress')
        .select('sections')
        .eq('id', inProgressId)
        .single()

      if (!current) {
        console.warn('[updateInProgressSections] No in-progress record found:', inProgressId)
        return
      }

      // Merge new sections with existing
      const updatedSections = {
        ...current.sections,
        ...newSections
      }

      // Update record
      await this.supabase
        .from('study_guides_in_progress')
        .update({
          sections: updatedSections,
          last_updated_at: new Date().toISOString()
        })
        .eq('id', inProgressId)

    } catch (error) {
      console.error('[updateInProgressSections] Error:', error)
      // Don't throw - progressive saves are optimization, not critical
    }
  }

  /**
   * Find existing in-progress generation for duplicate detection
   *
   * Checks if an identical study (same input, mode, language) is already
   * being generated by another client.
   *
   * @param inputType - Input type (scripture/topic/question)
   * @param inputHash - SHA-256 hash of the input
   * @param language - Language code
   * @param studyMode - Study mode
   * @returns In-progress record if found, null otherwise
   */
  async findInProgressGeneration(
    inputType: string,
    inputHash: string,
    language: string,
    studyMode: string
  ): Promise<any> {
    const { data } = await this.supabase
      .from('study_guides_in_progress')
      .select('*')
      .eq('input_type', inputType)
      .eq('input_value_hash', inputHash)
      .eq('language', language)
      .eq('study_mode', studyMode)
      .eq('status', 'generating')
      .maybeSingle()

    return data
  }

  /**
   * Delete old failed/completed in-progress records to avoid UNIQUE constraint conflicts
   *
   * @param inputType - Input type
   * @param inputHash - SHA-256 hash of input
   * @param language - Language code
   * @param studyMode - Study mode
   */
  async cleanupOldInProgressRecords(
    inputType: string,
    inputHash: string,
    language: string,
    studyMode: string
  ): Promise<void> {
    await this.supabase
      .from('study_guides_in_progress')
      .delete()
      .eq('input_type', inputType)
      .eq('input_value_hash', inputHash)
      .eq('language', language)
      .eq('study_mode', studyMode)
      .in('status', ['failed', 'completed'])
  }

  /**
   * Create in-progress record for tracking generation
   *
   * @param inProgressId - UUID for the in-progress record
   * @param userId - User ID (optional for authenticated users)
   * @param inputType - Input type
   * @param inputValue - Input value
   * @param inputHash - SHA-256 hash of input
   * @param language - Language code
   * @param studyMode - Study mode
   * @param clientId - Client UUID for tracking
   * @returns Error if insertion fails
   */
  async createInProgressRecord(
    inProgressId: string,
    userId: string | undefined,
    inputType: string,
    inputValue: string,
    inputHash: string,
    language: string,
    studyMode: string,
    clientId: string
  ): Promise<{ error: any }> {
    const { error } = await this.supabase
      .from('study_guides_in_progress')
      .insert({
        id: inProgressId,
        user_id: userId,
        input_type: inputType,
        input_value: inputValue,
        input_value_hash: inputHash,
        language: language,
        study_mode: studyMode,
        status: 'generating',
        client_id: clientId,
        last_heartbeat_at: new Date().toISOString(),
        sections: {}
      })

    return { error }
  }

  /**
   * Mark in-progress record as completed
   *
   * @param inProgressId - In-progress record ID
   */
  async markInProgressCompleted(inProgressId: string): Promise<void> {
    await this.supabase
      .from('study_guides_in_progress')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        last_updated_at: new Date().toISOString()
      })
      .eq('id', inProgressId)
  }

  /**
   * Mark in-progress record as failed
   *
   * @param inProgressId - In-progress record ID
   * @param errorCode - Error code
   * @param errorMessage - Error message
   */
  async markInProgressFailed(
    inProgressId: string,
    errorCode: string,
    errorMessage: string
  ): Promise<void> {
    await this.supabase
      .from('study_guides_in_progress')
      .update({
        status: 'failed',
        error_code: errorCode,
        error_message: errorMessage,
        last_updated_at: new Date().toISOString()
      })
      .eq('id', inProgressId)
  }

  /**
   * Get Supabase client for external operations
   * Used for polling in-progress records
   */
  getSupabaseClient(): SupabaseClient {
    return this.supabase
  }
}