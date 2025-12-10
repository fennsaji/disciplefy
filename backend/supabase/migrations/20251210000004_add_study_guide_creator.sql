-- Migration: Add creator tracking to study_guides table
-- Purpose: Track who originally generated each study guide so that:
--   - Original creator can revisit for FREE
--   - Other users accessing cached guides pay tokens
--
-- Decision: Legacy guides (no creator) remain FREE for all users

-- Add creator tracking columns to study_guides
ALTER TABLE public.study_guides
ADD COLUMN IF NOT EXISTS creator_user_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS creator_session_id TEXT;

-- Index for efficient creator lookups
CREATE INDEX IF NOT EXISTS idx_study_guides_creator_user_id
ON public.study_guides(creator_user_id);

-- Documentation comments
COMMENT ON COLUMN public.study_guides.creator_user_id IS
'User ID who originally generated this study guide (null for anonymous creators or legacy guides)';

COMMENT ON COLUMN public.study_guides.creator_session_id IS
'Session ID for anonymous users who generated this guide (null for authenticated users or legacy guides)';
