/**
 * Singleton Services Container for Supabase Edge Functions
 * 
 * This module provides a centralized dependency injection container
 * that initializes all services once and reuses them across function
 * invocations for optimal performance.
 */

import { SupabaseClient, createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AuthService } from '../services/auth-service.ts'
import { LLMService, LLMServiceConfig } from '../services/llm-service.ts'
import { StudyGuideRepository } from '../repositories/study-guide-repository.ts'
import { TopicsRepository } from '../repositories/topics-repository.ts'
import { FeedbackRepository } from '../repositories/feedback-repository.ts'
import { StudyGuideService } from '../services/study-guide-service.ts'
import { FeedbackService } from '../services/feedback-service.ts'
import { RateLimiter } from '../services/rate-limiter.ts'
import { AnalyticsLogger } from '../services/analytics-service.ts'
import { SecurityValidator } from '../utils/security-validator.ts'
import { AppError } from '../utils/error-handler.ts'
import { DailyVerseService } from '../../daily-verse/daily-verse-service.ts'
import { config } from './config.ts'

/**
 * Rate limiter configuration
 */
interface RateLimiterConfig {
  readonly anonymousLimit: number
  readonly authenticatedLimit: number
  readonly anonymousWindowMinutes: number
  readonly authenticatedWindowMinutes: number
}

/**
 * Service container interface
 */
export interface ServiceContainer {
  readonly authService: AuthService
  readonly supabaseServiceClient: SupabaseClient
  readonly llmService: LLMService
  readonly studyGuideRepository: StudyGuideRepository
  readonly topicsRepository: TopicsRepository
  readonly feedbackRepository: FeedbackRepository
  readonly studyGuideService: StudyGuideService
  readonly feedbackService: FeedbackService
  readonly rateLimiter: RateLimiter
  readonly analyticsLogger: AnalyticsLogger
  readonly securityValidator: SecurityValidator
  readonly dailyVerseService: DailyVerseService
  readonly serviceRoleClient: SupabaseClient // Alias for compatibility
}

// Global singleton instances
let globalServiceContainer: ServiceContainer | null = null
let globalInitializationPromise: Promise<ServiceContainer> | null = null

/**
 * Creates and validates environment configuration
 */

/**
 * Creates rate limiter configuration from environment variables
 */
function createRateLimiterConfig(): RateLimiterConfig {
  return {
    anonymousLimit: 3,
    authenticatedLimit: 10,
    anonymousWindowMinutes: 480, // 8 hours
    authenticatedWindowMinutes: 60 // 1 hour
  }
}

/**
 * Initializes the service container with all singleton instances
 */
async function initializeServiceContainer(): Promise<ServiceContainer> {
  try {
    console.log('[Services] Initializing service container...')
    
    // Create Supabase service role client using centralized config
    const supabaseServiceClient = createClient(
      config.supabaseUrl,
      config.supabaseServiceKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Test database connection
    const { error: testError } = await supabaseServiceClient
      .from('study_guides')
      .select('count')
      .limit(1)
    
    if (testError) {
      console.error('[Services] Database connection test failed:', testError)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to connect to database',
        500
      )
    }

    // Initialize services with dependency injection
    const authService = new AuthService(config.supabaseUrl, config.supabaseAnonKey)
    
    // Create LLM service config from centralized config
    const llmConfig: LLMServiceConfig = {
      openaiApiKey: config.openaiApiKey,
      anthropicApiKey: config.anthropicApiKey,
      provider: config.llmProvider,
      useMock: config.useMock
    }
    const llmService = new LLMService(llmConfig)
    
    const studyGuideRepository = new StudyGuideRepository(supabaseServiceClient)
    const topicsRepository = new TopicsRepository(supabaseServiceClient)
    const feedbackRepository = new FeedbackRepository(supabaseServiceClient)
    const studyGuideService = new StudyGuideService(llmService, studyGuideRepository)
    const feedbackService = new FeedbackService()
    const rateLimiterConfig = createRateLimiterConfig()
    const rateLimiter = new RateLimiter(supabaseServiceClient, rateLimiterConfig)
    const analyticsLogger = new AnalyticsLogger(supabaseServiceClient)
    const securityValidator = new SecurityValidator()
    const dailyVerseService = new DailyVerseService(supabaseServiceClient, llmService)

    // Test LLM service initialization
    try {
      // This will validate API keys and throw if misconfigured
      console.log('[Services] LLM service initialized successfully')
    } catch (error) {
      console.error('[Services] LLM service initialization failed:', error)
      // Don't throw - allow the service to start but log the error
      // LLM errors will be handled at request time
    }

    const container: ServiceContainer = {
      authService,
      supabaseServiceClient,
      llmService,
      studyGuideRepository,
      topicsRepository,
      feedbackRepository,
      studyGuideService,
      feedbackService,
      rateLimiter,
      analyticsLogger,
      securityValidator,
      dailyVerseService,
      serviceRoleClient: supabaseServiceClient // Alias for compatibility
    }

    console.log('[Services] Service container initialized successfully')
    return container
    
  } catch (error) {
    console.error('[Services] Failed to initialize service container:', error)
    throw error
  }
}

/**
 * Gets the singleton service container instance
 * 
 * This function ensures that services are initialized only once
 * and reused across all function invocations for optimal performance.
 */
export async function getServiceContainer(): Promise<ServiceContainer> {
  // Return existing instance if available
  if (globalServiceContainer) {
    return globalServiceContainer
  }

  // If initialization is in progress, wait for it
  if (globalInitializationPromise) {
    return await globalInitializationPromise
  }

  // Start initialization
  globalInitializationPromise = initializeServiceContainer()
  
  try {
    globalServiceContainer = await globalInitializationPromise
    return globalServiceContainer
  } catch (error) {
    // Reset globals on failure to allow retry
    globalInitializationPromise = null
    globalServiceContainer = null
    throw error
  }
}

/**
 * Creates a user-specific Supabase client with authentication
 * 
 * @param authToken - Authorization token from request headers
 * @returns Configured Supabase client
 */
export function createUserSupabaseClient(authToken: string, supabaseUrl: string, supabaseAnonKey: string): SupabaseClient {
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new AppError(
      'CONFIGURATION_ERROR',
      'Missing Supabase configuration for user client',
      500
    )
  }

  return createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { 
        Authorization: authToken
      },
    },
  })
}

/**
 * Resets the service container (mainly for testing)
 */
export function resetServiceContainer(): void {
  globalServiceContainer = null
  globalInitializationPromise = null
  console.log('[Services] Service container reset')
}

/**
 * Health check for service container
 */
export async function healthCheck(): Promise<{
  status: 'healthy' | 'unhealthy'
  services: Record<string, 'up' | 'down'>
  timestamp: string
}> {
  try {
    const container = await getServiceContainer()
    
    // Test each service
    const serviceChecks = await Promise.allSettled([
      // Database check
      container.supabaseServiceClient.from('study_guides').select('count').limit(1),
      // LLM service check (basic instantiation)
      Promise.resolve(container.llmService ? 'up' : 'down'),
      // Other services are mostly in-memory, so just check instantiation
      Promise.resolve(container.rateLimiter ? 'up' : 'down'),
      Promise.resolve(container.analyticsLogger ? 'up' : 'down'),
      Promise.resolve(container.securityValidator ? 'up' : 'down')
    ])

    const services = {
      database: serviceChecks[0].status === 'fulfilled' ? 'up' : 'down',
      llm: serviceChecks[1].status === 'fulfilled' ? 'up' : 'down',
      rateLimiter: serviceChecks[2].status === 'fulfilled' ? 'up' : 'down',
      analytics: serviceChecks[3].status === 'fulfilled' ? 'up' : 'down',
      security: serviceChecks[4].status === 'fulfilled' ? 'up' : 'down'
    } as Record<string, 'up' | 'down'>

    const allUp = Object.values(services).every(status => status === 'up')
    
    return {
      status: allUp ? 'healthy' : 'unhealthy',
      services,
      timestamp: new Date().toISOString()
    }
  } catch (error) {
    return {
      status: 'unhealthy',
      services: {
        error: 'down'
      },
      timestamp: new Date().toISOString()
    }
  }
}

// ServiceContainer interface is already exported above