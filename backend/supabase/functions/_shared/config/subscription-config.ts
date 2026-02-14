/**
 * Subscription Plans Configuration
 *
 * Centralized configuration for all subscription plans (Standard and Premium).
 * Plan IDs are loaded from environment variables.
 * Trial periods are now loaded from database via system-config-service.ts
 */

import { getTrialConfig } from '../services/system-config-service.ts'

/**
 * Plan type identifier
 */
export type PlanType = 'standard' | 'plus' | 'premium'

/**
 * Individual plan configuration
 */
export interface PlanConfig {
  readonly planId: string
  readonly price: number         // Price in INR
  readonly pricePaise: number    // Price in paise
  readonly currency: string
  readonly interval: 'monthly' | 'yearly'
  readonly name: string
  readonly trialEndDate: Date | null  // null = no trial period
  readonly trialStartDate?: Date      // Optional: Trial start date for Premium
  readonly trialDurationDays?: number // Optional: Trial duration for Premium
}

// ============================================================================
// DYNAMIC TRIAL CONFIGURATION (Database-Driven)
// ============================================================================

/**
 * Trial configuration cache
 * Cached for 5 minutes to match system-config-service.ts TTL
 */
interface TrialConfig {
  standardTrialEndDate: Date
  premiumTrialDays: number
  premiumTrialStartDate: Date
  gracePeriodDays: number
}

let cachedTrialConfig: TrialConfig | null = null
let trialConfigFetchTime: number = 0
const TRIAL_CONFIG_CACHE_MS = 5 * 60 * 1000 // 5 minutes

/**
 * Get dynamic trial configuration from database
 * Uses 5-minute cache to match system-config-service pattern
 *
 * @returns Trial configuration with dates and durations
 */
export async function getDynamicTrialConfig(): Promise<TrialConfig> {
  const now = Date.now()

  // Return cached config if still valid
  if (cachedTrialConfig && (now - trialConfigFetchTime < TRIAL_CONFIG_CACHE_MS)) {
    return cachedTrialConfig
  }

  // Fetch fresh config from database
  const config = await getTrialConfig()

  // Calculate grace period end date (standard trial end + grace period days)
  const gracePeriodEndDate = new Date(config.standardTrialEndDate)
  gracePeriodEndDate.setDate(gracePeriodEndDate.getDate() + config.gracePeriodDays)

  // Cache the config
  cachedTrialConfig = {
    standardTrialEndDate: config.standardTrialEndDate,
    premiumTrialDays: config.premiumTrialDays,
    premiumTrialStartDate: config.premiumTrialStartDate,
    gracePeriodDays: config.gracePeriodDays,
  }
  trialConfigFetchTime = now

  return cachedTrialConfig
}

/**
 * Clear trial config cache
 * Useful when config has been updated via admin panel
 */
export function clearTrialConfigCache(): void {
  cachedTrialConfig = null
  trialConfigFetchTime = 0
}

// ============================================================================
// DEPRECATED: Hardcoded constants for backward compatibility
// These are now fetched from database via getDynamicTrialConfig()
// IMPORTANT: New code should use getDynamicTrialConfig() instead
// ============================================================================

/**
 * @deprecated Use getDynamicTrialConfig().gracePeriodDays instead
 */
export const GRACE_PERIOD_DAYS = 7

/**
 * @deprecated Use getDynamicTrialConfig().standardTrialEndDate instead
 */
export const STANDARD_TRIAL_END_DATE = new Date('2026-03-31T23:59:59+05:30')

/**
 * @deprecated Calculated dynamically as standardTrialEndDate + gracePeriodDays
 */
export const GRACE_PERIOD_END_DATE = new Date('2026-04-07T23:59:59+05:30')

/**
 * @deprecated Use getDynamicTrialConfig().premiumTrialStartDate instead
 */
export const PREMIUM_TRIAL_START_DATE = new Date('2026-04-01T00:00:00+05:30')

/**
 * @deprecated Use getDynamicTrialConfig().premiumTrialDays instead
 */
export const PREMIUM_TRIAL_DAYS = 7

/**
 * Get subscription plan configuration
 * Now async to fetch trial dates from database
 *
 * @param planType - 'standard', 'plus', or 'premium'
 * @returns Plan configuration with dynamic trial dates
 */
export async function getPlanConfig(planType: PlanType): Promise<PlanConfig> {
  const trialConfig = await getDynamicTrialConfig()

  const configs: Record<PlanType, PlanConfig> = {
    standard: {
      planId: Deno.env.get('RAZORPAY_STANDARD_PLAN_ID') || '',
      price: 79,
      pricePaise: 7900,
      currency: 'INR',
      interval: 'monthly',
      name: 'Standard Monthly',
      trialEndDate: trialConfig.standardTrialEndDate, // From database
    },
    plus: {
      planId: Deno.env.get('RAZORPAY_PLUS_PLAN_ID') || '',
      price: 149,
      pricePaise: 14900,
      currency: 'INR',
      interval: 'monthly',
      name: 'Plus Monthly',
      trialEndDate: null, // No trial for Plus
    },
    premium: {
      planId: Deno.env.get('RAZORPAY_PREMIUM_PLAN_ID') || '',
      price: 499,
      pricePaise: 49900,
      currency: 'INR',
      interval: 'monthly',
      name: 'Premium Monthly',
      trialEndDate: null,
      trialStartDate: trialConfig.premiumTrialStartDate, // From database
      trialDurationDays: trialConfig.premiumTrialDays, // From database
    },
  }

  return configs[planType]
}

/**
 * Check if a plan type is valid
 *
 * @param planType - Plan type to validate
 * @returns true if valid plan type
 */
export function isValidPlanType(planType: string): planType is PlanType {
  return planType === 'standard' || planType === 'plus' || planType === 'premium'
}

/**
 * Check if the Standard trial period is currently active
 * Now async to fetch from database
 *
 * @returns true if current date is before trial end date
 */
export async function isStandardTrialActive(): Promise<boolean> {
  const config = await getDynamicTrialConfig()
  return new Date() <= config.standardTrialEndDate
}

/**
 * Get days until Standard trial ends
 * Now async to fetch from database
 *
 * @returns Number of days until trial ends (0 if already ended)
 */
export async function getDaysUntilTrialEnd(): Promise<number> {
  const config = await getDynamicTrialConfig()
  const now = new Date()
  const diffTime = config.standardTrialEndDate.getTime() - now.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  return Math.max(0, diffDays)
}

/**
 * Check if we're in the grace period
 * Now async to fetch from database
 *
 * @returns true if current date is after trial end but before grace period end
 */
export async function isInGracePeriod(): Promise<boolean> {
  const config = await getDynamicTrialConfig()
  const now = new Date()

  // Calculate grace period end date
  const gracePeriodEndDate = new Date(config.standardTrialEndDate)
  gracePeriodEndDate.setDate(gracePeriodEndDate.getDate() + config.gracePeriodDays)

  return now > config.standardTrialEndDate && now <= gracePeriodEndDate
}

/**
 * Get days remaining in grace period
 * Now async to fetch from database
 *
 * @returns Number of days until grace period ends (0 if not in grace period, full grace days if trial still active)
 */
export async function getGraceDaysRemaining(): Promise<number> {
  const config = await getDynamicTrialConfig()
  const now = new Date()

  // If still in trial, return full grace period days
  if (now <= config.standardTrialEndDate) {
    return config.gracePeriodDays
  }

  // Calculate grace period end date
  const gracePeriodEndDate = new Date(config.standardTrialEndDate)
  gracePeriodEndDate.setDate(gracePeriodEndDate.getDate() + config.gracePeriodDays)

  // If after grace period, return 0
  if (now > gracePeriodEndDate) {
    return 0
  }

  // Calculate remaining days in grace period
  const diffTime = gracePeriodEndDate.getTime() - now.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  return Math.max(0, diffDays)
}

/**
 * Check if a user was eligible for the trial based on signup date
 * Now async to fetch from database
 *
 * @param userCreatedAt - User's account creation date
 * @returns true if user signed up before or on trial end date
 */
export async function wasEligibleForTrial(userCreatedAt: Date): Promise<boolean> {
  const config = await getDynamicTrialConfig()
  return userCreatedAt <= config.standardTrialEndDate
}

/**
 * Check if Premium trial feature is currently available
 * Now async to fetch from database
 *
 * @returns true if current date is after Premium trial start date
 */
export async function isPremiumTrialAvailable(): Promise<boolean> {
  const config = await getDynamicTrialConfig()
  return new Date() >= config.premiumTrialStartDate
}

/**
 * Check if a user is eligible to start a Premium trial
 * Now async to fetch from database
 *
 * @param userCreatedAt - User's account creation date
 * @returns true if user can start Premium trial
 */
export async function canStartPremiumTrial(userCreatedAt: Date): Promise<boolean> {
  const config = await getDynamicTrialConfig()
  return userCreatedAt >= config.premiumTrialStartDate
}

/**
 * Calculate the Premium trial end date
 * Now async to fetch trial duration from database
 *
 * @param startDate - Trial start date (defaults to now)
 * @returns Date when trial ends
 */
export async function calculatePremiumTrialEndDate(startDate: Date = new Date()): Promise<Date> {
  const config = await getDynamicTrialConfig()
  const endDate = new Date(startDate)
  endDate.setDate(endDate.getDate() + config.premiumTrialDays)
  return endDate
}

/**
 * Check if a user is currently in Premium trial based on trial dates
 *
 * @param premiumTrialEndAt - Premium trial end date from database
 * @returns true if currently in active Premium trial
 */
export function isInPremiumTrial(premiumTrialEndAt: Date | null): boolean {
  if (!premiumTrialEndAt) return false
  return new Date() < premiumTrialEndAt
}

/**
 * Get days remaining in Premium trial
 *
 * @param premiumTrialEndAt - Premium trial end date from database
 * @returns Number of days remaining (0 if trial ended or null)
 */
export function getPremiumTrialDaysRemaining(premiumTrialEndAt: Date | null): number {
  if (!premiumTrialEndAt) return 0
  const now = new Date()
  if (now >= premiumTrialEndAt) return 0
  const diffTime = premiumTrialEndAt.getTime() - now.getTime()
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24))
}

// ========================================
// REVENUE ALLOCATION CONFIGURATION
// ========================================

/**
 * Revenue allocation per 100 operations for cost attribution
 * Used by Usage Tracking system for profitability calculations
 */
export const REVENUE_ALLOCATION_PER_100_OPS = {
  free: 0.00,      // ₹0/month
  standard: 0.79,  // ₹79/month / 100 operations
  plus: 1.49,      // ₹149/month / 100 operations
  premium: 4.99,   // ₹499/month / 100 operations
} as const

/**
 * Monthly subscription revenue in INR
 */
export const MONTHLY_REVENUE = {
  free: 0,
  standard: 79,
  plus: 149,
  premium: 499,
} as const

/**
 * Get revenue allocation for a tier and feature
 *
 * @param tier - Subscription tier
 * @param featureMultiplier - Feature importance multiplier (default 1.0)
 * @returns Allocated revenue in INR per operation
 */
export function getRevenueAllocation(
  tier: PlanType | 'free',
  featureMultiplier: number = 1.0
): number {
  const baseAllocation = REVENUE_ALLOCATION_PER_100_OPS[tier as keyof typeof REVENUE_ALLOCATION_PER_100_OPS] || 0
  return baseAllocation * featureMultiplier
}

/**
 * Calculate expected monthly revenue for a user base
 *
 * @param usersByTier - Count of users per tier
 * @returns Total monthly revenue in INR
 */
export function calculateMonthlyRevenue(usersByTier: {
  free?: number
  standard?: number
  plus?: number
  premium?: number
}): number {
  return (
    (usersByTier.free || 0) * MONTHLY_REVENUE.free +
    (usersByTier.standard || 0) * MONTHLY_REVENUE.standard +
    (usersByTier.plus || 0) * MONTHLY_REVENUE.plus +
    (usersByTier.premium || 0) * MONTHLY_REVENUE.premium
  )
}
