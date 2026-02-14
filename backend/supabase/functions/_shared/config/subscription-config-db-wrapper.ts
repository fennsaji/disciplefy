/**
 * Database-Backed Subscription Config Wrapper
 *
 * Provides backward-compatible interface using database-backed plan configuration.
 * Drop-in replacement for subscription-config.ts
 *
 * @module subscription-config-db-wrapper
 * @date 2026-02-13
 */

/// <reference path="../types/deno-env.d.ts" />

import {
  getPlanConfigFromDB,
  PlanType as DBPlanType,
  PlanConfigDB,
} from '../services/plan-config-db-service.ts'

/**
 * Plan type identifier (backward compatible)
 */
export type PlanType = 'standard' | 'plus' | 'premium'

/**
 * Individual plan configuration (backward compatible interface)
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
  readonly dailyTokens?: number       // NEW: From database
  readonly unlockedModes?: string[]   // NEW: From database (practice modes)
  // REMOVED: voiceMinutes - not used (use voice_conversations_monthly quota instead)
}

/**
 * Grace period in days after trial ends for existing users
 */
export const GRACE_PERIOD_DAYS = 7

/**
 * Standard trial end date (March 31st, 2026 at 23:59:59 IST)
 * All users get free Standard plan access until this date.
 */
export const STANDARD_TRIAL_END_DATE = new Date('2026-03-31T23:59:59+05:30')

/**
 * Grace period end date (April 7th, 2026 at 23:59:59 IST)
 * Users who signed up before March 31 keep Standard access until this date
 */
export const GRACE_PERIOD_END_DATE = new Date('2026-04-07T23:59:59+05:30')

/**
 * Premium trial start date (April 1st, 2026 at 00:00:00 IST)
 * New users signing up after this date can get a 7-day Premium trial
 */
export const PREMIUM_TRIAL_START_DATE = new Date('2026-04-01T00:00:00+05:30')

/**
 * Premium trial duration in days
 */
export const PREMIUM_TRIAL_DAYS = 7

/**
 * Convert database plan config to legacy PlanConfig format
 */
function convertToLegacyFormat(dbConfig: PlanConfigDB): PlanConfig {
  return {
    planId: dbConfig.pricing.razorpay?.planId || '',
    price: dbConfig.pricing.razorpay?.price || 0,
    pricePaise: dbConfig.pricing.razorpay?.pricePaise || 0,
    currency: dbConfig.pricing.razorpay?.currency || 'INR',
    interval: dbConfig.interval,
    name: dbConfig.planName,
    trialEndDate: dbConfig.planCode === 'standard' ? STANDARD_TRIAL_END_DATE : null,
    trialStartDate: dbConfig.planCode === 'premium' ? PREMIUM_TRIAL_START_DATE : undefined,
    trialDurationDays: dbConfig.planCode === 'premium' ? PREMIUM_TRIAL_DAYS : undefined,
    dailyTokens: dbConfig.features.daily_tokens,
    unlockedModes: dbConfig.features.unlocked_modes || dbConfig.features.study_modes,
  }
}

/**
 * Get subscription plan configuration from database
 *
 * @param planType - 'standard', 'plus', or 'premium'
 * @returns Plan configuration
 */
export async function getPlanConfig(planType: PlanType): Promise<PlanConfig> {
  const dbConfig = await getPlanConfigFromDB(planType as DBPlanType)
  return convertToLegacyFormat(dbConfig)
}

/**
 * Get subscription plan configuration synchronously (uses cached values)
 * DEPRECATED: Use async getPlanConfig() instead
 *
 * @param planType - 'standard', 'plus', or 'premium'
 * @returns Plan configuration with fallback hardcoded values
 */
export function getPlanConfigSync(planType: PlanType): PlanConfig {
  console.warn('[SubscriptionConfig] getPlanConfigSync is deprecated. Use async getPlanConfig() instead.')

  // Fallback to hardcoded values for sync access
  // These will be overridden by database values in async code
  const fallbackConfigs: Record<PlanType, PlanConfig> = {
    standard: {
      planId: Deno.env.get('RAZORPAY_STANDARD_PLAN_ID') || '',
      price: 79,
      pricePaise: 7900,
      currency: 'INR',
      interval: 'monthly',
      name: 'Standard Monthly',
      trialEndDate: STANDARD_TRIAL_END_DATE,
      dailyTokens: 20,
      unlockedModes: ['standard', 'deep'],
    },
    plus: {
      planId: Deno.env.get('RAZORPAY_PLUS_PLAN_ID') || '',
      price: 149,
      pricePaise: 14900,
      currency: 'INR',
      interval: 'monthly',
      name: 'Plus Monthly',
      trialEndDate: null,
      dailyTokens: 50,
      unlockedModes: ['standard', 'deep', 'lectio'],
    },
    premium: {
      planId: Deno.env.get('RAZORPAY_PREMIUM_PLAN_ID') || '',
      price: 499,
      pricePaise: 49900,
      currency: 'INR',
      interval: 'monthly',
      name: 'Premium Monthly',
      trialEndDate: null,
      trialStartDate: PREMIUM_TRIAL_START_DATE,
      trialDurationDays: PREMIUM_TRIAL_DAYS,
      dailyTokens: -1, // Unlimited
      unlockedModes: ['standard', 'deep', 'lectio', 'sermon', 'recommended'],
    },
  }

  return fallbackConfigs[planType]
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
 *
 * @returns true if current date is before trial end date
 */
export function isStandardTrialActive(): boolean {
  return new Date() <= STANDARD_TRIAL_END_DATE
}

/**
 * Get days until Standard trial ends
 *
 * @returns Number of days until trial ends (0 if already ended)
 */
export function getDaysUntilTrialEnd(): number {
  const now = new Date()
  const diffTime = STANDARD_TRIAL_END_DATE.getTime() - now.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  return Math.max(0, diffDays)
}

/**
 * Check if we're in the grace period
 *
 * @returns true if current date is after trial end but before grace period end
 */
export function isInGracePeriod(): boolean {
  const now = new Date()
  return now > STANDARD_TRIAL_END_DATE && now <= GRACE_PERIOD_END_DATE
}

/**
 * Get days remaining in grace period
 *
 * @returns Number of days until grace period ends
 */
export function getGraceDaysRemaining(): number {
  const now = new Date()

  if (now <= STANDARD_TRIAL_END_DATE) {
    return GRACE_PERIOD_DAYS
  }

  if (now > GRACE_PERIOD_END_DATE) {
    return 0
  }

  const diffTime = GRACE_PERIOD_END_DATE.getTime() - now.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  return Math.max(0, diffDays)
}

/**
 * Check if a user was eligible for the trial based on signup date
 *
 * @param userCreatedAt - User's account creation date
 * @returns true if user signed up before or on trial end date
 */
export function wasEligibleForTrial(userCreatedAt: Date): boolean {
  return userCreatedAt <= STANDARD_TRIAL_END_DATE
}

/**
 * Check if Premium trial feature is currently available
 *
 * @returns true if current date is after Premium trial start date
 */
export function isPremiumTrialAvailable(): boolean {
  return new Date() >= PREMIUM_TRIAL_START_DATE
}

/**
 * Check if a user is eligible to start a Premium trial
 *
 * @param userCreatedAt - User's account creation date
 * @returns true if user can start Premium trial
 */
export function canStartPremiumTrial(userCreatedAt: Date): boolean {
  return userCreatedAt >= PREMIUM_TRIAL_START_DATE
}

/**
 * Calculate the Premium trial end date
 *
 * @param startDate - Trial start date (defaults to now)
 * @returns Date when trial ends
 */
export function calculatePremiumTrialEndDate(startDate: Date = new Date()): Date {
  const endDate = new Date(startDate)
  endDate.setDate(endDate.getDate() + PREMIUM_TRIAL_DAYS)
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
 * Get revenue allocation from database plan pricing
 *
 * @param tier - Subscription tier
 * @param featureMultiplier - Feature importance multiplier (default 1.0)
 * @returns Allocated revenue in INR per operation
 */
export async function getRevenueAllocation(
  tier: PlanType | 'free',
  featureMultiplier: number = 1.0
): Promise<number> {
  if (tier === 'free') {
    return 0
  }

  const config = await getPlanConfig(tier as PlanType)
  const baseAllocation = config.price / 100 // Per 100 operations
  return baseAllocation * featureMultiplier
}

/**
 * Calculate expected monthly revenue for a user base
 *
 * @param usersByTier - Count of users per tier with pricing from database
 * @returns Total monthly revenue in INR
 */
export async function calculateMonthlyRevenue(usersByTier: {
  free?: number
  standard?: number
  plus?: number
  premium?: number
}): Promise<number> {
  const [standardConfig, plusConfig, premiumConfig] = await Promise.all([
    getPlanConfig('standard'),
    getPlanConfig('plus'),
    getPlanConfig('premium'),
  ])

  return (
    (usersByTier.free || 0) * 0 +
    (usersByTier.standard || 0) * standardConfig.price +
    (usersByTier.plus || 0) * plusConfig.price +
    (usersByTier.premium || 0) * premiumConfig.price
  )
}
