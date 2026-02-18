/**
 * System Configuration Service
 *
 * Manages system-wide configuration including:
 * - Maintenance mode (global on/off switch)
 * - App version requirements (force update control)
 * - Dynamic trial periods (database-driven trial dates)
 *
 * Implements 5-minute TTL caching pattern (matches plan-config-db-service.ts)
 * to minimize database queries while keeping configuration fresh.
 *
 * @example
 * ```typescript
 * const config = await getSystemConfig()
 * if (config.maintenanceModeEnabled) {
 *   throw new Error('MAINTENANCE_MODE')
 * }
 * ```
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

// ============================================================================
// Types & Interfaces
// ============================================================================

export interface SystemConfig {
  maintenanceModeEnabled: boolean
  maintenanceModeMessage: string
  minAppVersion: {
    android: string
    ios: string
    web: string
  }
  latestAppVersion: string
  forceUpdateEnabled: boolean
  trialConfig: {
    standardTrialEndDate: Date
    premiumTrialDays: number
    premiumTrialStartDate: Date
    gracePeriodDays: number
  }
}

interface CacheEntry {
  data: SystemConfig
  timestamp: number
}

// ============================================================================
// Cache Configuration
// ============================================================================

const CACHE_TTL_MS = 5 * 60 * 1000 // 5 minutes (matches plan-config-db-service.ts)
let configCache: CacheEntry | null = null

// ============================================================================
// Supabase Client
// ============================================================================

function getSupabaseClient() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  })
}

// ============================================================================
// Cache Management
// ============================================================================

function isCacheValid(entry: CacheEntry | null): boolean {
  if (!entry) return false
  const age = Date.now() - entry.timestamp
  return age < CACHE_TTL_MS
}

function getCacheAge(entry: CacheEntry | null): number {
  if (!entry) return -1
  return Date.now() - entry.timestamp
}

// ============================================================================
// Database Fetch
// ============================================================================

async function fetchSystemConfigFromDB(): Promise<SystemConfig> {
  const supabase = getSupabaseClient()

  // Use the database function to get all active configs
  const { data, error } = await supabase.rpc('get_system_configs')

  if (error) {
    console.error('[SystemConfig] Error fetching config:', error)
    throw new Error(`Failed to fetch system configuration: ${error.message}`)
  }

  if (!data || data.length === 0) {
    console.warn('[SystemConfig] No active system configs found, using defaults')
  }

  // Transform database rows into config map
  const configMap = new Map<string, string>()
  data?.forEach((row: any) => {
    configMap.set(row.key, row.value)
  })

  // Parse and construct SystemConfig object
  const config: SystemConfig = {
    maintenanceModeEnabled: configMap.get('maintenance_mode_enabled') === 'true',
    maintenanceModeMessage: configMap.get('maintenance_mode_message') || 'We are currently performing system maintenance. Please check back shortly.',
    minAppVersion: {
      android: configMap.get('min_app_version_android') || '1.0.0',
      ios: configMap.get('min_app_version_ios') || '1.0.0',
      web: configMap.get('min_app_version_web') || '1.0.0',
    },
    latestAppVersion: configMap.get('latest_app_version') || '1.0.0',
    forceUpdateEnabled: configMap.get('force_update_enabled') === 'true',
    trialConfig: {
      standardTrialEndDate: new Date(
        configMap.get('standard_trial_end_date') || '2026-03-31T23:59:59+05:30'
      ),
      premiumTrialDays: parseInt(configMap.get('premium_trial_days') || '7', 10),
      premiumTrialStartDate: new Date(
        configMap.get('premium_trial_start_date') || '2026-04-01T00:00:00+05:30'
      ),
      gracePeriodDays: parseInt(configMap.get('grace_period_days') || '7', 10),
    },
  }

  return config
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Get complete system configuration
 *
 * Uses 5-minute in-memory cache to minimize database queries.
 * Configuration is automatically refreshed when cache expires.
 *
 * @param forceRefresh - Force fetch from database, bypassing cache
 * @returns System configuration object
 *
 * @example
 * ```typescript
 * const config = await getSystemConfig()
 * console.log('Maintenance mode:', config.maintenanceModeEnabled)
 * ```
 */
export async function getSystemConfig(forceRefresh = false): Promise<SystemConfig> {
  if (!forceRefresh && isCacheValid(configCache)) {
    const cacheAge = getCacheAge(configCache)
    console.log(`[SystemConfig] Cache hit (age: ${Math.floor(cacheAge / 1000)}s)`)
    return configCache!.data
  }

  const cacheStatus = configCache ? `expired (age: ${Math.floor(getCacheAge(configCache) / 1000)}s)` : 'empty'
  console.log(`[SystemConfig] Fetching from database (cache: ${cacheStatus})`)

  const config = await fetchSystemConfigFromDB()

  configCache = {
    data: config,
    timestamp: Date.now(),
  }

  console.log('[SystemConfig] Config cached successfully')

  return config
}

/**
 * Quick check if maintenance mode is currently enabled
 *
 * This is the most commonly used function for maintenance checks.
 * Uses the cached config to avoid database queries.
 *
 * @returns true if maintenance mode is active
 *
 * @example
 * ```typescript
 * if (await isMaintenanceModeEnabled()) {
 *   throw new Error('MAINTENANCE_MODE')
 * }
 * ```
 */
export async function isMaintenanceModeEnabled(): Promise<boolean> {
  const config = await getSystemConfig()
  return config.maintenanceModeEnabled
}

/**
 * Get trial configuration for subscription management
 *
 * @returns Trial configuration with dates and durations
 *
 * @example
 * ```typescript
 * const trialConfig = await getTrialConfig()
 * console.log('Premium trial days:', trialConfig.premiumTrialDays)
 * console.log('Standard trial ends:', trialConfig.standardTrialEndDate)
 * ```
 */
export async function getTrialConfig() {
  const config = await getSystemConfig()
  return config.trialConfig
}

/**
 * Clear the system config cache
 *
 * Forces next getSystemConfig() call to fetch fresh data from database.
 * Useful when config has been updated via admin panel.
 *
 * @example
 * ```typescript
 * // After updating config in admin UI
 * clearSystemConfigCache()
 * const freshConfig = await getSystemConfig()
 * ```
 */
export function clearSystemConfigCache(): void {
  const hadCache = configCache !== null
  configCache = null

  if (hadCache) {
    console.log('[SystemConfig] Cache cleared manually')
  }
}

/**
 * Get cache statistics for monitoring
 *
 * @returns Cache age in milliseconds, or -1 if no cache
 *
 * @internal Used for debugging and monitoring
 */
export function getCacheStats(): { age: number; valid: boolean } {
  return {
    age: getCacheAge(configCache),
    valid: isCacheValid(configCache),
  }
}
