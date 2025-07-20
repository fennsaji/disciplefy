/**
 * Study Guides Management Edge Function
 * 
 * SECURITY REFACTORED: 
 * - Removed insecure manual JWT decoding
 * - Eliminated client-provided user_context
 * - Uses centralized AuthService for secure authentication
 * - Implements function factory pattern for consistency
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, StudyGuideResponse, UserContext } from '../_shared/types/index.ts'

/**
 * Request payload for save/unsave operations
 * 
 * SECURITY NOTE: user_context removed as per security guide
 */
interface SaveGuideRequest {
  readonly guide_id: string
  readonly action: 'save' | 'unsave'
}

/**
 * Complete API response structure
 */
interface StudyGuideManagementApiResponse extends ApiSuccessResponse<{
  readonly guides?: StudyGuideResponse[]
  readonly guide?: StudyGuideResponse
  readonly total?: number
  readonly hasMore?: boolean
  readonly message?: string
}> {}

/**
 * Main handler for study guide management
 * 
 * SECURITY: Now uses centralized AuthService for secure user identification
 */
async function handleStudyGuides(req: Request, services: ServiceContainer, userContext: UserContext): Promise<Response> {
  // User context is now provided by the function factory

  // Route to appropriate handler based on HTTP method
  switch (req.method) {
    case 'GET':
      return await handleGetStudyGuides(req, services, userContext)
    case 'POST':
      return await handleSaveUnsaveGuide(req, services, userContext)
    case 'DELETE':
      return await handleDeleteGuide(req, services, userContext)
    default:
      throw new AppError(
        'METHOD_NOT_ALLOWED',
        'Only GET, POST, and DELETE methods are allowed',
        405
      )
  }
}

/**
 * Handles GET requests for retrieving study guides
 */
async function handleGetStudyGuides(req: Request, services: ServiceContainer, userContext: UserContext): Promise<Response> {
  // Parse query parameters
  const url = new URL(req.url)
  const savedOnly = url.searchParams.get('saved') === 'true'
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 100)
  const offset = Math.max(parseInt(url.searchParams.get('offset') || '0'), 0)

  // Get user's study guides with total count using the service
  const result = await services.studyGuideService.getUserStudyGuidesWithCount(
    userContext,
    { savedOnly, limit, offset }
  )

  // Log analytics
  await services.analyticsLogger.logEvent('study_guides_retrieved', {
    saved_only: savedOnly,
    count: result.guides.length,
    total: result.total,
    user_type: userContext.type,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: StudyGuideManagementApiResponse = {
    success: true,
    data: {
      guides: result.guides,
      total: result.total,
      hasMore: result.hasMore
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Handles POST requests for save/unsave operations
 * 
 * SECURITY: No longer accepts user_context from request body
 */
async function handleSaveUnsaveGuide(req: Request, services: ServiceContainer, userContext: UserContext): Promise<Response> {
  // Parse request body
  let requestData: SaveGuideRequest
  try {
    requestData = await req.json()
  } catch (error) {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400)
  }

  // Validate request
  validateSaveGuideRequest(requestData)

  // Perform save/unsave operation using the service
  const isSaved = requestData.action === 'save'
  const updatedGuide = await services.studyGuideService.updateSaveStatus(
    requestData.guide_id,
    isSaved,
    userContext
  )

  // Log analytics
  await services.analyticsLogger.logEvent('study_guide_save_status_changed', {
    guide_id: requestData.guide_id,
    action: requestData.action,
    user_type: userContext.type,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: StudyGuideManagementApiResponse = {
    success: true,
    data: {
      guide: updatedGuide,
      message: `Study guide ${isSaved ? 'saved' : 'unsaved'} successfully`
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Handles DELETE requests to remove study guides
 */
async function handleDeleteGuide(req: Request, services: ServiceContainer, userContext: UserContext): Promise<Response> {
  const url = new URL(req.url)
  const guideId = url.searchParams.get('id')

  if (!guideId) {
    throw new AppError(
      'INVALID_REQUEST',
      'Guide ID is required as query parameter',
      400
    )
  }

  // Delete the user's relationship to the guide (not the cached content)
  await services.studyGuideService.deleteUserStudyGuideRelationship(guideId, userContext)

  // Log analytics
  await services.analyticsLogger.logEvent('study_guide_deleted', {
    guide_id: guideId,
    user_type: userContext.type,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  const response: StudyGuideManagementApiResponse = {
    success: true,
    data: {
      message: 'Study guide removed successfully'
    }
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Validates save/unsave request
 */
function validateSaveGuideRequest(requestData: any): void {
  if (!requestData.guide_id || typeof requestData.guide_id !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'guide_id is required and must be a string', 400)
  }

  if (!requestData.action || !['save', 'unsave'].includes(requestData.action)) {
    throw new AppError('VALIDATION_ERROR', 'action must be either "save" or "unsave"', 400)
  }
}


// Use the function factory for consistent architecture
createFunction(async (req: Request, services: ServiceContainer, userContext?: UserContext) => {
  if (!userContext) {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }
  return await handleStudyGuides(req, services, userContext)
}, {
  requireAuth: true,
  enableAnalytics: true,
  allowedMethods: ['GET', 'POST', 'DELETE'],
  timeout: 15000
})