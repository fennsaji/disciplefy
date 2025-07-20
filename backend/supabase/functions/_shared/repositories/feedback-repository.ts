import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../utils/error-handler.ts'

/**
 * Feedback data structure for saving
 */
export interface FeedbackData {
  readonly studyGuideId?: string
  readonly userId: string
  readonly wasHelpful: boolean
  readonly message?: string
  readonly category: string
  readonly sentimentScore?: number
}

/**
 * Saved feedback response structure
 */
export interface SavedFeedback {
  readonly id: string
  readonly study_guide_id?: string
  readonly user_id: string
  readonly was_helpful: boolean
  readonly message?: string
  readonly category: string
  readonly sentiment_score?: number
  readonly created_at: string
}

/**
 * Feedback Repository
 * 
 * Handles all database interactions for feedback data.
 */
export class FeedbackRepository {
  /**
   * Constructor with dependency injection
   * @param supabaseClient - Shared SupabaseClient instance from service container
   */
  constructor(private readonly supabaseClient: SupabaseClient) {}

  /**
   * Verifies that a study guide exists
   * 
   * @param studyGuideId - Study guide ID to verify
   * @returns True if study guide exists
   */
  async verifyStudyGuideExists(studyGuideId: string): Promise<boolean> {
    const { data, error } = await this.supabaseClient
      .from('study_guides')
      .select('id')
      .eq('id', studyGuideId)
      .single()

    if (error) {
      // Return false for not found, throw for other errors
      if (error.code === 'PGRST116') {
        return false
      }
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to verify study guide: ${error.message}`,
        500
      )
    }

    return !!data
  }

  /**
   * Saves feedback to database
   * 
   * @param feedbackData - Feedback data to save
   * @returns Saved feedback with generated ID
   */
  async saveFeedback(feedbackData: FeedbackData): Promise<SavedFeedback> {
    const { data, error } = await this.supabaseClient
      .from('feedback')
      .insert({
        study_guide_id: feedbackData.studyGuideId,
        user_id: feedbackData.userId,
        was_helpful: feedbackData.wasHelpful,
        message: feedbackData.message,
        category: feedbackData.category,
        sentiment_score: feedbackData.sentimentScore,
        created_at: new Date().toISOString()
      })
      .select()
      .single()

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to save feedback: ${error.message}`,
        500
      )
    }

    return data as SavedFeedback
  }

  /**
   * Gets feedback statistics for a study guide
   * 
   * @param studyGuideId - Study guide ID
   * @returns Feedback statistics
   */
  async getFeedbackStats(studyGuideId: string): Promise<{
    totalCount: number
    helpfulCount: number
    averageSentiment?: number
  }> {
    const { data, error } = await this.supabaseClient
      .from('feedback')
      .select('was_helpful, sentiment_score')
      .eq('study_guide_id', studyGuideId)

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to get feedback stats: ${error.message}`,
        500
      )
    }

    const totalCount = data.length
    const helpfulCount = data.filter(f => f.was_helpful).length
    const sentimentScores = data
      .map(f => f.sentiment_score)
      .filter(score => score !== null && score !== undefined)
    
    const averageSentiment = sentimentScores.length > 0
      ? sentimentScores.reduce((sum, score) => sum + score, 0) / sentimentScores.length
      : undefined

    return {
      totalCount,
      helpfulCount,
      averageSentiment
    }
  }
}