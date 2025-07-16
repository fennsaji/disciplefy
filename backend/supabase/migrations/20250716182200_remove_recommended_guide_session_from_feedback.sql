-- 1. Drop the existing CHECK constraint
ALTER TABLE public.feedback DROP CONSTRAINT feedback_reference_check;

-- 2. Drop the recommended_guide_session_id column
ALTER TABLE public.feedback DROP COLUMN recommended_guide_session_id;

-- 3. Make the study_guide_id column non-nullable
ALTER TABLE public.feedback ALTER COLUMN study_guide_id SET NOT NULL;
