/**
 * Centralized Environment Configuration Module
 * 
 * This module is the single source of truth for all environment variables
 * and provides startup validation to ensure proper configuration.
 */

import { AppError } from '../utils/error-handler.ts'

/**
 * Complete application configuration interface
 */
export interface AppConfig {
  readonly supabaseUrl: string
  readonly supabaseServiceKey: string
  readonly supabaseAnonKey: string
  readonly openaiApiKey?: string
  readonly anthropicApiKey?: string
  readonly llmProvider?: 'openai' | 'anthropic'
  readonly useMock: boolean
}

/**
 * Validates and returns the complete application configuration
 */
function getValidatedConfig(): AppConfig {
  const config: Partial<AppConfig> = {
    supabaseUrl: Deno.env.get('SUPABASE_URL'),
    supabaseServiceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
    supabaseAnonKey: Deno.env.get('SUPABASE_ANON_KEY'),
    openaiApiKey: Deno.env.get('OPENAI_API_KEY'),
    anthropicApiKey: Deno.env.get('ANTHROPIC_API_KEY'),
    llmProvider: Deno.env.get('LLM_PROVIDER') as 'openai' | 'anthropic' | undefined,
    useMock: Deno.env.get('USE_MOCK') === 'true'
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

  // Validate LLM configuration if not using mock
  if (!config.useMock && !config.openaiApiKey && !config.anthropicApiKey) {
    throw new AppError(
      'CONFIGURATION_ERROR',
      'Either OPENAI_API_KEY or ANTHROPIC_API_KEY must be provided when USE_MOCK is not true',
      500
    )
  }

  return config as AppConfig
}

/**
 * Export a single, validated config object for the entire application
 */
export const config = getValidatedConfig()