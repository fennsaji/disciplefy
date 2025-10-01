/**
 * Test function to verify EventSource streaming with authentication
 */

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

// CORS headers for EventSource support
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey, x-session-id',
  'Access-Control-Allow-Credentials': 'true',
  'Access-Control-Expose-Headers': 'Content-Type, Cache-Control, Connection',
}

/**
 * Validated and sanitized request parameters
 */
interface ValidatedParams {
  readonly studyGuideId: string
  readonly question: string
  readonly language: string
  readonly authToken: string | null
  readonly apiKey: string | null
}

/**
 * Validates and sanitizes request parameters
 * Enforces max lengths, strips control characters, validates formats
 */
function validateAndSanitizeParams(url: URL): ValidatedParams | { error: string } {
  // Extract raw parameters
  const rawStudyGuideId = url.searchParams.get('study_guide_id') || 'test-guide'
  const rawQuestion = url.searchParams.get('question') || 'test question'
  const rawLanguage = url.searchParams.get('language') || 'en'
  const rawAuthToken = url.searchParams.get('authorization')
  const rawApiKey = url.searchParams.get('apikey')

  // Validate and sanitize study_guide_id
  if (rawStudyGuideId.length > 100) {
    return { error: 'study_guide_id exceeds maximum length of 100 characters' }
  }
  // Strip control characters and disallowed chars (allow alphanumeric, dash, underscore)
  const studyGuideId = rawStudyGuideId.replace(/[^a-zA-Z0-9_-]/g, '')
  if (studyGuideId.length === 0) {
    return { error: 'study_guide_id contains only invalid characters' }
  }

  // Validate and sanitize question
  if (rawQuestion.length > 500) {
    return { error: 'question exceeds maximum length of 500 characters' }
  }
  // Strip control characters (keep alphanumeric, spaces, basic punctuation)
  const question = rawQuestion.replace(/[\x00-\x1F\x7F]/g, '').trim()
  if (question.length === 0) {
    return { error: 'question is required and cannot be empty' }
  }

  // Validate and sanitize language
  if (rawLanguage.length > 5) {
    return { error: 'language exceeds maximum length of 5 characters' }
  }
  // Normalize to lowercase, allow only letters and optional dash (ISO-like format)
  const language = rawLanguage.toLowerCase().replace(/[^a-z-]/g, '')
  if (language.length === 0 || language.length > 5) {
    return { error: 'language must be 1-5 lowercase letters with optional dash' }
  }

  // Validate authToken with safe regex (alphanumeric, dash, dot, underscore)
  let authToken: string | null = null
  if (rawAuthToken) {
    if (rawAuthToken.length > 500) {
      return { error: 'authorization token exceeds maximum length' }
    }
    if (!/^[a-zA-Z0-9._-]+$/.test(rawAuthToken)) {
      return { error: 'authorization token contains invalid characters' }
    }
    authToken = rawAuthToken
  }

  // Validate apiKey with safe regex (alphanumeric, dash, dot, underscore)
  let apiKey: string | null = null
  if (rawApiKey) {
    if (rawApiKey.length > 500) {
      return { error: 'API key exceeds maximum length' }
    }
    if (!/^[a-zA-Z0-9._-]+$/.test(rawApiKey)) {
      return { error: 'API key contains invalid characters' }
    }
    apiKey = rawApiKey
  }

  return {
    studyGuideId,
    question,
    language,
    authToken,
    apiKey
  }
}

/**
 * Creates a safe truncated preview of text for logging
 * Never logs full sensitive content
 */
function createSafePreview(text: string, maxLength: number = 30): string {
  if (text.length <= maxLength) {
    return text
  }
  return text.substring(0, maxLength) + '...'
}

async function handler(req: Request): Promise<Response> {
  console.log('🧪 [TEST-LOCAL] EventSource test function executing!')

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders
    })
  }

  try {
    // Parse and validate request parameters
    const url = new URL(req.url)
    const validationResult = validateAndSanitizeParams(url)

    // Check for validation errors
    if ('error' in validationResult) {
      console.warn('⚠️ [TEST-LOCAL] Validation failed:', validationResult.error)
      return new Response(JSON.stringify({
        success: false,
        error: validationResult.error
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Extract sanitized parameters
    const { studyGuideId, question, language, authToken, apiKey } = validationResult

    // Log sanitized params with safe preview (never log full question)
    console.log('📝 [TEST-LOCAL] Validated params:', {
      studyGuideId,
      questionPreview: createSafePreview(question, 30),
      language,
      hasAuth: !!authToken,
      hasApiKey: !!apiKey
    })

    // Auth validation
    if (!authToken && !apiKey) {
      return new Response(JSON.stringify({
        success: false,
        error: 'No authentication provided'
      }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Check if this is an EventSource request
    const acceptsEventStream = req.headers.get('accept')?.includes('text/event-stream') ||
                              req.headers.get('cache-control') === 'no-cache'

    if (acceptsEventStream || req.method === 'GET') {
      console.log('🌊 [TEST-LOCAL] Setting up EventSource response')

      // Create a readable stream for Server-Sent Events
      const stream = new ReadableStream({
        start(controller) {
          // Track timeout IDs for cleanup on error
          let chunkTimeoutId: number | null = null
          let initialTimeoutId: number | null = null

          try {
            // Send connection established event
            try {
              const connectionData = JSON.stringify({
                type: 'connection',
                message: 'Connected to test-local EventSource service',
                authenticated: true,
                authMethod: authToken ? 'Bearer token' : 'API key'
              })
              controller.enqueue(new TextEncoder().encode(`data: ${connectionData}\n\n`))
            } catch (encodeError) {
              console.error('❌ [TEST-LOCAL] Connection event encoding failed:', encodeError)
              controller.error(encodeError)
              return
            }

            // Send test response chunks
            const testResponse = `✅ SUCCESS! EventSource authentication working! Question: "${question}". Study guide: ${studyGuideId}. Authenticated with ${authToken ? 'Bearer token' : 'API key'}.`

            // Split response into chunks and send with delay
            const chunks = testResponse.match(/.{1,25}/g) || [testResponse]
            let chunkIndex = 0

            const sendChunk = () => {
              try {
                if (chunkIndex < chunks.length) {
                  // Encode and send chunk
                  try {
                    const chunkData = JSON.stringify({
                      type: 'content',
                      content: chunks[chunkIndex]
                    })
                    controller.enqueue(new TextEncoder().encode(`data: ${chunkData}\n\n`))
                  } catch (encodeError) {
                    console.error('❌ [TEST-LOCAL] Chunk encoding failed:', encodeError)
                    if (chunkTimeoutId) clearTimeout(chunkTimeoutId)
                    controller.error(encodeError)
                    return
                  }

                  chunkIndex++
                  chunkTimeoutId = setTimeout(sendChunk, 150) as unknown as number
                } else {
                  // Send completion event
                  try {
                    const completeData = JSON.stringify({
                      type: 'complete',
                      message_id: `test_msg_${Date.now()}`
                    })
                    controller.enqueue(new TextEncoder().encode(`data: ${completeData}\n\n`))
                    controller.close()
                  } catch (encodeError) {
                    console.error('❌ [TEST-LOCAL] Completion event encoding failed:', encodeError)
                    controller.error(encodeError)
                  }
                }
              } catch (error) {
                console.error('❌ [TEST-LOCAL] sendChunk error:', error)
                if (chunkTimeoutId) clearTimeout(chunkTimeoutId)
                controller.error(error)
              }
            }

            // Start sending chunks after a brief delay
            initialTimeoutId = setTimeout(sendChunk, 300) as unknown as number

          } catch (error) {
            console.error('❌ [TEST-LOCAL] Stream start error:', error)
            // Clear any pending timers
            if (chunkTimeoutId) clearTimeout(chunkTimeoutId)
            if (initialTimeoutId) clearTimeout(initialTimeoutId)
            // Signal error and close stream
            controller.error(error)
          }
        }
      })

      return new Response(stream, {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        }
      })
    } else {
      // Regular JSON response for non-streaming requests
      console.log('📝 [TEST-LOCAL] Sending JSON response')

      try {
        const response = {
          success: true,
          message: '✅ SUCCESS! Authentication working!',
          data: {
            response: `Test response for question: "${question}". Study guide: ${studyGuideId}`,
            message_id: `test_${Date.now()}`,
            language: language,
            authMethod: authToken ? 'Bearer token' : 'API key'
          }
        }

        return new Response(JSON.stringify(response), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      } catch (jsonError) {
        console.error('❌ [TEST-LOCAL] JSON response encoding failed:', jsonError)
        return new Response(JSON.stringify({
          success: false,
          error: 'Failed to encode JSON response'
        }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

  } catch (error) {
    console.error('❌ [TEST-LOCAL ERROR]:', error)
    return new Response(JSON.stringify({
      success: false,
      error: `Server error: ${error instanceof Error ? error.message : String(error)}`
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
}

// Start the server
serve(handler)