-- Add summary_insights column to study_guides table
-- This stores LLM-generated resonance themes for Summary card interaction (3-4 options)
-- Part of dynamic reflection options implementation

ALTER TABLE public.study_guides
ADD COLUMN IF NOT EXISTS summary_insights TEXT[];

-- Create index for performance when filtering guides with summary insights
CREATE INDEX IF NOT EXISTS idx_study_guides_has_summary_insights
ON public.study_guides((summary_insights IS NOT NULL))
WHERE summary_insights IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN public.study_guides.summary_insights IS
'LLM-generated resonance themes for Summary card interaction (3-4 options for Standard/Deep Dive, 2-3 for Quick/Lectio Divina). Examples: "Finding strength in God''s promises", "Experiencing comfort through scripture"';
