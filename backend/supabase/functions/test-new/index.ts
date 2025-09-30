/**
 * Brand new test function to verify fresh functions work
 */

const handler = async (req: Request): Promise<Response> => {
  console.log('🆕 [TEST-NEW] Fresh function is executing!')

  return new Response(JSON.stringify({
    success: true,
    message: 'FRESH FUNCTION WORKS! No cache issues!',
    timestamp: new Date().toISOString()
  }), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  })
}

// Use Deno's serve function
Deno.serve(handler)