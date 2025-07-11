import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { SecurityValidator } from '../_shared/security-validator.ts'
import { RateLimiter } from '../_shared/rate-limiter.ts'
import { LLMService } from '../_shared/llm-service.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { RequestValidator } from '../_shared/request-validator.ts'
import { AnalyticsLogger } from '../_shared/analytics-logger.ts'
import { 
  StudyGuideRepository,
  StudyGuideInput,
  StudyGuideContent,
  UserContext,
  StudyGuideResponse
} from '../_shared/repositories/study-guide-repository.ts'

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
 * Response payload for study guide generation.
 */
interface StudyGuideApiResponse {
  readonly success: true
  readonly data: {
    readonly study_guide: StudyGuideResponse
    readonly from_cache: boolean
    readonly cache_stats: {
      readonly hit_rate: number
      readonly response_time_ms: number
    }
  }
  readonly rate_limit: {
    readonly remaining: number
    readonly reset_time: number
  }
}

// Configuration constants
const DEFAULT_LANGUAGE = 'en' as const
const REQUIRED_ENV_VARS = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'] as const

/**
 * Study Guide Generation Edge Function
 * 
 * Enhanced version with content caching and deduplication.
 * Significantly reduces LLM API calls and storage requirements.
 */
serve(async (req: Request): Promise<Response> => {
  const startTime = performance.now()

  // Handle preflight CORS requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Validate environment and method
    validateEnvironment()
    RequestValidator.validateHttpMethod(req.method, ['POST'])

    // Initialize services
    const supabaseClient = createSupabaseClient(req)
    const services = initializeServices(supabaseClient)

    // Parse and validate request
    const requestData = await parseAndValidateRequest(req)
    const userContext = buildUserContext(requestData)

    // Security validation
    await performSecurityValidation(
      services.securityValidator,
      services.analyticsLogger,
      requestData,
      req
    )

    // Rate limiting
    const rateLimitResult = await enforceRateLimit(
      services.rateLimiter,
      userContext
    )

    // Attempt to find existing cached content
    const studyGuideInput: StudyGuideInput = {
      type: requestData.input_type,
      value: requestData.input_value,
      language: requestData.language || DEFAULT_LANGUAGE
    }

    let studyGuideResponse: StudyGuideResponse
    let fromCache = false

    // Check for existing content in cache
    const existingContent = await services.repository.findExistingContent(
      studyGuideInput,
      userContext
    )

    if (existingContent) {
      // Return cached content
      studyGuideResponse = existingContent
      fromCache = true
      
      await services.analyticsLogger.logEvent('study_guide_cache_hit', {
        input_type: requestData.input_type,
        language: requestData.language || DEFAULT_LANGUAGE,
        user_type: userContext.type,
        user_id: userContext.userId,
        session_id: userContext.sessionId
      }, req.headers.get('x-forwarded-for'))
    } else {
      // Generate new content
      const generatedContent = await generateNewContent(
        services.llmService,
        studyGuideInput
      )

      // Save to cache and link to user
      studyGuideResponse = await services.repository.saveStudyGuide(
        studyGuideInput,
        generatedContent,
        userContext
      )

      fromCache = false

      await services.analyticsLogger.logEvent('study_guide_generated', {
        input_type: requestData.input_type,
        language: requestData.language || DEFAULT_LANGUAGE,
        user_type: userContext.type,
        user_id: userContext.userId,
        session_id: userContext.sessionId
      }, req.headers.get('x-forwarded-for'))
    }

    // Calculate response time
    const responseTime = performance.now() - startTime

    // Build response
    const response: StudyGuideApiResponse = {
      success: true,
      data: {
        study_guide: studyGuideResponse,
        from_cache: fromCache,
        cache_stats: {
          hit_rate: fromCache ? 100 : 0, // Individual request hit rate
          response_time_ms: Math.round(responseTime)
        }
      },
      rate_limit: {
        remaining: rateLimitResult.remaining,
        reset_time: rateLimitResult.resetTime
      }
    }

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

/**
 * Validates required environment variables.
 */
function validateEnvironment(): void {
  RequestValidator.validateEnvironmentVariables(REQUIRED_ENV_VARS)
}

/**
 * Creates configured Supabase client.
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
 * Initializes all required services.
 */
function initializeServices(supabaseClient: SupabaseClient) {
  return {
    securityValidator: new SecurityValidator(),
    rateLimiter: new RateLimiter(supabaseClient),
    analyticsLogger: new AnalyticsLogger(supabaseClient),
    llmService: new LLMService(),
    repository: new StudyGuideRepository(supabaseClient)
  }
}

/**
 * Parses and validates request payload.
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

  // Validate user context
  if (requestBody.user_context) {
    validateUserContext(requestBody.user_context)
  }

  return requestBody as StudyGenerationRequest
}

/**
 * Validates user context structure.
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
 * Builds user context from request data.
 */
function buildUserContext(requestData: StudyGenerationRequest): UserContext {
  const userContextData = requestData.user_context

  if (!userContextData) {
    throw new AppError(
      'VALIDATION_ERROR',
      'user_context is required',
      400
    )
  }

  return {
    type: userContextData.is_authenticated ? 'authenticated' : 'anonymous',
    userId: userContextData.user_id,
    sessionId: userContextData.session_id
  }
}

/**
 * Performs security validation on input.
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
 * Enforces rate limiting.
 */
async function enforceRateLimit(
  rateLimiter: RateLimiter,
  userContext: UserContext
) {
  const identifier = userContext.type === 'authenticated' 
    ? userContext.userId! 
    : userContext.sessionId!

  await rateLimiter.enforceRateLimit(identifier, userContext.type)
  return await rateLimiter.checkRateLimit(identifier, userContext.type)
}

/**
 * Generates new study guide content using LLM.
 */
async function generateNewContent(
  llmService: LLMService,
  input: StudyGuideInput
): Promise<StudyGuideContent> {
  const generated = await llmService.generateStudyGuide({
    inputType: input.type,
    inputValue: input.value,
    language: input.language
  })

  return {
    summary: generated.summary,
    interpretation: generated.interpretation,
    context: generated.context,
    relatedVerses: generated.relatedVerses,
    reflectionQuestions: generated.reflectionQuestions,
    prayerPoints: generated.prayerPoints
  }
}