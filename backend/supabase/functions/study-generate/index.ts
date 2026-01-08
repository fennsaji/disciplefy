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
  readonly topic_description?: string  // Optional: provides context for topic-based study guides
  readonly language?: string
  readonly study_mode?: 'quick' | 'standard' | 'deep' | 'lectio'  // Optional: defaults to 'standard'
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
  const { input_type, input_value, topic_description, language, study_mode } = await parseAndValidateRequest(req)
  
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
    language: language || 'en',
    study_mode: study_mode || 'standard'
  }

  const existingContent = await studyGuideRepository.findExistingContent(studyGuideInput, userContext)

  if (existingContent) {
    // Check if current user is the original creator
    const isCreator = checkIsCreator(existingContent, userContext)

    if (isCreator) {
      // Original creator - FREE access
      await analyticsLogger.logEvent('study_guide_cache_hit_creator', {
        input_type,
        language: language || 'en',
        user_type: userContext.type,
        user_id: userContext.userId,
        session_id: userContext.sessionId,
        study_guide_id: existingContent.id
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
    } else {
      // Different user accessing cached content - CHARGE TOKENS
      const userPlan = await authService.getUserPlan(req)
      const targetLanguage = language || 'en'
      const tokenCost = tokenService.calculateTokenCost(
        targetLanguage as SupportedLanguage,
        study_mode || 'standard'
      )
      const identifier = userContext.type === 'authenticated' ? userContext.userId! : userContext.sessionId!

      let consumptionResult

      if (tokenService.isUnlimitedPlan(userPlan)) {
        // Premium/unlimited users are not charged tokens
        consumptionResult = {
          success: true,
          availableTokens: 999999,
          purchasedTokens: 0,
          dailyLimit: 999999,
          totalTokens: 999999,
          errorMessage: undefined
        }

        await analyticsLogger.logEvent('study_guide_cache_hit_non_creator_unlimited', {
          input_type,
          language: targetLanguage,
          user_type: userContext.type,
          user_plan: userPlan,
          user_id: userContext.userId,
          session_id: userContext.sessionId,
          study_guide_id: existingContent.id
        }, req.headers.get('x-forwarded-for'))
      } else {
        // Standard and free users consume tokens for non-creator cached access
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

        await analyticsLogger.logEvent('study_guide_cache_hit_non_creator_charged', {
          input_type,
          language: targetLanguage,
          user_type: userContext.type,
          user_plan: userPlan,
          tokens_consumed: tokenCost,
          user_id: userContext.userId,
          session_id: userContext.sessionId,
          study_guide_id: existingContent.id
        }, req.headers.get('x-forwarded-for'))
      }

      return new Response(JSON.stringify({
        success: true,
        data: {
          study_guide: existingContent,
          from_cache: true
        },
        tokens: {
          consumed: tokenService.isUnlimitedPlan(userPlan) ? 0 : tokenCost,
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
  }

  // --- CACHE MISS: Only now enforce token consumption for expensive LLM generation ---
  
  // 5. Determine user plan and calculate token cost
  const userPlan = await authService.getUserPlan(req)
  const targetLanguage = language || 'en'
  const tokenCost = tokenService.calculateTokenCost(
    targetLanguage as SupportedLanguage,
    study_mode || 'standard'
  )
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
    topicDescription: topic_description,  // Provides additional context for topic-based guides
    language: targetLanguage,
    tier: userPlan  // Premium English users get GPT-4.1-mini
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
      prayerPoints: generatedContent.prayerPoints,
      interpretationInsights: generatedContent.interpretationInsights,
      summaryInsights: generatedContent.summaryInsights,
      reflectionAnswers: generatedContent.reflectionAnswers,
      contextQuestion: generatedContent.contextQuestion,
      summaryQuestion: generatedContent.summaryQuestion,
      relatedVersesQuestion: generatedContent.relatedVersesQuestion,
      reflectionQuestion: generatedContent.reflectionQuestion,
      prayerQuestion: generatedContent.prayerQuestion
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
    topic_description: {
      required: false,
      maxLength: 1000  // Allow longer descriptions for better context
    },
    language: {
      required: false,
      allowedValues: ['en', 'hi', 'ml']
    },
    study_mode: {
      required: false,
      allowedValues: ['quick', 'standard', 'deep', 'lectio']
    }
  }

  RequestValidator.validateRequestBody(requestBody, validationRules)

  return {
    input_type: requestBody.input_type,
    input_value: requestBody.input_value,
    topic_description: requestBody.topic_description,
    language: requestBody.language,
    study_mode: requestBody.study_mode
  }
}

/**
 * Check if the current user is the original creator of the cached content
 *
 * Rules:
 * 1. Legacy guides (no creator) - treat as "creator" so they get free access
 * 2. Authenticated users - match by userId
 * 3. Anonymous users - match by sessionId
 */
function checkIsCreator(
  content: { creatorUserId?: string | null; creatorSessionId?: string | null },
  userContext: { type: 'authenticated' | 'anonymous'; userId?: string; sessionId?: string }
): boolean {
  // Legacy guides (no creator tracked) - free for all
  if (!content.creatorUserId && !content.creatorSessionId) {
    return true // Treat as "creator" so they get free access
  }

  if (userContext.type === 'authenticated') {
    return content.creatorUserId === userContext.userId
  } else {
    return content.creatorSessionId === userContext.sessionId
  }
}

// Wrap the handler in the factory as specified in the guide
createFunction(handleStudyGenerate)