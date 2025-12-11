/**
 * Subscription Plans Configuration
 *
 * Centralized configuration for all subscription plans (Standard and Premium).
 * Plan IDs are loaded from environment variables.
 */

/**
 * Plan type identifier
 */
export type PlanType = 'standard' | 'premium'

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
 * Get subscription plan configuration
 *
 * @param planType - 'standard' or 'premium'
 * @returns Plan configuration
 */
export function getPlanConfig(planType: PlanType): PlanConfig {
  const configs: Record<PlanType, PlanConfig> = {
    standard: {
      planId: Deno.env.get('RAZORPAY_STANDARD_PLAN_ID') || '',
      price: 50,
      pricePaise: 5000,
      currency: 'INR',
      interval: 'monthly',
      name: 'Standard Monthly',
      trialEndDate: STANDARD_TRIAL_END_DATE,
    },
    premium: {
      planId: Deno.env.get('RAZORPAY_PREMIUM_PLAN_ID') || '',
      price: 100,
      pricePaise: 10000,
      currency: 'INR',
      interval: 'monthly',
      name: 'Premium Monthly',
      trialEndDate: null,
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
  return planType === 'standard' || planType === 'premium'
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
 * Check if we're in the grace period (April 1-7, 2025)
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
 * @returns Number of days until grace period ends (0 if not in grace period, 7 if trial still active)
 */
export function getGraceDaysRemaining(): number {
  const now = new Date()

  // If still in trial, return full grace period days
  if (now <= STANDARD_TRIAL_END_DATE) {
    return GRACE_PERIOD_DAYS
  }

  // If after grace period, return 0
  if (now > GRACE_PERIOD_END_DATE) {
    return 0
  }

  // Calculate remaining days in grace period
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
 * Premium trials are available starting April 1st, 2025
 *
 * @returns true if current date is after Premium trial start date
 */
export function isPremiumTrialAvailable(): boolean {
  return new Date() >= PREMIUM_TRIAL_START_DATE
}

/**
 * Check if a user is eligible to start a Premium trial
 * User must have signed up after April 1st, 2025
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
