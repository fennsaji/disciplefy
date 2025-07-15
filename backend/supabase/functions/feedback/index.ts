import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

import { corsHeaders } from '../_shared/cors.ts'
import { SecurityValidator } from '../_shared/security-validator.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { RequestValidator } from '../_shared/request-validator.ts'
import { AnalyticsLogger } from '../_shared/analytics-logger.ts'
// TODO: Implement FeedbackService and FeedbackRepository
class FeedbackService {
  async calculateSentimentScore(message: string): Promise<number> {
    // Simple sentiment analysis - count positive/negative words
    const positiveWords = ['good', 'great', 'helpful', 'love', 'amazing', 'excellent', 'wonderful']
    const negativeWords = ['bad', 'terrible', 'awful', 'hate', 'horrible', 'poor', 'useless']
    
    const words = message.toLowerCase().split(/\s+/)
    const positiveCount = words.filter(word => positiveWords.includes(word)).length
    const negativeCount = words.filter(word => negativeWords.includes(word)).length
    
    return positiveCount > negativeCount ? 0.7 : negativeCount > positiveCount ? 0.3 : 0.5
  }
}

class FeedbackRepository {
  constructor(private supabaseClient: any) {}
  
  async verifyStudyGuideExists(studyGuideId: string, isAuthenticated: boolean): Promise<boolean> {
    const { data } = await this.supabaseClient
      .from('study_guides')
      .select('id')
      .eq('id', studyGuideId)
      .single()
    return !!data
  }
  
  async verifyJeffReedSessionExists(sessionId: string): Promise<boolean> {
    // Sessions not implemented yet
    return false
  }
  
  async saveFeedback(feedbackData: any) {
    const { data, error } = await this.supabaseClient
      .from('feedback')
      .insert({
        study_guide_id: feedbackData.studyGuideId,
        jeff_reed_session_id: feedbackData.jeffReedSessionId,
        user_id: feedbackData.userId,
        was_helpful: feedbackData.wasHelpful,
        message: feedbackData.message,
        category: feedbackData.category,
        sentiment_score: feedbackData.sentimentScore,
        created_at: new Date().toISOString()
      })
      .select()
      .single()
    
    if (error) throw error
    return data
  }
}

/**
 * Request payload for feedback submission.
 */
interface FeedbackRequest {
  readonly study_guide_id?: string
  readonly jeff_reed_session_id?: string
  readonly was_helpful: boolean
  readonly message?: string
  readonly category?: string
  readonly user_context?: {
    readonly is_authenticated: boolean
    readonly user_id?: string
    readonly session_id?: string
  }
}

/**
 * Response payload for submitted feedback.
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
 * Complete API response structure.
 */
interface ApiResponse {
  readonly success: true
  readonly data: FeedbackResponse
  readonly message: string
}

// Configuration constants
const DEFAULT_CATEGORY = 'general' as const
const ALLOWED_CATEGORIES = ['general', 'content', 'usability', 'technical', 'suggestion'] as const
const MAX_MESSAGE_LENGTH = 1000 as const
const REQUIRED_ENV_VARS = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'] as const

/**
 * Edge Function: Feedback Submission
 * 
 * Handles user feedback for study guides and Jeff Reed sessions
 * with sentiment analysis, security validation, and analytics tracking.
 * 
 * @param req - HTTP request object
 * @returns Response with feedback confirmation or error
 */
serve(async (req: Request): Promise<Response> => {
  // Handle preflight CORS requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Validate environment and HTTP method
    validateEnvironment()
    RequestValidator.validateHttpMethod(req.method, ['POST'])

    // Initialize dependencies
    const supabaseClient = createSupabaseClient(req)
    const dependencies = initializeDependencies(supabaseClient)

    // Parse and validate request
    const requestData = await parseAndValidateRequest(req)

    // Security validation
    const validatedMessage = await performSecurityValidation(
      dependencies.securityValidator,
      dependencies.analyticsLogger,
      requestData,
      req
    )

    // Verify referenced resources exist
    await verifyResourceAccess(
      dependencies.repository,
      requestData
    )

    // Process and save feedback
    const savedFeedback = await processFeedback(
      dependencies.feedbackService,
      dependencies.repository,
      requestData,
      validatedMessage
    )

    // Log analytics event
    await logFeedbackSubmission(
      dependencies.analyticsLogger,
      requestData,
      savedFeedback,
      req
    )

    // Build response
    const response: ApiResponse = {
      success: true,
      data: buildFeedbackResponse(savedFeedback),
      message: 'Thank you for your feedback!'
    }

    return createSuccessResponse(response)

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

/**
 * Validates required environment variables.
 * 
 * @throws {AppError} When environment variables are missing
 */
function validateEnvironment(): void {
  RequestValidator.validateEnvironmentVariables(REQUIRED_ENV_VARS)
}

/**
 * Creates a configured Supabase client with authentication.
 * 
 * @param req - HTTP request containing auth headers
 * @returns Configured Supabase client
 */
function createSupabaseClient(req: Request): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  return createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { 
        Authorization: req.headers.get('Authorization') || '' 
      },
    },
  })
}

/**
 * Initializes all service dependencies.
 * 
 * @param supabaseClient - Configured Supabase client
 * @returns Object containing all initialized dependencies
 */
function initializeDependencies(supabaseClient: SupabaseClient) {
  return {
    securityValidator: new SecurityValidator(),
    analyticsLogger: new AnalyticsLogger(supabaseClient),
    feedbackService: new FeedbackService(),
    repository: new FeedbackRepository(supabaseClient)
  }
}

/**
 * Parses and validates the request payload.
 * 
 * @param req - HTTP request object
 * @returns Validated request data
 * @throws {AppError} When request is invalid
 */
async function parseAndValidateRequest(req: Request): Promise<FeedbackRequest> {
  let requestBody: any

  try {
    requestBody = await req.json()
  } catch (error) {
    throw new AppError(
      'INVALID_REQUEST',
      'Invalid JSON in request body',
      400
    )
  }

  // Validate basic structure
  validateFeedbackStructure(requestBody)

  // Validate optional fields
  if (requestBody.category && !ALLOWED_CATEGORIES.includes(requestBody.category)) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Invalid category. Allowed values: ${ALLOWED_CATEGORIES.join(', ')}`,
      400
    )
  }

  if (requestBody.message && requestBody.message.length > MAX_MESSAGE_LENGTH) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Message cannot exceed ${MAX_MESSAGE_LENGTH} characters`,
      400
    )
  }

  // Validate user context if provided
  if (requestBody.user_context) {
    validateUserContext(requestBody.user_context)
  }

  return requestBody as FeedbackRequest
}

/**
 * Validates the basic feedback structure.
 * 
 * @param requestBody - Request body to validate
 * @throws {AppError} When structure is invalid
 */
function validateFeedbackStructure(requestBody: any): void {
  // Validate required boolean field
  if (typeof requestBody.was_helpful !== 'boolean') {
    throw new AppError(
      'VALIDATION_ERROR',
      'was_helpful field is required and must be a boolean',
      400
    )
  }

  // Validate that at least one reference ID is provided
  if (!requestBody.study_guide_id && !requestBody.jeff_reed_session_id) {
    throw new AppError(
      'VALIDATION_ERROR',
      'Either study_guide_id or jeff_reed_session_id must be provided',
      400
    )
  }

  // Validate reference IDs format if provided
  if (requestBody.study_guide_id && typeof requestBody.study_guide_id !== 'string') {
    throw new AppError(
      'VALIDATION_ERROR',
      'study_guide_id must be a string',
      400
    )
  }

  if (requestBody.jeff_reed_session_id && typeof requestBody.jeff_reed_session_id !== 'string') {
    throw new AppError(
      'VALIDATION_ERROR',
      'jeff_reed_session_id must be a string',
      400
    )
  }
}

/**
 * Validates user context structure.
 * 
 * @param userContext - User context object to validate
 * @throws {AppError} When user context is invalid
 */
function validateUserContext(userContext: any): void {
  if (typeof userContext.is_authenticated !== 'boolean') {
    throw new AppError(
      'VALIDATION_ERROR',
      'user_context.is_authenticated must be a boolean',
      400
    )
  }

  if (userContext.is_authenticated && !userContext.user_id) {
    throw new AppError(
      'VALIDATION_ERROR',
      'user_context.user_id is required for authenticated users',
      400
    )
  }

  if (!userContext.is_authenticated && !userContext.session_id) {
    throw new AppError(
      'VALIDATION_ERROR',
      'user_context.session_id is required for anonymous users',
      400
    )
  }
}

/**
 * Performs security validation on feedback message.
 * 
 * @param securityValidator - Security validator instance
 * @param analyticsLogger - Analytics logger instance
 * @param requestData - Request data to validate
 * @param req - HTTP request for IP extraction
 * @returns Validated and sanitized message
 */
async function performSecurityValidation(
  securityValidator: SecurityValidator,
  analyticsLogger: AnalyticsLogger,
  requestData: FeedbackRequest,
  req: Request
): Promise<string | undefined> {
  
  if (!requestData.message) {
    return undefined
  }

  const securityResult = await securityValidator.validateInput(
    requestData.message,
    'feedback'
  )

  if (!securityResult.isValid) {
    // Log security event but sanitize instead of blocking for feedback
    await analyticsLogger.logEvent('security_violation', {
      event_type: securityResult.eventType,
      risk_score: securityResult.riskScore,
      action_taken: 'SANITIZED',
      user_id: requestData.user_context?.user_id,
      session_id: requestData.user_context?.session_id
    }, req.headers.get('x-forwarded-for'))

    // Return sanitized message for feedback
    return securityValidator.sanitizeInput(requestData.message)
  }

  return requestData.message
}

/**
 * Verifies that referenced resources exist and user has access.
 * 
 * @param repository - Feedback repository instance
 * @param requestData - Request data containing resource references
 * @throws {AppError} When resources don't exist or access is denied
 */
async function verifyResourceAccess(
  repository: FeedbackRepository,
  requestData: FeedbackRequest
): Promise<void> {
  
  if (requestData.study_guide_id) {
    const exists = await repository.verifyStudyGuideExists(
      requestData.study_guide_id,
      requestData.user_context?.is_authenticated ?? false
    )
    
    if (!exists) {
      throw new AppError(
        'NOT_FOUND',
        'Study guide not found or access denied',
        404
      )
    }
  }

  if (requestData.jeff_reed_session_id) {
    const exists = await repository.verifyJeffReedSessionExists(
      requestData.jeff_reed_session_id
    )
    
    if (!exists) {
      throw new AppError(
        'NOT_FOUND',
        'Session not found or access denied',
        404
      )
    }
  }
}

/**
 * Processes and saves the feedback.
 * 
 * @param feedbackService - Feedback service instance
 * @param repository - Feedback repository instance
 * @param requestData - Original request data
 * @param validatedMessage - Security-validated message
 * @returns Saved feedback record
 */
async function processFeedback(
  feedbackService: FeedbackService,
  repository: FeedbackRepository,
  requestData: FeedbackRequest,
  validatedMessage?: string
) {
  // Calculate sentiment score if message is provided
  const sentimentScore = validatedMessage 
    ? await feedbackService.calculateSentimentScore(validatedMessage)
    : undefined

  // Prepare feedback data
  const feedbackData = {
    studyGuideId: requestData.study_guide_id,
    jeffReedSessionId: requestData.jeff_reed_session_id,
    userId: requestData.user_context?.user_id,
    wasHelpful: requestData.was_helpful,
    message: validatedMessage,
    category: requestData.category || DEFAULT_CATEGORY,
    sentimentScore
  }

  // Save feedback
  return await repository.saveFeedback(feedbackData)
}

/**
 * Logs analytics event for feedback submission.
 * 
 * @param analyticsLogger - Analytics logger instance
 * @param requestData - Original request data
 * @param savedFeedback - Saved feedback record
 * @param req - HTTP request for IP extraction
 */
async function logFeedbackSubmission(
  analyticsLogger: AnalyticsLogger,
  requestData: FeedbackRequest,
  savedFeedback: any,
  req: Request
): Promise<void> {
  
  await analyticsLogger.logEvent('feedback_submitted', {
    was_helpful: requestData.was_helpful,
    category: requestData.category || DEFAULT_CATEGORY,
    has_message: !!savedFeedback.message,
    is_authenticated: requestData.user_context?.is_authenticated ?? false,
    sentiment_score: savedFeedback.sentiment_score,
    user_id: requestData.user_context?.user_id,
    session_id: requestData.user_context?.session_id
  }, req.headers.get('x-forwarded-for'))
}

/**
 * Builds the feedback response from saved data.
 * 
 * @param savedData - Saved feedback data from database
 * @returns Formatted feedback response
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

/**
 * Creates a successful HTTP response.
 * 
 * @param data - Response data
 * @returns HTTP response object
 */
function createSuccessResponse(data: ApiResponse): Response {
  return new Response(
    JSON.stringify(data),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 201,
    }
  )
}