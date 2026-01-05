-- Migration: Drop unused tables identified in codebase analysis
-- Date: 2026-01-04
-- Description: Removes 12 unused tables (revised from original 16)
-- Preserved: receipt_counters, subscription_config, user_study_streaks, voice_usage_tracking

BEGIN;

-- Drop Discovery/Life Situations tables (5 tables)
DROP TABLE IF EXISTS public.life_situation_topics CASCADE;
DROP TABLE IF EXISTS public.life_situation_translations CASCADE;
DROP TABLE IF EXISTS public.life_situations CASCADE;
DROP TABLE IF EXISTS public.seasonal_translations CASCADE;
DROP TABLE IF EXISTS public.seasonal_topics CASCADE;

-- Drop Memory Verse Collections tables (2 tables)
DROP TABLE IF EXISTS public.memory_verse_collection_items CASCADE;
DROP TABLE IF EXISTS public.memory_verse_collections CASCADE;

-- Drop Payment-related tables (3 tables)
-- Note: receipt_counters PRESERVED (used by generate_receipt_number)
DROP TABLE IF EXISTS public.otp_requests CASCADE;
DROP TABLE IF EXISTS public.payment_method_usage_history CASCADE;
DROP TABLE IF EXISTS public.saved_payment_methods CASCADE;

-- Drop Analytics tables (2 tables)
DROP TABLE IF EXISTS public.topic_engagement_metrics CASCADE;
DROP TABLE IF EXISTS public.topic_scripture_references CASCADE;

COMMIT;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- Total tables dropped: 12
--
-- PRESERVED TABLES (4):
--   - receipt_counters           → Used by generate_receipt_number()
--   - subscription_config         → Used by subscription functions
--   - user_study_streaks         → Used by study streak tracking
--   - voice_usage_tracking       → Used by voice conversation quota system
--
-- ============================================================================
