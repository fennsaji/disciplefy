/**
 * Database-Backed Plan Configuration Service
 *
 * Replaces hardcoded subscription configuration with database queries.
 * Includes in-memory caching to avoid excessive database queries.
 *
 * @module plan-config-db-service
 * @date 2026-02-13
 */

/// <reference path="../types/deno-env.d.ts" />

// @deno-types="https://esm.sh/@supabase/supabase-js@2.39.0"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

/**
 * Plan type identifier
 */
export type PlanType = 'free' | 'standard' | 'plus' | 'premium'

/**
 * Plan configuration from database
 */
export interface PlanConfigDB {
  readonly planCode: string
  readonly planName: string
  readonly tier: number
  readonly interval: 'monthly' | 'yearly'
  readonly features: {
    daily_tokens: number
    study_modes: string[]
    memory_verses: number
    practice_modes: number
    practice_limit: number
    voice_conversations_monthly: number
    // REMOVED: ai_discipler (use feature flag instead)
    // REMOVED: followups (use study_chat feature flag instead)
    // REMOVED: unlocked_modes (never used)
    // REMOVED: voice_minutes_monthly (never used)
    [key: string]: any
  }
  readonly pricing: {
    razorpay?: {
      planId: string
      price: number
      pricePaise: number
      currency: string
    }
    googlePlay?: {
      sku: string
      price: number
    }
    appleAppStore?: {
      productId: string
      price: number
    }
  }
  readonly isActive: boolean
  readonly description?: string
}

/**
 * Cache entry with timestamp
 */
interface CacheEntry {
  data: PlanConfigDB
  timestamp: number
}

/**
 * In-memory cache for plan configurations
 * TTL: 5 minutes (300,000 ms)
 */
const CACHE_TTL_MS = 5 * 60 * 1000
const planCache = new Map<string, CacheEntry>()

/**
 * Get Supabase client
 */
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

/**
 * Clear all cached plan configurations
 */
export function clearPlanCache(): void {
  planCache.clear()
  console.log('[PlanConfigDB] Cache cleared')
}

/**
 * Clear specific plan from cache
 */
export function clearPlanFromCache(planCode: PlanType): void {
  planCache.delete(planCode)
  console.log(`[PlanConfigDB] Cleared ${planCode} from cache`)
}

/**
 * Check if cached entry is still valid
 */
function isCacheValid(entry: CacheEntry): boolean {
  return Date.now() - entry.timestamp < CACHE_TTL_MS
}

/**
 * Get plan configuration from cache if available and valid
 */
function getFromCache(planCode: PlanType): PlanConfigDB | null {
  const cached = planCache.get(planCode)

  if (cached && isCacheValid(cached)) {
    console.log(`[PlanConfigDB] Cache hit for ${planCode}`)
    return cached.data
  }

  if (cached) {
    console.log(`[PlanConfigDB] Cache expired for ${planCode}`)
    planCache.delete(planCode)
  }

  return null
}

/**
 * Store plan configuration in cache
 */
function storeInCache(planCode: PlanType, data: PlanConfigDB): void {
  planCache.set(planCode, {
    data,
    timestamp: Date.now(),
  })
  console.log(`[PlanConfigDB] Cached ${planCode}`)
}

/**
 * Fetch plan configuration from database
 */
async function fetchPlanFromDatabase(planCode: PlanType): Promise<PlanConfigDB | null> {
  const supabase = getSupabaseClient()

  const { data, error } = await supabase
    .from('subscription_plans_with_pricing')
    .select('*')
    .eq('plan_code', planCode)
    .single()

  if (error) {
    console.error(`[PlanConfigDB] Error fetching ${planCode}:`, error)
    return null
  }

  if (!data) {
    console.warn(`[PlanConfigDB] Plan ${planCode} not found in database`)
    return null
  }

  // Format the response
  const config: PlanConfigDB = {
    planCode: data.plan_code,
    planName: data.plan_name,
    tier: data.tier,
    interval: data.interval,
    features: data.features || {},
    pricing: {
      razorpay: data.razorpay_plan_id ? {
        planId: data.razorpay_plan_id,
        price: data.price_inr || 0,
        pricePaise: (data.price_inr || 0) * 100,
        currency: 'INR',
      } : undefined,
      googlePlay: data.google_play_sku ? {
        sku: data.google_play_sku,
        price: data.price_google_play || 0,
      } : undefined,
      appleAppStore: data.apple_product_id ? {
        productId: data.apple_product_id,
        price: data.price_apple || 0,
      } : undefined,
    },
    isActive: data.is_active,
    description: data.description,
  }

  return config
}

/**
 * Get plan configuration from database with caching
 *
 * @param planCode - Plan code ('free', 'standard', 'plus', 'premium')
 * @param forceRefresh - Force refresh from database, bypassing cache
 * @returns Plan configuration
 * @throws Error if plan not found
 */
export async function getPlanConfigFromDB(
  planCode: PlanType,
  forceRefresh = false
): Promise<PlanConfigDB> {
  // Check cache first (unless force refresh)
  if (!forceRefresh) {
    const cached = getFromCache(planCode)
    if (cached) {
      return cached
    }
  }

  // Fetch from database
  console.log(`[PlanConfigDB] Fetching ${planCode} from database`)
  const config = await fetchPlanFromDatabase(planCode)

  if (!config) {
    throw new Error(`Plan configuration not found for: ${planCode}`)
  }

  // Store in cache
  storeInCache(planCode, config)

  return config
}

/**
 * Get all plan configurations from database
 *
 * @param forceRefresh - Force refresh from database
 * @returns Array of all plan configurations
 */
export async function getAllPlanConfigs(forceRefresh = false): Promise<PlanConfigDB[]> {
  const plans: PlanType[] = ['free', 'standard', 'plus', 'premium']

  const configs = await Promise.all(
    plans.map(plan => getPlanConfigFromDB(plan, forceRefresh).catch(err => {
      console.error(`[PlanConfigDB] Failed to fetch ${plan}:`, err)
      return null
    }))
  )

  return configs.filter((c): c is PlanConfigDB => c !== null)
}

/**
 * Check if a plan type is valid
 */
export function isValidPlanType(planType: string): planType is PlanType {
  return ['free', 'standard', 'plus', 'premium'].includes(planType)
}

/**
 * Get daily token limit for a plan
 *
 * @param planCode - Plan code
 * @returns Daily token limit (-1 for unlimited)
 */
export async function getDailyTokenLimit(planCode: PlanType): Promise<number> {
  const config = await getPlanConfigFromDB(planCode)
  return config.features.daily_tokens || 0
}

// REMOVED: getVoiceMinutesLimit() - voice_minutes_monthly field removed from schema
// Use voice_conversations_monthly quota instead via VoiceConversationLimitService

/**
 * Get unlocked study modes for a plan
 *
 * @param planCode - Plan code
 * @returns Array of unlocked study mode names
 */
export async function getUnlockedModes(planCode: PlanType): Promise<string[]> {
  const config = await getPlanConfigFromDB(planCode)
  return config.features.unlocked_modes || config.features.study_modes || []
}

/**
 * Get Razorpay plan ID for a plan
 *
 * @param planCode - Plan code
 * @returns Razorpay plan ID
 */
export async function getRazorpayPlanId(planCode: PlanType): Promise<string> {
  const config = await getPlanConfigFromDB(planCode)
  return config.pricing.razorpay?.planId || ''
}

/**
 * Get plan price in INR
 *
 * @param planCode - Plan code
 * @returns Price in INR
 */
export async function getPlanPrice(planCode: PlanType): Promise<number> {
  const config = await getPlanConfigFromDB(planCode)
  return config.pricing.razorpay?.price || 0
}

/**
 * Preload all plans into cache (useful for startup)
 */
export async function preloadPlanCache(): Promise<void> {
  console.log('[PlanConfigDB] Preloading plan cache...')
  await getAllPlanConfigs(true)
  console.log('[PlanConfigDB] Plan cache preloaded')
}
