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
 * Try to build IAP config from environment variables.
 * Env var naming: GOOGLE_PLAY_{SANDBOX|PRODUCTION}_* and APPLE_{SANDBOX|PRODUCTION}_*
 * Returns null if required vars are absent (falls back to DB).
 */
function getConfigFromEnvVars(provider: IAPProvider, environment: IAPEnvironment): IAPConfig | null {
  const envSuffix = environment.toUpperCase()  // 'SANDBOX' or 'PRODUCTION'

  if (provider === 'google_play') {
    const email = Deno.env.get(`GOOGLE_PLAY_${envSuffix}_SERVICE_ACCOUNT_EMAIL`)

    // Support both raw JSON (_KEY) and base64-encoded JSON (_KEY_B64).
    // The script uses _B64 to avoid env file parsing issues with slashes/newlines.
    let key = Deno.env.get(`GOOGLE_PLAY_${envSuffix}_SERVICE_ACCOUNT_KEY`)
    if (!key) {
      const b64 = Deno.env.get(`GOOGLE_PLAY_${envSuffix}_SERVICE_ACCOUNT_KEY_B64`)
      if (b64) key = atob(b64)
    }

    const pkgDefault = 'com.disciplefy.bible_study'
    const packageName = Deno.env.get(`GOOGLE_PLAY_${envSuffix}_PACKAGE_NAME`) ?? pkgDefault

    if (email && key) {
      console.log(`[IAP_CONFIG] Source: ENV_VARS | Provider: ${provider} | Env: ${environment} | Package: ${packageName}`)
      return { provider, environment, serviceAccountEmail: email, serviceAccountKey: key, packageName }
    }
  } else if (provider === 'apple_appstore') {
    const sharedSecret = Deno.env.get(`APPLE_${envSuffix}_SHARED_SECRET`)
    const bundleDefault = 'com.disciplefy.bible_study'
    const bundleId = Deno.env.get(`APPLE_${envSuffix}_BUNDLE_ID`) ?? bundleDefault

    if (sharedSecret) {
      console.log(`[IAP_CONFIG] Source: ENV_VARS | Provider: ${provider} | Env: ${environment} | Bundle: ${bundleId}`)
      return { provider, environment, sharedSecret, bundleId }
    }
  }

  return null
}

/**
 * Get IAP configuration with priority:
 *   1. Environment variables (local dev / CI)
 *   2. Database iap_config rows (production / Supabase secrets)
 *
 * Note: USE_MOCK is handled upstream in each validator — it bypasses getIAPConfig entirely.
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

  // 1. Try env vars first (fast path — no DB round-trip)
  const envConfig = getConfigFromEnvVars(provider, environment)
  if (envConfig) {
    configCache.set(cacheKey, { config: envConfig, fetchedAt: now })
    return envConfig
  }

  // 2. Fall back to database
  console.log(`[IAP_CONFIG] Source: DATABASE | Provider: ${provider} | Env: ${environment}`)

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
    const envVarHint = provider === 'google_play'
      ? `GOOGLE_PLAY_${environment.toUpperCase()}_SERVICE_ACCOUNT_EMAIL / _KEY / _PACKAGE_NAME`
      : `APPLE_${environment.toUpperCase()}_SHARED_SECRET / _BUNDLE_ID`
    const hint = environment === 'production'
      ? ` — set APP_ENVIRONMENT=sandbox for local/test, or set USE_MOCK=true to bypass validation`
      : ` — set ${envVarHint} in your env file, or populate iap_config rows with is_active=true`
    throw new Error(`No IAP configuration found for ${provider} (${environment})${hint}`)
  }

  // Build config object
  const config: IAPConfig = { provider, environment }

  for (const row of configRows) {
    switch (row.config_key) {
      case 'service_account_email':
        config.serviceAccountEmail = row.config_value
        break
      case 'service_account_key':
        config.serviceAccountKey = row.config_value
        break
      case 'shared_secret':
        config.sharedSecret = row.config_value
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
      throw new Error('Missing required Google Play configuration: service_account_email, service_account_key, package_name must all be present in iap_config')
    }
  } else if (provider === 'apple_appstore') {
    if (!config.sharedSecret || !config.bundleId) {
      throw new Error('Missing required Apple App Store configuration: shared_secret and bundle_id must be present in iap_config')
    }
  }

  // Cache the config
  configCache.set(cacheKey, { config, fetchedAt: now })

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
 * Detect environment from APP_ENVIRONMENT secret, defaulting to production.
 * Set APP_ENVIRONMENT=sandbox in Supabase secrets for testing.
 */
export function detectEnvironment(_receipt?: string): IAPEnvironment {
  return Deno.env.get('APP_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production'
}
