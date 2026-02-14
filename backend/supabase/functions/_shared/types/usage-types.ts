/**
 * Usage Tracking & Rate Limiting Types
 * Defines interfaces for centralized usage logging, cost tracking, and profitability analysis
 */

// ========================================
// Usage Log Types
// ========================================

export type SubscriptionTier = 'free' | 'standard' | 'plus' | 'premium';

export type FeatureName =
  | 'study_generate'
  | 'study_followup'
  | 'voice_conversation'
  | 'memory_practice'
  | 'memory_verse_add'
  | 'subscription_change'
  | 'token_purchase'
  | 'user_login'
  | 'admin_operation'
  | 'continue_learning';

export type OperationType = 'create' | 'read' | 'update' | 'delete' | 'consume';

export type LLMProvider = 'openai' | 'anthropic' | 'elevenlabs' | null;

export interface UsageLogEntry {
  id?: string;
  user_id: string;
  session_id?: string;
  tier: SubscriptionTier;
  feature_name: FeatureName;
  operation_type: OperationType;
  tokens_consumed?: number;
  llm_provider?: LLMProvider;
  llm_model?: string;
  llm_input_tokens?: number;
  llm_output_tokens?: number;
  llm_cost_usd?: number;
  request_metadata?: Record<string, unknown>;
  response_metadata?: Record<string, unknown>;
  estimated_revenue_inr?: number;
  profit_margin_inr?: number;
  created_at?: string;
}

// ========================================
// LLM Cost Tracking Types
// ========================================

export interface LLMCostEntry {
  id?: string;
  operation_id?: string;
  provider: string;
  model: string;
  input_tokens?: number;
  output_tokens?: number;
  cost_usd: number;
  request_id?: string;
  created_at?: string;
}

export interface LLMCostCalculation {
  provider: LLMProvider;
  model: string;
  inputTokens: number;
  outputTokens: number;
  totalCost: number; // USD
}

// ========================================
// Rate Limiting Types
// ========================================

export interface RateLimitRule {
  id?: string;
  feature_name: string;
  tier: SubscriptionTier;
  max_requests_per_hour?: number;
  max_requests_per_day?: number;
  max_cost_per_day_usd?: number;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface RateLimitCheck {
  allowed: boolean;
  current_usage: number;
  limit: number;
  reset_at: Date;
  reason?: string;
}

// ========================================
// Analytics Types
// ========================================

export interface UsageStats {
  total_operations: number;
  total_cost_usd: number;
  total_revenue_inr: number;
  total_profit_margin_inr: number;
  avg_cost_usd: number;
  avg_revenue_inr: number;
  avg_profit_margin_inr: number;
  unique_users: number;
}

export interface ProfitabilityReport {
  tier: SubscriptionTier;
  feature: FeatureName;
  total_operations: number;
  avg_llm_cost_usd: number;
  avg_allocated_revenue_inr: number;
  avg_profit_margin_inr: number;
  profitability_score: number; // percentage
  recommendations: string[];
}

export interface UserProfitability {
  user_id: string;
  tier: SubscriptionTier;
  lifetime_operations: number;
  lifetime_cost_usd: number;
  lifetime_revenue_inr: number;
  lifetime_profit_inr: number;
  profitability_status: 'profit' | 'break_even' | 'loss';
  avg_operations_per_month: number;
  months_active: number;
  first_operation_date: string;
}

export interface UsageAnomaly {
  user_id: string;
  tier: SubscriptionTier;
  feature_name: string;
  recent_usage_count: number;
  avg_usage_count: number;
  anomaly_factor: number; // multiplier (e.g., 5.0 = 5x average)
}

// ========================================
// Alert Types
// ========================================

export type AlertType =
  | 'cost_spike'
  | 'usage_anomaly'
  | 'rate_limit_exceeded'
  | 'negative_profitability';

export type NotificationChannel = 'email' | 'slack' | 'database';

export interface UsageAlert {
  id?: string;
  alert_type: AlertType;
  threshold_value?: number;
  notification_channel: NotificationChannel;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface AlertTrigger {
  alert_type: AlertType;
  user_id?: string;
  feature_name?: string;
  current_value: number;
  threshold_value: number;
  message: string;
  timestamp: Date;
}

// ========================================
// Request/Response Types for Logging Service
// ========================================

export interface LogUsageRequest {
  userId: string;
  tier: SubscriptionTier;
  featureName: FeatureName;
  operationType: OperationType;
  tokensConsumed?: number;
  llmProvider?: LLMProvider;
  llmModel?: string;
  llmInputTokens?: number;
  llmOutputTokens?: number;
  llmCostUsd?: number;
  requestMetadata?: Record<string, unknown>;
  responseMetadata?: Record<string, unknown>;
}

export interface LogUsageResponse {
  logId: string;
  success: boolean;
  profitMargin: number;
  estimatedRevenue: number;
}

// ========================================
// Admin Dashboard Types
// ========================================

export interface AdminUsageAnalytics {
  total_operations: number;
  total_cost_usd: number;
  total_revenue_inr: number;
  profit_margin_inr: number;
  by_tier: Record<SubscriptionTier, UsageStats>;
  by_feature: Record<FeatureName, UsageStats>;
  by_date: Array<{
    date: string;
    operations: number;
    cost: number;
    revenue: number;
    profit: number;
  }>;
}

export interface AdminRealTimeStats {
  last_24h: {
    operations: number;
    active_users: number;
    cost_usd: number;
    revenue_inr: number;
    profit_margin_inr: number;
  };
  current_active_users: number;
  rate_limit_violations: number;
  error_rate: number;
}

// ========================================
// Configuration Types
// ========================================

export interface RevenueAllocationConfig {
  free: number; // ₹0/month
  standard: number; // ₹79/month
  plus: number; // ₹149/month
  premium: number; // ₹499/month
}

export interface LLMPricingConfig {
  openai: {
    'gpt-3.5-turbo': {
      input_per_1k: number; // USD
      output_per_1k: number; // USD
    };
    'gpt-4-turbo': {
      input_per_1k: number;
      output_per_1k: number;
    };
  };
  anthropic: {
    'claude-haiku-3': {
      input_per_1k: number;
      output_per_1k: number;
    };
    'claude-sonnet-3.5': {
      input_per_1k: number;
      output_per_1k: number;
    };
  };
  elevenlabs: {
    'eleven-turbo-v2': {
      per_character: number; // USD
    };
  };
}

// ========================================
// Utility Types
// ========================================

export interface DateRange {
  startDate: Date;
  endDate: Date;
}

export interface PaginationParams {
  page: number;
  limit: number;
}

export interface SortParams {
  field: string;
  direction: 'asc' | 'desc';
}
