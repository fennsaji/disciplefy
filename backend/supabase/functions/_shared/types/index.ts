/**
 * Shared TypeScript types for Supabase Edge Functions
 *
 * This file contains all shared type definitions used across
 * the backend services, ensuring consistency and maintainability.
 */

import type { User, Session } from 'https://esm.sh/@supabase/supabase-js@2'

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
  readonly user: User | null
  readonly session: Session | null
  readonly isAuthenticated: boolean
}

// =============================================================================
// Study Guide Types
// =============================================================================

/**
 * Study guide content for caching.
 * All 15 fields are required to ensure complete study guide generation.
 */
export interface StudyGuideContent {
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly passage?: string | null  // LLM-generated Scripture passage (3-8 verses with full text) for meditation in Standard mode
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
  readonly interpretationInsights: readonly string[]  // 2-5 theological insights for Reflect Mode multi-select
  readonly summaryInsights: readonly string[]  // 2-5 resonance themes for Summary card (Reflect Mode)
  readonly reflectionAnswers: readonly string[]  // 2-5 actionable life application responses for Reflection card (Reflect Mode)
  readonly contextQuestion: string  // Yes/no question from historical context for Reflect Mode
  readonly summaryQuestion: string  // Engaging question about the summary (8-12 words)
  readonly relatedVersesQuestion: string  // Question prompting verse selection/memorization (8-12 words)
  readonly reflectionQuestion: string  // Question connecting study to daily life (8-12 words)
  readonly prayerQuestion: string  // Question inviting personal prayer response (6-10 words)
}

/**
 * Valid study modes for study guide generation
 */
export type StudyMode = 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon'

/**
 * Study guide input parameters
 */
export interface StudyGuideInput {
  readonly type: 'scripture' | 'topic' | 'question'
  readonly value: string
  readonly language: string
  readonly study_mode: StudyMode
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
  readonly creatorUserId?: string | null
  readonly creatorSessionId?: string | null
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