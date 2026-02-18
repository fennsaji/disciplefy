/**
 * Admin Study Generator Edge Function
 *
 * Allows admins to generate study guides without token consumption.
 * Reuses existing study generation infrastructure from study-generate-v2.
 *
 * Supported Operations:
 * - GET /admin-study-generator - Generate study guide (SSE streaming)
 *
 * Query Parameters:
 * - input_type: 'scripture' | 'topic' | 'question'
 * - input_value: string (verse reference, topic, or question)
 * - topic_description: string (optional, for topic input type)
 * - language: 'en' | 'hi' | 'ml' (default: 'en')
 * - study_mode: 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon' (default: 'standard')
 * - authorization: Bearer token (query param for EventSource compatibility)
 * - apikey: Supabase anon key (query param for EventSource compatibility)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { StudyGuideInput } from '../_shared/types/index.ts'
import { SupportedLanguage } from '../_shared/types/token-types.ts'
import { UserContext } from '../_shared/types/index.ts'
import type { StudyMode } from '../_shared/services/llm-types.ts'
import { getCorsHeaders } from '../_shared/utils/cors.ts'
import {
  StreamingJsonParser,
  createInitEvent,
  createSectionEvent,
  createCompleteEvent,
  createErrorEvent,
  CompleteStudyGuide
} from '../_shared/services/streaming-json-parser.ts'

/**
 * Extract authentication credentials from request (query params for EventSource)
 */
function extractAuthCredentials(req: Request): { authToken: string | null; apiKey: string | null } {
  const url = new URL(req.url)
  let authToken = url.searchParams.get('authorization')
  let apiKey = url.searchParams.get('apikey')

  // Fallback to headers for non-EventSource requests
  if (!authToken) {
    const authHeader = req.headers.get('authorization')
    if (authHeader?.startsWith('Bearer ')) {
      authToken = authHeader.substring(7)
    }
  }

  if (!apiKey) {
    apiKey = req.headers.get('apikey')
  }

  return { authToken, apiKey }
}

/**
 * Parse request parameters from query string
 */
function parseRequestParams(req: Request): {
  input_type: 'scripture' | 'topic' | 'question'
  input_value: string
  topic_description?: string
  language: string
  study_mode: StudyMode
} | null {
  const url = new URL(req.url)

  const input_type = url.searchParams.get('input_type') as 'scripture' | 'topic' | 'question' | null
  const input_value = url.searchParams.get('input_value')
  const topic_description = url.searchParams.get('topic_description') || undefined
  const language = url.searchParams.get('language') || 'en'
  const mode = url.searchParams.get('mode') as StudyMode | null

  if (!input_type || !input_value) {
    return null
  }

  if (!['scripture', 'topic', 'question'].includes(input_type)) {
    return null
  }

  // Validate and default study mode
  const validModes: StudyMode[] = ['quick', 'standard', 'deep', 'lectio', 'sermon']
  const study_mode: StudyMode = mode && validModes.includes(mode) ? mode : 'standard'

  return { input_type, input_value, topic_description, language, study_mode }
}

/**
 * Main handler for admin study generation
 */
async function handleAdminStudyGenerator(
  req: Request,
  {
    authService,
    llmService,
    studyGuideRepository,
    analyticsLogger,
    securityValidator
  }: ServiceContainer
): Promise<Response> {
  console.log('🚀 [ADMIN-STUDY] Starting admin study guide generation')

  const corsHeaders = getCorsHeaders(req.headers.get('origin'))

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }

  // Only allow GET for EventSource
  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'METHOD_NOT_ALLOWED', message: 'Use GET for SSE streaming' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Authenticate user
  let userContext: UserContext
  let authReq: Request

  try {
    const { authToken, apiKey } = extractAuthCredentials(req)

    if (!authToken && !apiKey) {
      return new Response(
        JSON.stringify({ error: 'UNAUTHORIZED', message: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    authReq = new Request(req.url, {
      method: req.method,
      headers: new Headers({
        'Authorization': authToken ? `Bearer ${authToken}` : '',
        'apikey': apiKey || ''
      })
    })

    userContext = await authService.getUserContext(authReq)

    // Verify admin status
    if (userContext.userType !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'FORBIDDEN', message: 'Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('✅ [ADMIN-STUDY] Admin authentication successful:', {
      userId: userContext.userId
    })
  } catch (error) {
    console.error('❌ [ADMIN-STUDY] Authentication failed:', error)
    return new Response(
      JSON.stringify({
        error: 'UNAUTHORIZED',
        message: error instanceof Error ? error.message : 'Authentication failed'
      }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Parse request parameters
  const params = parseRequestParams(req)
  if (!params) {
    return new Response(
      JSON.stringify({
        error: 'INVALID_REQUEST',
        message: 'Missing required parameters: input_type, input_value'
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const { input_type, input_value, topic_description, language, study_mode } = params

  console.log(`📝 [ADMIN-STUDY] Study mode: ${study_mode}, language: ${language}`)

  // Security validation
  const securityResult = await securityValidator.validateInput(input_value, input_type)
  if (!securityResult.isValid) {
    await analyticsLogger.logEvent('admin_security_violation', {
      event_type: securityResult.eventType,
      risk_score: securityResult.riskScore,
      action_taken: 'BLOCKED',
      user_id: userContext.userId,
      admin: true
    }, req.headers.get('x-forwarded-for'))

    return new Response(
      JSON.stringify({
        error: 'SECURITY_VIOLATION',
        message: securityResult.message
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Check for cached content
  const studyGuideInput: StudyGuideInput = {
    type: input_type,
    value: input_value,
    language: language,
    study_mode: study_mode
  }

  const existingContent = await studyGuideRepository.findExistingContent(studyGuideInput, userContext)

  const targetLanguage = (language || 'en') as SupportedLanguage

  // Create SSE response stream
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder()

      const emit = (data: string) => {
        try {
          controller.enqueue(encoder.encode(data))
        } catch (error) {
          console.log('[ADMIN-STUDY] Stream closed, continuing generation in background')
        }
      }

      const emitError = (code: string, message: string, retryable: boolean) => {
        emit(createErrorEvent(code, message, retryable))
        try {
          controller.close()
        } catch (error) {
          // Controller already closed - ignore
        }
      }

      // Emit keepalive immediately
      emit(': keepalive\n\n')

      try {
        // Handle cached content (admin can reuse cache without consuming tokens)
        if (existingContent) {
          console.log('📦 [ADMIN-STUDY] Streaming cached content')

          const cachedGuide: CompleteStudyGuide = {
            summary: existingContent.content.summary || '',
            interpretation: existingContent.content.interpretation || '',
            context: existingContent.content.context || '',
            passage: existingContent.content.passage || undefined,
            relatedVerses: [...(existingContent.content.relatedVerses || [])],
            reflectionQuestions: [...(existingContent.content.reflectionQuestions || [])],
            prayerPoints: [...(existingContent.content.prayerPoints || [])],
            interpretationInsights: existingContent.content.interpretationInsights
              ? [...existingContent.content.interpretationInsights]
              : undefined,
            summaryInsights: existingContent.content.summaryInsights
              ? [...existingContent.content.summaryInsights]
              : undefined,
            reflectionAnswers: existingContent.content.reflectionAnswers
              ? [...existingContent.content.reflectionAnswers]
              : undefined,
            contextQuestion: existingContent.content.contextQuestion || undefined,
            summaryQuestion: existingContent.content.summaryQuestion || undefined,
            relatedVersesQuestion: existingContent.content.relatedVersesQuestion || undefined,
            reflectionQuestion: existingContent.content.reflectionQuestion || undefined,
            prayerQuestion: existingContent.content.prayerQuestion || undefined
          }

          const cachedSectionCount = 6 +
            (cachedGuide.passage ? 1 : 0) +
            (cachedGuide.interpretationInsights ? 1 : 0) +
            (cachedGuide.summaryInsights ? 1 : 0) +
            (cachedGuide.reflectionAnswers ? 1 : 0) +
            (cachedGuide.contextQuestion ? 1 : 0) +
            (cachedGuide.summaryQuestion ? 1 : 0) +
            (cachedGuide.relatedVersesQuestion ? 1 : 0) +
            (cachedGuide.reflectionQuestion ? 1 : 0) +
            (cachedGuide.prayerQuestion ? 1 : 0)

          emit(createInitEvent('cache_hit', cachedSectionCount))

          // Stream all sections
          const sections = [
            { type: 'summary', content: cachedGuide.summary, index: 0 },
            { type: 'context', content: cachedGuide.context, index: 1 },
            { type: 'interpretation', content: cachedGuide.interpretation, index: 2 },
            { type: 'relatedVerses', content: cachedGuide.relatedVerses, index: 3 },
            { type: 'reflectionQuestions', content: cachedGuide.reflectionQuestions, index: 4 },
            { type: 'prayerPoints', content: cachedGuide.prayerPoints, index: 5 }
          ]

          let idx = 6
          if (cachedGuide.passage) sections.push({ type: 'passage', content: cachedGuide.passage, index: idx++ })
          if (cachedGuide.interpretationInsights) sections.push({ type: 'interpretationInsights', content: cachedGuide.interpretationInsights, index: idx++ })
          if (cachedGuide.summaryInsights) sections.push({ type: 'summaryInsights', content: cachedGuide.summaryInsights, index: idx++ })
          if (cachedGuide.reflectionAnswers) sections.push({ type: 'reflectionAnswers', content: cachedGuide.reflectionAnswers, index: idx++ })
          if (cachedGuide.contextQuestion) sections.push({ type: 'contextQuestion', content: cachedGuide.contextQuestion, index: idx++ })
          if (cachedGuide.summaryQuestion) sections.push({ type: 'summaryQuestion', content: cachedGuide.summaryQuestion, index: idx++ })
          if (cachedGuide.relatedVersesQuestion) sections.push({ type: 'relatedVersesQuestion', content: cachedGuide.relatedVersesQuestion, index: idx++ })
          if (cachedGuide.reflectionQuestion) sections.push({ type: 'reflectionQuestion', content: cachedGuide.reflectionQuestion, index: idx++ })
          if (cachedGuide.prayerQuestion) sections.push({ type: 'prayerQuestion', content: cachedGuide.prayerQuestion, index: idx++ })

          for (const section of sections) {
            emit(createSectionEvent(section as any, cachedSectionCount))
            await new Promise(resolve => setTimeout(resolve, 50))
          }

          emit(createCompleteEvent(existingContent.id, 0, true)) // No tokens consumed for admin

          controller.close()
          return
        }

        // NEW GENERATION - No token consumption for admin
        console.log('🪄 [ADMIN-STUDY] Starting new generation (admin privilege - no tokens consumed)')

        const parser = new StreamingJsonParser()
        emit(createInitEvent('started', parser.getTotalSections()))

        // Stream from LLM
        const llmStream = llmService.streamStudyGuide({
          inputType: input_type,
          inputValue: input_value,
          topicDescription: topic_description,
          language: targetLanguage,
          tier: 'premium', // Admin gets premium-level generation
          studyMode: study_mode
        })

        let streamingUsage = null

        // Manually iterate to capture return value
        while (true) {
          const result = await llmStream.next()
          if (result.done) {
            streamingUsage = result.value
            break
          }

          const chunk = result.value
          const newSections = parser.addChunk(chunk)

          // Emit any newly complete sections
          for (const section of newSections) {
            console.log(`📤 [ADMIN-STUDY] Emitting section: ${section.type}`)
            emit(createSectionEvent(section, parser.getTotalSections()))
          }
        }

        console.log(`💰 [ADMIN-STUDY] LLM Usage: ${streamingUsage?.totalTokens} tokens, $${streamingUsage?.costUsd.toFixed(4)} (not charged to admin)`)

        // Get complete study guide
        let studyGuideData: CompleteStudyGuide | undefined
        if (parser.isComplete()) {
          studyGuideData = parser.getCompleteStudyGuide()
        } else {
          const fallbackData = await parser.tryParseComplete()
          if (fallbackData) {
            studyGuideData = fallbackData
          }
        }

        if (!studyGuideData) {
          console.error('❌ [ADMIN-STUDY] Study guide data was not generated')
          emit(createErrorEvent('LM-E-004', 'Study guide generation failed', true))
          return
        }

        // Save to database
        const savedGuide = await studyGuideRepository.saveStudyGuide(
          studyGuideInput,
          {
            summary: studyGuideData.summary,
            interpretation: studyGuideData.interpretation,
            context: studyGuideData.context,
            passage: studyGuideData.passage || null,
            relatedVerses: studyGuideData.relatedVerses,
            reflectionQuestions: studyGuideData.reflectionQuestions,
            prayerPoints: studyGuideData.prayerPoints,
            interpretationInsights: studyGuideData.interpretationInsights || [],
            summaryInsights: studyGuideData.summaryInsights || [],
            reflectionAnswers: studyGuideData.reflectionAnswers || [],
            contextQuestion: studyGuideData.contextQuestion || '',
            summaryQuestion: studyGuideData.summaryQuestion || '',
            relatedVersesQuestion: studyGuideData.relatedVersesQuestion || '',
            reflectionQuestion: studyGuideData.reflectionQuestion || '',
            prayerQuestion: studyGuideData.prayerQuestion || ''
          },
          userContext
        )

        console.log('💾 [ADMIN-STUDY] Study guide saved:', savedGuide.id)

        // Emit complete event (no tokens consumed)
        emit(createCompleteEvent(savedGuide.id, 0, false))

        // Log analytics
        await analyticsLogger.logEvent('admin_study_guide_generated', {
          input_type,
          language: targetLanguage,
          study_mode,
          study_guide_id: savedGuide.id,
          admin_user_id: userContext.userId
        }, req.headers.get('x-forwarded-for'))

        controller.close()

      } catch (error) {
        console.error('❌ [ADMIN-STUDY] Stream error:', error)

        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        const isRetryable = !(error instanceof AppError && error.statusCode >= 400 && error.statusCode < 500)
        const errorCode = error instanceof AppError ? error.code : 'LM-E-001'

        emitError(errorCode, errorMessage, isRetryable)
      }
    }
  })

  return new Response(stream, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    }
  })
}

// Use simple function factory (bypasses Kong for EventSource compatibility)
createSimpleFunction(handleAdminStudyGenerator, {
  allowedMethods: ['GET', 'OPTIONS']
})
