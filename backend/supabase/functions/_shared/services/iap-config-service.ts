/**
 * IAP Configuration Service
 *
 * Manages In-App Purchase configuration for Google Play and Apple App Store.
 * Credentials are stored encrypted in the database and cached for performance.
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export type IAPProvider = 'google_play' | 'apple_appstore'
export type IAPEnvironment = 'sandbox' | 'production'

export interface IAPConfig {
  provider: IAPProvider
  environment: IAPEnvironment
  serviceAccountEmail?: string  // Google Play
  serviceAccountKey?: string    // Google Play (encrypted)
  sharedSecret?: string         // Apple App Store (encrypted)
  bundleId?: string            // Apple App Store
  packageName?: string         // Google Play
}

interface CachedConfig {
  config: IAPConfig
  fetchedAt: number
}

// Cache for 5 minutes (same pattern as subscription-config.ts)
const CONFIG_CACHE_TTL = 5 * 60 * 1000
const configCache = new Map<string, CachedConfig>()

/**
 * Get IAP configuration from database with caching
 */
export async function getIAPConfig(
  supabase: SupabaseClient,
  provider: IAPProvider,
  environment: IAPEnvironment
): Promise<IAPConfig> {
  const cacheKey = `${provider}_${environment}`
  const now = Date.now()

  // Check cache
  const cached = configCache.get(cacheKey)
  if (cached && (now - cached.fetchedAt < CONFIG_CACHE_TTL)) {
    console.log(`[IAP_CONFIG] Cache hit for ${cacheKey}`)
    return cached.config
  }

  console.log(`[IAP_CONFIG] Fetching config for ${provider} (${environment})`)

  // Fetch all config keys for this provider/environment
  const { data: configRows, error } = await supabase
    .from('iap_config')
    .select('config_key, config_value')
    .eq('provider', provider)
    .eq('environment', environment)
    .eq('is_active', true)

  if (error) {
    throw new Error(`Failed to fetch IAP config: ${error.message}`)
  }

  if (!configRows || configRows.length === 0) {
    throw new Error(`No IAP configuration found for ${provider} (${environment})`)
  }

  // Build config object
  const config: IAPConfig = {
    provider,
    environment
  }

  for (const row of configRows) {
    switch (row.config_key) {
      case 'service_account_email':
        config.serviceAccountEmail = row.config_value
        break
      case 'service_account_key':
        config.serviceAccountKey = row.config_value  // Already encrypted
        break
      case 'shared_secret':
        config.sharedSecret = row.config_value  // Already encrypted
        break
      case 'bundle_id':
        config.bundleId = row.config_value
        break
      case 'package_name':
        config.packageName = row.config_value
        break
    }
  }

  // Validate required fields
  if (provider === 'google_play') {
    if (!config.serviceAccountEmail || !config.serviceAccountKey || !config.packageName) {
      throw new Error('Missing required Google Play configuration')
    }
  } else if (provider === 'apple_appstore') {
    if (!config.sharedSecret || !config.bundleId) {
      throw new Error('Missing required Apple App Store configuration')
    }
  }

  // Cache the config
  configCache.set(cacheKey, {
    config,
    fetchedAt: now
  })

  return config
}

/**
 * Clear configuration cache
 */
export function clearIAPConfigCache(provider?: IAPProvider, environment?: IAPEnvironment): void {
  if (provider && environment) {
    configCache.delete(`${provider}_${environment}`)
  } else {
    configCache.clear()
  }
  console.log('[IAP_CONFIG] Cache cleared')
}

/**
 * Detect environment from receipt or default to production
 */
export function detectEnvironment(receipt: string): IAPEnvironment {
  // Apple receipts have environment in the response
  // Google Play receipts don't indicate environment, use configuration
  // Default to production for safety
  return 'production'
}
