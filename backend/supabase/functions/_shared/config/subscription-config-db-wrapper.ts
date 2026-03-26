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
import { getDynamicTrialConfig } from './subscription-config.ts'

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
 * Premium trial duration in days
 */
export const PREMIUM_TRIAL_DAYS = 7

/**
 * Convert database plan config to legacy PlanConfig format
 */
function convertToLegacyFormat(dbConfig: PlanConfigDB, trialEndDate: Date | null, premiumTrialStartDate: Date | null): PlanConfig {
  return {
    planId: dbConfig.pricing.razorpay?.planId || '',
    price: dbConfig.pricing.razorpay?.price || 0,
    pricePaise: dbConfig.pricing.razorpay?.pricePaise || 0,
    currency: dbConfig.pricing.razorpay?.currency || 'INR',
    interval: dbConfig.interval,
    name: dbConfig.planName,
    trialEndDate: dbConfig.planCode === 'standard' ? trialEndDate : null,
    trialStartDate: dbConfig.planCode === 'premium' ? (premiumTrialStartDate ?? undefined) : undefined,
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
  const [dbConfig, trialConfig] = await Promise.all([
    getPlanConfigFromDB(planType as DBPlanType),
    getDynamicTrialConfig(),
  ])
  return convertToLegacyFormat(dbConfig, trialConfig.standardTrialEndDate, trialConfig.premiumTrialStartDate)
}

/**
 * Check if a plan type is valid
 */
export function isValidPlanType(planType: string): planType is PlanType {
  return planType === 'standard' || planType === 'plus' || planType === 'premium'
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
