-- Add 4 new reflection question columns for dynamic LLM-generated questions
-- These fields enable content-aware reflection questions for all 6 Reflect Mode cards

-- Add nullable TEXT columns for backward compatibility
ALTER TABLE public.study_guides
ADD COLUMN IF NOT EXISTS summary_question TEXT,
ADD COLUMN IF NOT EXISTS related_verses_question TEXT,
ADD COLUMN IF NOT EXISTS reflection_question TEXT,
ADD COLUMN IF NOT EXISTS prayer_question TEXT;

-- Add index for efficient queries on guides with dynamic questions
-- This helps optimize queries that filter for guides with new question fields
CREATE INDEX IF NOT EXISTS idx_study_guides_has_reflection_questions
ON public.study_guides((summary_question IS NOT NULL))
WHERE summary_question IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN public.study_guides.summary_question IS 'LLM-generated question about what resonates from the summary (8-12 words)';
COMMENT ON COLUMN public.study_guides.related_verses_question IS 'LLM-generated question prompting verse selection/memorization (8-12 words)';
COMMENT ON COLUMN public.study_guides.reflection_question IS 'LLM-generated question connecting study to daily life (8-12 words)';
COMMENT ON COLUMN public.study_guides.prayer_question IS 'LLM-generated question inviting personal prayer response (6-10 words)';
