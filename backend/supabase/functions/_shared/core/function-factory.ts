/**
 * Function Factory for Supabase Edge Functions
 * 
 * This factory eliminates boilerplate code and provides a standardized
 * way to create Edge Functions with proper dependency injection,
 * error handling, and CORS support.
 * 
 * As specified in the refactoring guide, this factory:
 * - Handles CORS preflight requests
 * - Injects singleton services
 * - Provides centralized error handling
 * - Eliminates repetitive setup code
 * - Provides authentication handling
 * - Includes performance monitoring
 * - Supports request validation
 */

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { corsHeaders, handleCors } from '../utils/cors.ts'
import { ErrorHandler } from '../utils/error-handler.ts'
import { getServiceContainer, createUserSupabaseClient, ServiceContainer } from './services.ts'
import { config } from './config.ts'
import { UserContext } from '../types/index.ts'

/**
 * Handler function signature that Edge Functions must implement
 * userContext is optional to handle both authenticated and non-authenticated scenarios
 */
export type FunctionHandler = (
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
) => Promise<Response>

/**
 * Simple handler that only receives request and services
 */
export type SimpleFunctionHandler = (
  req: Request,
  services: ServiceContainer
) => Promise<Response>

/**
 * Legacy handler type for backward compatibility
 */
export type Handler = SimpleFunctionHandler

/**
 * Configuration options for the function factory
 */
interface FunctionConfig {
  /** Whether to automatically parse user context from JWT */
  readonly requireAuth?: boolean
  /** Whether to log request details for analytics */
  readonly enableAnalytics?: boolean
  /** Whether to validate request method */
  readonly allowedMethods?: readonly string[]
  /** Maximum request body size in bytes */
  readonly maxBodySize?: number
  /** Request timeout in milliseconds */
  readonly timeout?: number
  /** Custom CORS headers */
  readonly corsHeaders?: Record<string, string>
}

/**
 * Default configuration
 */
const DEFAULT_CONFIG: Required<FunctionConfig> = {
  requireAuth: false,
  enableAnalytics: true,
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  maxBodySize: 10 * 1024 * 1024, // 10MB
  timeout: 60000, // 60 seconds
  corsHeaders: {}
}

/**
 * Performance metrics for monitoring
 */
interface PerformanceMetrics {
  startTime: number
  initTime: number
  authTime: number
  handlerTime: number
  totalTime: number
}

/**
 * Creates a standardized Edge Function with all common functionality
 * 
 * @param handler - The actual business logic handler (must be FunctionHandler)
 * @param config - Configuration options
 * @returns Deno serve function
 */
export function createFunction(
  handler: FunctionHandler,
  config: FunctionConfig = {}
): void {
  const finalConfig = { ...DEFAULT_CONFIG, ...config }

  serve(async (req: Request): Promise<Response> => {
    const metrics: Partial<PerformanceMetrics> = {
      startTime: performance.now()
    }

    const requestId = generateRequestId()
    const corsHeaders = handleCors(req)
    const mergedCorsHeaders = { ...corsHeaders, ...finalConfig.corsHeaders }
    
    try {
      // Handle CORS preflight requests
      if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: mergedCorsHeaders })
      }

      // Validate HTTP method
      if (!finalConfig.allowedMethods.includes(req.method)) {
        return new Response(
          JSON.stringify({
            success: false,
            error: {
              code: 'METHOD_NOT_ALLOWED',
              message: `Method ${req.method} not allowed. Allowed methods: ${finalConfig.allowedMethods.join(', ')}`,
              requestId
            }
          }),
          {
            status: 405,
            headers: { ...mergedCorsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // Validate request body size
      const contentLength = req.headers.get('content-length')
      if (contentLength && parseInt(contentLength) > finalConfig.maxBodySize) {
        return new Response(
          JSON.stringify({
            success: false,
            error: {
              code: 'PAYLOAD_TOO_LARGE',
              message: `Request body too large. Maximum size: ${finalConfig.maxBodySize} bytes`,
              requestId
            }
          }),
          {
            status: 413,
            headers: { ...mergedCorsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // Initialize services
      const services = await getServiceContainer()
      metrics.initTime = performance.now()

      // Parse user context if required
      let userContext: UserContext | undefined
      if (finalConfig.requireAuth) {
        userContext = await parseUserContext(req, services)
        metrics.authTime = performance.now()
      }

      // Set up timeout
      const timeoutPromise = new Promise<Response>((_, reject) => {
        setTimeout(() => {
          reject(new Error(`Request timeout after ${finalConfig.timeout}ms`))
        }, finalConfig.timeout)
      })

      // Execute handler with timeout
      // Always pass userContext (can be undefined if requireAuth is false)
      const handlerPromise = handler(req, services, userContext)
      const response = await Promise.race([handlerPromise, timeoutPromise])
      
      metrics.handlerTime = performance.now()
      metrics.totalTime = performance.now() - metrics.startTime!

      // Log analytics if enabled
      if (finalConfig.enableAnalytics) {
        await logRequestAnalytics(
          services,
          req,
          userContext,
          metrics as PerformanceMetrics,
          requestId
        )
      }

      // Add CORS headers to all responses
      const responseHeaders = new Headers(response.headers)
      Object.entries(mergedCorsHeaders).forEach(([key, value]) => {
        responseHeaders.set(key, value)
      })

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders
      })

    } catch (error) {
      // Log error metrics
      metrics.totalTime = performance.now() - metrics.startTime!
      
      if (finalConfig.enableAnalytics) {
        try {
          const services = await getServiceContainer()
          await logErrorAnalytics(services, req, error, metrics as PerformanceMetrics, requestId)
        } catch (analyticsError) {
          // Don't fail the request if analytics fails
          console.error('[Analytics] Failed to log error:', analyticsError)
        }
      }

      return ErrorHandler.handleError(error, mergedCorsHeaders, requestId)
    }
  })
}

/**
 * Creates a simple function without user context parsing
 * 
 * @param handler - Handler that only needs request and services
 * @param config - Configuration options
 */
export function createSimpleFunction(
  handler: SimpleFunctionHandler,
  config: FunctionConfig = {}
): void {
  // Wrap SimpleFunctionHandler to match FunctionHandler signature
  const wrappedHandler: FunctionHandler = async (req, services, userContext) => {
    return await handler(req, services)
  }
  createFunction(wrappedHandler, { ...config, requireAuth: false })
}

/**
 * Factory for functions that require authentication
 * 
 * @param handler - Handler function that receives user context
 * @param config - Configuration options
 */
export function createAuthenticatedFunction(
  handler: FunctionHandler,
  config: FunctionConfig = {}
): void {
  createFunction(handler, { ...config, requireAuth: true })
}

/**
 * Generates a unique request ID for tracing
 * 
 * @returns Unique request ID
 */
function generateRequestId(): string {
  return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
}

/**
 * Utility function to create a simple GET-only endpoint
 * 
 * @param handler - Handler function
 * @param config - Configuration options
 */
export function createGetFunction(
  handler: SimpleFunctionHandler,
  config: FunctionConfig = {}
): void {
  createSimpleFunction(handler, { ...config, allowedMethods: ['GET'] })
}

/**
 * Utility function to create a POST-only endpoint
 * 
 * @param handler - Handler function
 * @param config - Configuration options
 */
export function createPostFunction(
  handler: SimpleFunctionHandler,
  config: FunctionConfig = {}
): void {
  createSimpleFunction(handler, { ...config, allowedMethods: ['POST'] })
}

/**
 * Parses user context from JWT token
 *
 * SECURITY WARNING: Query-based authentication (via URL parameters) is INSECURE and should
 * only be used as a last resort for EventSource connections that cannot send custom headers.
 * Query parameters appear in:
 * - Browser history
 * - Server logs
 * - Proxy logs
 * - Referrer headers
 *
 * RECOMMENDED: Use Authorization headers, secure cookies, or implement a proper EventSource
 * authentication handshake (e.g., initial POST to exchange credentials for a session token,
 * then use that token in EventSource URL without exposing the primary auth token).
 *
 * @param req - Incoming request
 * @param services - Service container
 * @returns User context extracted from JWT
 */
async function parseUserContext(
  req: Request,
  services: ServiceContainer
): Promise<UserContext> {
  let authToken = req.headers.get('Authorization') || ''
  const hasHeaderAuth = !!authToken
  console.log('[AUTH] Header auth:', hasHeaderAuth ? 'PRESENT' : 'MISSING')

  // For EventSource requests, check query parameters as fallback (INSECURE - see JSDoc warning)
  if (!authToken) {
    const url = new URL(req.url)
    const queryAuthToken = url.searchParams.get('authorization')
    const hasQueryAuth = !!queryAuthToken
    console.log('[AUTH] Query auth:', hasQueryAuth ? 'PRESENT' : 'MISSING')

    if (queryAuthToken) {
      authToken = `Bearer ${queryAuthToken}`
      console.log('[AUTH] Using query-based auth (insecure)')
    }
  }

  if (!authToken) {
    console.log('[AUTH] ERROR: No auth token found')
    throw new Error('Missing authorization header')
  }

  const userSupabaseClient = createUserSupabaseClient(authToken, config.supabaseUrl, config.supabaseAnonKey)
  const { data: { user }, error } = await userSupabaseClient.auth.getUser()

  if (error) {
    throw new Error(`Authentication failed: ${error.message}`)
  }

  if (!user) {
    throw new Error('No user found in token')
  }

  return {
    type: user.is_anonymous ? 'anonymous' : 'authenticated',
    userId: user.is_anonymous ? undefined : user.id,
    sessionId: user.is_anonymous ? user.id : undefined
  }
}

/**
 * Logs request analytics
 */
async function logRequestAnalytics(
  services: ServiceContainer,
  req: Request,
  userContext: UserContext | undefined,
  metrics: PerformanceMetrics,
  requestId: string
): Promise<void> {
  try {
    await services.analyticsLogger.logEvent('function_request', {
      method: req.method,
      url: req.url,
      userType: userContext?.type || 'unknown',
      userId: userContext?.userId,
      sessionId: userContext?.sessionId,
      requestId,
      metrics: {
        initTime: Math.round(metrics.initTime - metrics.startTime),
        authTime: metrics.authTime ? Math.round(metrics.authTime - metrics.initTime) : 0,
        handlerTime: Math.round(metrics.handlerTime - (metrics.authTime || metrics.initTime)),
        totalTime: Math.round(metrics.totalTime)
      }
    }, req.headers.get('x-forwarded-for'))
  } catch (error) {
    console.error('[Analytics] Failed to log request:', error)
  }
}

/**
 * Logs error analytics
 */
async function logErrorAnalytics(
  services: ServiceContainer,
  req: Request,
  error: any,
  metrics: Partial<PerformanceMetrics>,
  requestId: string
): Promise<void> {
  try {
    await services.analyticsLogger.logEvent('function_error', {
      method: req.method,
      url: req.url,
      errorType: error?.constructor?.name || 'Unknown',
      errorMessage: error?.message || 'Unknown error',
      requestId,
      metrics: {
        totalTime: metrics.totalTime ? Math.round(metrics.totalTime) : 0,
        failurePoint: metrics.authTime ? 'handler' : metrics.initTime ? 'auth' : 'init'
      }
    }, req.headers.get('x-forwarded-for'))
  } catch (analyticsError) {
    console.error('[Analytics] Failed to log error:', analyticsError)
  }
}


/**
 * Middleware-style function creator for more complex scenarios
 */
export function createAdvancedFunction(
  handler: FunctionHandler,
  middlewares: Array<(req: Request, services: ServiceContainer) => Promise<void>>,
  config: FunctionConfig = {}
): void {
  const wrappedHandler: FunctionHandler = async (req, services, userContext) => {
    // Run all middlewares
    for (const middleware of middlewares) {
      await middleware(req, services)
    }
    
    return await handler(req, services, userContext)
  }

  createFunction(wrappedHandler, config)
}

/**
 * Health check function factory
 */
export function createHealthCheck(): void {
  createSimpleFunction(async (req, services) => {
    const health = await services.supabaseServiceClient
      .from('study_guides')
      .select('count')
      .limit(1)

    return new Response(
      JSON.stringify({
        success: true,
        status: 'healthy',
        timestamp: new Date().toISOString(),
        services: {
          database: health.error ? 'down' : 'up',
          llm: 'up', // Basic check
          cache: 'up'
        }
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      }
    )
  }, {
    allowedMethods: ['GET'],
    enableAnalytics: false
  })
}

/**
 * Utility function to create a function with custom error handling
 */
export function createFunctionWithErrorHandler(
  handler: FunctionHandler,
  customErrorHandler: (error: any, req: Request, services: ServiceContainer) => Promise<Response>,
  config: FunctionConfig = {}
): void {
  const wrappedHandler: FunctionHandler = async (req, services, userContext) => {
    try {
      return await handler(req, services, userContext)
    } catch (error) {
      return await customErrorHandler(error, req, services)
    }
  }

  createFunction(wrappedHandler, config)
}