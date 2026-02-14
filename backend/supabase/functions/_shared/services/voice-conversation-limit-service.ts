/**
 * Voice Conversation Limit Service
 *
 * Manages monthly conversation limits for AI Study Buddy Voice feature.
 * Tier-based limits: Free=1, Standard=3, Plus=10, Premium=unlimited per month
 *
 * @module VoiceConversationLimitService
 */

import { SupabaseClient } from '@supabase/supabase-js'

/**
 * Status of user's monthly conversation limit
 */
export interface MonthlyLimitStatus {
  /** Whether user can start a new conversation this month */
  canStart: boolean
  /** Number of conversations started this month */
  conversationsUsed: number
  /** Maximum conversations allowed per month (-1 for unlimited) */
  limit: number
  /** Remaining conversations this month */
  remaining: number
  /** User's subscription tier */
  tier: string
  /** Current month in YYYY-MM format */
  month?: string
}

/**
 * Service for managing monthly voice conversation limits
 */
export class VoiceConversationLimitService {
  constructor(private supabaseClient: SupabaseClient) {}

  /**
   * Check if user can start a new voice conversation this month
   *
   * @param userId - User's UUID
   * @param tier - User's subscription tier (free, standard, plus, premium)
   * @returns Monthly limit status with can_start flag and usage stats
   * @throws Error if database operation fails
   *
   * @example
   * ```typescript
   * const limitService = new VoiceConversationLimitService(supabaseClient)
   * const status = await limitService.checkMonthlyLimit(userId, 'free')
   *
   * if (!status.canStart) {
   *   console.log(`User has used ${status.conversationsUsed} of ${status.limit} conversations`)
   * }
   * ```
   */
  async checkMonthlyLimit(userId: string, tier: string): Promise<MonthlyLimitStatus> {
    const { data, error } = await this.supabaseClient.rpc(
      'check_monthly_voice_conversation_limit',
      {
        p_user_id: userId,
        p_tier: tier.toLowerCase()
      }
    )

    if (error) {
      console.error('[VoiceConversationLimitService] Error checking monthly limit:', error)
      throw new Error(`Failed to check monthly conversation limit: ${error.message}`)
    }

    return {
      canStart: data.can_start as boolean,
      conversationsUsed: data.conversations_used as number,
      limit: data.limit as number,
      remaining: data.remaining as number,
      tier: data.tier as string,
      month: data.month as string
    }
  }

  /**
   * Increment monthly conversation counter after successful conversation creation
   *
   * This should be called AFTER the conversation is successfully created in the database.
   * Uses fire-and-forget pattern - failures are logged but don't block conversation creation.
   *
   * @param userId - User's UUID
   * @param tier - User's subscription tier
   * @returns Promise<void> - Resolves when counter is incremented
   * @throws Error if database operation fails (should be caught by caller)
   *
   * @example
   * ```typescript
   * // Fire-and-forget pattern (non-blocking)
   * limitService.incrementMonthlyCounter(userId, userTier)
   *   .catch(err => console.error('Failed to increment counter:', err))
   * ```
   */
  async incrementMonthlyCounter(userId: string, tier: string): Promise<void> {
    const currentMonth = new Date().toISOString().substring(0, 7) // YYYY-MM format

    try {
      // Get or create monthly record
      const { data: record, error: getError } = await this.supabaseClient.rpc(
        'get_or_create_monthly_voice_usage',
        {
          p_user_id: userId,
          p_tier: tier.toLowerCase()
        }
      )

      if (getError) {
        console.error('[VoiceConversationLimitService] Error getting monthly record:', getError)
        throw new Error(`Failed to get monthly usage record: ${getError.message}`)
      }

      if (!record) {
        throw new Error('No record returned from get_or_create_monthly_voice_usage')
      }

      // Increment monthly counter
      const { error: updateError } = await this.supabaseClient
        .from('voice_usage_tracking')
        .update({
          monthly_conversations_started: record.monthly_conversations_started + 1
        })
        .eq('user_id', userId)
        .eq('month_year', currentMonth)

      if (updateError) {
        console.error('[VoiceConversationLimitService] Error incrementing counter:', updateError)
        // Non-critical error - conversation already created, just log
        throw new Error(`Failed to increment monthly counter: ${updateError.message}`)
      }

      console.log(`[VoiceConversationLimitService] Incremented monthly counter for user ${userId} (${tier}): ${record.monthly_conversations_started} -> ${record.monthly_conversations_started + 1}`)
    } catch (error) {
      // Re-throw for caller to handle (typically fire-and-forget)
      throw error
    }
  }

  /**
   * Mark a conversation as completed in monthly tracking
   *
   * Updates the monthly_conversations_completed counter. This is separate from
   * conversations_started to track completion rates.
   *
   * @param userId - User's UUID
   * @param tier - User's subscription tier
   * @returns Promise<void>
   */
  async markConversationCompleted(userId: string, tier: string): Promise<void> {
    const currentMonth = new Date().toISOString().substring(0, 7)

    try {
      // Get or create monthly record
      const { data: record, error: getError } = await this.supabaseClient.rpc(
        'get_or_create_monthly_voice_usage',
        {
          p_user_id: userId,
          p_tier: tier.toLowerCase()
        }
      )

      if (getError || !record) {
        console.error('[VoiceConversationLimitService] Error getting record for completion:', getError)
        return // Non-critical, just skip
      }

      // Increment completed counter
      await this.supabaseClient
        .from('voice_usage_tracking')
        .update({
          monthly_conversations_completed: record.monthly_conversations_completed + 1
        })
        .eq('user_id', userId)
        .eq('month_year', currentMonth)

      console.log(`[VoiceConversationLimitService] Marked conversation completed for user ${userId}`)
    } catch (error) {
      console.error('[VoiceConversationLimitService] Error marking completion:', error)
      // Non-critical, don't throw
    }
  }

  /**
   * Get user-friendly error message for monthly limit exceeded
   *
   * @param tier - User's subscription tier
   * @param conversationsUsed - Number of conversations used this month
   * @param limit - Maximum conversations allowed
   * @returns Formatted error message for user
   */
  getMonthlyLimitMessage(tier: string, conversationsUsed: number, limit: number): string {
    const tierNames: Record<string, string> = {
      free: 'Free',
      standard: 'Standard',
      plus: 'Plus',
      premium: 'Premium'
    }

    const tierName = tierNames[tier.toLowerCase()] || 'your'
    const conversationWord = limit === 1 ? 'conversation' : 'conversations'

    return `You've reached your monthly limit of ${limit} voice ${conversationWord} for ${tierName} plan. Upgrade to continue using AI Study Buddy Voice this month.`
  }

  /**
   * Get tier limits for display purposes
   *
   * @returns Object mapping tier names to their monthly conversation limits
   */
  static getTierLimits(): Record<string, number> {
    return {
      free: 1,
      standard: 3,
      plus: 10,
      premium: -1 // unlimited
    }
  }

  /**
   * Get recommended upgrade tier based on current tier
   *
   * @param currentTier - User's current tier
   * @returns Recommended tier to upgrade to
   */
  static getRecommendedUpgradeTier(currentTier: string): string {
    const upgradePath: Record<string, string> = {
      free: 'standard',
      standard: 'plus',
      plus: 'premium',
      premium: 'premium'
    }

    return upgradePath[currentTier.toLowerCase()] || 'standard'
  }
}
