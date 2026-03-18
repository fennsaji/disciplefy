-- =====================================================
-- Migration: Clear All Saved Study Guides
-- =====================================================
-- Purpose: Delete all study guide content to force regeneration
--          with the updated LLM model (Sonnet for all modes).
-- =====================================================

BEGIN;

-- Clear conversation history (references study_guides)
DELETE FROM study_guide_conversations;

-- Clear in-progress guides
DELETE FROM study_guides_in_progress;

-- Clear user-saved study guide links
DELETE FROM user_study_guides;

-- Clear all study guides (main table)
DELETE FROM study_guides;

COMMIT;
