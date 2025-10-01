/**
 * Brand new test function to verify fresh functions work
 */

import { handleCors } from '../_shared/utils/cors.ts'

const handler = async (req: Request): Promise<Response> => {
  console.log('🆕 [TEST-NEW] Fresh function is executing!')

  // Get canonical CORS headers
  const corsHeaders = handleCors(req)

  // Handle preflight OPTIONS requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders
    })
  }

  return new Response(JSON.stringify({
    success: true,
    message: 'FRESH FUNCTION WORKS! No cache issues!',
    timestamp: new Date().toISOString()
  }), {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  })
}

// Use Deno's serve function
Deno.serve(handler)