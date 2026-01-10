/**
 * Study Reflections Service
 * 
 * Handles CRUD operations for study guide reflections.
 * Implements SOLID principles with proper validation and security.
 * 
 * ARCHITECTURE:
 * - Single Responsibility: Manages only reflection data operations
 * - Open/Closed: Extensible for new reflection types
 * - Dependency Inversion: Depends on abstractions (SupabaseClient)
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../utils/error-handler.ts'
import { UserContext } from '../types/index.ts'

/**
 * Valid study modes for reflections
 */
export type StudyMode = 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon'

/**
 * Reflection response structure stored in JSONB
 */
export interface ReflectionResponses {
  readonly summary_theme?: string
  readonly interpretation_relevance?: number
  readonly context_related?: boolean
  readonly context_note?: string
  readonly saved_verses?: string[]
  readonly life_areas?: string[]
  readonly prayer_mode?: string
  readonly prayer_duration_seconds?: number
  readonly [key: string]: unknown // Allow additional fields
}

/**
 * Study reflection database record
 */
export interface StudyReflection {
  readonly id: string
  readonly user_id: string
  readonly study_guide_id: string
  readonly study_mode: StudyMode
  readonly responses: ReflectionResponses
  readonly time_spent_seconds: number
  readonly completed_at: string | null
  readonly created_at: string
  readonly updated_at: string
}

/**
 * Request to create or update a reflection
 */
export interface ReflectionSaveRequest {
  readonly study_guide_id: string
  readonly study_mode: StudyMode
  readonly responses: ReflectionResponses
  readonly time_spent_seconds: number
  readonly completed_at?: string
}

/**
 * Paginated reflection list response
 */
export interface ReflectionListResponse {
  readonly reflections: StudyReflection[]
  readonly total: number
  readonly page: number
  readonly per_page: number
  readonly has_more: boolean
}

/**
 * Service for managing study reflections
 */
export class ReflectionsService {
  private readonly supabase: SupabaseClient

  constructor(supabase: SupabaseClient) {
    this.supabase = supabase
  }

  /**
   * Save a new reflection or update existing one
   */
  async saveReflection(
    request: ReflectionSaveRequest,
    userContext: UserContext
  ): Promise<StudyReflection> {
    // Validate user is authenticated
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Only authenticated users can save reflections',
        401
      )
    }

    // Validate study mode
    const validModes: StudyMode[] = ['quick', 'standard', 'deep', 'lectio', 'sermon']
    if (!validModes.includes(request.study_mode)) {
      throw new AppError(
        'VALIDATION_ERROR',
        `Invalid study mode: ${request.study_mode}. Must be one of: ${validModes.join(', ')}`,
        400
      )
    }

    // Verify study guide exists
    const { data: studyGuide, error: guideError } = await this.supabase
      .from('study_guides')
      .select('id')
      .eq('id', request.study_guide_id)
      .single()

    if (guideError || !studyGuide) {
      throw new AppError(
        'NOT_FOUND',
        `Study guide not found: ${request.study_guide_id}`,
        404
      )
    }

    // Check for existing reflection
    const { data: existing } = await this.supabase
      .from('study_reflections')
      .select('id')
      .eq('user_id', userContext.userId)
      .eq('study_guide_id', request.study_guide_id)
      .single()

    const now = new Date().toISOString()
    const reflectionData = {
      user_id: userContext.userId,
      study_guide_id: request.study_guide_id,
      study_mode: request.study_mode,
      responses: request.responses,
      time_spent_seconds: request.time_spent_seconds,
      completed_at: request.completed_at || now,
      updated_at: now
    }

    let result: StudyReflection

    if (existing) {
      // Update existing reflection
      const { data, error } = await this.supabase
        .from('study_reflections')
        .update(reflectionData)
        .eq('id', existing.id)
        .select()
        .single()

      if (error) {
        console.error('[ReflectionsService] Update error:', error)
        throw new AppError(
          'DATABASE_ERROR',
          'Failed to update reflection',
          500
        )
      }

      result = data as StudyReflection
    } else {
      // Insert new reflection
      const { data, error } = await this.supabase
        .from('study_reflections')
        .insert({
          ...reflectionData,
          created_at: now
        })
        .select()
        .single()

      if (error) {
        console.error('[ReflectionsService] Insert error:', error)
        throw new AppError(
          'DATABASE_ERROR',
          'Failed to save reflection',
          500
        )
      }

      result = data as StudyReflection
    }

    console.log('[ReflectionsService] Reflection saved:', result.id)
    return result
  }

  /**
   * Get a single reflection by ID
   */
  async getReflection(
    reflectionId: string,
    userContext: UserContext
  ): Promise<StudyReflection | null> {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Only authenticated users can view reflections',
        401
      )
    }

    const { data, error } = await this.supabase
      .from('study_reflections')
      .select('*')
      .eq('id', reflectionId)
      .eq('user_id', userContext.userId)
      .single()

    if (error) {
      if (error.code === 'PGRST116') {
        return null // Not found
      }
      console.error('[ReflectionsService] Get error:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to retrieve reflection',
        500
      )
    }

    return data as StudyReflection
  }

  /**
   * Get reflection for a specific study guide
   */
  async getReflectionForGuide(
    studyGuideId: string,
    userContext: UserContext
  ): Promise<StudyReflection | null> {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Only authenticated users can view reflections',
        401
      )
    }

    const { data, error } = await this.supabase
      .from('study_reflections')
      .select('*')
      .eq('study_guide_id', studyGuideId)
      .eq('user_id', userContext.userId)
      .single()

    if (error) {
      if (error.code === 'PGRST116') {
        return null // Not found
      }
      console.error('[ReflectionsService] Get for guide error:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to retrieve reflection',
        500
      )
    }

    return data as StudyReflection
  }

  /**
   * List user's reflections with pagination
   */
  async listReflections(
    userContext: UserContext,
    page: number = 1,
    perPage: number = 20,
    studyMode?: StudyMode
  ): Promise<ReflectionListResponse> {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Only authenticated users can list reflections',
        401
      )
    }

    // Validate pagination
    const validPage = Math.max(1, page)
    const validPerPage = Math.min(Math.max(1, perPage), 100)
    const offset = (validPage - 1) * validPerPage

    // Build query
    let query = this.supabase
      .from('study_reflections')
      .select('*', { count: 'exact' })
      .eq('user_id', userContext.userId)
      .order('completed_at', { ascending: false })

    // Apply study mode filter if provided
    if (studyMode) {
      query = query.eq('study_mode', studyMode)
    }

    // Apply pagination
    query = query.range(offset, offset + validPerPage - 1)

    const { data, error, count } = await query

    if (error) {
      console.error('[ReflectionsService] List error:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to list reflections',
        500
      )
    }

    const total = count || 0
    const reflections = (data || []) as StudyReflection[]

    return {
      reflections,
      total,
      page: validPage,
      per_page: validPerPage,
      has_more: offset + reflections.length < total
    }
  }

  /**
   * Delete a reflection
   */
  async deleteReflection(
    reflectionId: string,
    userContext: UserContext
  ): Promise<void> {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Only authenticated users can delete reflections',
        401
      )
    }

    const { error } = await this.supabase
      .from('study_reflections')
      .delete()
      .eq('id', reflectionId)
      .eq('user_id', userContext.userId)

    if (error) {
      console.error('[ReflectionsService] Delete error:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to delete reflection',
        500
      )
    }

    console.log('[ReflectionsService] Reflection deleted:', reflectionId)
  }

  /**
   * Get reflection statistics for a user
   */
  async getReflectionStats(
    userContext: UserContext
  ): Promise<{
    total_reflections: number
    total_time_spent_seconds: number
    reflections_by_mode: Record<StudyMode, number>
    most_common_life_areas: string[]
  }> {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Only authenticated users can view statistics',
        401
      )
    }

    const { data, error } = await this.supabase
      .from('study_reflections')
      .select('study_mode, time_spent_seconds, responses')
      .eq('user_id', userContext.userId)

    if (error) {
      console.error('[ReflectionsService] Stats error:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to calculate statistics',
        500
      )
    }

    const reflections = data || []
    
    // Calculate totals
    const totalReflections = reflections.length
    const totalTimeSpent = reflections.reduce(
      (sum, r) => sum + (r.time_spent_seconds || 0),
      0
    )

    // Count by mode
    const byMode: Record<StudyMode, number> = {
      quick: 0,
      standard: 0,
      deep: 0,
      lectio: 0,
      sermon: 0
    }
    
    reflections.forEach(r => {
      const mode = r.study_mode as StudyMode
      if (mode in byMode) {
        byMode[mode]++
      }
    })

    // Aggregate life areas
    const lifeAreaCounts: Record<string, number> = {}
    reflections.forEach(r => {
      const areas = (r.responses as ReflectionResponses)?.life_areas || []
      areas.forEach((area: string) => {
        lifeAreaCounts[area] = (lifeAreaCounts[area] || 0) + 1
      })
    })

    // Sort and get top 5 life areas
    const sortedAreas = Object.entries(lifeAreaCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([area]) => area)

    return {
      total_reflections: totalReflections,
      total_time_spent_seconds: totalTimeSpent,
      reflections_by_mode: byMode,
      most_common_life_areas: sortedAreas
    }
  }
}
