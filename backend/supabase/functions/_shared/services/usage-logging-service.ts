/**
 * Usage Logging Service
 * Centralized service for logging all operations with cost attribution and profitability tracking
 */

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type {
  LogUsageRequest,
  LogUsageResponse,
  SubscriptionTier,
  FeatureName,
  LLMProvider,
} from '../types/usage-types.ts';

// ========================================
// Configuration
// ========================================

const REVENUE_ALLOCATION_PER_100_OPS: Record<SubscriptionTier, number> = {
  free: 0.00, // ₹0/month
  standard: 0.79, // ₹79/month / 100 operations
  plus: 1.49, // ₹149/month / 100 operations
  premium: 4.99, // ₹499/month / 100 operations
};

const USD_TO_INR_RATE = 83.5; // Update periodically

// ========================================
// Usage Logging Service Class
// ========================================

export class UsageLoggingService {
  private supabaseClient: SupabaseClient;

  constructor(supabaseUrl: string, supabaseKey: string) {
    this.supabaseClient = createClient(supabaseUrl, supabaseKey);
  }

  /**
   * Log a usage operation with automatic profit margin calculation
   */
  async logUsage(request: LogUsageRequest): Promise<LogUsageResponse> {
    try {
      // Calculate revenue allocation based on tier
      const estimatedRevenue = this.calculateAllocatedRevenue(
        request.tier,
        request.featureName
      );

      // Convert LLM cost to INR
      const costInr = (request.llmCostUsd || 0) * USD_TO_INR_RATE;

      // Calculate profit margin
      const profitMargin = estimatedRevenue - costInr;

      // Call RPC function to log usage
      const { data, error } = await this.supabaseClient.rpc('log_usage', {
        p_user_id: request.userId,
        p_tier: request.tier,
        p_feature_name: request.featureName,
        p_operation_type: request.operationType,
        p_tokens_consumed: request.tokensConsumed || 0,
        p_llm_provider: request.llmProvider || null,
        p_llm_model: request.llmModel || null,
        p_llm_input_tokens: request.llmInputTokens || null,
        p_llm_output_tokens: request.llmOutputTokens || null,
        p_llm_cost_usd: request.llmCostUsd || null,
        p_request_metadata: request.requestMetadata || null,
        p_response_metadata: request.responseMetadata || null,
      });

      if (error) {
        console.error('Error logging usage:', error);
        throw new Error(`Failed to log usage: ${error.message}`);
      }

      return {
        logId: data,
        success: true,
        profitMargin,
        estimatedRevenue,
      };
    } catch (error) {
      console.error('Usage logging failed:', error);
      throw error;
    }
  }

  /**
   * Calculate allocated revenue per operation based on tier and feature
   * @private
   */
  private calculateAllocatedRevenue(
    tier: SubscriptionTier,
    featureName: FeatureName
  ): number {
    // Base revenue allocation from subscription tier
    const baseRevenue = REVENUE_ALLOCATION_PER_100_OPS[tier];

    // Feature-specific multipliers (some features are more valuable)
    const featureMultiplier = this.getFeatureMultiplier(featureName);

    return baseRevenue * featureMultiplier;
  }

  /**
   * Get feature-specific revenue multiplier
   * @private
   */
  private getFeatureMultiplier(featureName: FeatureName): number {
    const multipliers: Record<FeatureName, number> = {
      study_generate: 2.0, // Core feature, higher value
      study_followup: 1.0, // Standard value
      voice_conversation: 1.5, // Premium feature
      memory_practice: 0.5, // Non-LLM operation, lower value
      memory_verse_add: 0.5, // Non-LLM operation
      subscription_change: 0.0, // Administrative action
      token_purchase: 0.0, // Revenue already captured via payment
      user_login: 0.0, // No direct revenue
      admin_operation: 0.0, // Administrative
      continue_learning: 0.0, // Read operation, no direct revenue
      invoice_pdf_generation: 0.0, // Document generation, no direct revenue
    };

    return multipliers[featureName] || 1.0;
  }

  /**
   * Calculate profit margin from revenue and cost
   */
  calculateProfitMargin(revenueInr: number, costUsd: number): number {
    const costInr = costUsd * USD_TO_INR_RATE;
    return revenueInr - costInr;
  }

  /**
   * Log a non-LLM operation (memory practice, login, etc.)
   */
  async logNonLLMOperation(
    userId: string,
    tier: SubscriptionTier,
    featureName: FeatureName,
    operationType: string,
    metadata?: Record<string, unknown>
  ): Promise<LogUsageResponse> {
    return this.logUsage({
      userId,
      tier,
      featureName,
      operationType: operationType as any,
      tokensConsumed: 0,
      llmCostUsd: 0.0,
      requestMetadata: metadata,
      responseMetadata: { success: true },
    });
  }

  /**
   * Log a study generation operation
   */
  async logStudyGeneration(
    userId: string,
    tier: SubscriptionTier,
    tokensConsumed: number,
    llmCost: number,
    studyMode: string,
    language: string,
    success: boolean,
    latencyMs: number
  ): Promise<LogUsageResponse> {
    return this.logUsage({
      userId,
      tier,
      featureName: 'study_generate',
      operationType: 'create',
      tokensConsumed,
      llmProvider: 'openai',
      llmModel: 'gpt-3.5-turbo',
      llmCostUsd: llmCost,
      requestMetadata: {
        study_mode: studyMode,
        language,
      },
      responseMetadata: {
        success,
        latency_ms: latencyMs,
      },
    });
  }

  /**
   * Log a follow-up question operation
   */
  async logFollowUpQuestion(
    userId: string,
    tier: SubscriptionTier,
    llmCost: number,
    studyGuideId: string,
    success: boolean,
    latencyMs: number
  ): Promise<LogUsageResponse> {
    return this.logUsage({
      userId,
      tier,
      featureName: 'study_followup',
      operationType: 'create',
      tokensConsumed: 5, // Follow-ups cost 5 tokens
      llmProvider: 'anthropic',
      llmModel: 'claude-haiku-3',
      llmCostUsd: llmCost,
      requestMetadata: {
        study_guide_id: studyGuideId,
      },
      responseMetadata: {
        success,
        latency_ms: latencyMs,
      },
    });
  }

  /**
   * Log a voice conversation operation
   */
  async logVoiceConversation(
    userId: string,
    tier: SubscriptionTier,
    llmCost: number,
    conversationType: string,
    durationSeconds: number,
    success: boolean
  ): Promise<LogUsageResponse> {
    return this.logUsage({
      userId,
      tier,
      featureName: 'voice_conversation',
      operationType: 'create',
      tokensConsumed: 0, // Voice doesn't use app tokens
      llmProvider: 'elevenlabs',
      llmModel: 'eleven-turbo-v2',
      llmCostUsd: llmCost,
      requestMetadata: {
        conversation_type: conversationType,
        duration_seconds: durationSeconds,
      },
      responseMetadata: {
        success,
      },
    });
  }

  /**
   * Log a memory practice session
   */
  async logMemoryPractice(
    userId: string,
    tier: SubscriptionTier,
    practiceMode: string,
    verseId: string,
    success: boolean,
    score: number
  ): Promise<LogUsageResponse> {
    return this.logUsage({
      userId,
      tier,
      featureName: 'memory_practice',
      operationType: 'consume',
      tokensConsumed: 0,
      llmCostUsd: 0.0,
      requestMetadata: {
        practice_mode: practiceMode,
        verse_id: verseId,
        score,
      },
      responseMetadata: {
        success,
      },
    });
  }

  /**
   * Batch log multiple operations (for efficiency)
   */
  async logBatch(requests: LogUsageRequest[]): Promise<LogUsageResponse[]> {
    const results: LogUsageResponse[] = [];

    for (const request of requests) {
      try {
        const result = await this.logUsage(request);
        results.push(result);
      } catch (error) {
        console.error('Batch logging error for request:', request, error);
        // Continue with other logs even if one fails
        results.push({
          logId: '',
          success: false,
          profitMargin: 0,
          estimatedRevenue: 0,
        });
      }
    }

    return results;
  }
}

// ========================================
// Singleton Instance Factory
// ========================================

let usageLoggingServiceInstance: UsageLoggingService | null = null;

export function getUsageLoggingService(
  supabaseUrl: string,
  supabaseKey: string
): UsageLoggingService {
  if (!usageLoggingServiceInstance) {
    usageLoggingServiceInstance = new UsageLoggingService(supabaseUrl, supabaseKey);
  }
  return usageLoggingServiceInstance;
}

// ========================================
// Helper Functions
// ========================================

/**
 * Convert USD to INR using current exchange rate
 */
export function convertUSDtoINR(usd: number): number {
  return usd * USD_TO_INR_RATE;
}

/**
 * Convert INR to USD using current exchange rate
 */
export function convertINRtoUSD(inr: number): number {
  return inr / USD_TO_INR_RATE;
}

/**
 * Format currency for display
 */
export function formatCurrency(amount: number, currency: 'USD' | 'INR'): string {
  const symbol = currency === 'USD' ? '$' : '₹';
  return `${symbol}${amount.toFixed(2)}`;
}
