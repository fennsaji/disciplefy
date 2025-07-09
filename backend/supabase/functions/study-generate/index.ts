import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Declare Deno types for Supabase Edge Functions environment
declare const Deno: {
  env: {
    get(key: string): string | undefined
  }
}

import { corsHeaders } from '../_shared/cors.ts'
import { SecurityValidator } from '../_shared/security-validator.ts'
import { RateLimiter } from '../_shared/rate-limiter.ts'
import { LLMService } from '../_shared/llm-service.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { RequestValidator } from '../_shared/request-validator.ts'
import { AnalyticsLogger } from '../_shared/analytics-logger.ts'
import { StudyGuideService } from './study-guide-service.ts'
import { StudyGuideRepository } from './study-guide-repository.ts'

/**
 * Request payload for study guide generation.
 */
interface StudyGenerationRequest {
  readonly input_type: 'scripture' | 'topic'
  readonly input_value: string
  readonly language?: string
  readonly user_context?: {
    readonly is_authenticated: boolean
    readonly user_id?: string
    readonly session_id?: string
  }
}

/**
 * Response payload for generated study guide.
 */
interface StudyGuideResponse {
  readonly id: string
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly related_verses: readonly string[]
  readonly reflection_questions: readonly string[]
  readonly prayer_points: readonly string[]
  readonly language: string
  readonly created_at: string
}

/**
 * Rate limit information included in response.
 */
interface RateLimitInfo {
  readonly remaining: number
  readonly reset_time: number
}

/**
 * Complete API response structure.
 */
interface ApiResponse {
  readonly success: true
  readonly data: StudyGuideResponse
  readonly rate_limit: RateLimitInfo
}

// Configuration constants
const DEFAULT_LANGUAGE = 'en' as const
const REQUIRED_ENV_VARS = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'] as const

/**
 * Edge Function: Study Guide Generation
 * 
 * Generates AI-powered Bible study guides following structured methodology.
 * Supports both scripture references and topic-based generation with
 * comprehensive security validation and rate limiting.
 * 
 * @param req - HTTP request object
 * @returns Response with study guide data or error
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
    await performSecurityValidation(
      dependencies.securityValidator,
      dependencies.analyticsLogger,
      requestData,
      req
    )

    // Rate limiting
    const rateLimitResult = await enforceRateLimit(
      dependencies.rateLimiter,
      requestData
    )

    // Generate study guide
    const studyGuide = await generateStudyGuide(
      dependencies.studyGuideService,
      requestData
    )

    // Store study guide
    const savedStudyGuide = await saveStudyGuide(
      dependencies.repository,
      dependencies.securityValidator,
      requestData,
      studyGuide
    )

    // Log analytics
    await logStudyGeneration(
      dependencies.analyticsLogger,
      requestData,
      req
    )

    // Build response
    const response: ApiResponse = {
      success: true,
      data: buildStudyGuideResponse(savedStudyGuide),
      rate_limit: {
        remaining: rateLimitResult.remaining,
        reset_time: rateLimitResult.resetTime
      }
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
    rateLimiter: new RateLimiter(supabaseClient),
    analyticsLogger: new AnalyticsLogger(supabaseClient),
    studyGuideService: new StudyGuideService(),
    repository: new StudyGuideRepository(supabaseClient)
  }
}

/**
 * Parses and validates the request payload.
 * 
 * @param req - HTTP request object
 * @returns Validated request data
 * @throws {AppError} When request is invalid
 */
async function parseAndValidateRequest(req: Request): Promise<StudyGenerationRequest> {
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

  // Validate required fields
  const validationRules = {
    input_type: {
      required: true,
      allowedValues: ['scripture', 'topic']
    },
    input_value: {
      required: true,
      minLength: 1,
      maxLength: 500
    },
    language: {
      required: false,
      allowedValues: ['en', 'hi', 'ml']
    }
  }

  RequestValidator.validateRequestBody(requestBody, validationRules)

  // Validate user context if provided
  if (requestBody.user_context) {
    validateUserContext(requestBody.user_context)
  }

  return requestBody as StudyGenerationRequest
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
 * Performs security validation on the input.
 * 
 * @param securityValidator - Security validator instance
 * @param analyticsLogger - Analytics logger instance
 * @param requestData - Request data to validate
 * @param req - HTTP request for IP extraction
 * @throws {AppError} When security validation fails
 */
async function performSecurityValidation(
  securityValidator: SecurityValidator,
  analyticsLogger: AnalyticsLogger,
  requestData: StudyGenerationRequest,
  req: Request
): Promise<void> {
  const securityResult = await securityValidator.validateInput(
    requestData.input_value,
    requestData.input_type
  )

  if (!securityResult.isValid) {
    // Log security violation
    await analyticsLogger.logEvent('security_violation', {
      event_type: securityResult.eventType,
      risk_score: securityResult.riskScore,
      action_taken: 'BLOCKED',
      user_id: requestData.user_context?.user_id,
      session_id: requestData.user_context?.session_id
    }, req.headers.get('x-forwarded-for'))

    throw new AppError('SECURITY_VIOLATION', securityResult.message, 400)
  }
}

/**
 * Enforces rate limiting for the request.
 * 
 * @param rateLimiter - Rate limiter instance
 * @param requestData - Request data containing user context
 * @returns Rate limit check result
 * @throws {AppError} When rate limit is exceeded
 */
async function enforceRateLimit(
  rateLimiter: RateLimiter,
  requestData: StudyGenerationRequest
) {
  const userContext = requestData.user_context
  if (!userContext) {
    throw new AppError(
      'VALIDATION_ERROR',
      'user_context is required for rate limiting',
      400
    )
  }

  const isAuthenticated = userContext.is_authenticated
  const identifier = isAuthenticated ? userContext.user_id! : userContext.session_id!
  const userType = isAuthenticated ? 'authenticated' : 'anonymous'

  await rateLimiter.enforceRateLimit(identifier, userType)
  return await rateLimiter.checkRateLimit(identifier, userType)
}

/**
 * Generates the study guide using the LLM service.
 * 
 * @param studyGuideService - Study guide service instance
 * @param requestData - Request data for generation
 * @returns Generated study guide
 */
async function generateStudyGuide(
  studyGuideService: StudyGuideService,
  requestData: StudyGenerationRequest
) {
  return await studyGuideService.generateStudyGuide({
    inputType: requestData.input_type,
    inputValue: requestData.input_value,
    language: requestData.language || DEFAULT_LANGUAGE
  })
}

/**
 * Saves the generated study guide to the database.
 * 
 * @param repository - Study guide repository
 * @param securityValidator - Security validator for hashing
 * @param requestData - Original request data
 * @param studyGuide - Generated study guide
 * @returns Saved study guide data
 */
async function saveStudyGuide(
  repository: StudyGuideRepository,
  securityValidator: SecurityValidator,
  requestData: StudyGenerationRequest,
  studyGuide: any
) {
  const userContext = requestData.user_context!
  const isAuthenticated = userContext.is_authenticated

  const studyGuideData = {
    inputType: requestData.input_type,
    inputValue: requestData.input_value,
    summary: studyGuide.summary,
    interpretation: studyGuide.interpretation,
    context: studyGuide.context,
    relatedVerses: studyGuide.relatedVerses,
    reflectionQuestions: studyGuide.reflectionQuestions,
    prayerPoints: studyGuide.prayerPoints,
    language: requestData.language || DEFAULT_LANGUAGE
  }

  if (isAuthenticated) {
    return await repository.saveAuthenticatedStudyGuide(
      userContext.user_id!,
      studyGuideData
    )
  } else {
    const inputValueHash = await securityValidator.hashSensitiveData(
      requestData.input_value
    )
    
    return await repository.saveAnonymousStudyGuide(
      userContext.session_id!,
      { ...studyGuideData, inputValueHash }
    )
  }
}

/**
 * Logs analytics event for study guide generation.
 * 
 * @param analyticsLogger - Analytics logger instance
 * @param requestData - Request data
 * @param req - HTTP request for IP extraction
 */
async function logStudyGeneration(
  analyticsLogger: AnalyticsLogger,
  requestData: StudyGenerationRequest,
  req: Request
): Promise<void> {
  await analyticsLogger.logEvent('study_guide_generated', {
    input_type: requestData.input_type,
    language: requestData.language || DEFAULT_LANGUAGE,
    is_authenticated: requestData.user_context?.is_authenticated ?? false,
    user_id: requestData.user_context?.user_id,
    session_id: requestData.user_context?.session_id
  }, req.headers.get('x-forwarded-for'))
}

/**
 * Builds the study guide response from saved data.
 * 
 * @param savedData - Saved study guide data from database
 * @returns Formatted study guide response
 */
function buildStudyGuideResponse(savedData: any): StudyGuideResponse {
  return {
    id: savedData.id,
    summary: savedData.summary,
    interpretation: savedData.interpretation,
    context: savedData.context,
    related_verses: savedData.related_verses,
    reflection_questions: savedData.reflection_questions,
    prayer_points: savedData.prayer_points,
    language: savedData.language,
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
      status: 200,
    }
  )
}