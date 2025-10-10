/**
 * Notes Validation Module
 * 
 * Extracted validation logic for personal notes to maintain file size limits.
 * Contains focused validation functions with clear dependencies.
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
 * Personal notes validation result
 */
export interface ValidationResult {
  readonly isValid: boolean
  readonly error?: string
  readonly sanitizedNotes: string | null
}

/**
 * Configuration for notes validation
 */
export interface NotesConfig {
  readonly maxNotesLength: number
}

/**
 * Validates study guide ID format and presence
 * @param studyGuideId - Study guide ID to validate
 * @returns Error message if invalid, undefined if valid
 */
function validateStudyGuideId(studyGuideId: unknown): string | undefined {
  if (!studyGuideId || typeof studyGuideId !== 'string') {
    return 'Study guide ID is required and must be a string';
  }

  // Basic UUID format validation (simplified)
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(studyGuideId)) {
    return 'Study guide ID must be a valid UUID format';
  }

  return undefined;
}

/**
 * Validates and sanitizes personal notes content
 * @param personalNotes - Notes content to validate
 * @param config - Configuration with length limits
 * @param securityValidator - Security validator for sanitization
 * @returns Object with validation result and sanitized notes
 */
function validateNotesType(
  personalNotes: unknown,
  config: NotesConfig,
  securityValidator: SecurityValidator
): { error?: string; sanitizedNotes: string | null } {
  // Handle null notes (deletion case)
  if (personalNotes === null || personalNotes === undefined) {
    return { sanitizedNotes: null };
  }

  // Validate notes content type
  if (typeof personalNotes !== 'string') {
    return { 
      error: 'Notes must be a string or null',
      sanitizedNotes: null
    };
  }

  // Sanitize content for security first
  const sanitizedNotes = securityValidator.sanitizeInput(personalNotes);

  // Check length constraint on sanitized content
  if (sanitizedNotes && sanitizedNotes.length > config.maxNotesLength) {
    return {
      error: `Notes cannot exceed ${config.maxNotesLength} characters`,
      sanitizedNotes: null
    };
  }

  return {
    sanitizedNotes: sanitizedNotes && sanitizedNotes.length > 0 ? sanitizedNotes : null
  };
}

/**
 * Validates and sanitizes notes input
 * Implements DRY principle by centralizing validation logic
 * 
 * @param request - Request to validate
 * @param config - Configuration with length limits
 * @param securityValidator - Security validator for sanitization
 * @returns Validation result with sanitized notes
 */
export async function validateNotesInput(
  request: PersonalNotesUpdateRequest,
  config: NotesConfig,
  securityValidator: SecurityValidator
): Promise<ValidationResult> {
  // Validate study guide ID
  const studyGuideIdError = validateStudyGuideId(request.study_guide_id);
  if (studyGuideIdError) {
    return {
      isValid: false,
      error: studyGuideIdError,
      sanitizedNotes: null
    };
  }

  // Validate and sanitize notes
  const notesValidation = validateNotesType(request.personal_notes, config, securityValidator);
  if (notesValidation.error) {
    return {
      isValid: false,
      error: notesValidation.error,
      sanitizedNotes: null
    };
  }

  return {
    isValid: true,
    sanitizedNotes: notesValidation.sanitizedNotes
  };
}

/**
 * Validates that user has access to the study guide
 * Implements security validation using existing repository logic
 * 
 * @param study_guide_id - Study guide ID to check
 * @param userContext - User context for access check
 * @param studyGuideRepository - Repository for access validation
 * @throws AppError if user doesn't have access
 */
export async function validateStudyGuideAccess(
  study_guide_id: string,
  userContext: UserContext,
  studyGuideRepository: StudyGuideRepository
): Promise<void> {
  try {
    // Use existing repository method to check access
    const hasAccess = await studyGuideRepository.userHasContent(
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