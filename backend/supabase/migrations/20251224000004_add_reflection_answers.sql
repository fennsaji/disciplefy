-- Add reflection_answers column to study_guides table
-- This column stores LLM-generated actionable life application responses for Reflect Mode
-- Follows the same pattern as summary_insights and interpretation_insights

ALTER TABLE public.study_guides
ADD COLUMN IF NOT EXISTS reflection_answers TEXT[];

-- Create index for performance when querying guides with reflection answers
CREATE INDEX IF NOT EXISTS idx_study_guides_has_reflection_answers
ON public.study_guides((reflection_answers IS NOT NULL))
WHERE reflection_answers IS NOT NULL;

-- Add comment explaining the column purpose
COMMENT ON COLUMN public.study_guides.reflection_answers IS
'LLM-generated actionable life application responses for Reflection card interaction (3-4 options). Users select from these concrete action steps during Reflect Mode to personalize their study experience.';
