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
import { SupportedLanguage } from '../_shared/types/token-types.ts'

/**
 * Request payload for study guide generation
 * 
 * Note: user_context is removed as per security guide to prevent
 * client-provided user impersonation attacks
 */
interface StudyGenerationRequest {
  readonly input_type: 'scripture' | 'topic' | 'question'
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
async function handleStudyGenerate(req: Request, { authService, llmService, studyGuideRepository, tokenService, analyticsLogger, securityValidator }: ServiceContainer): Promise<Response> {
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

  // --- CACHE MISS: Only now enforce token consumption for expensive LLM generation ---
  
  // 5. Determine user plan and calculate token cost
  const userPlan = await authService.getUserPlan(req)
  const targetLanguage = language || 'en'
  const tokenCost = tokenService.calculateTokenCost(targetLanguage as SupportedLanguage)
  const identifier = userContext.type === 'authenticated' ? userContext.userId! : userContext.sessionId!
  
  // 6. Token consumption enforcement (only for new content generation)
  let consumptionResult
  
  if (tokenService.isUnlimitedPlan(userPlan)) {
    // Premium/unlimited users are not charged tokens
    consumptionResult = {
      success: true,
      availableTokens: 999999, // Unlimited indicator
      purchasedTokens: 0,
      dailyLimit: 999999,
      totalTokens: 999999,
      errorMessage: undefined
    }
  } else {
    // Standard and free users consume tokens normally
    consumptionResult = await tokenService.consumeTokens(
      identifier,
      userPlan,
      tokenCost,
      {
        userId: userContext.userId,
        sessionId: userContext.sessionId,
        userPlan: userPlan,
        operation: 'consume',
        language: targetLanguage as SupportedLanguage,
        ipAddress: req.headers.get('x-forwarded-for') || undefined,
        userAgent: req.headers.get('user-agent') || undefined,
        timestamp: new Date()
      }
    )
  }

  // 7. Generate new content using LLM service
  const generatedContent = await llmService.generateStudyGuide({
    inputType: input_type,
    inputValue: input_value,
    language: targetLanguage
  })

  // 8. Save to repository
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

  // 9. Log analytics for successful generation
  await analyticsLogger.logEvent('study_guide_generated', {
    input_type,
    language: targetLanguage,
    user_type: userContext.type,
    user_plan: userPlan,
    tokens_consumed: tokenCost,
    user_id: userContext.userId,
    session_id: userContext.sessionId
  }, req.headers.get('x-forwarded-for'))

  // 10. Return response with token information
  return new Response(JSON.stringify({
    success: true,
    data: {
      study_guide: savedGuide,
      from_cache: false
    },
    tokens: {
      consumed: tokenCost,
      remaining: {
        available_tokens: consumptionResult.availableTokens,
        purchased_tokens: consumptionResult.purchasedTokens,
        total_tokens: consumptionResult.totalTokens
      },
      daily_limit: consumptionResult.dailyLimit,
      user_plan: userPlan
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
      allowedValues: ['scripture', 'topic', 'question']
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