import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Analytics event data structure.
 */
interface AnalyticsEventData {
  [key: string]: string | number | boolean | null | undefined
}

/**
 * Logger for analytics events with structured data.
 * 
 * Provides a clean abstraction for logging user interactions and system events
 * while ensuring no sensitive data is logged inappropriately.
 */
export class AnalyticsLogger {
  
  /**
   * Creates a new analytics logger instance.
   * 
   * @param supabaseClient - Configured Supabase client
   */
  constructor(private readonly supabaseClient: SupabaseClient) {}

  /**
   * Logs an analytics event to the database.
   * 
   * This method ensures that sensitive data is filtered out and only
   * relevant metadata is stored for analytics purposes.
   * 
   * @param eventType - Type of event (e.g., 'study_generated', 'topics_accessed')
   * @param eventData - Structured event data (no sensitive information)
   * @param ipAddress - Client IP address (optional)
   * @returns Promise that resolves when event is logged
   */
  async logEvent(
    eventType: string,
    eventData: AnalyticsEventData,
    ipAddress?: string | null
  ): Promise<void> {
    try {
      // Sanitize event data to ensure no sensitive information is logged
      const sanitizedData = this.sanitizeEventData(eventData)

      // Insert analytics event
      const { error } = await this.supabaseClient
        .from('analytics_events')
        .insert({
          event_type: eventType,
          event_data: sanitizedData,
          ip_address: ipAddress,
          created_at: new Date().toISOString()
        })

      if (error) {
        console.error('Failed to log analytics event:', error)
        // Don't throw - analytics failures shouldn't break the main flow
      }
    } catch (error) {
      console.error('Analytics logging error:', error)
      // Don't throw - analytics failures shouldn't break the main flow
    }
  }

  /**
   * Logs a user interaction event.
   * 
   * @param userId - User ID (can be null for anonymous users)
   * @param action - Action performed by user
   * @param metadata - Additional metadata about the interaction
   * @param ipAddress - Client IP address
   */
  async logUserInteraction(
    userId: string | null,
    action: string,
    metadata: AnalyticsEventData = {},
    ipAddress?: string | null
  ): Promise<void> {
    await this.logEvent('user_interaction', {
      user_id: userId,
      action,
      ...metadata
    }, ipAddress)
  }

  /**
   * Logs a system performance event.
   * 
   * @param operation - Operation that was performed
   * @param duration - Duration in milliseconds
   * @param success - Whether the operation succeeded
   * @param metadata - Additional performance metadata
   */
  async logPerformanceEvent(
    operation: string,
    duration: number,
    success: boolean,
    metadata: AnalyticsEventData = {}
  ): Promise<void> {
    await this.logEvent('performance', {
      operation,
      duration_ms: duration,
      success,
      ...metadata
    })
  }

  /**
   * Logs an error event for debugging and monitoring.
   * 
   * @param errorType - Type of error that occurred
   * @param errorCode - Application-specific error code
   * @param metadata - Additional error context (no sensitive data)
   */
  async logErrorEvent(
    errorType: string,
    errorCode: string,
    metadata: AnalyticsEventData = {}
  ): Promise<void> {
    await this.logEvent('error', {
      error_type: errorType,
      error_code: errorCode,
      ...metadata
    })
  }

  /**
   * Logs API usage statistics.
   * 
   * @param endpoint - API endpoint that was called
   * @param method - HTTP method
   * @param statusCode - Response status code
   * @param responseTime - Response time in milliseconds
   * @param userType - Type of user ('anonymous' | 'authenticated')
   */
  async logApiUsage(
    endpoint: string,
    method: string,
    statusCode: number,
    responseTime: number,
    userType: 'anonymous' | 'authenticated'
  ): Promise<void> {
    await this.logEvent('api_usage', {
      endpoint,
      method,
      status_code: statusCode,
      response_time_ms: responseTime,
      user_type: userType
    })
  }

  /**
   * Sanitizes event data to remove sensitive information.
   * 
   * This method filters out potentially sensitive keys and truncates
   * long values to prevent excessive data storage.
   * 
   * @param data - Raw event data
   * @returns Sanitized event data safe for logging
   */
  private sanitizeEventData(data: AnalyticsEventData): AnalyticsEventData {
    const sensitiveKeys = ['password', 'token', 'secret', 'key', 'email', 'phone']
    const maxValueLength = 500

    const sanitized: AnalyticsEventData = {}

    for (const [key, value] of Object.entries(data)) {
      // Skip sensitive keys
      if (sensitiveKeys.some(sensitive => key.toLowerCase().includes(sensitive))) {
        continue
      }

      // Truncate long string values
      if (typeof value === 'string' && value.length > maxValueLength) {
        sanitized[key] = value.substring(0, maxValueLength) + '...'
        continue
      }

      // Keep safe values
      if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
        sanitized[key] = value
      } else if (value === null || value === undefined) {
        sanitized[key] = value
      } else {
        // For complex objects, convert to string and truncate
        const stringValue = JSON.stringify(value)
        if (stringValue.length > maxValueLength) {
          sanitized[key] = stringValue.substring(0, maxValueLength) + '...'
        } else {
          sanitized[key] = stringValue
        }
      }
    }

    return sanitized
  }
}