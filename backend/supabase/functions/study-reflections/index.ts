/**
 * Study Reflections Edge Function
 * 
 * Handles CRUD operations for study guide reflections from Reflect Mode.
 * Implements SOLID principles with proper security and validation.
 * 
 * ARCHITECTURE:
 * - Uses function factory for consistent structure
 * - Delegates business logic to ReflectionsService
 * - Implements proper error handling and security
 * - Follows RESTful API conventions
 * 
 * ENDPOINTS:
 * - GET /study-reflections - List user's reflections (paginated)
 * - GET /study-reflections?study_guide_id=xxx - Get reflection for specific guide
 * - GET /study-reflections?id=xxx - Get single reflection by ID
 * - GET /study-reflections?stats=true - Get reflection statistics
 * - POST /study-reflections - Save/update reflection
 * - DELETE /study-reflections?id=xxx - Delete a reflection
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { isFeatureEnabledForPlan } from '../_shared/services/feature-flag-service.ts'
import {
  ReflectionsService,
  StudyReflection,
  ReflectionSaveRequest,
  ReflectionListResponse,
  StudyMode
} from '../_shared/services/reflections-service.ts'

/**
 * API response types
 */
interface ReflectionApiResponse extends ApiSuccessResponse<{
  readonly reflection?: StudyReflection
  readonly reflections?: StudyReflection[]
  readonly stats?: {
    total_reflections: number
    total_time_spent_seconds: number
    reflections_by_mode: Record<StudyMode, number>
    most_common_life_areas: string[]
  }
  readonly pagination?: {
    total: number
    page: number
    per_page: number
    has_more: boolean
  }
  readonly message?: string
}> {}

/**
 * Create reflections service instance
 */
function createReflectionsService(services: ServiceContainer): ReflectionsService {
  return new ReflectionsService(services.supabaseServiceClient)
}

/**
 * Main handler for reflections operations
 */
async function handleReflections(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  // Ensure user is authenticated
  if (userContext.type !== 'authenticated') {
    throw new AppError(
      'UNAUTHORIZED',
      'Reflections are only available for authenticated users',
      401
    )
  }

  // Get user's subscription plan
  const userPlan = await services.authService.getUserPlan(req)
  console.log(`👤 [Reflections] User plan: ${userPlan}`)

  // Feature flag validation - Check if reflections is enabled for user's plan
  const hasReflectionsAccess = await isFeatureEnabledForPlan('reflections', userPlan)

  if (!hasReflectionsAccess) {
    console.warn(`⛔ [Reflections] Feature access denied: reflections not available for plan ${userPlan}`)
    throw new AppError(
      'FEATURE_NOT_AVAILABLE',
      `Reflections are not available for your current plan (${userPlan}). Please upgrade to Standard, Plus, or Premium to access this feature.`,
      403
    )
  }

  console.log(`✅ [Reflections] Feature access granted: reflections available for plan ${userPlan}`)

  // Route to appropriate handler based on HTTP method
  switch (req.method) {
    case 'GET':
      return await handleGetReflections(req, services, userContext)
    case 'POST':
      return await handleSaveReflection(req, services, userContext)
    case 'DELETE':
      return await handleDeleteReflection(req, services, userContext)
    default:
      throw new AppError(
        'METHOD_NOT_ALLOWED',
        'Only GET, POST, and DELETE methods are allowed',
        405
      )
  }
}

/**
 * Handles GET requests for retrieving reflections
 * 
 * Query params:
 * - id: Get specific reflection by ID
 * - study_guide_id: Get reflection for a study guide
 * - stats: Get reflection statistics (true/false)
 * - page: Page number for list (default 1)
 * - per_page: Items per page (default 20, max 100)
 * - study_mode: Filter by study mode
 */
async function handleGetReflections(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  const url = new URL(req.url)
  const reflectionsService = createReflectionsService(services)
  
  // Check for specific reflection by ID
  const reflectionId = url.searchParams.get('id')
  if (reflectionId) {
    const reflection = await reflectionsService.getReflection(reflectionId, userContext)
    
    if (!reflection) {
      throw new AppError('NOT_FOUND', 'Reflection not found', 404)
    }

    await logAnalytics(services, 'reflection_retrieved', {
      reflection_id: reflectionId,
      user_id: userContext.userId
    }, req)

    const response: ReflectionApiResponse = {
      success: true,
      data: { reflection }
    }

    return jsonResponse(response)
  }

  // Check for reflection by study guide ID
  const studyGuideId = url.searchParams.get('study_guide_id')
  if (studyGuideId) {
    const reflection = await reflectionsService.getReflectionForGuide(studyGuideId, userContext)

    await logAnalytics(services, 'reflection_for_guide_retrieved', {
      study_guide_id: studyGuideId,
      has_reflection: !!reflection,
      user_id: userContext.userId
    }, req)

    const response: ReflectionApiResponse = {
      success: true,
      data: { reflection: reflection || undefined }
    }

    return jsonResponse(response)
  }

  // Check for statistics request
  const statsParam = url.searchParams.get('stats')
  if (statsParam === 'true') {
    const stats = await reflectionsService.getReflectionStats(userContext)

    await logAnalytics(services, 'reflection_stats_retrieved', {
      total_reflections: stats.total_reflections,
      user_id: userContext.userId
    }, req)

    const response: ReflectionApiResponse = {
      success: true,
      data: { stats }
    }

    return jsonResponse(response)
  }

  // List reflections with pagination
  const page = parseInt(url.searchParams.get('page') || '1', 10)
  const perPage = parseInt(url.searchParams.get('per_page') || '20', 10)
  const studyMode = url.searchParams.get('study_mode') as StudyMode | undefined

  const result = await reflectionsService.listReflections(
    userContext,
    page,
    perPage,
    studyMode
  )

  await logAnalytics(services, 'reflections_listed', {
    page,
    per_page: perPage,
    total: result.total,
    study_mode_filter: studyMode || 'none',
    user_id: userContext.userId
  }, req)

  const response: ReflectionApiResponse = {
    success: true,
    data: {
      reflections: result.reflections,
      pagination: {
        total: result.total,
        page: result.page,
        per_page: result.per_page,
        has_more: result.has_more
      }
    }
  }

  return jsonResponse(response)
}

/**
 * Handles POST requests for saving reflections
 */
async function handleSaveReflection(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  // Parse request body
  let requestData: ReflectionSaveRequest
  try {
    requestData = await req.json()
  } catch {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400)
  }

  // Validate request
  validateSaveRequest(requestData)

  const reflectionsService = createReflectionsService(services)
  const reflection = await reflectionsService.saveReflection(requestData, userContext)

  await logAnalytics(services, 'reflection_saved', {
    reflection_id: reflection.id,
    study_guide_id: requestData.study_guide_id,
    study_mode: requestData.study_mode,
    time_spent_seconds: requestData.time_spent_seconds,
    response_keys: Object.keys(requestData.responses).join(','),
    user_id: userContext.userId
  }, req)

  const response: ReflectionApiResponse = {
    success: true,
    data: {
      reflection,
      message: 'Reflection saved successfully'
    }
  }

  return jsonResponse(response, 201)
}

/**
 * Handles DELETE requests for removing reflections
 */
async function handleDeleteReflection(
  req: Request,
  services: ServiceContainer,
  userContext: UserContext
): Promise<Response> {
  const url = new URL(req.url)
  const reflectionId = url.searchParams.get('id')

  if (!reflectionId) {
    throw new AppError('INVALID_REQUEST', 'id query parameter is required', 400)
  }

  const reflectionsService = createReflectionsService(services)
  await reflectionsService.deleteReflection(reflectionId, userContext)

  await logAnalytics(services, 'reflection_deleted', {
    reflection_id: reflectionId,
    user_id: userContext.userId
  }, req)

  const response: ReflectionApiResponse = {
    success: true,
    data: {
      message: 'Reflection deleted successfully'
    }
  }

  return jsonResponse(response)
}

/**
 * Validates save request structure
 */
function validateSaveRequest(data: unknown): asserts data is ReflectionSaveRequest {
  if (!data || typeof data !== 'object') {
    throw new AppError('VALIDATION_ERROR', 'Request body must be an object', 400)
  }

  const request = data as Record<string, unknown>

  // Validate study_guide_id
  if (!request.study_guide_id || typeof request.study_guide_id !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'study_guide_id is required and must be a string', 400)
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(request.study_guide_id)) {
    throw new AppError('VALIDATION_ERROR', 'study_guide_id must be a valid UUID', 400)
  }

  // Validate study_mode
  const validModes = ['quick', 'standard', 'deep', 'lectio', 'sermon']
  if (!request.study_mode || typeof request.study_mode !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'study_mode is required and must be a string', 400)
  }
  if (!validModes.includes(request.study_mode)) {
    throw new AppError(
      'VALIDATION_ERROR',
      `study_mode must be one of: ${validModes.join(', ')}`,
      400
    )
  }

  // Validate responses
  if (!request.responses || typeof request.responses !== 'object') {
    throw new AppError('VALIDATION_ERROR', 'responses is required and must be an object', 400)
  }

  // Validate time_spent_seconds
  if (typeof request.time_spent_seconds !== 'number' || request.time_spent_seconds < 0) {
    throw new AppError('VALIDATION_ERROR', 'time_spent_seconds must be a non-negative number', 400)
  }

  // Validate optional completed_at if provided
  if (request.completed_at !== undefined) {
    if (typeof request.completed_at !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'completed_at must be an ISO 8601 string', 400)
    }
    // Basic ISO date validation
    if (isNaN(Date.parse(request.completed_at))) {
      throw new AppError('VALIDATION_ERROR', 'completed_at must be a valid ISO 8601 date', 400)
    }
  }
}

/**
 * Helper to create JSON response
 */
function jsonResponse(data: unknown, status: number = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Analytics event data type
 */
type AnalyticsEventData = Record<string, string | number | boolean | null | undefined | Record<string, unknown>>

/**
 * Helper to log analytics
 */
async function logAnalytics(
  services: ServiceContainer,
  event: string,
  data: AnalyticsEventData,
  req: Request
): Promise<void> {
  try {
    await services.analyticsLogger.logEvent(
      event,
      data,
      req.headers.get('x-forwarded-for')
    )
  } catch (error) {
    console.error('[study-reflections] Analytics log failed:', error)
    // Don't throw - analytics failures shouldn't break the request
  }
}

// Use the function factory for consistent architecture and security
createFunction(async (req: Request, services: ServiceContainer, userContext?: UserContext) => {
  if (!userContext) {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }
  
  return await handleReflections(req, services, userContext)
}, {
  requireAuth: true,
  enableAnalytics: true,
  allowedMethods: ['GET', 'POST', 'DELETE'],
  timeout: 15000 // 15 second timeout
})
