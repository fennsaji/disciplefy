-- =====================================================
-- Migration: Drop fellowship_posts.to_mentors
-- Date: 2026-09-06
-- =====================================================
--
-- The "ask the mentors directly" flag is removed: every active member of a
-- fellowship (mentors included) is already notified of every new post, and
-- the private "Message mentor" contact covers the "reach a person" case.
-- The dedicated mentor-only targeting is redundant, so the column is dropped.

BEGIN;

ALTER TABLE public.fellowship_posts DROP COLUMN IF EXISTS to_mentors;

COMMIT;
