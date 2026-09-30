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

import { getServiceRoleClient } from '../core/service-client.ts'

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
  return getServiceRoleClient()
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

/** One row of get_system_configs. */
export interface SystemConfigRow {
  key: string
  value: string
}

/** Raw config rows plus the time they were read. */
export interface SystemConfigRows {
  rows: SystemConfigRow[]
  fetchedAt: number
}

let rowsCache: SystemConfigRows | null = null
let rowsInFlight: Promise<SystemConfigRows> | null = null

/**
 * The raw rows of get_system_configs, cached for five minutes per worker.
 *
 * Several readers parse different keys out of the same RPC (this service, the
 * memory verse config). Sharing one cached read means a request that needs
 * both makes a single round trip, and concurrent callers share one in-flight
 * read instead of each starting their own. Throws when the RPC fails; a
 * failure is never cached.
 */
export async function getSystemConfigRows(forceRefresh = false): Promise<SystemConfigRows> {
  if (!forceRefresh && rowsCache && Date.now() - rowsCache.fetchedAt < CACHE_TTL_MS) {
    return rowsCache
  }
  if (!forceRefresh && rowsInFlight) return rowsInFlight

  const read = (async (): Promise<SystemConfigRows> => {
    const supabase = getSupabaseClient()

    // Use the database function to get all active configs
    const { data, error } = await supabase.rpc('get_system_configs')

    if (error) {
      console.error('[SystemConfig] Error fetching config:', error)
      throw new Error(`Failed to fetch system configuration: ${error.message}`)
    }

    const result: SystemConfigRows = {
      rows: (data ?? []) as SystemConfigRow[],
      fetchedAt: Date.now(),
    }
    rowsCache = result
    return result
  })()

  rowsInFlight = read
  try {
    return await read
  } finally {
    if (rowsInFlight === read) rowsInFlight = null
  }
}

async function fetchSystemConfigFromDB(forceRefresh = false): Promise<{ config: SystemConfig; fetchedAt: number }> {
  const { rows: data, fetchedAt } = await getSystemConfigRows(forceRefresh)

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
      standardTrialEndDate: (() => {
        const v = configMap.get('standard_trial_end_date')
        if (!v) throw new Error('[system-config] standard_trial_end_date missing from DB')
        return new Date(v)
      })(),
      premiumTrialDays: parseInt(configMap.get('premium_trial_days') || '7', 10),
      premiumTrialStartDate: (() => {
        const v = configMap.get('premium_trial_start_date')
        return v ? new Date(v) : new Date()  // Deprecated: premium trial is now on-demand
      })(),
      gracePeriodDays: parseInt(configMap.get('grace_period_days') || '7', 10),
    },
  }

  return { config, fetchedAt }
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

  const { config, fetchedAt } = await fetchSystemConfigFromDB(forceRefresh)

  // Age runs from when the rows were read, so sharing rows with another
  // reader never stretches staleness past one TTL.
  configCache = {
    data: config,
    timestamp: fetchedAt,
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
  rowsCache = null

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
