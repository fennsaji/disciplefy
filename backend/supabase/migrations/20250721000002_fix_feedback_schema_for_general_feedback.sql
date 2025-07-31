-- Fix feedback table schema to support general feedback
-- Make study_guide_id nullable to allow general feedback without study guide reference
-- This reverts the overly restrictive constraint from migration 20250716182200

-- 1. Make study_guide_id nullable to allow general feedback
ALTER TABLE public.feedback ALTER COLUMN study_guide_id DROP NOT NULL;

-- 2. Add a comment explaining the new schema
COMMENT ON COLUMN public.feedback.study_guide_id IS 'Optional reference to study guide. NULL for general feedback.';
COMMENT ON TABLE public.feedback IS 'User feedback table supporting both study-specific and general feedback';