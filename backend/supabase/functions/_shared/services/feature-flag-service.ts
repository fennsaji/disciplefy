/**
 * Feature Flag Service
 *
 * Manages dynamic feature toggles with plan-based access control.
 * Allows enabling/disabling features without deployment.
 *
 * Features can be:
 * - Enabled/disabled globally
 * - Restricted to specific subscription plans
 * - Rolled out to a percentage of users (future enhancement)
 *
 * Implements 5-minute TTL caching pattern to minimize database queries.
 *
 * @example
 * ```typescript
 * const flags = await getFeatureFlags()
 * const voiceEnabled = await isFeatureEnabledForPlan('voice_buddy', 'premium')
 * ```
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

// ============================================================================
// Types & Interfaces
// ============================================================================

export interface FeatureFlag {
  featureKey: string
  featureName: string
  isEnabled: boolean
  enabledForPlans: string[] // ['free', 'standard', 'plus', 'premium']
  rolloutPercentage: number // 0-100 (for future A/B testing)
  displayMode: 'hide' | 'lock' // How feature appears when user lacks access
  metadata: Record<string, any>
}

interface CacheEntry {
  data: FeatureFlag[]
  timestamp: number
}

// ============================================================================
// Cache Configuration
// ============================================================================

const CACHE_TTL_MS = 5 * 60 * 1000 // 5 minutes
let flagsCache: CacheEntry | null = null

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

async function fetchFeatureFlagsFromDB(): Promise<FeatureFlag[]> {
  const supabase = getSupabaseClient()

  // Fetch all enabled feature flags
  const { data, error } = await supabase
    .from('feature_flags')
    .select('*')
    .eq('is_enabled', true)
    .order('feature_key')

  if (error) {
    console.error('[FeatureFlags] Error fetching flags:', error)
    // Return empty array on error (fail-safe: no features enabled)
    return []
  }

  if (!data || data.length === 0) {
    console.warn('[FeatureFlags] No enabled feature flags found')
    return []
  }

  // Transform database rows to FeatureFlag objects
  const flags: FeatureFlag[] = data.map(row => ({
    featureKey: row.feature_key,
    featureName: row.feature_name,
    isEnabled: row.is_enabled,
    enabledForPlans: row.enabled_for_plans || [],
    rolloutPercentage: row.rollout_percentage || 100,
    displayMode: (row.display_mode || 'hide') as 'hide' | 'lock', // Default to 'hide' for backward compatibility
    metadata: row.metadata || {},
  }))

  return flags
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Get all enabled feature flags
 *
 * Uses 5-minute in-memory cache to minimize database queries.
 * Flags are automatically refreshed when cache expires.
 *
 * @param forceRefresh - Force fetch from database, bypassing cache
 * @returns Array of enabled feature flags
 *
 * @example
 * ```typescript
 * const flags = await getFeatureFlags()
 * flags.forEach(flag => {
 *   console.log(`${flag.featureName}: ${flag.enabledForPlans.join(', ')}`)
 * })
 * ```
 */
export async function getFeatureFlags(forceRefresh = false): Promise<FeatureFlag[]> {
  if (!forceRefresh && isCacheValid(flagsCache)) {
    const cacheAge = getCacheAge(flagsCache)
    console.log(`[FeatureFlags] Cache hit (age: ${Math.floor(cacheAge / 1000)}s)`)
    return flagsCache!.data
  }

  const cacheStatus = flagsCache ? `expired (age: ${Math.floor(getCacheAge(flagsCache) / 1000)}s)` : 'empty'
  console.log(`[FeatureFlags] Fetching from database (cache: ${cacheStatus})`)

  const flags = await fetchFeatureFlagsFromDB()

  flagsCache = {
    data: flags,
    timestamp: Date.now(),
  }

  console.log(`[FeatureFlags] Cached ${flags.length} feature flags`)

  return flags
}

/**
 * Check if a feature is enabled for a specific subscription plan
 *
 * @param featureKey - Feature identifier (e.g., 'voice_buddy')
 * @param planType - Subscription plan type ('free', 'standard', 'plus', 'premium')
 * @returns true if feature is enabled globally AND plan has access
 *
 * @example
 * ```typescript
 * const hasVoice = await isFeatureEnabledForPlan('voice_buddy', userPlan)
 * if (!hasVoice) {
 *   throw new Error('Voice feature not available for your plan')
 * }
 * ```
 */
export async function isFeatureEnabledForPlan(
  featureKey: string,
  planType: string
): Promise<boolean> {
  const flags = await getFeatureFlags()
  const flag = flags.find(f => f.featureKey === featureKey)

  if (!flag) {
    console.log(`[FeatureFlags] Feature '${featureKey}' not found or disabled`)
    return false
  }

  if (!flag.isEnabled) {
    console.log(`[FeatureFlags] Feature '${featureKey}' is globally disabled`)
    return false
  }

  const hasAccess = flag.enabledForPlans.includes(planType)

  if (!hasAccess) {
    console.log(
      `[FeatureFlags] Plan '${planType}' does not have access to '${featureKey}' (allowed: ${flag.enabledForPlans.join(', ')})`
    )
  }

  return hasAccess
}

/**
 * Get a specific feature flag by key
 *
 * @param featureKey - Feature identifier
 * @returns FeatureFlag object or undefined if not found
 *
 * @example
 * ```typescript
 * const voiceFlag = await getFeatureFlag('voice_buddy')
 * if (voiceFlag) {
 *   console.log('Enabled plans:', voiceFlag.enabledForPlans)
 * }
 * ```
 */
export async function getFeatureFlag(featureKey: string): Promise<FeatureFlag | undefined> {
  const flags = await getFeatureFlags()
  return flags.find(f => f.featureKey === featureKey)
}

/**
 * Clear the feature flags cache
 *
 * Forces next getFeatureFlags() call to fetch fresh data from database.
 * Useful when flags have been updated via admin panel.
 *
 * @example
 * ```typescript
 * // After updating flags in admin UI
 * clearFeatureFlagsCache()
 * const freshFlags = await getFeatureFlags()
 * ```
 */
export function clearFeatureFlagsCache(): void {
  const hadCache = flagsCache !== null
  flagsCache = null

  if (hadCache) {
    console.log('[FeatureFlags] Cache cleared manually')
  }
}

/**
 * Get cache statistics for monitoring
 *
 * @returns Cache age in milliseconds, or -1 if no cache
 *
 * @internal Used for debugging and monitoring
 */
export function getCacheStats(): { age: number; valid: boolean; count: number } {
  return {
    age: getCacheAge(flagsCache),
    valid: isCacheValid(flagsCache),
    count: flagsCache?.data.length || 0,
  }
}
