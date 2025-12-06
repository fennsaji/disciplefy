/**
 * Voice Quota Service
 *
 * Handles voice conversation quotas and limits:
 * - Per-conversation message limits (50 messages for non-premium)
 * - Premium users have unlimited messages per conversation
 *
 * Note: Monthly conversation quota (10/month for standard) is checked
 * at conversation START in the frontend, not here.
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Result of message limit check
 */
export interface MessageLimitResult {
  canProceed: boolean
  messageCount: number
  limit: number
  remaining: number
}

/**
 * Service for managing voice conversation quotas
 */
export class VoiceQuotaService {
  private readonly MAX_MESSAGES_PER_CONVERSATION = 50

  constructor(private readonly supabase: SupabaseClient) {}

  /**
   * Check if a conversation has exceeded its message limit
   * Premium users bypass this limit entirely
   *
   * @param conversationId - The conversation ID
   * @param tier - User's subscription tier
   */
  async checkMessageLimit(
    conversationId: string,
    tier: string
  ): Promise<MessageLimitResult> {
    // Premium users have unlimited messages per conversation
    if (tier === 'premium') {
      return {
        canProceed: true,
        messageCount: 0,
        limit: -1,
        remaining: -1
      }
    }

    // Get current message count
    const { count, error } = await this.supabase
      .from('voice_conversation_messages')
      .select('*', { count: 'exact', head: true })
      .eq('conversation_id', conversationId)

    if (error) {
      console.error('[VoiceQuota] Error checking message limit:', error)
      // On error, allow proceeding but log the issue
      return {
        canProceed: true,
        messageCount: 0,
        limit: this.MAX_MESSAGES_PER_CONVERSATION,
        remaining: this.MAX_MESSAGES_PER_CONVERSATION
      }
    }

    const messageCount = count || 0
    const remaining = this.MAX_MESSAGES_PER_CONVERSATION - messageCount

    return {
      canProceed: messageCount < this.MAX_MESSAGES_PER_CONVERSATION,
      messageCount,
      limit: this.MAX_MESSAGES_PER_CONVERSATION,
      remaining: Math.max(0, remaining)
    }
  }

  /**
   * Get the maximum messages allowed per conversation
   */
  get maxMessagesPerConversation(): number {
    return this.MAX_MESSAGES_PER_CONVERSATION
  }
}
