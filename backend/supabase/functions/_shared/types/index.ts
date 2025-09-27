/**
 * Shared TypeScript types for Supabase Edge Functions
 * 
 * This file contains all shared type definitions used across
 * the backend services, ensuring consistency and maintainability.
 */

// =============================================================================
// User and Authentication Types
// =============================================================================

/**
 * User context for operations
 */
export interface UserContext {
  readonly type: 'authenticated' | 'anonymous'
  readonly userId?: string
  readonly sessionId?: string
  readonly userType?: 'admin' | 'user' // Admin users get premium access temporarily
}

/**
 * Authentication context
 */
export interface AuthContext {
  readonly user: any
  readonly session: any
  readonly isAuthenticated: boolean
}

// =============================================================================
// Study Guide Types
// =============================================================================

/**
 * Study guide content for caching
 */
export interface StudyGuideContent {
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
}

/**
 * Study guide input parameters
 */
export interface StudyGuideInput {
  readonly type: 'scripture' | 'topic' | 'question'
  readonly value: string
  readonly language: string
}

/**
 * Complete study guide response
 */
export interface StudyGuideResponse {
  readonly id: string
  readonly input: StudyGuideInput
  readonly content: StudyGuideContent
  readonly isSaved: boolean
  readonly createdAt: string
  readonly updatedAt: string
}

// =============================================================================
// API Response Types
// =============================================================================

/**
 * Standard API success response
 */
export interface ApiSuccessResponse<T = any> {
  readonly success: true
  readonly data: T
  readonly message?: string
}

/**
 * Standard API error response
 */
export interface ApiErrorResponse {
  readonly success: false
  readonly error: {
    readonly code: string
    readonly message: string
    readonly timestamp?: string
    readonly requestId?: string
  }
}

/**
 * API response with pagination
 */
export interface PaginatedResponse<T = any> {
  readonly success: true
  readonly data: T[]
  readonly pagination: {
    readonly total: number
    readonly limit: number
    readonly offset: number
    readonly hasMore: boolean
  }
}

// =============================================================================
// Service Types
// =============================================================================

/**
 * LLM generation parameters
 */
export interface LLMGenerationParams {
  readonly inputType: 'scripture' | 'topic' | 'question'
  readonly inputValue: string
  readonly language: string
}

/**
 * Rate limiting result
 */
export interface RateLimitResult {
  readonly allowed: boolean
  readonly remaining: number
  readonly resetTime: number
  readonly window: number
}

/**
 * Analytics event data
 */
export interface AnalyticsEvent {
  readonly eventType: string
  readonly userId?: string
  readonly sessionId?: string
  readonly metadata?: Record<string, any>
  readonly timestamp: string
  readonly ipAddress?: string
}

// =============================================================================
// Security Types
// =============================================================================

/**
 * Security validation result
 */
export interface SecurityValidationResult {
  readonly isValid: boolean
  readonly riskScore: number
  readonly eventType: string
  readonly message: string
}

/**
 * Request validation rules
 */
export interface ValidationRules {
  readonly [key: string]: {
    readonly required?: boolean
    readonly minLength?: number
    readonly maxLength?: number
    readonly allowedValues?: readonly string[]
    readonly pattern?: RegExp
  }
}

// =============================================================================
// Repository Types
// =============================================================================

/**
 * Database query options
 */
export interface QueryOptions {
  readonly limit?: number
  readonly offset?: number
  readonly orderBy?: string
  readonly orderDirection?: 'asc' | 'desc'
  readonly filters?: Record<string, any>
}

/**
 * Repository result with metadata
 */
export interface RepositoryResult<T = any> {
  readonly data: T[]
  readonly total: number
  readonly hasMore: boolean
}

// =============================================================================
// Utility Types
// =============================================================================

/**
 * Environment configuration
 */
export interface EnvironmentConfig {
  readonly supabaseUrl: string
  readonly supabaseAnonKey: string
  readonly supabaseServiceKey: string
  readonly openaiApiKey?: string
  readonly anthropicApiKey?: string
  readonly llmProvider?: 'openai' | 'anthropic'
}

/**
 * HTTP method types
 */
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH' | 'OPTIONS'

/**
 * Language codes
 */
export type LanguageCode = 'en' | 'hi' | 'ml'

/**
 * Difficulty levels
 */
export type DifficultyLevel = 'beginner' | 'intermediate' | 'advanced'

// =============================================================================
// Error Types
// =============================================================================

/**
 * Application error codes
 */
export type ErrorCode = 
  | 'VALIDATION_ERROR'
  | 'AUTHENTICATION_ERROR'
  | 'AUTHORIZATION_ERROR'
  | 'RATE_LIMIT_EXCEEDED'
  | 'RESOURCE_NOT_FOUND'
  | 'INTERNAL_SERVER_ERROR'
  | 'CONFIGURATION_ERROR'
  | 'SECURITY_VIOLATION'
  | 'LLM_SERVICE_ERROR'
  | 'DATABASE_ERROR'
  | 'NETWORK_ERROR'

/**
 * Error severity levels
 */
export type ErrorSeverity = 'low' | 'medium' | 'high' | 'critical'

// =============================================================================
// Export all types
// =============================================================================

export type {
  // Re-export common types for convenience
  UserContext as User,
  StudyGuideContent as Content,
  StudyGuideInput as Input,
  StudyGuideResponse as Response,
  ApiSuccessResponse as Success,
  ApiErrorResponse as Error,
  PaginatedResponse as Paginated,
  ValidationRules as Rules,
  QueryOptions as Options,
  RepositoryResult as Result,
}