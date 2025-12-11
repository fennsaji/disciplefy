/**
 * Voice Conversation Repository
 *
 * Handles all database operations for voice conversations including:
 * - Message history management
 * - User context retrieval
 * - Study guide context fetching
 * - Conversation statistics
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Message in a voice conversation
 */
export interface ConversationMessage {
  role: 'user' | 'assistant' | 'system'
  content: string
}

/**
 * Database row structure for voice_conversation_messages table
 */
interface VoiceMessageRow {
  readonly role: string
  readonly content_text: string | null
}

/**
 * Valid message roles for voice conversations
 */
type ValidMessageRole = 'user' | 'assistant'

/**
 * Type guard to validate message role
 */
function isValidMessageRole(role: string): role is ValidMessageRole {
  return role === 'user' || role === 'assistant'
}

/**
 * Parameters for saving a message
 */
export interface SaveMessageParams {
  conversationId: string
  userId: string
  role: 'user' | 'assistant'
  content: string
  language: string
  metadata?: {
    llmModelUsed?: string
    llmTokensUsed?: number
    scriptureReferences?: string[]
  }
}

/**
 * User profile context for personalization
 */
export interface UserProfileContext {
  maturityLevel: string
  recentTopics: string[]
}

/**
 * Study guide context for conversation enrichment
 */
export interface StudyContext {
  inputValue: string
  inputType: string
  summary?: string
  context?: string
  interpretation?: string
}

/**
 * Message count result
 */
export interface MessageCountResult {
  count: number
  canAddMore: boolean
}

/**
 * Repository for voice conversation data operations
 */
export class VoiceConversationRepository {
  private readonly MAX_HISTORY_MESSAGES = 10
  private readonly MAX_MESSAGES_PER_CONVERSATION = 50

  constructor(private readonly supabase: SupabaseClient) {}

  /**
   * Get conversation history for context window
   * Returns the last N messages for LLM context
   *
   * @param conversationId - The conversation ID
   * @param limit - Maximum messages to return (default: 10)
   */
  async getConversationHistory(
    conversationId: string,
    limit: number = this.MAX_HISTORY_MESSAGES
  ): Promise<ConversationMessage[]> {
    const { data: messages, error } = await this.supabase
      .from('voice_conversation_messages')
      .select('role, content_text')
      .eq('conversation_id', conversationId)
      .order('message_order', { ascending: true })
      .limit(limit)

    if (error) {
      console.error('[VoiceRepo] Error fetching conversation history:', error)
      return []
    }

    if (!messages) return []

    return messages
      .filter((msg: VoiceMessageRow): msg is VoiceMessageRow & { role: ValidMessageRole } => 
        isValidMessageRole(msg.role)
      )
      .map((msg): ConversationMessage => ({
        role: msg.role,
        content: msg.content_text ?? ''
      }))
  }

  /**
   * Get the current message count for a conversation
   *
   * @param conversationId - The conversation ID
   */
  async getMessageCount(conversationId: string): Promise<MessageCountResult> {
    const { count, error } = await this.supabase
      .from('voice_conversation_messages')
      .select('*', { count: 'exact', head: true })
      .eq('conversation_id', conversationId)

    if (error) {
      console.error('[VoiceRepo] Error getting message count:', error)
      return { count: 0, canAddMore: true }
    }

    const messageCount = count || 0
    return {
      count: messageCount,
      canAddMore: messageCount < this.MAX_MESSAGES_PER_CONVERSATION
    }
  }

  /**
   * Save a message to the conversation
   * Also updates conversation statistics
   *
   * @param params - Message parameters
   */
  async saveMessage(params: SaveMessageParams): Promise<void> {
    const { conversationId, userId, role, content, language, metadata } = params

    // Get current message count for ordering
    const { count: currentCount } = await this.getMessageCount(conversationId)

    // Insert the message
    const { error: insertError } = await this.supabase
      .from('voice_conversation_messages')
      .insert({
        conversation_id: conversationId,
        user_id: userId,
        message_order: currentCount,
        role,
        content_text: content,
        content_language: language,
        llm_model_used: metadata?.llmModelUsed,
        llm_tokens_used: metadata?.llmTokensUsed,
        scripture_references: metadata?.scriptureReferences,
      })

    if (insertError) {
      console.error('[VoiceRepo] Error saving message:', insertError)
      throw new Error('Failed to save message')
    }

    // Update conversation stats
    await this.updateConversationStats(conversationId, currentCount + 1)
  }

  /**
   * Update conversation statistics
   *
   * @param conversationId - The conversation ID
   * @param totalMessages - New total message count
   */
  async updateConversationStats(
    conversationId: string,
    totalMessages: number
  ): Promise<void> {
    const { error } = await this.supabase
      .from('voice_conversations')
      .update({
        total_messages: totalMessages,
        updated_at: new Date().toISOString(),
      })
      .eq('id', conversationId)

    if (error) {
      console.error('[VoiceRepo] Error updating conversation stats:', error)
      // Don't throw - stats update is not critical
    }
  }

  /**
   * Get user profile context for personalized responses
   *
   * @param userId - The user ID
   */
  async getUserContext(userId: string): Promise<UserProfileContext> {
    const { data: profile, error } = await this.supabase
      .from('user_profiles')
      .select('interests')
      .eq('id', userId)
      .single()

    if (error) {
      console.error('[VoiceRepo] Error fetching user context:', error)
      return {
        maturityLevel: 'intermediate',
        recentTopics: []
      }
    }

    return {
      maturityLevel: 'intermediate', // Not stored in DB, use default
      recentTopics: profile?.interests || []
    }
  }

  /**
   * Get study guide context for conversation enrichment
   * Returns formatted context string for LLM prompt
   *
   * @param studyGuideId - The study guide ID
   */
  async getStudyContext(studyGuideId: string): Promise<string | null> {
    const { data: guide, error } = await this.supabase
      .from('study_guides')
      .select('input_value, input_type, summary, context, interpretation')
      .eq('id', studyGuideId)
      .single()

    if (error || !guide) {
      console.error('[VoiceRepo] Error fetching study context:', error)
      return null
    }

    let context = `The user is studying: ${guide.input_value} (${guide.input_type})\n`
    if (guide.summary) context += `Summary: ${guide.summary}\n`
    if (guide.context) context += `Context: ${guide.context}\n`
    if (guide.interpretation) context += `Interpretation: ${guide.interpretation}`

    return context
  }

  /**
   * Get the maximum messages allowed per conversation
   */
  get maxMessagesPerConversation(): number {
    return this.MAX_MESSAGES_PER_CONVERSATION
  }
}
