/**
 * Rate Limiting Service
 * Enforces tier-based rate limits, detects abuse, and manages request throttling
 */

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type {
  RateLimitRule,
  RateLimitCheck,
  SubscriptionTier,
  FeatureName,
} from '../types/usage-types.ts';

// ========================================
// Rate Limiting Service Class
// ========================================

export class RateLimitService {
  private supabaseClient: SupabaseClient;
  private ruleCache: Map<string, RateLimitRule> = new Map();
  private usageCache: Map<string, { count: number; resetAt: Date }> = new Map();

  constructor(supabaseUrl: string, supabaseKey: string) {
    this.supabaseClient = createClient(supabaseUrl, supabaseKey);
  }

  /**
   * Check if a user can perform an operation based on rate limits
   */
  async checkRateLimit(
    userId: string,
    tier: SubscriptionTier,
    featureName: FeatureName
  ): Promise<RateLimitCheck> {
    try {
      // Get rate limit rule for this tier and feature
      const rule = await this.getRateLimitRule(featureName, tier);

      if (!rule || !rule.is_active) {
        // No active rate limit rule, allow operation
        return {
          allowed: true,
          current_usage: 0,
          limit: Infinity,
          reset_at: new Date(Date.now() + 3600000), // 1 hour from now
        };
      }

      // Check hourly limit
      const hourlyCheck = await this.checkHourlyLimit(
        userId,
        featureName,
        rule.max_requests_per_hour || Infinity
      );

      if (!hourlyCheck.allowed) {
        return hourlyCheck;
      }

      // Check daily limit
      const dailyCheck = await this.checkDailyLimit(
        userId,
        featureName,
        rule.max_requests_per_day || Infinity
      );

      return dailyCheck;
    } catch (error) {
      console.error('Rate limit check failed:', error);
      // Fail open: allow the operation if rate limit check fails
      return {
        allowed: true,
        current_usage: 0,
        limit: Infinity,
        reset_at: new Date(Date.now() + 3600000),
        reason: 'Rate limit check failed, defaulting to allow',
      };
    }
  }

  /**
   * Check hourly rate limit
   * @private
   */
  private async checkHourlyLimit(
    userId: string,
    featureName: string,
    limit: number
  ): Promise<RateLimitCheck> {
    const cacheKey = `hourly:${userId}:${featureName}`;
    const now = new Date();
    const hourAgo = new Date(now.getTime() - 3600000); // 1 hour ago
    const nextHour = new Date(now.getTime() + 3600000); // 1 hour from now

    // Query usage logs for last hour
    const { data, error } = await this.supabaseClient
      .from('usage_logs')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('feature_name', featureName)
      .gte('created_at', hourAgo.toISOString());

    if (error) {
      console.error('Error checking hourly limit:', error);
      throw error;
    }

    const currentUsage = data?.length || 0;

    return {
      allowed: currentUsage < limit,
      current_usage: currentUsage,
      limit,
      reset_at: nextHour,
      reason: currentUsage >= limit
        ? `Hourly rate limit exceeded (${currentUsage}/${limit})`
        : undefined,
    };
  }

  /**
   * Check daily rate limit
   * @private
   */
  private async checkDailyLimit(
    userId: string,
    featureName: string,
    limit: number
  ): Promise<RateLimitCheck> {
    const now = new Date();
    const dayAgo = new Date(now.getTime() - 86400000); // 24 hours ago
    const nextDay = new Date(now.getTime() + 86400000); // 24 hours from now

    // Query usage logs for last 24 hours
    const { data, error } = await this.supabaseClient
      .from('usage_logs')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('feature_name', featureName)
      .gte('created_at', dayAgo.toISOString());

    if (error) {
      console.error('Error checking daily limit:', error);
      throw error;
    }

    const currentUsage = data?.length || 0;

    return {
      allowed: currentUsage < limit,
      current_usage: currentUsage,
      limit,
      reset_at: nextDay,
      reason: currentUsage >= limit
        ? `Daily rate limit exceeded (${currentUsage}/${limit})`
        : undefined,
    };
  }

  /**
   * Get rate limit rule for a feature and tier (with caching)
   * @private
   */
  private async getRateLimitRule(
    featureName: FeatureName,
    tier: SubscriptionTier
  ): Promise<RateLimitRule | null> {
    const cacheKey = `${featureName}:${tier}`;

    // Check cache first (cache for 5 minutes)
    const cached = this.ruleCache.get(cacheKey);
    if (cached) {
      return cached;
    }

    // Fetch from database
    const { data, error } = await this.supabaseClient
      .from('rate_limit_rules')
      .select('*')
      .eq('feature_name', featureName)
      .eq('tier', tier)
      .eq('is_active', true)
      .single();

    if (error) {
      console.error('Error fetching rate limit rule:', error);
      return null;
    }

    // Cache the rule
    if (data) {
      this.ruleCache.set(cacheKey, data);
      // Clear cache after 5 minutes
      setTimeout(() => this.ruleCache.delete(cacheKey), 300000);
    }

    return data;
  }

  /**
   * Increment rate limit counter after successful operation
   */
  async incrementCounter(userId: string, featureName: FeatureName): Promise<void> {
    // This is handled automatically by the usage logging
    // No additional action needed as we query usage_logs for rate limiting
  }

  /**
   * Detect potential abuse based on unusual usage patterns
   */
  async detectAbuse(
    userId: string,
    featureName: FeatureName,
    threshold: number = 5.0
  ): Promise<boolean> {
    try {
      // Call RPC function to detect anomalies
      const { data, error } = await this.supabaseClient
        .rpc('detect_usage_anomalies', { p_threshold_multiplier: threshold });

      if (error) {
        console.error('Error detecting abuse:', error);
        return false;
      }

      // Check if this user + feature combination is flagged
      const anomaly = (data || []).find(
        (a: any) => a.user_id === userId && a.feature_name === featureName
      );

      return !!anomaly;
    } catch (error) {
      console.error('Abuse detection failed:', error);
      return false;
    }
  }

  /**
   * Get current usage for a user and feature
   */
  async getCurrentUsage(
    userId: string,
    featureName: FeatureName,
    period: 'hour' | 'day' = 'hour'
  ): Promise<number> {
    const now = new Date();
    const cutoff = period === 'hour'
      ? new Date(now.getTime() - 3600000) // 1 hour ago
      : new Date(now.getTime() - 86400000); // 24 hours ago

    const { data, error } = await this.supabaseClient
      .from('usage_logs')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('feature_name', featureName)
      .gte('created_at', cutoff.toISOString());

    if (error) {
      console.error('Error getting current usage:', error);
      return 0;
    }

    return data?.length || 0;
  }

  /**
   * Check cost-based rate limit (daily cost limit)
   */
  async checkCostLimit(
    userId: string,
    tier: SubscriptionTier,
    featureName: FeatureName
  ): Promise<{ allowed: boolean; currentCost: number; limit: number }> {
    // Get rate limit rule with cost limit
    const rule = await this.getRateLimitRule(featureName, tier);

    if (!rule || !rule.max_cost_per_day_usd) {
      return { allowed: true, currentCost: 0, limit: Infinity };
    }

    // Calculate total cost for last 24 hours
    const dayAgo = new Date(Date.now() - 86400000);

    const { data, error } = await this.supabaseClient
      .from('usage_logs')
      .select('llm_cost_usd')
      .eq('user_id', userId)
      .eq('feature_name', featureName)
      .gte('created_at', dayAgo.toISOString());

    if (error) {
      console.error('Error checking cost limit:', error);
      return { allowed: true, currentCost: 0, limit: rule.max_cost_per_day_usd };
    }

    const currentCost = (data || []).reduce((sum, log) => sum + (log.llm_cost_usd || 0), 0);

    return {
      allowed: currentCost < rule.max_cost_per_day_usd,
      currentCost,
      limit: rule.max_cost_per_day_usd,
    };
  }

  /**
   * Clear cache (useful for testing or manual admin operations)
   */
  clearCache(): void {
    this.ruleCache.clear();
    this.usageCache.clear();
  }
}

// ========================================
// Singleton Instance Factory
// ========================================

let rateLimitServiceInstance: RateLimitService | null = null;

export function getRateLimitService(
  supabaseUrl: string,
  supabaseKey: string
): RateLimitService {
  if (!rateLimitServiceInstance) {
    rateLimitServiceInstance = new RateLimitService(supabaseUrl, supabaseKey);
  }
  return rateLimitServiceInstance;
}

// ========================================
// Helper Functions
// ========================================

/**
 * Format rate limit error message for user
 */
export function formatRateLimitError(check: RateLimitCheck, tier: SubscriptionTier): string {
  const resetTime = check.reset_at.toLocaleTimeString();

  return `Rate limit exceeded. You've reached your ${tier} tier limit of ${check.limit} requests. Limit resets at ${resetTime}. Upgrade your plan for higher limits.`;
}

/**
 * Get recommended tier upgrade for rate limit
 */
export function getRecommendedUpgrade(currentTier: SubscriptionTier): SubscriptionTier | null {
  const upgradePath: Record<SubscriptionTier, SubscriptionTier | null> = {
    free: 'standard',
    standard: 'plus',
    plus: 'premium',
    premium: null, // Already at highest tier
  };

  return upgradePath[currentTier];
}
