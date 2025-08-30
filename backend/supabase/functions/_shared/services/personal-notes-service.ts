/**
 * Personal Notes Service
 * 
 * Handles business logic for personal notes on study guides.
 * Implements SOLID principles with clear separation of concerns.
 */

import { StudyGuideRepository } from '../repositories/study-guide-repository.ts'
import { UserContext } from '../types/index.ts'
import { AppError } from '../utils/error-handler.ts'
import { SecurityValidator } from '../utils/security-validator.ts'

/**
 * Personal notes update request
 */
export interface PersonalNotesUpdateRequest {
  readonly study_guide_id: string
  readonly personal_notes: string | null
}

/**
 * Personal notes response
 */
export interface PersonalNotesResponse {
  readonly study_guide_id: string
  readonly personal_notes: string | null
  readonly updated_at: string
  readonly is_autosave: boolean
}

/**
 * Personal notes validation result
 */
interface ValidationResult {
  readonly isValid: boolean
  readonly error?: string
  readonly sanitizedNotes: string | null
}

/**
 * Personal Notes Service Configuration
 */
export interface PersonalNotesServiceConfig {
  readonly maxNotesLength: number
  readonly enableAutoSave: boolean
  readonly autoSaveDelayMs: number
}

/**
 * Personal Notes Service
 * 
 * Follows SOLID principles:
 * - Single Responsibility: Manages only personal notes operations
 * - Open/Closed: Extensible for new note types without modification
 * - Liskov Substitution: Can be substituted with enhanced implementations
 * - Interface Segregation: Focused interface for notes operations
 * - Dependency Inversion: Depends on abstractions (repository interface)
 */
export class PersonalNotesService {
  private readonly config: PersonalNotesServiceConfig
  private readonly securityValidator: SecurityValidator

  constructor(
    private readonly studyGuideRepository: StudyGuideRepository,
    config: Partial<PersonalNotesServiceConfig> = {}
  ) {
    this.config = {
      maxNotesLength: 512, // Match database constraint
      enableAutoSave: true,
      autoSaveDelayMs: 2000, // 2 second debounce
      ...config
    }
    this.securityValidator = new SecurityValidator()
  }

  /**
   * Updates personal notes for a study guide
   * Implements DRY principle by reusing validation and security logic
   * 
   * @param request - Notes update request
   * @param userContext - User context for security
   * @returns Updated notes response
   */
  async updatePersonalNotes(
    request: PersonalNotesUpdateRequest,
    userContext: UserContext
  ): Promise<PersonalNotesResponse> {
    // Validate authentication
    this.validateAuthenticatedUser(userContext)

    // Validate and sanitize input
    const validation = await this.validateNotesInput(request)
    if (!validation.isValid) {
      throw new AppError('VALIDATION_ERROR', validation.error!, 400)
    }

    // Check if user has access to the study guide
    await this.validateStudyGuideAccess(request.study_guide_id, userContext)

    // Update notes in repository
    const updatedAt = await this.studyGuideRepository.updatePersonalNotes(
      request.study_guide_id,
      validation.sanitizedNotes,
      userContext
    )

    return {
      study_guide_id: request.study_guide_id,
      personal_notes: validation.sanitizedNotes,
      updated_at: updatedAt,
      is_autosave: false // Manual update
    }
  }

  /**
   * Retrieves personal notes for a study guide
   * 
   * @param study_guide_id - Study guide ID
   * @param userContext - User context for security
   * @returns Personal notes response
   */
  async getPersonalNotes(
    study_guide_id: string,
    userContext: UserContext
  ): Promise<PersonalNotesResponse | null> {
    // Validate authentication
    this.validateAuthenticatedUser(userContext)

    // Validate study guide access
    await this.validateStudyGuideAccess(study_guide_id, userContext)

    // Get notes from repository
    const result = await this.studyGuideRepository.getPersonalNotes(
      study_guide_id,
      userContext
    )

    if (!result) {
      return null
    }

    return {
      study_guide_id: study_guide_id,
      personal_notes: result.notes,
      updated_at: result.updatedAt,
      is_autosave: false
    }
  }

  /**
   * Auto-saves personal notes with debouncing
   * Implements DRY by reusing manual save logic
   * 
   * @param request - Notes update request
   * @param userContext - User context for security
   * @returns Updated notes response
   */
  async autoSavePersonalNotes(
    request: PersonalNotesUpdateRequest,
    userContext: UserContext
  ): Promise<PersonalNotesResponse> {
    if (!this.config.enableAutoSave) {
      throw new AppError('FEATURE_DISABLED', 'Auto-save is disabled', 400)
    }

    // Reuse manual update logic (DRY principle)
    const result = await this.updatePersonalNotes(request, userContext)

    return {
      ...result,
      is_autosave: true
    }
  }

  /**
   * Deletes personal notes for a study guide
   * 
   * @param study_guide_id - Study guide ID
   * @param userContext - User context for security
   * @returns Success confirmation
   */
  async deletePersonalNotes(
    study_guide_id: string,
    userContext: UserContext
  ): Promise<void> {
    // Validate authentication
    this.validateAuthenticatedUser(userContext)

    // Validate study guide access
    await this.validateStudyGuideAccess(study_guide_id, userContext)

    // Delete notes (set to null)
    await this.studyGuideRepository.updatePersonalNotes(
      study_guide_id,
      null,
      userContext
    )
  }

  /**
   * Validates that the user is authenticated
   * Implements Single Responsibility principle
   * 
   * @param userContext - User context to validate
   * @throws AppError if user is not authenticated
   */
  private validateAuthenticatedUser(userContext: UserContext): void {
    if (userContext.type !== 'authenticated' || !userContext.userId) {
      throw new AppError(
        'UNAUTHORIZED',
        'Personal notes are only available for authenticated users',
        401
      )
    }
  }

  /**
   * Validates and sanitizes notes input
   * Implements DRY principle by centralizing validation logic
   * 
   * @param request - Request to validate
   * @returns Validation result with sanitized notes
   */
  private async validateNotesInput(
    request: PersonalNotesUpdateRequest
  ): Promise<ValidationResult> {
    // Validate study guide ID
    if (!request.study_guide_id || typeof request.study_guide_id !== 'string') {
      return {
        isValid: false,
        error: 'Study guide ID is required and must be a string',
        sanitizedNotes: null
      }
    }

    // Basic UUID format validation (simplified)
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    if (!uuidPattern.test(request.study_guide_id)) {
      return {
        isValid: false,
        error: 'Study guide ID must be a valid UUID format',
        sanitizedNotes: null
      }
    }

    // Handle null notes (deletion case)
    if (request.personal_notes === null || request.personal_notes === undefined) {
      return {
        isValid: true,
        error: undefined,
        sanitizedNotes: null
      }
    }

    // Validate notes content
    if (typeof request.personal_notes !== 'string') {
      return {
        isValid: false,
        error: 'Notes must be a string or null',
        sanitizedNotes: null
      }
    }

    // Check length constraint
    if (request.personal_notes.length > this.config.maxNotesLength) {
      return {
        isValid: false,
        error: `Notes cannot exceed ${this.config.maxNotesLength} characters`,
        sanitizedNotes: null
      }
    }

    // Sanitize content for security
    const sanitizedNotes = this.securityValidator.sanitizeInput(request.personal_notes)

    return {
      isValid: true,
      sanitizedNotes: sanitizedNotes && sanitizedNotes.length > 0 ? sanitizedNotes : null
    } as ValidationResult
  }

  /**
   * Validates that user has access to the study guide
   * Implements security validation using existing repository logic
   * 
   * @param study_guide_id - Study guide ID to check
   * @param userContext - User context for access check
   * @throws AppError if user doesn't have access
   */
  private async validateStudyGuideAccess(
    study_guide_id: string,
    userContext: UserContext
  ): Promise<void> {
    try {
      // Use existing repository method to check access
      const hasAccess = await this.studyGuideRepository.userHasContent(
        study_guide_id,
        userContext
      )

      if (!hasAccess) {
        throw new AppError(
          'FORBIDDEN',
          'You do not have access to this study guide',
          403
        )
      }
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to validate study guide access',
        500
      )
    }
  }

  /**
   * Gets service health status
   * 
   * @returns Health status information
   */
  getHealthStatus(): {
    status: 'healthy' | 'degraded' | 'unhealthy'
    config: {
      maxNotesLength: number
      autoSaveEnabled: boolean
    }
    timestamp: string
  } {
    return {
      status: 'healthy',
      config: {
        maxNotesLength: this.config.maxNotesLength,
        autoSaveEnabled: this.config.enableAutoSave
      },
      timestamp: new Date().toISOString()
    }
  }
}