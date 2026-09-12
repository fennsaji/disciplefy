/**
 * LLM Cost Tracking Service
 * Calculates and tracks actual LLM provider costs (OpenAI, Anthropic, ElevenLabs)
 */

import type { LLMProvider, LLMCostCalculation } from '../types/usage-types.ts';
import { FALLBACK_USD_TO_INR } from './exchange-rate.ts';

// ========================================
// LLM Pricing Configuration
// ========================================
//
// Checked against the published rate cards on 2026-09-12:
//   platform.claude.com/docs/en/about-claude/pricing
//   developers.openai.com/api/docs/pricing
//
// Every figure below is per 1K tokens; the rate cards quote per million, so
// divide by 1000 when updating. These numbers are the app's only measure of
// spend — the daily cost ceiling, the pre-warm budget and the per-user daily
// cost limit all sum usage_logs.llm_cost_usd, which is computed from here — so
// a stale entry silently moves real spending limits, in whichever direction it
// is wrong.

const LLM_PRICING = {
  openai: {
    'gpt-3.5-turbo': {
      input_per_1k: 0.0005, // $0.50 per million input tokens
      output_per_1k: 0.0015, // $1.50 per million output tokens
    },
    'gpt-4-turbo': {
      input_per_1k: 0.01, // $10 per million input tokens
      output_per_1k: 0.03, // $30 per million output tokens
    },
    'gpt-4o-mini-2024-07-18': {
      input_per_1k: 0.00015, // $0.15 per million input tokens
      output_per_1k: 0.0006, // $0.60 per million output tokens
    },
    'gpt-4.1-mini-2025-04-14': {
      // Not priced like gpt-4o-mini, despite the name: 4.1-mini is $0.40/$1.60
      // per million against 4o-mini's $0.15/$0.60. Assuming they matched
      // under-counted every premium-English generation by about 2.7x.
      input_per_1k: 0.0004, // $0.40 per million input tokens
      output_per_1k: 0.0016, // $1.60 per million output tokens
    },
  },
  anthropic: {
    'claude-haiku-3': {
      input_per_1k: 0.00025, // $0.00025 per 1K input tokens
      output_per_1k: 0.00125, // $0.00125 per 1K output tokens
    },
    'claude-sonnet-3.5': {
      input_per_1k: 0.003, // $0.003 per 1K input tokens
      output_per_1k: 0.015, // $0.015 per 1K output tokens
    },
    'claude-sonnet-4-5-20250929': {
      input_per_1k: 0.003, // $0.003 per 1K input tokens
      output_per_1k: 0.015, // $0.015 per 1K output tokens
    },
    'claude-haiku-4-5-20251001': {
      input_per_1k: 0.001, // $1 per million input tokens
      output_per_1k: 0.005, // $5 per million output tokens
    },
  },
  elevenlabs: {
    'eleven-turbo-v2': {
      per_character: 0.00003, // $0.00003 per character
    },
  },
};

/**
 * A cache read is billed at 10% of the input price, a 5-minute cache write at
 * 125%. Both verified against the rate card on 2026-09-12.
 *
 * The write multiplier assumes the default 5-minute TTL, which is what this
 * codebase uses — nothing requests the 1-hour TTL. A 1-hour write is billed at
 * 200%, so if one is ever introduced this constant stops being right and the
 * write has to be priced by its own TTL.
 */
const CACHE_READ_MULTIPLIER = 0.1;
const CACHE_WRITE_MULTIPLIER = 1.25;

/**
 * Used when a model has no entry above. Deliberately dearer than anything we
 * run, so an untracked model overstates rather than disappears.
 *
 * Set at Opus-class rates ($5/$25 per million). The old $3/$15 was described as
 * "the dearest rate we know" but had stopped being true — Opus is $5/$25 and
 * the Fable line $10/$50 — so switching to a model that was not in the table
 * would have under-counted rather than over-counted, which is the one direction
 * this fallback exists to avoid.
 */
const FALLBACK_PRICING = { input_per_1k: 0.005, output_per_1k: 0.025 };

/** Cached-token counts, as Anthropic reports them alongside input_tokens. */
export interface CacheTokenCounts {
  readonly cacheReadTokens?: number;
  readonly cacheCreationTokens?: number;
}

/**
 * Display-side conversions only. The authoritative rate is
 * `system_config.usd_to_inr_rate` (see exchange-rate.ts); these helpers are
 * synchronous, so they use the shared fallback rather than reading config.
 */
const USD_TO_INR_RATE = FALLBACK_USD_TO_INR;

// ========================================
// Cost Tracking Service
// ========================================

export class CostTrackingService {
  /**
   * Calculate LLM cost based on token usage
   */
  calculateCost(
    provider: LLMProvider,
    model: string,
    inputTokens: number,
    outputTokens: number,
    cacheTokens?: CacheTokenCounts
  ): LLMCostCalculation {
    let totalCost = 0;

    const pricing = this.getModelPricing(provider, model);

    if (pricing) {
      // Anthropic reports cached tokens separately from input_tokens: a cache
      // read is billed at 10% of the input price and a cache write at 125%.
      // Both are additions. Treating a read as a discount on input_tokens —
      // which never included it — made cache-heavy calls look free, and could
      // drive a recorded cost below zero.
      const billableInput = inputTokens +
        (cacheTokens?.cacheReadTokens ?? 0) * CACHE_READ_MULTIPLIER +
        (cacheTokens?.cacheCreationTokens ?? 0) * CACHE_WRITE_MULTIPLIER;

      totalCost = (billableInput / 1000) * pricing.input_per_1k +
                 (outputTokens / 1000) * pricing.output_per_1k;
    } else {
      // Silently costing nothing is worse than costing too much: an untracked
      // model would spend real money while every budget read zero. Fall back to
      // the dearest price we know, so the gap shows up rather than hiding.
      const fallback = FALLBACK_PRICING;
      totalCost = (inputTokens / 1000) * fallback.input_per_1k +
                 (outputTokens / 1000) * fallback.output_per_1k;
      console.error(
        `[CostTracking] No price for ${provider}/${model}. Charging the highest known rate ` +
        `($${fallback.input_per_1k}/$${fallback.output_per_1k} per 1K) so the spend is visible. Add it to LLM_PRICING.`
      );
    }

    return {
      provider,
      model,
      inputTokens,
      outputTokens,
      totalCost,
    };
  }

  /**
   * Calculate ElevenLabs TTS cost based on character count
   */
  calculateTTSCost(characterCount: number): number {
    const pricing = LLM_PRICING.elevenlabs['eleven-turbo-v2'];
    return characterCount * pricing.per_character;
  }

  /**
   * Estimate LLM cost for study generation based on study mode and language
   */
  estimateStudyGenerationCost(studyMode: string, language: string): number {
    // Base token estimates for different study modes
    const tokenEstimates: Record<string, { input: number; output: number }> = {
      quick: { input: 500, output: 800 },
      standard: { input: 1000, output: 1500 },
      deep: { input: 1500, output: 2500 },
      lectio: { input: 1200, output: 2000 },
      sermon: { input: 2000, output: 3500 },
    };

    // Language multiplier (non-English requires more tokens)
    const languageMultiplier = language === 'en' ? 1.0 : 1.3;

    const estimate = tokenEstimates[studyMode] || tokenEstimates.standard;
    const adjustedInput = Math.round(estimate.input * languageMultiplier);
    const adjustedOutput = Math.round(estimate.output * languageMultiplier);

    const cost = this.calculateCost('openai', 'gpt-3.5-turbo', adjustedInput, adjustedOutput);
    return cost.totalCost;
  }

  /**
   * Estimate follow-up question cost (uses Claude Haiku)
   */
  estimateFollowUpCost(): number {
    // Follow-ups are short, ~200 input, ~300 output tokens
    const cost = this.calculateCost('anthropic', 'claude-haiku-3', 200, 300);
    return cost.totalCost;
  }

  /**
   * Estimate voice conversation cost based on duration
   */
  estimateVoiceConversationCost(durationSeconds: number): number {
    // Approximate: 150 characters per second of speech
    const characterCount = durationSeconds * 150;
    return this.calculateTTSCost(characterCount);
  }

  /**
   * Convert cost from USD to INR
   */
  convertToINR(costUsd: number): number {
    return costUsd * USD_TO_INR_RATE;
  }

  /**
   * Convert cost from INR to USD
   */
  convertToUSD(costInr: number): number {
    return costInr / USD_TO_INR_RATE;
  }

  /**
   * Get pricing information for a specific model
   */
  getModelPricing(provider: LLMProvider, model: string): any {
    if (provider === 'openai') {
      return LLM_PRICING.openai[model as keyof typeof LLM_PRICING.openai] || null;
    }
    if (provider === 'anthropic') {
      return LLM_PRICING.anthropic[model as keyof typeof LLM_PRICING.anthropic] || null;
    }
    if (provider === 'elevenlabs') {
      return LLM_PRICING.elevenlabs[model as keyof typeof LLM_PRICING.elevenlabs] || null;
    }
    return null;
  }

  /**
   * Calculate cost breakdown for analytics
   */
  getCostBreakdown(
    provider: LLMProvider,
    model: string,
    inputTokens: number,
    outputTokens: number
  ): {
    inputCost: number;
    outputCost: number;
    totalCost: number;
    inputTokens: number;
    outputTokens: number;
  } {
    let inputCost = 0;
    let outputCost = 0;

    if (provider === 'openai' && LLM_PRICING.openai[model as keyof typeof LLM_PRICING.openai]) {
      const pricing = LLM_PRICING.openai[model as keyof typeof LLM_PRICING.openai];
      inputCost = (inputTokens / 1000) * pricing.input_per_1k;
      outputCost = (outputTokens / 1000) * pricing.output_per_1k;
    } else if (provider === 'anthropic' && LLM_PRICING.anthropic[model as keyof typeof LLM_PRICING.anthropic]) {
      const pricing = LLM_PRICING.anthropic[model as keyof typeof LLM_PRICING.anthropic];
      inputCost = (inputTokens / 1000) * pricing.input_per_1k;
      outputCost = (outputTokens / 1000) * pricing.output_per_1k;
    }

    return {
      inputCost,
      outputCost,
      totalCost: inputCost + outputCost,
      inputTokens,
      outputTokens,
    };
  }

  /**
   * Format cost for display
   */
  formatCost(costUsd: number, currency: 'USD' | 'INR' = 'USD'): string {
    if (currency === 'INR') {
      const costInr = this.convertToINR(costUsd);
      return `₹${costInr.toFixed(2)}`;
    }
    return `$${costUsd.toFixed(4)}`;
  }

  /**
   * Calculate cost savings between two models
   */
  calculateSavings(
    originalCost: number,
    optimizedCost: number
  ): {
    savingsUsd: number;
    savingsInr: number;
    savingsPercentage: number;
  } {
    const savingsUsd = originalCost - optimizedCost;
    const savingsInr = this.convertToINR(savingsUsd);
    const savingsPercentage = ((savingsUsd / originalCost) * 100);

    return {
      savingsUsd,
      savingsInr,
      savingsPercentage,
    };
  }
}

// ========================================
// Singleton Instance Factory
// ========================================

let costTrackingServiceInstance: CostTrackingService | null = null;

export function getCostTrackingService(): CostTrackingService {
  if (!costTrackingServiceInstance) {
    costTrackingServiceInstance = new CostTrackingService();
  }
  return costTrackingServiceInstance;
}

// ========================================
// Helper Functions
// ========================================

/**
 * Quick cost estimate for common operations
 */
export function quickCostEstimate(operation: string, params?: any): number {
  const service = getCostTrackingService();

  switch (operation) {
    case 'study_generate_quick':
      return service.estimateStudyGenerationCost('quick', params?.language || 'en');
    case 'study_generate_standard':
      return service.estimateStudyGenerationCost('standard', params?.language || 'en');
    case 'study_generate_deep':
      return service.estimateStudyGenerationCost('deep', params?.language || 'en');
    case 'followup':
      return service.estimateFollowUpCost();
    case 'voice':
      return service.estimateVoiceConversationCost(params?.duration || 60);
    default:
      return 0;
  }
}
