-- =====================================================
-- Consolidated Migration: Performance Indexes
-- =====================================================
-- Source: Extracted from all 193 migration files
-- Description: Comprehensive performance indexes organized by table
--              for all database tables (0001-0012)
-- =====================================================

-- Dependencies: All table creation migrations (0001-0012)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates performance indexes
-- Completed 0001-0012 (all tables), now adding
-- comprehensive indexes for optimal query performance
-- =====================================================

-- =====================================================
-- PART 1: CORE TABLES INDEXES (Migration 0001)
-- =====================================================

-- Table: user_profiles
-- NOTE: Most indexes already created in core_schema.sql
-- COMMENTED OUT: Indexes already exist or columns don't exist

-- Column doesn't exist in current schema
-- CREATE INDEX IF NOT EXISTS idx_user_profiles_email_verification_token
--   ON user_profiles(email_verification_token)
--   WHERE email_verification_token IS NOT NULL;

-- Already created in core_schema.sql (line 68-69)
-- CREATE INDEX IF NOT EXISTS idx_user_profiles_phone
--   ON user_profiles(phone_number)
--   WHERE phone_number IS NOT NULL;

-- Already created in core_schema.sql (line 64)
-- CREATE INDEX IF NOT EXISTS idx_user_profiles_admin
--   ON user_profiles(is_admin)
--   WHERE is_admin = TRUE;

-- Already created in core_schema.sql (line 63)
-- CREATE INDEX IF NOT EXISTS idx_user_profiles_language
--   ON user_profiles(language_preference);

-- Already created in core_schema.sql (line 65)
-- CREATE INDEX IF NOT EXISTS idx_user_profiles_onboarding_status
--   ON user_profiles(onboarding_status);

-- Column doesn't exist in current schema
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_razorpay_customer_id_unique
--   ON user_profiles(razorpay_customer_id)
--   WHERE razorpay_customer_id IS NOT NULL;

-- Table: anonymous_sessions
-- COMMENTED OUT: Already created in core_schema.sql (lines 98-99)
-- CREATE INDEX IF NOT EXISTS idx_anonymous_sessions_device_hash
--   ON anonymous_sessions(device_fingerprint_hash);

-- CREATE INDEX IF NOT EXISTS idx_anonymous_sessions_expires_at
--   ON anonymous_sessions(expires_at);

-- Table: oauth_states
-- COMMENTED OUT: Already created in core_schema.sql (lines 122-124)
-- CREATE INDEX IF NOT EXISTS idx_oauth_states_state
--   ON oauth_states(state);

-- CREATE INDEX IF NOT EXISTS idx_oauth_states_expires_at
--   ON oauth_states(expires_at);

-- CREATE INDEX IF NOT EXISTS idx_oauth_states_used
--   ON oauth_states(used);

-- Table: otp_requests
-- COMMENTED OUT: Already created in core_schema.sql (lines 147-149)
-- CREATE INDEX IF NOT EXISTS idx_otp_requests_phone
--   ON otp_requests(phone_number);

-- CREATE INDEX IF NOT EXISTS idx_otp_requests_expires
--   ON otp_requests(expires_at);

-- CREATE INDEX IF NOT EXISTS idx_otp_requests_created_at
--   ON otp_requests(created_at DESC);

-- COMMENTED OUT: Cannot use NOW() in index predicate (not immutable)
-- This index would prevent multiple unverified OTP requests for same phone
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_otp_requests_active_phone
--   ON otp_requests(phone_number)
--   WHERE is_verified = false AND expires_at > NOW();

-- Table: llm_security_events
-- COMMENTED OUT: Already created in core_schema.sql (lines 228-230)
-- CREATE INDEX IF NOT EXISTS idx_security_events_user
--   ON llm_security_events(user_id, created_at DESC);

-- CREATE INDEX IF NOT EXISTS idx_security_events_type_time
--   ON llm_security_events(event_type, created_at DESC);

-- CREATE INDEX IF NOT EXISTS idx_security_events_ip
--   ON llm_security_events(ip_address, created_at DESC);

-- Table: notification_logs
-- COMMENTED OUT: Already created in core_schema.sql (lines 269-276)
-- CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id
--   ON notification_logs(user_id);

-- CREATE INDEX IF NOT EXISTS idx_notification_logs_type
--   ON notification_logs(notification_type);

-- CREATE INDEX IF NOT EXISTS idx_notification_logs_status
--   ON notification_logs(delivery_status);

-- CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at
--   ON notification_logs(sent_at DESC);

-- CREATE INDEX IF NOT EXISTS idx_notification_logs_topic_id
--   ON notification_logs(topic_id);

-- CREATE INDEX IF NOT EXISTS idx_notification_logs_user_sent
--   ON notification_logs(user_id, sent_at DESC);

-- Table: user_notification_tokens
-- COMMENTED OUT: Already created in core_schema.sql (lines 303-305)
-- CREATE INDEX IF NOT EXISTS idx_notification_tokens_user_id
--   ON user_notification_tokens(user_id);

-- CREATE INDEX IF NOT EXISTS idx_notification_tokens_fcm_token
--   ON user_notification_tokens(fcm_token);

-- CREATE INDEX IF NOT EXISTS idx_notification_tokens_platform
--   ON user_notification_tokens(platform);

-- Table: user_notification_preferences
-- NOTE: All indexes already created in core_schema.sql (lines 336-341)
-- COMMENTED OUT: Wrong column names and duplicates

-- Already created in core_schema.sql (line 336)
-- CREATE INDEX IF NOT EXISTS idx_notification_prefs_user_id
--   ON user_notification_preferences(user_id);

-- Wrong column: should be daily_verse_enabled, already indexed in core_schema.sql (line 337-338)
-- CREATE INDEX IF NOT EXISTS idx_notification_prefs_daily_verse
--   ON user_notification_preferences(daily_verse_time);

-- Wrong column: should be recommended_topic_enabled, already indexed in core_schema.sql (line 339-340)
-- CREATE INDEX IF NOT EXISTS idx_notification_prefs_recommended
--   ON user_notification_preferences(recommended_topics_time);

-- Wrong table: fcm_token is in user_notification_tokens, not user_notification_preferences
-- CREATE INDEX IF NOT EXISTS idx_notification_prefs_fcm_token
--   ON user_notification_preferences(fcm_token);

-- Wrong column: should be timezone_offset_minutes, already indexed in core_schema.sql (line 341)
-- CREATE INDEX IF NOT EXISTS idx_notification_prefs_timezone
--   ON user_notification_preferences(timezone);

-- Table: user_personalization
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_user_personalization_user_id
--   ON user_personalization(user_id);
--
-- CREATE INDEX IF NOT EXISTS idx_user_personalization_completed
--   ON user_personalization(questionnaire_completed);

-- Table: rate_limit_usage
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_rate_limit_usage_lookup
--   ON rate_limit_usage(user_id, feature_name);
--
-- CREATE INDEX IF NOT EXISTS idx_rate_limit_usage_last_activity
--   ON rate_limit_usage(last_activity_at);
--
-- COMMENTED OUT: Cannot use NOW() in index predicate (not immutable)
-- CREATE INDEX IF NOT EXISTS idx_rate_limit_usage_cleanup
--   ON rate_limit_usage(last_activity_at)
--   WHERE last_activity_at < NOW() - INTERVAL '7 days';
--
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_limit_usage_unique
--   ON rate_limit_usage(user_id, feature_name);

-- =====================================================
-- PART 2: STUDY SYSTEM INDEXES (Migration 0002)
-- =====================================================

-- Table: study_guides
-- NOTE: Most indexes already created in 20260119000100_study_guides.sql (lines 66-80)
-- COMMENTED OUT: Wrong column names (user_id doesn't exist) or duplicates

-- Wrong column: should be creator_user_id, and already indexed in study_guides.sql (line 71)
-- CREATE INDEX IF NOT EXISTS idx_study_guides_user_id
--   ON study_guides(user_id);

-- Already created in study_guides.sql (line 73)
-- CREATE INDEX IF NOT EXISTS idx_study_guides_created_at
--   ON study_guides(created_at DESC);

-- Already created in study_guides.sql (line 74)
-- CREATE INDEX IF NOT EXISTS idx_study_guides_language
--   ON study_guides(language);

-- Already created in study_guides.sql (line 76)
-- CREATE INDEX IF NOT EXISTS idx_study_guides_input_type
--   ON study_guides(input_type);

-- Already created in study_guides.sql (line 78)
-- CREATE INDEX IF NOT EXISTS idx_study_guides_topic_id
--   ON study_guides(topic_id);

-- Wrong table: these should be on user_study_guides table, not study_guides
-- (user_study_guides already has correct indexes in study_guides.sql lines 128-132)
-- CREATE INDEX IF NOT EXISTS idx_user_study_guides_user_completion
--   ON study_guides(user_id, created_at DESC);
--
-- CREATE INDEX IF NOT EXISTS idx_user_study_guides_completed_at
--   ON study_guides(user_id, created_at DESC);

-- Table: study_guide_conversations
-- COMMENTED OUT: Already created in study_guides.sql (lines 219-221)
-- CREATE INDEX IF NOT EXISTS idx_study_guide_conversations_study_guide_id
--   ON study_guide_conversations(study_guide_id);

-- CREATE INDEX IF NOT EXISTS idx_study_guide_conversations_user_id
--   ON study_guide_conversations(user_id);

-- CREATE INDEX IF NOT EXISTS idx_study_guide_conversations_session_id
--   ON study_guide_conversations(session_id);

-- Table: anonymous_study_guides
-- NOTE: All indexes already created in study_guides.sql (lines 180-183)
-- COMMENTED OUT: Wrong column names or duplicates

-- Already created in study_guides.sql (line 180)
-- CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_session_id
--   ON anonymous_study_guides(session_id);

-- Already created in study_guides.sql (line 182)
-- CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_created_at
--   ON anonymous_study_guides(created_at DESC);

-- Already created in study_guides.sql (line 183)
-- CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_expires_at
--   ON anonymous_study_guides(expires_at);

-- Wrong column: should be is_saved, already indexed in study_guides.sql (line 181)
-- CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_saved
--   ON anonymous_study_guides(saved);

-- Already covered by the index on line 182
-- CREATE INDEX IF NOT EXISTS idx_anonymous_guides_session_created
--   ON anonymous_study_guides(session_id, created_at DESC);

-- Table: recommended_guide_sessions
-- COMMENTED OUT: Already created in study_guides.sql (lines 312-314)
-- CREATE INDEX IF NOT EXISTS idx_recommended_guide_sessions_user_id
--   ON recommended_guide_sessions(user_id);

-- CREATE INDEX IF NOT EXISTS idx_recommended_guide_sessions_topic
--   ON recommended_guide_sessions(topic);

-- CREATE INDEX IF NOT EXISTS idx_recommended_guide_sessions_completion
--   ON recommended_guide_sessions(completion_status);

-- Table: daily_verses_cache
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_date_key
--   ON daily_verses_cache(date_key);

-- CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_expires_at
--   ON daily_verses_cache(expires_at);

-- CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_uuid
--   ON daily_verses_cache(id);

-- =====================================================
-- PART 3: TOKEN SYSTEM INDEXES (Migration 0003)
-- =====================================================

-- Table: user_tokens
-- COMMENTED OUT: All indexes already created in token_system.sql (lines 46-49)
-- Wrong column: should be user_plan, not plan
-- CREATE INDEX IF NOT EXISTS idx_user_tokens_plan
--   ON user_tokens(plan);

-- Already created on line 49
-- CREATE INDEX IF NOT EXISTS idx_user_tokens_reset
--   ON user_tokens(last_reset_at);

-- Not needed
-- CREATE INDEX IF NOT EXISTS idx_user_tokens_created_at
--   ON user_tokens(created_at);

-- Not needed
-- CREATE INDEX IF NOT EXISTS idx_user_tokens_updated_at
--   ON user_tokens(updated_at);

-- Already created on line 46 (with correct columns: identifier, user_plan)
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_user_tokens_identifier
--   ON user_tokens(user_id, plan);

-- =====================================================
-- PART 4: SUBSCRIPTION SYSTEM INDEXES (Migration 0004)
-- =====================================================

-- Table: subscriptions
-- COMMENTED OUT: Already created in subscription_system.sql (lines 200-204)
-- CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id
--   ON subscriptions(user_id);

-- CREATE INDEX IF NOT EXISTS idx_subscriptions_status
--   ON subscriptions(status);

-- Note: This specific index doesn't exist in subscription_system.sql, but a similar
-- idx_subscriptions_razorpay_subscription_id_unique exists on line 196
-- CREATE INDEX IF NOT EXISTS idx_subscriptions_razorpay_id
--   ON subscriptions(razorpay_subscription_id);

-- Note: This index uses next_billing_at which doesn't exist; subscription_system.sql
-- has idx_subscriptions_current_period_end instead (line 204)
-- CREATE INDEX IF NOT EXISTS idx_subscriptions_next_billing
--   ON subscriptions(next_billing_at)
--   WHERE status = 'active';

-- REMOVED: Replaced with full unique constraint in subscription_system.sql
-- Old partial index (status = 'active') caused issues with multiple subscriptions
-- New approach: ONE subscription per user (any status) enforced by idx_subscriptions_one_per_user
-- When subscription changes (active → cancelled), UPDATE the existing record instead of creating new
-- DROP INDEX IF EXISTS unique_active_subscription_per_user;

-- Table: subscription_history
-- COMMENTED OUT: Already created in subscription_system.sql (lines 266-270)
-- CREATE INDEX IF NOT EXISTS idx_subscription_history_subscription
--   ON subscription_history(subscription_id);

-- CREATE INDEX IF NOT EXISTS idx_subscription_history_user
--   ON subscription_history(user_id);

-- CREATE INDEX IF NOT EXISTS idx_subscription_history_event_type
--   ON subscription_history(event_type);

-- Note: This index uses created_at DESC, not in subscription_system.sql
-- Keeping active for query optimization
CREATE INDEX IF NOT EXISTS idx_subscription_history_created_at
  ON subscription_history(created_at DESC);

-- =====================================================
-- PART 5: PAYMENT SYSTEM INDEXES (Migration 0005)
-- =====================================================

-- Table: saved_payment_methods
-- COMMENTED OUT: Already created in payment_system.sql (lines 296-298)
-- CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_user_id
--   ON saved_payment_methods(user_id);

-- CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_user_default
--   ON saved_payment_methods(user_id, is_default)
--   WHERE is_default = TRUE;

-- CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_active
--   ON saved_payment_methods(user_id, is_active)
--   WHERE is_active = TRUE;

-- Table: purchase_history
-- COMMENTED OUT: Already created in payment_system.sql (lines 282-289)
-- CREATE INDEX IF NOT EXISTS idx_purchase_history_user_id
--   ON purchase_history(user_id);

-- CREATE INDEX IF NOT EXISTS idx_purchase_history_payment_id
--   ON purchase_history(payment_id);

-- CREATE INDEX IF NOT EXISTS idx_purchase_history_status
--   ON purchase_history(status);

-- CREATE INDEX IF NOT EXISTS idx_purchase_history_purchased_at
--   ON purchase_history(purchased_at DESC);

-- CREATE INDEX IF NOT EXISTS idx_purchase_history_receipt_number
--   ON purchase_history(receipt_number);

-- CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_history_payment_id_unique
--   ON purchase_history(payment_id);

-- Table: pending_token_purchases
-- COMMENTED OUT: Already created in payment_system.sql (line 275)
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_purchases_payment_id_unique
--   ON pending_token_purchases(payment_id);

-- Table: purchase_issue_reports
-- COMMENTED OUT: Already created in payment_system.sql (lines 307-310)
-- CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_user_id
--   ON purchase_issue_reports(user_id);

-- CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_purchase_id
--   ON purchase_issue_reports(purchase_id);

-- CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_status
--   ON purchase_issue_reports(status);

-- CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_created_at
--   ON purchase_issue_reports(created_at DESC);

-- =====================================================
-- PART 6: MEMORY SYSTEM INDEXES (Migration 0007)
-- =====================================================

-- Table: memory_verses
-- COMMENTED OUT: All indexes already created in memory_system.sql (lines 70-78)
-- Wrong column: should be next_review_date, not next_review_at
-- Already created on line 70-72
-- CREATE INDEX IF NOT EXISTS idx_memory_verses_user_next_review
--   ON memory_verses(user_id, next_review_at);

-- Wrong column: should be next_review_date, not next_review_at
-- CREATE INDEX IF NOT EXISTS idx_memory_verses_next_review_date
--   ON memory_verses(next_review_at);

-- Wrong column: should be user_id, verse_reference (already on line 77-78)
-- CREATE INDEX IF NOT EXISTS idx_memory_verses_reference
--   ON memory_verses(reference);

-- Already created on line 80-81
-- CREATE INDEX IF NOT EXISTS idx_memory_verses_language
--   ON memory_verses(language);

-- Wrong column: should be user_id, source_type, source_id (already on line 74-75)
-- CREATE INDEX IF NOT EXISTS idx_memory_verses_source
--   ON memory_verses(source);

-- Column doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_memory_verses_fully_mastered
--   ON memory_verses(user_id, fully_mastered);

-- Table: memory_verse_collections
-- COMMENTED OUT: Already created in memory_system.sql (lines 244-248)
-- CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_user_id
--   ON memory_verse_collections(user_id);

-- Already created on line 246-247
-- CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_category
--   ON memory_verse_collections(category);

-- Already created on line 280
-- CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id
--   ON memory_verse_collection_items(collection_id);

-- Already created on line 282
-- CREATE INDEX IF NOT EXISTS idx_collection_items_verse_id
--   ON memory_verse_collection_items(memory_verse_id);

-- Table: practice_sessions (memory_practice_modes)
-- COMMENTED OUT: All indexes already created in memory_system.sql (lines 131-138)
-- Wrong column: should be memory_verse_id, not verse_id
-- Wrong column: should be practice_mode, not mode_type
-- CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_user_id
--   ON practice_sessions(user_id);

-- CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_verse_id
--   ON practice_sessions(verse_id);

-- CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_mode_type
--   ON practice_sessions(mode_type);

-- Table: daily_unlocked_modes
-- COMMENTED OUT: Already created in memory_system.sql (lines 212-217)
-- Wrong column: should be memory_verse_id, not verse_id
-- CREATE INDEX IF NOT EXISTS idx_daily_unlocked_modes_user_verse_date
--   ON daily_unlocked_modes(user_id, verse_id, unlock_date);

-- CREATE INDEX IF NOT EXISTS idx_daily_unlocked_modes_date
--   ON daily_unlocked_modes(unlock_date);

-- Table: memory_verse_mastery
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_user_id
--   ON memory_verse_mastery(user_id);

-- CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_verse_id
--   ON memory_verse_mastery(verse_id);

-- CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_level
--   ON memory_verse_mastery(mastery_level);

-- Table: memory_verse_streaks
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_current_streak
--   ON memory_verse_streaks(current_streak);

-- CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_last_practice
--   ON memory_verse_streaks(last_practice_date);

-- Table: memory_daily_goals
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_user_id
--   ON memory_daily_goals(user_id);

-- Table doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_date
--   ON memory_daily_goals(goal_date);

-- Table doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_achieved
--   ON memory_daily_goals(achieved);

-- Table: memory_challenges (if exists)
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_memory_challenges_type
--   ON memory_challenges(challenge_type);

-- CREATE INDEX IF NOT EXISTS idx_memory_challenges_dates
--   ON memory_challenges(start_date, end_date);

-- CREATE INDEX IF NOT EXISTS idx_memory_challenges_active
--   ON memory_challenges(is_active)
--   WHERE is_active = TRUE;

-- =====================================================
-- PART 7: GAMIFICATION INDEXES (Migration 0008)
-- =====================================================

-- Table: user_study_streaks
-- COMMENTED OUT: Already created in gamification.sql (lines 137-143)
-- CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_user_id
--   ON user_study_streaks(user_id);

-- CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_current_streak
--   ON user_study_streaks(current_streak);

-- =====================================================
-- PART 8: LEARNING PATHS INDEXES (Migration 0009)
-- =====================================================

-- Table: learning_paths
-- COMMENTED OUT: Already created in learning_paths.sql (lines 53-55)
-- Note: Line 53 has composite index (is_active, is_featured, display_order) which
-- is more efficient than separate indexes below
-- CREATE INDEX IF NOT EXISTS idx_learning_paths_slug
--   ON learning_paths(slug);

-- Covered by composite index on line 53 of learning_paths.sql
-- CREATE INDEX IF NOT EXISTS idx_learning_paths_active
--   ON learning_paths(is_active)
--   WHERE is_active = TRUE;

-- Covered by composite index on line 53 of learning_paths.sql
-- CREATE INDEX IF NOT EXISTS idx_learning_paths_featured
--   ON learning_paths(is_featured)
--   WHERE is_featured = TRUE;

-- Covered by composite index on line 53 of learning_paths.sql
-- CREATE INDEX IF NOT EXISTS idx_learning_paths_display_order
--   ON learning_paths(display_order);

-- Table: user_topic_progress
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_user_topic_progress_user_id
--   ON user_topic_progress(user_id);

-- CREATE INDEX IF NOT EXISTS idx_user_topic_progress_topic_id
--   ON user_topic_progress(topic_id);

-- CREATE INDEX IF NOT EXISTS idx_user_topic_progress_in_progress
--   ON user_topic_progress(user_id, started_at)
--   WHERE completed_at IS NULL;

-- CREATE INDEX IF NOT EXISTS idx_user_topic_progress_completed
--   ON user_topic_progress(user_id, completed_at)
--   WHERE completed_at IS NOT NULL;

-- CREATE INDEX IF NOT EXISTS idx_user_topic_progress_generation_mode
--   ON user_topic_progress(generation_mode);

-- CREATE INDEX IF NOT EXISTS idx_user_topic_progress_user_mode
--   ON user_topic_progress(user_id, generation_mode);

-- Table: user_learning_path_progress
-- COMMENTED OUT: All indexes already created in learning_paths.sql (lines 129-131)
-- Wrong column: should be enrolled_at, not started_at
-- Column doesn't exist: bonus_xp, consecutive_days_streak
-- CREATE INDEX IF NOT EXISTS idx_user_learning_path_user
--   ON user_learning_path_progress(user_id);

-- Already created on line 130
-- CREATE INDEX IF NOT EXISTS idx_user_learning_path_path
--   ON user_learning_path_progress(learning_path_id);

-- Wrong column: should be enrolled_at, not started_at (already created on line 131)
-- CREATE INDEX IF NOT EXISTS idx_user_learning_path_active
--   ON user_learning_path_progress(user_id, started_at)
--   WHERE completed_at IS NULL;

-- Not needed
-- CREATE INDEX IF NOT EXISTS idx_user_learning_path_completed
--   ON user_learning_path_progress(user_id, completed_at)
--   WHERE completed_at IS NOT NULL;

-- Column doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_user_learning_path_progress_bonus_xp
--   ON user_learning_path_progress(bonus_xp);

-- Column doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_user_learning_path_progress_streak
--   ON user_learning_path_progress(consecutive_days_streak);

-- Table: topic_scripture_references
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_scripture_ref_topic
--   ON topic_scripture_references(topic_id);

-- CREATE INDEX IF NOT EXISTS idx_scripture_ref_book
--   ON topic_scripture_references(book_name);

-- CREATE INDEX IF NOT EXISTS idx_scripture_ref_book_number
--   ON topic_scripture_references(book_number);

-- CREATE INDEX IF NOT EXISTS idx_scripture_ref_chapter
--   ON topic_scripture_references(book_name, chapter_start);

-- CREATE INDEX IF NOT EXISTS idx_scripture_ref_primary
--   ON topic_scripture_references(is_primary_reference)
--   WHERE is_primary_reference = TRUE;

-- Table: life_situations
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_life_situations_active
--   ON life_situations(is_active)
--   WHERE is_active = TRUE;

-- Table: life_situation_topics
-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_life_situation_topics_situation
--   ON life_situation_topics(life_situation_id);

-- =====================================================
-- PART 9: USAGE TRACKING INDEXES (Migration 0010)
-- =====================================================

-- Table: llm_api_costs
-- COMMENTED OUT: Already created in usage_tracking.sql (lines 103-105)
-- CREATE INDEX IF NOT EXISTS idx_llm_api_costs_provider
--   ON llm_api_costs(provider, created_at DESC);

-- CREATE INDEX IF NOT EXISTS idx_llm_api_costs_operation
--   ON llm_api_costs(operation_id);

-- CREATE INDEX IF NOT EXISTS idx_llm_api_costs_request
--   ON llm_api_costs(request_id);

-- =====================================================
-- PART 10: RECOMMENDED TOPICS INDEXES (Migration 0011)
-- =====================================================

-- Table: recommended_topics
-- COMMENTED OUT: All indexes already created in recommended_topics.sql (lines 53-58)
-- Wrong column: difficulty_level, is_active, study_guide_id don't exist
-- Already created on line 53
-- CREATE INDEX IF NOT EXISTS idx_recommended_topics_category
--   ON recommended_topics(category);

-- Column doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_recommended_topics_difficulty
--   ON recommended_topics(difficulty_level);

-- Already created on line 54 (with just display_order)
-- CREATE INDEX IF NOT EXISTS idx_recommended_topics_order
--   ON recommended_topics(display_order, created_at);

-- Column doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_recommended_topics_active
--   ON recommended_topics(is_active)
--   WHERE is_active = TRUE;

-- Column doesn't exist
-- CREATE INDEX IF NOT EXISTS idx_recommended_topics_study_guide
--   ON recommended_topics(study_guide_id);

-- Column doesn't exist: is_active
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_recommended_topics_unique_display_order_active
--   ON recommended_topics(display_order)
--   WHERE is_active = TRUE;

-- =====================================================
-- PART 11: ADDITIONAL PERFORMANCE INDEXES
-- =====================================================

-- GIN indexes for array/JSONB columns
-- COMMENTED OUT: Already created in recommended_topics.sql (line 55)
-- CREATE INDEX IF NOT EXISTS idx_recommended_topics_tags_gin
--   ON recommended_topics USING GIN(tags);

-- COMMENTED OUT: Table doesn't exist in any migration
-- CREATE INDEX IF NOT EXISTS idx_user_personalization_preferences_gin
--   ON user_personalization USING GIN(preferences);

-- Full-text search indexes (if needed in future)
-- CREATE INDEX IF NOT EXISTS idx_study_guides_content_fts
--   ON study_guides USING GIN(to_tsvector('english', content));

-- =====================================================
-- PART 12: COMMENTS AND DOCUMENTATION
-- =====================================================

-- COMMENTED OUT: Indexes don't exist or have been commented out
-- COMMENT ON INDEX idx_user_profiles_razorpay_customer_id_unique IS
--   'Ensures one Razorpay customer ID per user. Partial index excludes NULL values.';

-- COMMENT ON INDEX idx_subscriptions_next_billing IS
--   'Optimizes queries for upcoming billing dates on active subscriptions.';

-- COMMENT ON INDEX idx_memory_verses_user_next_review IS
--   'Composite index for spaced repetition queries - most frequent query pattern.';

-- COMMENT ON INDEX idx_user_topic_progress_in_progress IS
--   'Partial index for active learning path topics to optimize progress queries.';

-- COMMENT ON INDEX idx_rate_limit_usage_cleanup IS
--   'Facilitates cleanup of old rate limit records (> 7 days old).';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMIT;

-- Verification query
SELECT
  'Migration 0013 Complete' as status,
  COUNT(*) as total_indexes
FROM pg_indexes
WHERE schemaname = 'public';
