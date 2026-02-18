/**
 * Admin Dashboard Type Definitions
 * Types for LLM cost analytics, subscriptions, and promo codes
 */

// ============================================================================
// LLM Cost Analytics Types
// ============================================================================

export interface UsageAnalyticsRequest {
  start_date?: string // ISO date string (e.g., "2026-02-01")
  end_date?: string   // ISO date string (e.g., "2026-02-06")
  tier?: 'free' | 'standard' | 'plus' | 'premium'
  feature?: 'study_generate' | 'study_followup' | 'voice_conversation'
}

export interface UsageOverview {
  total_operations: number
  total_llm_cost_usd: number
  total_llm_tokens: number
  avg_cost_per_operation: number
  unique_users: number
}

export interface FeatureBreakdown {
  operations: number
  cost_usd: number
  input_tokens: number
  output_tokens: number
  avg_cost_per_operation: number
}

export interface TierBreakdown {
  operations: number
  cost_usd: number
  unique_users: number
  avg_cost_per_user: number
}

export interface ProviderBreakdown {
  operations: number
  cost_usd: number
  input_tokens: number
  output_tokens: number
  avg_cost_per_operation: number
}

export interface ModelBreakdown {
  operations: number
  cost_usd: number
  input_tokens: number
  output_tokens: number
  provider: 'openai' | 'anthropic'
}

export interface DailyCost {
  date: string
  total_cost_usd: number
  operations: number
  total_tokens: number
}

export interface UsageAnalyticsResponse {
  overview: UsageOverview
  by_feature: Record<string, FeatureBreakdown>
  by_tier: Record<string, TierBreakdown>
  by_provider: Record<string, ProviderBreakdown>
  by_model: Record<string, ModelBreakdown>
  daily_costs: DailyCost[]
}

// ============================================================================
// Subscription Types
// ============================================================================

export type SubscriptionTier = 'free' | 'standard' | 'plus' | 'premium'
export type SubscriptionStatus = 'trial' | 'created' | 'in_progress' | 'active' | 'pending_cancellation' | 'paused' | 'cancelled' | 'completed' | 'expired'

export interface SubscriptionPlan {
  plan_name: string
  price_inr: number
  billing_cycle: 'monthly' | 'yearly'
}

export interface Subscription {
  id: string
  tier: SubscriptionTier
  status: SubscriptionStatus
  start_date: string
  end_date?: string
  next_billing_at?: string
  current_period_start?: string
  current_period_end?: string
  subscription_plans: SubscriptionPlan
  provider?: string
  provider_subscription_id?: string
  amount_paise?: number
  currency?: string
  cancelled_at?: string
  cancellation_reason?: string
}

export interface UserWithSubscription {
  id: string
  email: string
  full_name?: string
  phone?: string
  created_at: string
  subscriptions: Subscription[]
}

export interface SearchUsersRequest {
  query: string
  limit?: number
  offset?: number
}

export interface SearchUsersResponse {
  users: UserWithSubscription[]
  total: number
  limit: number
  offset: number
}

export interface UpdateSubscriptionRequest {
  target_user_id: string
  new_tier: SubscriptionTier
  effective_date?: string
  reason?: string
  // Extended fields for full subscription editing
  new_status?: SubscriptionStatus
  new_start_date?: string
  new_end_date?: string
  current_period_end?: string
  next_billing_at?: string
  plan_name?: string
  billing_cycle?: 'monthly' | 'yearly'
}

export interface UpdateSubscriptionResponse {
  success: boolean
  subscription: Subscription
  message: string
}

export interface CreatePaymentRecordRequest {
  user_id: string
  subscription_id: string
  amount: number
  currency: 'INR' | 'USD'
  payment_method: 'bank_transfer' | 'cash' | 'cheque' | 'other'
  payment_date: string
  reference_number?: string
  notes?: string
}

export interface CreatePaymentRecordResponse {
  success: boolean
  payment_id: string
  message: string
}

export interface PaymentRecord {
  id: string
  token_amount: number
  cost_rupees: string
  cost_paise: number
  payment_id: string
  order_id: string
  payment_method: string
  payment_provider: string
  status: string
  receipt_number?: string
  receipt_url?: string
  purchased_at: string
  created_at: string
}

export interface SubscriptionInvoice {
  id: string
  subscription_id: string
  invoice_number: string
  amount_minor: number
  currency: string
  payment_status: string
  payment_date?: string
  due_date: string
  created_at: string
}

export interface PaymentHistoryResponse {
  payments: PaymentRecord[]
  invoices: SubscriptionInvoice[]
  total_payments: number
  total_spent: number
}

// ============================================================================
// Promo Code Types
// ============================================================================

export type DiscountType = 'percentage' | 'fixed_amount'
export type EligibilityType = 'all' | 'new_users_only' | 'specific_tiers' | 'specific_users'

export interface PromoCodeCampaign {
  id: string
  code: string
  campaign_name: string
  description?: string
  discount_type: DiscountType
  discount_value: number
  applies_to_plan: string[]
  max_total_uses?: number
  max_uses_per_user: number
  eligible_for: EligibilityType
  eligible_tiers?: string[]
  eligible_user_ids?: string[]
  start_date: string
  end_date: string
  is_active: boolean
  current_uses: number
  is_expired: boolean
  created_at: string
  created_by: string
}

export interface ListPromoCodesRequest {
  status?: 'all' | 'active' | 'inactive' | 'expired'
  limit?: number
  offset?: number
}

export interface ListPromoCodesResponse {
  campaigns: PromoCodeCampaign[]
  total: number
  limit: number
  offset: number
}

export interface CreatePromoCodeRequest {
  code: string
  campaign_name: string
  description?: string
  discount_type: DiscountType
  discount_value: number
  applies_to_plan: string[]
  max_total_uses?: number
  max_uses_per_user: number
  eligible_for: EligibilityType
  eligible_tiers?: string[]
  eligible_user_ids?: string[]
  start_date: string
  end_date: string
  is_active: boolean
}

export interface CreatePromoCodeResponse {
  success: boolean
  campaign: PromoCodeCampaign
  message: string
}

export interface TogglePromoCodeRequest {
  campaign_id: string
  is_active: boolean
}

export interface TogglePromoCodeResponse {
  success: boolean
  campaign: PromoCodeCampaign
  message: string
}

// ============================================================================
// Learning Paths Types
// ============================================================================

export type DifficultyLevel = 'beginner' | 'intermediate' | 'advanced'
export type DiscipleLevel = 'seeker' | 'follower' | 'disciple' | 'leader'
export type StudyMode = 'quick' | 'standard' | 'deep' | 'lectio' | 'sermon' | 'recommended'
export type LanguageCode = 'en' | 'hi' | 'ml'

export interface LearningPath {
  id: string
  slug: string
  title: string
  description: string
  icon_name: string
  color: string
  total_xp: number
  estimated_days: number
  difficulty_level: DifficultyLevel
  disciple_level: DiscipleLevel
  recommended_mode: StudyMode
  is_featured: boolean
  is_active: boolean
  display_order: number
  allow_non_sequential_access: boolean
  created_at: string
  updated_at: string
  topics_count?: number
  enrolled_count?: number
}

export interface LearningPathTranslation {
  learning_path_id: string
  language: LanguageCode
  title: string
  description: string
}

export interface LearningPathWithDetails extends LearningPath {
  translations: Record<string, { title: string; description: string }>
  topics: Array<{
    id: string
    title: string
    position: number
    is_milestone: boolean
    xp_value: number
  }>
}

export interface ListLearningPathsResponse {
  learning_paths: LearningPath[]
}

export interface GetLearningPathResponse {
  learning_path: LearningPathWithDetails
}

export interface CreateLearningPathRequest {
  slug: string
  title: string
  description: string
  icon_name: string
  color: string
  estimated_days: number
  difficulty_level: DifficultyLevel
  disciple_level: DiscipleLevel
  recommended_mode: StudyMode
  is_featured?: boolean
  is_active?: boolean
  allow_non_sequential_access?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

export interface UpdateLearningPathRequest {
  title?: string
  description?: string
  icon_name?: string
  color?: string
  estimated_days?: number
  difficulty_level?: DifficultyLevel
  disciple_level?: DiscipleLevel
  recommended_mode?: StudyMode
  is_featured?: boolean
  is_active?: boolean
  allow_non_sequential_access?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

export interface CreateLearningPathResponse {
  learning_path: LearningPath
}

export interface UpdateLearningPathResponse {
  learning_path: LearningPath
}

export interface DeleteLearningPathResponse {
  message: string
  cascade_warnings: {
    had_enrollments: boolean
    had_topics: boolean
  }
}

export interface ReorderLearningPathRequest {
  display_order: number
}

export interface ToggleLearningPathRequest {
  is_active: boolean
}

// ============================================================================
// Recommended Topics Types
// ============================================================================

export type InputType = 'topic' | 'verse' | 'question' | 'passage' | 'scripture'

export interface RecommendedTopic {
  id: string
  title: string
  description: string
  category: string
  input_type: InputType
  input_value: string
  tags: string[]
  xp_value: number
  display_order: number
  is_active: boolean
  created_at: string
  updated_at: string
  usage_count?: number
}

export interface TopicTranslation {
  topic_id: string
  language: LanguageCode
  title: string
  description: string
}

export interface RecommendedTopicWithDetails extends RecommendedTopic {
  translations: Record<string, { title: string; description: string }>
  used_in_paths: Array<{
    learning_path_id: string
    learning_path_title: string
    position: number
  }>
  learning_paths?: string[]
  learning_path_ids?: string[]
}

export interface ListTopicsRequest {
  category?: string
  input_type?: InputType
  is_active?: boolean
}

export interface ListTopicsResponse {
  topics: RecommendedTopic[]
}

export interface GetTopicResponse {
  topic: RecommendedTopicWithDetails
}

export interface CreateTopicRequest {
  title: string
  description: string
  category: string
  input_type: InputType
  input_value: string
  tags?: string[]
  xp_value?: number
  is_active?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

export interface UpdateTopicRequest {
  title?: string
  description?: string
  category?: string
  input_type?: InputType
  input_value?: string
  tags?: string[]
  xp_value?: number
  is_active?: boolean
  translations?: {
    en?: { title: string; description: string }
    hi?: { title: string; description: string }
    ml?: { title: string; description: string }
  }
}

export interface CreateTopicResponse {
  topic: RecommendedTopic
}

export interface UpdateTopicResponse {
  topic: RecommendedTopic
}

export interface DeleteTopicResponse {
  message: string
  error?: string
  used_in_paths?: string[]
  usage_count?: number
}

export interface CSVTopicRow {
  title: string
  description: string
  category: string
  input_type: InputType
  input_value: string
  tags?: string
  xp_value?: string
  title_hi?: string
  description_hi?: string
  title_ml?: string
  description_ml?: string
}

export interface BulkImportRequest {
  topics: CSVTopicRow[]
}

export interface BulkImportResult {
  success_count: number
  error_count: number
  errors: Array<{ row: number; error: string }>
  created_topics: string[]
}

// ============================================================================
// Learning Path Topics Association Types
// ============================================================================

export interface AddTopicToPathRequest {
  learning_path_id: string
  topic_id: string
  position: number
  is_milestone?: boolean
}

export interface AddTopicToPathResponse {
  message: string
  entry: {
    learning_path_id: string
    topic_id: string
    position: number
    is_milestone: boolean
  }
}

export interface RemoveTopicFromPathRequest {
  learning_path_id: string
  topic_id: string
}

export interface RemoveTopicFromPathResponse {
  message: string
}

export interface ReorderTopicsRequest {
  learning_path_id: string
  topic_orders: Array<{
    topic_id: string
    position: number
  }>
}

export interface ReorderTopicsResponse {
  message: string
}

export interface ToggleMilestoneRequest {
  is_milestone: boolean
}

export interface ToggleMilestoneResponse {
  message: string
  entry: {
    learning_path_id: string
    topic_id: string
    position: number
    is_milestone: boolean
  }
}

// ============================================================================
// Study Generator Types
// ============================================================================

export interface StudyGenerationRequest {
  input_type: InputType
  input_value: string
  topic_description?: string
  language: LanguageCode
  study_mode: StudyMode
}

export interface StudyGuideSection {
  type: string
  content: string | any[] | Record<string, any>
  index: number
}

export interface StudyGuideStreamEvent {
  type: 'init' | 'section' | 'complete' | 'error'
  data: any
}

// ============================================================================
// Study Modifier Types
// ============================================================================

export interface StudyGuideContent {
  summary?: string
  context?: string
  interpretation?: string
  passage?: string | null
  relatedVerses?: Array<{ reference: string; text: string }> | string[]
  related_verses?: Array<{ reference: string; text: string }> | string[]
  reflectionQuestions?: string[]
  reflection_questions?: string[]
  prayerPoints?: string[]
  prayer_points?: string[]
  interpretationInsights?: string[]
  interpretation_insights?: string[]
  summaryInsights?: string[]
  summary_insights?: string[]
  reflectionAnswers?: string[]
  reflection_answers?: string[]
  contextQuestion?: string
  context_question?: string
  summaryQuestion?: string
  summary_question?: string
  relatedVersesQuestion?: string
  related_verses_question?: string
  reflectionQuestion?: string
  reflection_question?: string
  prayerQuestion?: string
  prayer_question?: string
}

export interface StudyGuide {
  id: string
  input_type: InputType
  input_value: string
  input_value_display: string
  language: LanguageCode
  study_mode: StudyMode
  content: StudyGuideContent
  creator_user_id?: string
  creator_session_id?: string
  creator_name?: string
  title?: string
  summary?: string
  created_at: string
  updated_at: string
  // Snake-case flat fields (legacy / direct DB mapping)
  passage?: string | null
  context?: string
  interpretation?: string
  related_verses?: any[]
  reflection_questions?: string[]
  prayer_points?: string[]
  interpretation_insights?: string[]
  summary_insights?: string[]
  reflection_answers?: string[]
  context_question?: string
  summary_question?: string
  related_verses_question?: string
  reflection_question?: string
  prayer_question?: string
}

export interface LoadStudyGuideResponse {
  study_guide: StudyGuide
}

export interface UpdateStudyGuideRequest {
  content: StudyGuideContent
  update_cache?: boolean
  notes?: string
}

export interface UpdateStudyGuideResponse {
  message: string
  study_guide: StudyGuide
  version_type: 'cache_updated' | 'new_version'
  original_guide_id?: string
}

// ============================================================================
// Study Guides Management Types
// ============================================================================

export interface StudyGuideListItem {
  id: string
  input_type: InputType
  input_value: string
  language: LanguageCode
  study_mode: StudyMode
  topic_id?: string
  topic_title?: string
  creator_user_id?: string
  creator_name?: string
  created_at: string
  updated_at: string
  usage_count: number
}

export interface ListStudyGuidesResponse {
  study_guides: StudyGuideListItem[]
}
