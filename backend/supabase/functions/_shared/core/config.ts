/**
 * Centralized Environment Configuration Module
 * 
 * This module is the single source of truth for all environment variables
 * and provides startup validation to ensure proper configuration.
 */

import { AppError } from '../utils/error-handler.ts'

/**
 * Complete application configuration interface
 * All these environment variables are actively used by Edge Functions
 */
export interface AppConfig {
  // Supabase configuration (required)
  readonly supabaseUrl: string
  readonly supabaseServiceKey: string
  readonly supabaseAnonKey: string
  
  // LLM provider configuration (optional - auto-mock if missing)
  readonly openaiApiKey?: string
  readonly anthropicApiKey?: string
  readonly llmProvider?: 'openai' | 'anthropic'
  
  // Development/testing flags
  readonly useMock: boolean
}

/**
 * Validates and returns the complete application configuration
 */
function getValidatedConfig(): AppConfig {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  const anthropicApiKey = Deno.env.get('ANTHROPIC_API_KEY')
  const useMockEnv = Deno.env.get('USE_MOCK')
  
  // Auto-enable mock mode if no LLM keys are provided
  const hasLLMKeys = !!(openaiApiKey || anthropicApiKey)
  const useMock = useMockEnv === 'true' || !hasLLMKeys

  const config: Partial<AppConfig> = {
    supabaseUrl: Deno.env.get('SUPABASE_URL'),
    supabaseServiceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
    supabaseAnonKey: Deno.env.get('SUPABASE_ANON_KEY'),
    openaiApiKey,
    anthropicApiKey,
    llmProvider: Deno.env.get('LLM_PROVIDER') as 'openai' | 'anthropic' | undefined,
    useMock
  }

  // Validate required variables
  const requiredVars: (keyof AppConfig)[] = ['supabaseUrl', 'supabaseServiceKey', 'supabaseAnonKey']
  const missingVars = requiredVars.filter(varName => !config[varName])

  if (missingVars.length > 0) {
    throw new AppError(
      'CONFIGURATION_ERROR',
      `Missing required environment variables: ${missingVars.join(', ')}`,
      500
    )
  }

  // Provide mock keys if in mock mode but no real keys available
  if (config.useMock && !hasLLMKeys) {
    (config as any).openaiApiKey = 'mock-openai-key'
    ;(config as any).anthropicApiKey = 'mock-anthropic-key'
    ;(config as any).llmProvider = 'openai'
  }

  // Log configuration status (for debugging)
  console.log(`[CONFIG] Mock mode: ${config.useMock}, LLM Provider: ${config.llmProvider}`)

  return config as AppConfig
}

/**
 * Export a single, validated config object for the entire application
 */
export const config = getValidatedConfig()