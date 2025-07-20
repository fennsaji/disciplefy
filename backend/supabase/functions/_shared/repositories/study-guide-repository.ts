import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../utils/error-handler.ts'
import { SecurityValidator } from '../utils/security-validator.ts'

/**
 * Study guide content for caching
 */
export interface StudyGuideContent {
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
}

/**
 * Study guide input parameters
 */
export interface StudyGuideInput {
  readonly type: 'scripture' | 'topic'
  readonly value: string
  readonly language: string
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
    const inputHash = await this.generateInputHash(input.value)

    // 2. Find or create cached content
    const cachedContent = await this.findOrCreateCachedContent(
      input,
      inputHash,
      content
    )

    // 3. Link user to content
    await this.linkUserToContent(cachedContent.id, userContext)

    // 4. Return unified response
    return {
      id: cachedContent.id,
      input: {
        type: input.type,
        value: input.value, // Show original input value
        language: input.language
      },
      content: {
        summary: cachedContent.summary,
        interpretation: cachedContent.interpretation,
        context: cachedContent.context,
        relatedVerses: cachedContent.related_verses,
        reflectionQuestions: cachedContent.reflection_questions,
        prayerPoints: cachedContent.prayer_points
      },
      isSaved: false, // Newly generated content is not saved by default
      createdAt: cachedContent.created_at,
      updatedAt: cachedContent.updated_at
    }
  }

  /**
   * Find existing cached content or create new
   */
  private async findOrCreateCachedContent(
    input: StudyGuideInput,
    inputHash: string,
    content: StudyGuideContent
  ): Promise<any> {
    // Check if content already exists
    const { data: existingContent, error: selectError } = await this.supabase
      .from('study_guides')
      .select('*')
      .eq('input_type', input.type)
      .eq('input_value_hash', inputHash)
      .eq('language', input.language)
      .single()

    if (selectError && selectError.code !== 'PGRST116') {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to check existing content: ${selectError.message}`,
        500
      )
    }

    // Return existing content if found
    if (existingContent) {
      return existingContent
    }

    // Create new cached content
    const { data: newContent, error: insertError } = await this.supabase
      .from('study_guides')
      .insert({
        input_type: input.type,
        input_value: input.value,
        input_value_hash: inputHash,
        language: input.language,
        summary: content.summary,
        interpretation: content.interpretation,
        context: content.context,
        related_verses: content.relatedVerses,
        reflection_questions: content.reflectionQuestions,
        prayer_points: content.prayerPoints
      })
      .select()
      .single()

    if (insertError) {
      // Handle race condition - another user might have created the same content
      if (insertError.code === '23505') { // Unique constraint violation
        // Retry finding the content
        const { data: raceContent, error: raceError } = await this.supabase
          .from('study_guides')
          .select('*')
          .eq('input_type', input.type)
          .eq('input_value_hash', inputHash)
          .eq('language', input.language)
          .single()

        if (raceError || !raceContent) {
          throw new AppError(
            'DATABASE_ERROR',
            'Failed to handle concurrent content creation',
            500
          )
        }

        return raceContent
      }

      throw new AppError(
        'DATABASE_ERROR',
        `Failed to create cached content: ${insertError.message}`,
        500
      )
    }

    return newContent
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
    const { error } = await this.supabase
      .from('user_study_guides_new')
      .insert({
        user_id: userId,
        study_guide_id: contentId,
        is_saved: false
      })

    if (error) {
      // Ignore duplicate key errors (user already has this content)
      if (error.code !== '23505') {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to link authenticated user to content: ${error.message}`,
          500
        )
      }
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
      .from('user_study_guides_new')
      .select(`
        id,
        is_saved,
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
          related_verses,
          reflection_questions,
          prayer_points,
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
      .from('user_study_guides_new')
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

    // Use UPSERT to handle missing relationship records
    const { data, error } = await this.supabase
      .from('user_study_guides_new')
      .upsert({
        user_id: userId,
        study_guide_id: studyGuideId,
        is_saved: isSaved,
        updated_at: new Date().toISOString()
      })
      .select(`
        id,
        is_saved,
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
          related_verses,
          reflection_questions,
          prayer_points,
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
        .from('user_study_guides_new')
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
    const inputHash = await this.generateInputHash(input.value)

    // Check if content exists in cache
    const { data: content, error } = await this.supabase
      .from('study_guides')
      .select('*')
      .eq('input_type', input.type)
      .eq('input_value_hash', inputHash)
      .eq('language', input.language)
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
      await this.linkUserToContent(content.id, userContext)
    }

    // Return cached content (for both authenticated and anonymous users)
    return {
      id: content.id,
      input: {
        type: input.type,
        value: content.input_value || input.value, // Use stored input value from database
        language: input.language
      },
      content: {
        summary: content.summary,
        interpretation: content.interpretation,
        context: content.context,
        relatedVerses: content.related_verses,
        reflectionQuestions: content.reflection_questions,
        prayerPoints: content.prayer_points
      },
      isSaved: false, // Anonymous users can't save, authenticated users get it linked above
      createdAt: content.created_at,
      updatedAt: content.updated_at
    }
  }

  /**
   * Check if user has content relationship
   */
  private async userHasContent(
    contentId: string,
    userContext: UserContext
  ): Promise<boolean> {
    if (userContext.type === 'authenticated') {
      const { data, error } = await this.supabase
        .from('user_study_guides_new')
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
   * Get user's relationship to content
   */
  private async getUserContentRelation(
    contentId: string,
    userContext: UserContext
  ): Promise<StudyGuideResponse> {
    if (userContext.type === 'authenticated') {
      const { data, error } = await this.supabase
        .from('user_study_guides_new')
        .select(`
          id,
          is_saved,
          created_at,
          updated_at,
          study_guides (
            id,
            input_type,
            input_value_hash,
            language,
            summary,
            interpretation,
            context,
            related_verses,
            reflection_questions,
            prayer_points,
            created_at,
            updated_at
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
   * Generate consistent hash for input value
   */
  private async generateInputHash(inputValue: string): Promise<string> {
    return await this.securityValidator.hashSensitiveData(inputValue)
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

    return {
      id: studyGuide.id,
      input: {
        type: studyGuide.input_type as 'scripture' | 'topic',
        value: studyGuide.input_value || originalInputValue || '[Content]', // Use stored input value from database
        language: studyGuide.language
      },
      content: {
        summary: studyGuide.summary,
        interpretation: studyGuide.interpretation,
        context: studyGuide.context,
        relatedVerses: studyGuide.related_verses,
        reflectionQuestions: studyGuide.reflection_questions,
        prayerPoints: studyGuide.prayer_points
      },
      isSaved: data.is_saved,
      createdAt: data.created_at,
      updatedAt: data.updated_at
    }
  }
}