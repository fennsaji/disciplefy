// ============================================================================
// Error Formatter Utility
// ============================================================================
// Provides consistent error message formatting across all edge functions
// Ensures predictable error logging and debugging

/**
 * Formats any error type into a consistent string message
 * 
 * @param error - The error to format (can be Error, string, object, or unknown)
 * @param prefix - Optional prefix to add to the error message
 * @returns Formatted error string
 * 
 * @example
 * try {
 *   await riskyOperation();
 * } catch (error) {
 *   console.error('Operation failed:', formatError(error));
 *   throw new AppError('INTERNAL_ERROR', formatError(error, 'Database'));
 * }
 */
export function formatError(error: unknown, prefix?: string): string {
  let message: string;

  // Handle Error objects
  if (error instanceof Error) {
    message = error.message;
  }
  // Handle string errors
  else if (typeof error === 'string') {
    message = error;
  }
  // Handle object errors (like API responses)
  else if (error && typeof error === 'object') {
    // Try to extract message from common error object structures
    const errorObj = error as any;
    
    if (errorObj.message) {
      message = String(errorObj.message);
    } else if (errorObj.error) {
      message = String(errorObj.error);
    } else {
      try {
        message = JSON.stringify(error);
      } catch {
        message = 'Unknown error (could not serialize)';
      }
    }
  }
  // Handle null/undefined
  else if (error == null) {
    message = 'Unknown error (null or undefined)';
  }
  // Fallback for other types
  else {
    message = String(error) || 'Unknown error';
  }

  // Add prefix if provided
  return prefix ? `${prefix}: ${message}` : message;
}

/**
 * Safely extracts error message from FCM API error responses
 * 
 * @param fcmError - FCM API error response
 * @returns Error message string
 */
export function formatFCMError(fcmError: any): string {
  if (!fcmError) {
    return 'Unknown FCM error';
  }

  // FCM errors typically have error.message structure
  if (fcmError.error?.message) {
    return fcmError.error.message;
  }

  // Fallback to regular error formatting
  return formatError(fcmError);
}

/**
 * Formats error with stack trace for debugging (development only)
 * 
 * @param error - The error to format
 * @returns Detailed error string with stack trace
 */
export function formatDetailedError(error: unknown): string {
  if (error instanceof Error && error.stack) {
    return `${error.message}\n\nStack trace:\n${error.stack}`;
  }

  return formatError(error);
}
