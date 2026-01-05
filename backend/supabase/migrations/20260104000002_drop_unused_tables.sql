-- Migration: Drop unused tables identified in codebase analysis
-- Date: 2026-01-04
-- Description: Removes 16 tables that have no code references (25% of application tables)

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

-- Drop Payment-related tables (4 tables)
DROP TABLE IF EXISTS public.otp_requests CASCADE;
DROP TABLE IF EXISTS public.payment_method_usage_history CASCADE;
DROP TABLE IF EXISTS public.receipt_counters CASCADE;
DROP TABLE IF EXISTS public.saved_payment_methods CASCADE;

-- Drop Subscription configuration table (1 table)
DROP TABLE IF EXISTS public.subscription_config CASCADE;

-- Drop Analytics tables (2 tables)
DROP TABLE IF EXISTS public.topic_engagement_metrics CASCADE;
DROP TABLE IF EXISTS public.topic_scripture_references CASCADE;

-- Drop Streak/Usage tracking tables (2 tables)
DROP TABLE IF EXISTS public.user_study_streaks CASCADE;
DROP TABLE IF EXISTS public.voice_usage_tracking CASCADE;

COMMIT;

-- Total tables dropped: 16
-- Note: llm_security_events table is KEPT and will be actively used for security logging
