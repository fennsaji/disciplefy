/**
 * CORS Configuration for Supabase Edge Functions
 * 
 * Updated to handle specific origins properly while maintaining security
 */

// Allowed origins for CORS
const ALLOWED_ORIGINS = [
  'http://localhost:59641',           // Flutter web local development
  'http://localhost:3000',            // Alternative local development port
  'https://www.disciplefy.in',        // Production web app
  'https://dev.disciplefy.in',             // Vercel preview deployments
]

/**
 * Get appropriate CORS headers based on request origin
 */
export function getCorsHeaders(origin?: string | null): Record<string, string> {
  // Determine if origin is allowed
  let allowedOrigin = '*'
  
  if (origin) {
    // Check exact matches first
    if (ALLOWED_ORIGINS.includes(origin)) {
      allowedOrigin = origin
    } else {
      // Check wildcard patterns
      const isAllowed = ALLOWED_ORIGINS.some(allowedOrigin => {
        if (allowedOrigin.includes('*')) {
          const pattern = allowedOrigin.replace(/\*/g, '.*')
          const regex = new RegExp(`^${pattern}$`)
          return regex.test(origin)
        }
        return false
      })
      
      if (isAllowed) {
        allowedOrigin = origin
      }
    }
  }

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-session-id, x-anonymous-session-id',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
    'Access-Control-Allow-Credentials': 'true',
    'Vary': 'Origin'
  }
}

/**
 * Default CORS headers (for backward compatibility)
 * Now uses origin-specific headers
 */
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-session-id, x-anonymous-session-id',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
}

/**
 * Enhanced CORS middleware for Edge Functions
 */
export function handleCors(req: Request): Record<string, string> {
  const origin = req.headers.get('origin')
  return getCorsHeaders(origin)
}

/**
 * Check if origin is allowed
 */
export function isOriginAllowed(origin: string): boolean {
  if (ALLOWED_ORIGINS.includes(origin)) {
    return true
  }
  
  // Check wildcard patterns
  return ALLOWED_ORIGINS.some(allowedOrigin => {
    if (allowedOrigin.includes('*')) {
      const pattern = allowedOrigin.replace(/\*/g, '.*')
      const regex = new RegExp(`^${pattern}$`)
      return regex.test(origin)
    }
    return false
  })
}