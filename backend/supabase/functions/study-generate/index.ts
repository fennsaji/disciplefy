/**
 * Study Guide Generation Edge Function
 * 
 * Refactored according to the security guide to eliminate critical vulnerabilities:
 * - Removed insecure manual JWT decoding
 * - Eliminated client-provided user context
 * - Uses centralized AuthService for secure authentication
 * - Leverages function factory for boilerplate elimination
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { RequestValidator } from '../_shared/utils/request-validator.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { StudyGuideInput } from '../_shared/types/index.ts'

/**
 * Request payload for study guide generation
 * 
 * Note: user_context is removed as per security guide to prevent
 * client-provided user impersonation attacks
 */
interface StudyGenerationRequest {
  readonly input_type: 'scripture' | 'topic'
  readonly input_value: string
  readonly language?: string
}

/**
 * Study guide generation handler
 * 
 * This handler demonstrates the new secure pattern:
 * 1. Get user context SECURELY from AuthService
 * 2. Validate request body (no client-provided user context)
 * 3. Use injected services for business logic
 */
async function handleStudyGenerate(req: Request, { authService, llmService, studyGuideRepository, rateLimiter, analyticsLogger, securityValidator }: ServiceContainer): Promise<Response> {
  // 1. Get user context SECURELY from the new AuthService
  const userContext = await authService.getUserContext(req)
  
  // 2. Validate request body and parse data
  const { input_type, input_value, language } = await parseAndValidateRequest(req)
  
  // 3. Security validation of input
  const securityResult = await securityValidator.validateInput(input_value, input_type)
  if (!securityResult.isValid) {
    await analyticsLogger.logEvent('security_violation', {
      event_type: securityResult.eventType,
      risk_score: securityResult.riskScore,
      action_taken: 'BLOCKED',
      user_id: userContext.userId,
      session_id: userContext.sessionId
    }, req.headers.get('x-forwarded-for'))

    throw new AppError('SECURITY_VIOLATION', securityResult.message, 400)
  }

  // 4. Check for existing cached content FIRST (before rate limiting)
  const studyGuideInput: StudyGuideInput = {
    type: input_type,
    value: input_value,
    language: language || 'en'
  }

  const existingContent = await studyGuideRepository.findExistingContent(studyGuideInput, userContext)
  
  if (existingContent) {
    // Return cached content immediately (no rate limit check needed)
    await analyticsLogger.logEvent('study_guide_cache_hit', {
      input_type,
      language: language || 'en',
      user_type: userContext.type,
      user_id: userContext.userId,
      session_id: userContext.sessionId
    }, req.headers.get('x-forwarded-for'))

    return new Response(JSON.stringify({
      success: true,
      data: {
        study_guide: existingContent,
        from_cache: true
      }
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  // --- CACHE MISS: Only now enforce rate limiting for expensive LLM generation ---
  
  // 5. Rate limiting enforcement (only for new content generation)
  const identifier = userContext.type === 'authenticated' ? userContext.userId! : userContext.sessionId!
  await rateLimiter.enforceRateLimit(identifier, userContext.type)

  // 6. Generate new content using LLM service
  const generatedContent = await llmService.generateStudyGuide({
    inputType: input_type,
    inputValue: input_value,
    language: language || 'en'
  })

  // 7. Save to repository
  const savedGuide = await studyGuideRepository.saveStudyGuide(
    studyGuideInput,
    {
      summary: generatedContent.summary,
      interpretation: generatedContent.interpretation,
      context: generatedContent.context,
      relatedVerses: generatedContent.relatedVerses,
      reflectionQuestions: generatedContent.reflectionQuestions,
      prayerPoints: generatedContent.prayerPoints
    },
    userContext
  )

  // 8. Record usage for rate limiting
  await rateLimiter.recordUsage(identifier, userContext.type)

  // 9. Log analytics
  await analyticsLogger.logEvent('study_guide_generated', {
    input_type,
    language: language || 'en',
    user_type: userContext.type,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  // 10. Get rate limit status
  const rateLimitResult = await rateLimiter.checkRateLimit(identifier, userContext.type)

  // 11. Return response
  return new Response(JSON.stringify({
    success: true,
    data: {
      study_guide: savedGuide,
      from_cache: false
    },
    rate_limit: {
      remaining: rateLimitResult.remaining,
      reset_time: rateLimitResult.resetTime
    }
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Parses and validates request payload
 * 
 * Note: This no longer accepts user_context from client as per security guide
 */
async function parseAndValidateRequest(req: Request): Promise<StudyGenerationRequest> {
  let requestBody: any

  try {
    requestBody = await req.json()
  } catch (error) {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400)
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

  return {
    input_type: requestBody.input_type,
    input_value: requestBody.input_value,
    language: requestBody.language
  }
}

// Wrap the handler in the factory as specified in the guide
createFunction(handleStudyGenerate)