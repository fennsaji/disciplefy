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
    // Parse request parameters
    const url = new URL(req.url)
    const studyGuideId = url.searchParams.get('study_guide_id') || 'test-guide'
    const question = url.searchParams.get('question') || 'test question'
    const language = url.searchParams.get('language') || 'en'

    // Get auth parameters from query (EventSource limitation)
    const authToken = url.searchParams.get('authorization')
    const apiKey = url.searchParams.get('apikey')

    console.log('📝 [TEST-LOCAL] Extracted params:', {
      studyGuideId,
      question: question.substring(0, 30) + '...',
      language,
      hasAuth: !!authToken,
      hasApiKey: !!apiKey
    })

    // Simple auth validation
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
          // Send connection established event
          controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
            type: 'connection',
            message: 'Connected to test-local EventSource service',
            authenticated: true,
            authMethod: authToken ? 'Bearer token' : 'API key'
          })}\n\n`))

          // Send test response chunks
          const testResponse = `✅ SUCCESS! EventSource authentication working! Question: "${question}". Study guide: ${studyGuideId}. Authenticated with ${authToken ? 'Bearer token' : 'API key'}.`

          // Split response into chunks and send with delay
          const chunks = testResponse.match(/.{1,25}/g) || [testResponse]
          let chunkIndex = 0

          const sendChunk = () => {
            if (chunkIndex < chunks.length) {
              controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
                type: 'content',
                content: chunks[chunkIndex]
              })}\n\n`))
              chunkIndex++
              setTimeout(sendChunk, 150) // 150ms delay between chunks
            } else {
              // Send completion event
              controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
                type: 'complete',
                message_id: `test_msg_${Date.now()}`
              })}\n\n`))
              controller.close()
            }
          }

          // Start sending chunks after a brief delay
          setTimeout(sendChunk, 300)
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