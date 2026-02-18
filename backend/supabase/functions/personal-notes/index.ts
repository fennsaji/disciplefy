/**
 * Personal Notes Management Edge Function
 * 
 * Handles personal notes operations for authenticated users' study guides.
 * Implements SOLID principles with proper security and validation.
 * 
 * ARCHITECTURE:
 * - Uses function factory for consistent structure
 * - Delegates business logic to PersonalNotesService
 * - Implements proper error handling and security
 * - Follows RESTful API conventions
 * 
 * ENDPOINTS:
 * - GET /personal-notes?study_guide_id=xxx - Get personal notes
 * - POST /personal-notes - Update/create personal notes
 * - DELETE /personal-notes?study_guide_id=xxx - Delete personal notes
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import {
  PersonalNotesUpdateRequest,
  PersonalNotesResponse
} from '../_shared/services/personal-notes-service.ts'

/**
 * Complete API response structure
 */
interface PersonalNotesApiResponse extends ApiSuccessResponse<{
  readonly notes?: PersonalNotesResponse
  readonly message?: string
}> {}

/**
 * Main handler for personal notes operations
 */
async function handlePersonalNotes(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  // Ensure user is authenticated
  if (userContext.type !== 'authenticated') {
    throw new AppError(
      'UNAUTHORIZED',
      'Personal notes are only available for authenticated users',
      401
    )
  }

  // Route to appropriate handler based on HTTP method
  switch (req.method) {
    case 'GET':
      return await handleGetPersonalNotes(req, services, userContext)
    case 'POST':
      return await handleUpdatePersonalNotes(req, services, userContext)
    case 'DELETE':
      return await handleDeletePersonalNotes(req, services, userContext)
    default:
      throw new AppError(
        'METHOD_NOT_ALLOWED',
        'Only GET, POST, and DELETE methods are allowed',
        405
      )
  }
}

/**
 * Handles GET requests for retrieving personal notes
 * GET /personal-notes?study_guide_id=xxx
 */
async function handleGetPersonalNotes(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  // Parse query parameters
  const url = new URL(req.url)
  const studyGuideId = url.searchParams.get('study_guide_id')

  // Validate required parameters
  if (!studyGuideId) {
    throw new AppError(
      'INVALID_REQUEST',
      'study_guide_id is required as query parameter',
      400
    )
  }

  // Get personal notes using service
  const notes = await services.personalNotesService.getPersonalNotes(
    studyGuideId,
    userContext
  )

  // Log analytics
  await services.analyticsLogger.logEvent('personal_notes_retrieved', {
    study_guide_id: studyGuideId,
    has_notes: !!notes?.personal_notes,
    user_type: userContext.type,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: PersonalNotesApiResponse = {
    success: true,
    data: {
      notes: notes || {
        study_guide_id: studyGuideId,
        personal_notes: null,
        updated_at: new Date().toISOString(),
        is_autosave: false
      }
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Handles POST requests for updating/creating personal notes
 * POST /personal-notes with JSON body
 */
async function handleUpdatePersonalNotes(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  // Parse request body
  let requestData: PersonalNotesUpdateRequest
  try {
    requestData = await req.json()
  } catch (error) {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400)
  }

  // Validate request structure
  validateUpdateRequest(requestData)

  // Determine if this is an auto-save request
  const url = new URL(req.url)
  const isAutoSave = url.searchParams.get('autoSave') === 'true'

  // Update personal notes using service
  const updatedNotes = isAutoSave
    ? await services.personalNotesService.autoSavePersonalNotes(requestData, userContext)
    : await services.personalNotesService.updatePersonalNotes(requestData, userContext)

  // Log analytics
  await services.analyticsLogger.logEvent('personal_notes_updated', {
    study_guide_id: requestData.study_guide_id,
    is_auto_save: isAutoSave,
    notes_length: requestData.personal_notes?.length || 0,
    action: requestData.personal_notes === null ? 'delete' : 'update',
    user_type: userContext.type,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: PersonalNotesApiResponse = {
    success: true,
    data: {
      notes: updatedNotes,
      message: `Personal notes ${isAutoSave ? 'auto-saved' : 'updated'} successfully`
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Handles DELETE requests for removing personal notes
 * DELETE /personal-notes?study_guide_id=xxx
 */
async function handleDeletePersonalNotes(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  // Parse query parameters
  const url = new URL(req.url)
  const studyGuideId = url.searchParams.get('study_guide_id')

  // Validate required parameters
  if (!studyGuideId) {
    throw new AppError(
      'INVALID_REQUEST',
      'study_guide_id is required as query parameter',
      400
    )
  }

  // Delete personal notes using service
  await services.personalNotesService.deletePersonalNotes(
    studyGuideId,
    userContext
  )

  // Log analytics
  await services.analyticsLogger.logEvent('personal_notes_deleted', {
    study_guide_id: studyGuideId,
    user_type: userContext.type,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: PersonalNotesApiResponse = {
    success: true,
    data: {
      message: 'Personal notes deleted successfully'
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Validates personal notes update request
 * Implements DRY principle by centralizing validation with strict type safety
 */
function validateUpdateRequest(requestData: unknown): void {
  // First, ensure requestData is a non-null object
  if (requestData === null || requestData === undefined) {
    throw new AppError(
      'VALIDATION_ERROR',
      'Request body is required',
      400
    )
  }

  if (typeof requestData !== 'object') {
    throw new AppError(
      'VALIDATION_ERROR',
      'Request body must be an object',
      400
    )
  }

  // Type narrowing: now we know requestData is a non-null object
  const data = requestData as Record<string, unknown>

  // Validate study_guide_id is present and is a string
  if (!('study_guide_id' in data)) {
    throw new AppError(
      'VALIDATION_ERROR',
      'study_guide_id is required',
      400
    )
  }

  if (typeof data.study_guide_id !== 'string') {
    throw new AppError(
      'VALIDATION_ERROR',
      'study_guide_id must be a string',
      400
    )
  }

  // Validate personal_notes: allow null, undefined, or string with length limit
  if ('personal_notes' in data) {
    const personalNotes = data.personal_notes

    // Allow null or undefined for deletion
    if (personalNotes !== null && personalNotes !== undefined) {
      if (typeof personalNotes !== 'string') {
        throw new AppError(
          'VALIDATION_ERROR',
          'personal_notes must be a string or null',
          400
        )
      }

      // Enforce maximum length of 2000 characters
      if (personalNotes.length > 2000) {
        throw new AppError(
          'VALIDATION_ERROR',
          'personal_notes cannot exceed 2000 characters',
          400
        )
      }
    }
  }
}

// Use the function factory for consistent architecture and security
createFunction(async (req: Request, services: ServiceContainer, userContext?: UserContext) => {
  // This endpoint requires authentication
  if (!userContext) {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }
  
  return await handlePersonalNotes(req, services, userContext)
}, {
  requireAuth: true, // Enforces authentication at function level
  enableAnalytics: true, // Enables request analytics
  allowedMethods: ['GET', 'POST', 'DELETE'], // Restricts allowed HTTP methods
  timeout: 10000 // 10 second timeout for notes operations
})