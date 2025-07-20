/**
 * Feedback Edge Function
 * 
 * Refactored according to security guide to eliminate client-provided
 * user context and use centralized AuthService.
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { FeedbackData } from '../_shared/repositories/feedback-repository.ts'

/**
 * Request payload for feedback submission
 * 
 * Note: user_context removed as per security guide
 */
interface FeedbackRequest {
  readonly study_guide_id?: string
  readonly was_helpful: boolean
  readonly message?: string
  readonly category?: string
}

/**
 * Response payload for submitted feedback
 */
interface FeedbackResponse {
  readonly id: string
  readonly was_helpful: boolean
  readonly message?: string
  readonly category: string
  readonly sentiment_score?: number
  readonly created_at: string
}

/**
 * Complete API response structure
 */
interface FeedbackApiResponse extends ApiSuccessResponse<FeedbackResponse> {
  readonly message: string
}

/**
 * Main handler for feedback submission
 */
async function handleFeedback(req: Request, services: ServiceContainer, userContext?: UserContext): Promise<Response> {
  const { feedbackService, feedbackRepository, securityValidator, analyticsLogger } = services

  // Parse and validate request
  const requestData = await parseAndValidateRequest(req, feedbackService)

  // Security validation
  const validatedMessage = await performSecurityValidation(
    securityValidator,
    analyticsLogger,
    requestData,
    req,
    userContext
  )

  // Verify referenced resources exist
  await verifyResourceAccess(feedbackRepository, requestData)

  // Process and save feedback
  const savedFeedback = await processFeedback(
    feedbackService,
    feedbackRepository,
    requestData,
    userContext,
    validatedMessage
  )

  // Log analytics event
  await analyticsLogger.logEvent('feedback_submitted', {
    was_helpful: requestData.was_helpful,
    category: requestData.category || feedbackService.getDefaultCategory(),
    has_message: !!savedFeedback.message,
    is_authenticated: userContext?.type === 'authenticated',
    sentiment_score: savedFeedback.sentiment_score,
    user_id: userContext?.userId,
    session_id: userContext?.sessionId
  }, req.headers.get('x-forwarded-for'))

  // Build response
  const response: FeedbackApiResponse = {
    success: true,
    data: buildFeedbackResponse(savedFeedback),
    message: 'Thank you for your feedback!'
  }

  return new Response(JSON.stringify(response), {
    status: 201,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Parses and validates request payload
 */
async function parseAndValidateRequest(req: Request, feedbackService: any): Promise<FeedbackRequest> {
  let requestBody: any

  try {
    requestBody = await req.json()
  } catch (error) {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400)
  }

  // Validate basic structure
  validateFeedbackStructure(requestBody)

  // Validate optional fields using service
  if (requestBody.category && !feedbackService.isValidCategory(requestBody.category)) {
    throw new AppError(
      'VALIDATION_ERROR',
      'Invalid category provided',
      400
    )
  }

  const maxLength = feedbackService.getMaxMessageLength()
  if (requestBody.message && requestBody.message.length > maxLength) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Message cannot exceed ${maxLength} characters`,
      400
    )
  }

  return requestBody as FeedbackRequest
}

/**
 * Validates feedback structure
 */
function validateFeedbackStructure(requestBody: any): void {
  if (typeof requestBody.was_helpful !== 'boolean') {
    throw new AppError(
      'VALIDATION_ERROR',
      'was_helpful field is required and must be a boolean',
      400
    )
  }

  if (!requestBody.study_guide_id) {
    throw new AppError('VALIDATION_ERROR', 'study_guide_id must be provided', 400)
  }

  if (requestBody.study_guide_id && typeof requestBody.study_guide_id !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'study_guide_id must be a string', 400)
  }
}

/**
 * Performs security validation on feedback message
 */
async function performSecurityValidation(
  securityValidator: any,
  analyticsLogger: any,
  requestData: FeedbackRequest,
  req: Request,
  userContext?: UserContext
): Promise<string | undefined> {
  
  if (!requestData.message) {
    return undefined
  }

  const securityResult = await securityValidator.validateInput(requestData.message, 'feedback')

  if (!securityResult.isValid) {
    // Log security event but sanitize instead of blocking for feedback
    await analyticsLogger.logEvent('security_violation', {
      event_type: securityResult.eventType,
      risk_score: securityResult.riskScore,
      action_taken: 'SANITIZED',
      user_id: userContext?.userId,
      session_id: userContext?.sessionId
    }, req.headers.get('x-forwarded-for'))

    // Return sanitized message for feedback
    return securityValidator.sanitizeInput(requestData.message)
  }

  return requestData.message
}

/**
 * Verifies that referenced resources exist
 */
async function verifyResourceAccess(
  repository: any,
  requestData: FeedbackRequest
): Promise<void> {
  
  if (requestData.study_guide_id) {
    const exists = await repository.verifyStudyGuideExists(requestData.study_guide_id)
    
    if (!exists) {
      throw new AppError('NOT_FOUND', 'Study guide not found', 404)
    }
  }
}

/**
 * Processes and saves feedback
 */
async function processFeedback(
  feedbackService: any,
  repository: any,
  requestData: FeedbackRequest,
  userContext?: UserContext,
  validatedMessage?: string
) {
  // Calculate sentiment score if message is provided
  const sentimentScore = validatedMessage 
    ? await feedbackService.calculateSentimentScore(validatedMessage)
    : undefined

  // Prepare feedback data
  const feedbackData: FeedbackData = {
    studyGuideId: requestData.study_guide_id,
    userId: userContext?.userId || userContext?.sessionId || 'anonymous',
    wasHelpful: requestData.was_helpful,
    message: validatedMessage,
    category: requestData.category || feedbackService.getDefaultCategory(),
    sentimentScore
  }

  // Save feedback
  return await repository.saveFeedback(feedbackData)
}

/**
 * Builds feedback response from saved data
 */
function buildFeedbackResponse(savedData: any): FeedbackResponse {
  return {
    id: savedData.id,
    was_helpful: savedData.was_helpful,
    message: savedData.message,
    category: savedData.category,
    sentiment_score: savedData.sentiment_score,
    created_at: savedData.created_at
  }
}

// Wrap the handler in the factory
createFunction(handleFeedback, {
  requireAuth: true,
  enableAnalytics: true,
  allowedMethods: ['POST'],
  timeout: 10000
})