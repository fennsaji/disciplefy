/**
 * Singleton Services Container for Supabase Edge Functions
 * 
 * This module provides a centralized dependency injection container
 * that initializes all services once and reuses them across function
 * invocations for optimal performance.
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AuthService } from '../services/auth-service.ts'
import { RateLimiter } from '../services/rate-limiter.ts'
import { TokenService } from '../services/token-service.ts'
import { AnalyticsLogger } from '../services/analytics-service.ts'
import { VoiceQuotaService } from '../services/voice-quota-service.ts'
import { UsageLoggingService } from '../services/usage-logging-service.ts'
import { CostTrackingService } from '../services/cost-tracking-service.ts'
import { RateLimitService } from '../services/rate-limit-service.ts'
import { MemoryVerseConfigService } from '../services/memory-verse-config-service.ts'
import { AppError } from '../utils/error-handler.ts'
import { getServiceRoleClient } from './service-client.ts'
import { config } from './config.ts'
// Heavy services are type-only here and loaded with dynamic import() on first
// use, so functions that never touch them don't load or evaluate their modules
// (LLM clients, prompt builders, voice streaming, repositories).
import type { LLMService, LLMServiceConfig } from '../services/llm-service.ts'
import type { StudyGuideRepository } from '../repositories/study-guide-repository.ts'
import type { TopicsRepository } from '../repositories/topics-repository.ts'
import type { FeedbackRepository } from '../repositories/feedback-repository.ts'
import type { VoiceConversationRepository } from '../repositories/voice-conversation-repository.ts'
import type { StudyGuideService } from '../services/study-guide-service.ts'
import type { FeedbackService } from '../services/feedback-service.ts'
import type { PersonalNotesService } from '../services/personal-notes-service.ts'
import type { VoiceStreamingService } from '../services/voice-streaming-service.ts'
import type { SecurityValidator } from '../utils/security-validator.ts'

/**
 * Service container.
 *
 * Cheap services are sync properties constructed on first access.
 * Heavy services are async getters that load their module on first call and
 * return the same instance afterwards.
 */
export interface ServiceContainer {
  readonly authService: AuthService
  readonly supabaseServiceClient: SupabaseClient
  readonly rateLimiter: RateLimiter
  readonly tokenService: TokenService
  readonly analyticsLogger: AnalyticsLogger
  readonly voiceQuotaService: VoiceQuotaService
  readonly usageLoggingService: UsageLoggingService
  readonly costTrackingService: CostTrackingService
  readonly rateLimitService: RateLimitService
  readonly memoryVerseConfigService: MemoryVerseConfigService
  readonly serviceRoleClient: SupabaseClient // Alias for compatibility
  getLlmService(): Promise<LLMService>
  getStudyGuideRepository(): Promise<StudyGuideRepository>
  getTopicsRepository(): Promise<TopicsRepository>
  getFeedbackRepository(): Promise<FeedbackRepository>
  getVoiceConversationRepository(): Promise<VoiceConversationRepository>
  getStudyGuideService(): Promise<StudyGuideService>
  getFeedbackService(): Promise<FeedbackService>
  getPersonalNotesService(): Promise<PersonalNotesService>
  getSecurityValidator(): Promise<SecurityValidator>
  getVoiceStreamingService(): Promise<VoiceStreamingService>
}

// Global singleton instance
let globalServiceContainer: ServiceContainer | null = null

/** Memoizes a sync factory: runs once, on first call. */
function lazy<T>(factory: () => T): () => T {
  let value: T | undefined
  let done = false
  return () => {
    if (!done) {
      value = factory()
      done = true
    }
    return value as T
  }
}

/** Memoizes an async factory; a failed load is retried on the next call. */
function lazyAsync<T>(factory: () => Promise<T>): () => Promise<T> {
  let promise: Promise<T> | null = null
  return () => {
    if (!promise) {
      promise = factory().catch((error) => {
        promise = null
        throw error
      })
    }
    return promise
  }
}

function buildServiceContainer(): ServiceContainer {
  const supabaseServiceClient = getServiceRoleClient(config.supabaseUrl, config.supabaseServiceKey)

  const authService = lazy(() => new AuthService(config.supabaseUrl, config.supabaseAnonKey, supabaseServiceClient))
  const rateLimiter = lazy(() => new RateLimiter(supabaseServiceClient, {
    anonymousLimit: 3,
    authenticatedLimit: 10,
    anonymousWindowMinutes: 480, // 8 hours
    authenticatedWindowMinutes: 60 // 1 hour
  }))
  const tokenService = lazy(() => new TokenService(supabaseServiceClient))
  const analyticsLogger = lazy(() => new AnalyticsLogger(supabaseServiceClient))
  const voiceQuotaService = lazy(() => new VoiceQuotaService(supabaseServiceClient))
  const usageLoggingService = lazy(() => new UsageLoggingService(config.supabaseUrl, config.supabaseServiceKey))
  const costTrackingService = lazy(() => new CostTrackingService())
  const rateLimitService = lazy(() => new RateLimitService(config.supabaseUrl, config.supabaseServiceKey))
  const memoryVerseConfigService = lazy(() => new MemoryVerseConfigService(supabaseServiceClient))

  const getLlmService = lazyAsync(async () => {
    const { LLMService } = await import('../services/llm-service.ts')
    const llmConfig: LLMServiceConfig = {
      openaiApiKey: config.openaiApiKey,
      anthropicApiKey: config.anthropicApiKey,
      provider: config.llmProvider,
      useMock: config.useMock,
      supabaseClient: supabaseServiceClient // For security event logging
    }
    return new LLMService(llmConfig)
  })
  const getStudyGuideRepository = lazyAsync(async () => {
    const { StudyGuideRepository } = await import('../repositories/study-guide-repository.ts')
    return new StudyGuideRepository(supabaseServiceClient)
  })
  const getTopicsRepository = lazyAsync(async () => {
    const { TopicsRepository } = await import('../repositories/topics-repository.ts')
    return new TopicsRepository(supabaseServiceClient)
  })
  const getFeedbackRepository = lazyAsync(async () => {
    const { FeedbackRepository } = await import('../repositories/feedback-repository.ts')
    return new FeedbackRepository(supabaseServiceClient)
  })
  const getVoiceConversationRepository = lazyAsync(async () => {
    const { VoiceConversationRepository } = await import('../repositories/voice-conversation-repository.ts')
    return new VoiceConversationRepository(supabaseServiceClient)
  })
  const getStudyGuideService = lazyAsync(async () => {
    const [{ StudyGuideService }, llmService, repository] = await Promise.all([
      import('../services/study-guide-service.ts'),
      getLlmService(),
      getStudyGuideRepository()
    ])
    return new StudyGuideService(llmService, repository)
  })
  const getFeedbackService = lazyAsync(async () => {
    const { FeedbackService } = await import('../services/feedback-service.ts')
    return new FeedbackService()
  })
  const getPersonalNotesService = lazyAsync(async () => {
    const [{ PersonalNotesService }, repository] = await Promise.all([
      import('../services/personal-notes-service.ts'),
      getStudyGuideRepository()
    ])
    return new PersonalNotesService(repository)
  })
  const getSecurityValidator = lazyAsync(async () => {
    const { SecurityValidator } = await import('../utils/security-validator.ts')
    return new SecurityValidator()
  })
  const getVoiceStreamingService = lazyAsync(async () => {
    const { VoiceStreamingService } = await import('../services/voice-streaming-service.ts')
    return new VoiceStreamingService({
      openaiApiKey: config.useMock ? '' : (config.openaiApiKey || ''),
      anthropicApiKey: config.useMock ? undefined : config.anthropicApiKey,
      useMock: config.useMock
    })
  })

  return {
    supabaseServiceClient,
    serviceRoleClient: supabaseServiceClient,
    get authService() { return authService() },
    get rateLimiter() { return rateLimiter() },
    get tokenService() { return tokenService() },
    get analyticsLogger() { return analyticsLogger() },
    get voiceQuotaService() { return voiceQuotaService() },
    get usageLoggingService() { return usageLoggingService() },
    get costTrackingService() { return costTrackingService() },
    get rateLimitService() { return rateLimitService() },
    get memoryVerseConfigService() { return memoryVerseConfigService() },
    getLlmService,
    getStudyGuideRepository,
    getTopicsRepository,
    getFeedbackRepository,
    getVoiceConversationRepository,
    getStudyGuideService,
    getFeedbackService,
    getPersonalNotesService,
    getSecurityValidator,
    getVoiceStreamingService
  }
}

/**
 * Gets the singleton service container instance.
 *
 * Building the container only creates the shared client; every service is
 * constructed on first use and reused for the worker's lifetime.
 */
export function getServiceContainer(): Promise<ServiceContainer> {
  if (!globalServiceContainer) {
    globalServiceContainer = buildServiceContainer()
  }
  return Promise.resolve(globalServiceContainer)
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
      container.getLlmService().then(() => 'up'),
      // Other services are mostly in-memory, so just check instantiation
      Promise.resolve(container.rateLimiter ? 'up' : 'down'),
      Promise.resolve(container.analyticsLogger ? 'up' : 'down'),
      container.getSecurityValidator().then(() => 'up')
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