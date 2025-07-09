import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../_shared/error-handler.ts'

/**
 * Study guide data for database storage.
 */
interface StudyGuideData {
  readonly inputType: string
  readonly inputValue: string
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
  readonly language: string
}

/**
 * Anonymous study guide data including hashed input.
 */
interface AnonymousStudyGuideData extends StudyGuideData {
  readonly inputValueHash: string
}

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
  readonly created_at: string
  readonly updated_at: string
}

/**
 * Repository for managing study guide data persistence.
 * 
 * Handles both authenticated and anonymous user study guide storage
 * with appropriate data privacy and security measures.
 */
export class StudyGuideRepository {

  /**
   * Creates a new study guide repository instance.
   * 
   * @param supabaseClient - Configured Supabase client
   */
  constructor(private readonly supabaseClient: SupabaseClient) {}

  /**
   * Saves a study guide for an authenticated user.
   * 
   * @param userId - User ID
   * @param studyGuideData - Study guide data to save
   * @returns Promise resolving to saved study guide record
   * @throws {AppError} When save operation fails
   */
  async saveAuthenticatedStudyGuide(
    userId: string, 
    studyGuideData: StudyGuideData
  ): Promise<StudyGuideRecord> {
    
    this.validateUserId(userId)
    this.validateStudyGuideData(studyGuideData)

    try {
      const { data, error } = await this.supabaseClient
        .from('study_guides')
        .insert({
          user_id: userId,
          input_type: studyGuideData.inputType,
          input_value: studyGuideData.inputValue,
          summary: studyGuideData.summary,
          interpretation: studyGuideData.interpretation,
          context: studyGuideData.context,
          related_verses: studyGuideData.relatedVerses,
          reflection_questions: studyGuideData.reflectionQuestions,
          prayer_points: studyGuideData.prayerPoints,
          language: studyGuideData.language,
          created_at: new Date().toISOString()
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

      return data as StudyGuideRecord
      
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      throw new AppError(
        'DATABASE_ERROR',
        'Unexpected error saving authenticated study guide',
        500
      )
    }
  }

  /**
   * Saves a study guide for an anonymous user.
   * 
   * @param sessionId - Anonymous session ID
   * @param studyGuideData - Study guide data including input hash
   * @returns Promise resolving to saved study guide record
   * @throws {AppError} When save operation fails
   */
  async saveAnonymousStudyGuide(
    sessionId: string, 
    studyGuideData: AnonymousStudyGuideData
  ): Promise<StudyGuideRecord> {
    
    this.validateSessionId(sessionId)
    this.validateAnonymousStudyGuideData(studyGuideData)

    try {
      const { data, error } = await this.supabaseClient
        .from('anonymous_study_guides')
        .insert({
          session_id: sessionId,
          input_type: studyGuideData.inputType,
          input_value_hash: studyGuideData.inputValueHash,
          summary: studyGuideData.summary,
          interpretation: studyGuideData.interpretation,
          context: studyGuideData.context,
          related_verses: studyGuideData.relatedVerses,
          reflection_questions: studyGuideData.reflectionQuestions,
          prayer_points: studyGuideData.prayerPoints,
          language: studyGuideData.language,
          created_at: new Date().toISOString()
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

      // Also update the anonymous session activity
      await this.updateAnonymousSessionActivity(sessionId)

      return data as StudyGuideRecord
      
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      throw new AppError(
        'DATABASE_ERROR',
        'Unexpected error saving anonymous study guide',
        500
      )
    }
  }

  /**
   * Retrieves study guides for an authenticated user.
   * 
   * @param userId - User ID
   * @param limit - Maximum number of records to return
   * @param offset - Number of records to skip
   * @returns Promise resolving to array of study guide records
   */
  async getAuthenticatedStudyGuides(
    userId: string, 
    limit = 20, 
    offset = 0
  ): Promise<readonly StudyGuideRecord[]> {
    
    this.validateUserId(userId)
    this.validatePaginationParams(limit, offset)

    try {
      const { data, error } = await this.supabaseClient
        .from('study_guides')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1)

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to retrieve authenticated study guides: ${error.message}`,
          500
        )
      }

      return data as StudyGuideRecord[]
      
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      throw new AppError(
        'DATABASE_ERROR',
        'Unexpected error retrieving authenticated study guides',
        500
      )
    }
  }

  /**
   * Retrieves study guides for an anonymous session.
   * 
   * @param sessionId - Anonymous session ID
   * @param limit - Maximum number of records to return
   * @param offset - Number of records to skip
   * @returns Promise resolving to array of study guide records
   */
  async getAnonymousStudyGuides(
    sessionId: string, 
    limit = 20, 
    offset = 0
  ): Promise<readonly StudyGuideRecord[]> {
    
    this.validateSessionId(sessionId)
    this.validatePaginationParams(limit, offset)

    try {
      const { data, error } = await this.supabaseClient
        .from('anonymous_study_guides')
        .select('*')
        .eq('session_id', sessionId)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1)

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to retrieve anonymous study guides: ${error.message}`,
          500
        )
      }

      return data as StudyGuideRecord[]
      
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      throw new AppError(
        'DATABASE_ERROR',
        'Unexpected error retrieving anonymous study guides',
        500
      )
    }
  }

  /**
   * Deletes a study guide for an authenticated user.
   * 
   * @param userId - User ID
   * @param studyGuideId - Study guide ID to delete
   * @returns Promise that resolves when deletion is complete
   * @throws {AppError} When deletion fails
   */
  async deleteAuthenticatedStudyGuide(userId: string, studyGuideId: string): Promise<void> {
    this.validateUserId(userId)
    this.validateStudyGuideId(studyGuideId)

    try {
      const { error } = await this.supabaseClient
        .from('study_guides')
        .delete()
        .eq('id', studyGuideId)
        .eq('user_id', userId) // Ensure user can only delete their own guides

      if (error) {
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to delete study guide: ${error.message}`,
          500
        )
      }
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      throw new AppError(
        'DATABASE_ERROR',
        'Unexpected error deleting study guide',
        500
      )
    }
  }

  /**
   * Updates anonymous session activity.
   * 
   * @param sessionId - Anonymous session ID
   */
  private async updateAnonymousSessionActivity(sessionId: string): Promise<void> {
    try {
      await this.supabaseClient
        .from('anonymous_sessions')
        .update({ 
          last_activity: new Date().toISOString()
        })
        .eq('session_id', sessionId)
    } catch (error) {
      // Don't fail the main operation if session update fails
      console.warn('Failed to update anonymous session activity:', error)
    }
  }

  /**
   * Validates user ID parameter.
   * 
   * @param userId - User ID to validate
   * @throws {AppError} When user ID is invalid
   */
  private validateUserId(userId: string): void {
    if (!userId || typeof userId !== 'string' || userId.trim().length === 0) {
      throw new AppError(
        'VALIDATION_ERROR',
        'User ID must be a non-empty string',
        400
      )
    }
  }

  /**
   * Validates session ID parameter.
   * 
   * @param sessionId - Session ID to validate
   * @throws {AppError} When session ID is invalid
   */
  private validateSessionId(sessionId: string): void {
    if (!sessionId || typeof sessionId !== 'string' || sessionId.trim().length === 0) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Session ID must be a non-empty string',
        400
      )
    }
  }

  /**
   * Validates study guide ID parameter.
   * 
   * @param studyGuideId - Study guide ID to validate
   * @throws {AppError} When study guide ID is invalid
   */
  private validateStudyGuideId(studyGuideId: string): void {
    if (!studyGuideId || typeof studyGuideId !== 'string' || studyGuideId.trim().length === 0) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Study guide ID must be a non-empty string',
        400
      )
    }
  }

  /**
   * Validates study guide data.
   * 
   * @param data - Study guide data to validate
   * @throws {AppError} When data is invalid
   */
  private validateStudyGuideData(data: StudyGuideData): void {
    if (!data.summary || typeof data.summary !== 'string') {
      throw new AppError(
        'VALIDATION_ERROR',
        'Study guide summary must be a non-empty string',
        400
      )
    }

    if (!data.context || typeof data.context !== 'string') {
      throw new AppError(
        'VALIDATION_ERROR',
        'Study guide context must be a non-empty string',
        400
      )
    }

    if (!Array.isArray(data.relatedVerses)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Related verses must be an array',
        400
      )
    }

    if (!Array.isArray(data.reflectionQuestions)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Reflection questions must be an array',
        400
      )
    }

    if (!Array.isArray(data.prayerPoints)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Prayer points must be an array',
        400
      )
    }
  }

  /**
   * Validates anonymous study guide data.
   * 
   * @param data - Anonymous study guide data to validate
   * @throws {AppError} When data is invalid
   */
  private validateAnonymousStudyGuideData(data: AnonymousStudyGuideData): void {
    this.validateStudyGuideData(data)

    if (!data.inputValueHash || typeof data.inputValueHash !== 'string') {
      throw new AppError(
        'VALIDATION_ERROR',
        'Input value hash must be a non-empty string',
        400
      )
    }
  }

  /**
   * Validates pagination parameters.
   * 
   * @param limit - Limit parameter
   * @param offset - Offset parameter
   * @throws {AppError} When parameters are invalid
   */
  private validatePaginationParams(limit: number, offset: number): void {
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Limit must be an integer between 1 and 100',
        400
      )
    }

    if (!Number.isInteger(offset) || offset < 0) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Offset must be a non-negative integer',
        400
      )
    }
  }
}