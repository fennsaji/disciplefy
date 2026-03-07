-- =====================================================
-- Migration: Drop anonymous_study_guides Table
-- =====================================================
-- This table was never queried by any edge function.
-- Only existed in database.types.ts type definitions.
-- =====================================================

BEGIN;

DROP TABLE IF EXISTS anonymous_study_guides CASCADE;

COMMIT;
