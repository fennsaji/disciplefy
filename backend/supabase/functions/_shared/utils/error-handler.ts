/**
 * Application-specific error class for structured error handling.
 * 
 * Provides consistent error structure across all Edge Functions
 * with proper error codes and HTTP status codes.
 */
export class AppError extends Error {
  
  /**
   * Creates a new application error.
   * 
   * @param code - Application-specific error code
   * @param message - Human-readable error message
   * @param statusCode - HTTP status code (defaults to 400)
   */
  constructor(
    public readonly code: string,
    public override readonly message: string,
    public readonly statusCode: number = 400
  ) {
    super(message)
    this.name = 'AppError'
    
    // Ensure the prototype chain is properly maintained
    Object.setPrototypeOf(this, AppError.prototype)
  }
}

/**
 * Structured error response format.
 */
interface ErrorResponse {
  readonly success: false
  readonly error: {
    readonly code: string
    readonly message: string
    readonly timestamp?: string
    readonly requestId?: string
  }
}

/**
 * Centralized error handler for Edge Functions.
 * 
 * Provides consistent error handling patterns across all functions
 * with proper logging, status codes, and response formatting.
 */
export class ErrorHandler {
  
  /**
   * Handles and formats errors for HTTP responses.
   * 
   * This method ensures that:
   * - Sensitive information is not exposed to clients
   * - Errors are properly logged for debugging
   * - Response format is consistent across all functions
   * - HTTP status codes are appropriate
   * 
   * @param error - Error object to handle
   * @param corsHeaders - CORS headers to include in response
   * @param requestId - Optional request ID for tracing
   * @returns Formatted HTTP error response
   */
  static handleError(
    error: any, 
    corsHeaders: Record<string, string>,
    requestId?: string
  ): Response {
    
    // Log the error for debugging (sanitized)
    this.logError(error, requestId)
    
    // Handle known application errors
    if (error instanceof AppError) {
      return this.createErrorResponse(
        error.code,
        error.message,
        error.statusCode,
        corsHeaders,
        requestId
      )
    }

    // Handle specific error patterns
    const errorPattern = this.categorizeError(error)
    
    return this.createErrorResponse(
      errorPattern.code,
      errorPattern.message,
      errorPattern.statusCode,
      corsHeaders,
      requestId
    )
  }

  /**
   * Creates a standardized error response.
   * 
   * @param code - Error code
   * @param message - Error message
   * @param statusCode - HTTP status code
   * @param corsHeaders - CORS headers
   * @param requestId - Optional request ID
   * @returns HTTP response with error
   */
  private static createErrorResponse(
    code: string,
    message: string,
    statusCode: number,
    corsHeaders: Record<string, string>,
    requestId?: string
  ): Response {
    
    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code,
        message,
        timestamp: new Date().toISOString(),
        ...(requestId && { requestId })
      }
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        status: statusCode,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        }
      }
    )
  }

  /**
   * Categorizes unknown errors into standard error patterns.
   * 
   * @param error - Error object to categorize
   * @returns Error pattern with code, message, and status
   */
  private static categorizeError(error: any): {
    code: string
    message: string
    statusCode: number
  } {
    const errorMessage = error?.message?.toLowerCase() || ''

    // Rate limiting errors - very specific
    if (errorMessage.includes('rate limit') || errorMessage.includes('too many requests')) {
      return {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Rate limit exceeded. Please try again later.',
        statusCode: 429
      }
    }

    // Database errors - specific service errors first
    if (errorMessage.includes('database') || errorMessage.includes('postgres') || errorMessage.includes('constraint') || errorMessage.includes('relation')) {
      return {
        code: 'DATABASE_ERROR',
        message: 'Database error occurred. Please try again later.',
        statusCode: 503
      }
    }

    // LLM service errors - specific service errors
    if (errorMessage.includes('openai') || errorMessage.includes('anthropic') || errorMessage.includes('llm')) {
      return {
        code: 'LLM_SERVICE_ERROR',
        message: 'AI service temporarily unavailable. Please try again.',
        statusCode: 503
      }
    }

    // Configuration errors - specific system errors
    if (errorMessage.includes('config') || errorMessage.includes('environment') || errorMessage.includes('missing required')) {
      return {
        code: 'CONFIGURATION_ERROR',
        message: 'Service configuration error.',
        statusCode: 500
      }
    }

    // Network/timeout errors - specific connection errors
    if (errorMessage.includes('timeout') || errorMessage.includes('network') || errorMessage.includes('connection')) {
      return {
        code: 'NETWORK_ERROR',
        message: 'Network error occurred. Please try again.',
        statusCode: 503
      }
    }

    // Authentication errors - specific auth patterns
    if (errorMessage.includes('auth') || errorMessage.includes('unauthorized') || errorMessage.includes('jwt') || errorMessage.includes('token')) {
      return {
        code: 'AUTHENTICATION_ERROR',
        message: 'Authentication required or invalid credentials.',
        statusCode: 401
      }
    }

    // Permission errors - specific authorization patterns
    if (errorMessage.includes('permission') || errorMessage.includes('forbidden') || errorMessage.includes('access denied')) {
      return {
        code: 'PERMISSION_DENIED',
        message: 'Insufficient permissions to perform this action.',
        statusCode: 403
      }
    }

    // Validation errors - more generic patterns that could overlap
    if (errorMessage.includes('validation') || errorMessage.includes('invalid') || errorMessage.includes('required')) {
      return {
        code: 'VALIDATION_ERROR',
        message: error?.message || 'Invalid input data provided.',
        statusCode: 400
      }
    }

    // Default server error
    return {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred. Please try again later.',
      statusCode: 500
    }
  }

  /**
   * Logs error information for debugging and monitoring.
   * 
   * Ensures no sensitive information is logged while providing
   * enough context for effective debugging.
   * 
   * @param error - Error object to log
   * @param requestId - Optional request ID for correlation
   */
  private static logError(error: any, requestId?: string): void {
    const logContext = {
      timestamp: new Date().toISOString(),
      requestId,
      errorType: error?.constructor?.name || 'Unknown',
      errorCode: error?.code,
      statusCode: error?.statusCode,
      // Only log the error message, not the full error object to avoid sensitive data
      message: error?.message ? String(error.message).substring(0, 500) : 'No message',
    }

    console.error('Edge Function Error:', JSON.stringify(logContext))
    
    // If it's an unexpected error (not AppError), log the stack trace
    if (!(error instanceof AppError) && error?.stack) {
      console.error('Stack trace:', error.stack.substring(0, 1000))
    }
  }

  /**
   * Creates a validation error for invalid input.
   * 
   * @param message - Validation error message
   * @param details - Optional validation details
   * @returns AppError instance for validation failure
   */
  static createValidationError(message: string, details?: any): AppError {
    const errorMessage = details ? 
      `${message}: ${JSON.stringify(details)}` : 
      message

    return new AppError('VALIDATION_ERROR', errorMessage, 400)
  }

  /**
   * Creates a rate limit error.
   * 
   * @param resetTime - Time until rate limit resets (in minutes)
   * @returns AppError instance for rate limiting
   */
  static createRateLimitError(resetTime?: number): AppError {
    const message = resetTime ? 
      `Rate limit exceeded. Try again in ${resetTime} minutes.` :
      'Rate limit exceeded. Please try again later.'

    return new AppError('RATE_LIMIT_EXCEEDED', message, 429)
  }

  /**
   * Creates an authentication error.
   * 
   * @param message - Optional custom message
   * @returns AppError instance for authentication failure
   */
  static createAuthenticationError(message = 'Authentication required'): AppError {
    return new AppError('AUTHENTICATION_ERROR', message, 401)
  }

  /**
   * Creates a permission denied error.
   * 
   * @param resource - Optional resource that was accessed
   * @returns AppError instance for permission denial
   */
  static createPermissionError(resource?: string): AppError {
    const message = resource ? 
      `Insufficient permissions to access ${resource}` :
      'Insufficient permissions to perform this action'

    return new AppError('PERMISSION_DENIED', message, 403)
  }

  /**
   * Creates a configuration error for missing environment variables.
   * 
   * @param missingVars - Array of missing variable names
   * @returns AppError instance for configuration issues
   */
  static createConfigurationError(missingVars: string[]): AppError {
    return new AppError(
      'CONFIGURATION_ERROR',
      `Missing required configuration: ${missingVars.join(', ')}`,
      500
    )
  }
}