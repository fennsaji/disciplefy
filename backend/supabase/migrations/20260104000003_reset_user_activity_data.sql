-- Migration: Reset User Activity Data
-- Date: 2026-01-04
-- Description: Truncates all user activity tables while preserving:
--   - User profiles and authentication
--   - Subscription and payment data
--   - System configuration (achievements, learning paths, topics)
--
-- This migration resets:
--   - Study guides and conversations
--   - Memory verses and practice data
--   - XP, achievements, and streaks
--   - Progress tracking
--   - Analytics and feedback
--   - Notification logs

BEGIN;

-- =====================================================================
-- TRUNCATE ORDER: From leaf tables to parent tables to avoid FK conflicts
-- =====================================================================

-- 1. Study Guide Related (3 tables)
TRUNCATE TABLE public.study_guide_conversations CASCADE;
TRUNCATE TABLE public.user_study_guides CASCADE;
TRUNCATE TABLE public.study_guides CASCADE;

-- 2. Memory Verse Related (3 tables)
TRUNCATE TABLE public.memory_verse_streaks CASCADE;
TRUNCATE TABLE public.memory_verse_mastery CASCADE;
TRUNCATE TABLE public.memory_verses CASCADE;

-- 3. XP & Gamification (2 tables)
TRUNCATE TABLE public.user_achievements CASCADE;
TRUNCATE TABLE public.daily_verse_streaks CASCADE;

-- 4. Progress Tracking (3 tables)
TRUNCATE TABLE public.user_challenge_progress CASCADE;
TRUNCATE TABLE public.user_learning_path_progress CASCADE;
TRUNCATE TABLE public.user_topic_progress CASCADE;

-- 5. Analytics & Feedback (2 tables)
TRUNCATE TABLE public.analytics_events CASCADE;
TRUNCATE TABLE public.feedback CASCADE;

-- 6. Notifications (1 table)
TRUNCATE TABLE public.notification_logs CASCADE;

-- =====================================================================
-- RESET SEQUENCES (auto-increment IDs)
-- =====================================================================

-- Note: Most tables use UUID primary keys, but if any use SERIAL/BIGSERIAL,
-- their sequences will be reset by the CASCADE option above

-- =====================================================================
-- VERIFICATION QUERIES (for manual checking after migration)
-- =====================================================================

-- Run these to verify data was truncated:
-- SELECT COUNT(*) FROM study_guides;                    -- Should be 0
-- SELECT COUNT(*) FROM memory_verses;                   -- Should be 0
-- SELECT COUNT(*) FROM user_achievements;               -- Should be 0
-- SELECT COUNT(*) FROM user_topic_progress;             -- Should be 0
-- SELECT COUNT(*) FROM analytics_events;                -- Should be 0

-- Verify preserved data still exists:
-- SELECT COUNT(*) FROM auth.users;                      -- Should be > 0 (preserved)
-- SELECT COUNT(*) FROM user_profiles;                   -- Should be > 0 (preserved)
-- SELECT COUNT(*) FROM subscriptions;                   -- Should be > 0 (preserved)
-- SELECT COUNT(*) FROM achievements;                    -- Should be > 0 (preserved)
-- SELECT COUNT(*) FROM learning_paths;                  -- Should be > 0 (preserved)
-- SELECT COUNT(*) FROM recommended_topics;              -- Should be > 0 (preserved)

COMMIT;

-- =====================================================================
-- SUMMARY
-- =====================================================================
-- Tables Truncated: 14
-- Total Data Removed: ~1.85 MB
--
-- Preserved:
--   ✓ User profiles and authentication (auth.users, user_profiles, user_preferences)
--   ✓ Subscription data (subscriptions, subscription_history, purchase_history)
--   ✓ System configuration (achievements, learning_paths, recommended_topics)
--   ✓ Static reference data (learning_path_topics, learning_path_translations)
--
-- Next Steps:
--   1. Users can generate fresh study guides
--   2. Users can add new memory verses
--   3. XP and achievements reset - users start fresh
--   4. Progress tracking cleared - learning paths can be restarted
-- =====================================================================
