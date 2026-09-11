-- Retire Reflect Mode.
--
-- The three insight lists and the five card questions were 18% of every study
-- guide's output tokens, measured 9 September 2026, and the screen that read
-- them has been removed from the app. Generation no longer produces them, so
-- the columns are dead weight.
--
-- Guides already stored keep every field a reader still sees: summary, context,
-- passage, interpretation, related verses, reflection questions and prayer.

ALTER TABLE public.study_guides DROP COLUMN IF EXISTS summary_insights;
ALTER TABLE public.study_guides DROP COLUMN IF EXISTS interpretation_insights;
ALTER TABLE public.study_guides DROP COLUMN IF EXISTS reflection_answers;
ALTER TABLE public.study_guides DROP COLUMN IF EXISTS context_question;
ALTER TABLE public.study_guides DROP COLUMN IF EXISTS summary_question;
ALTER TABLE public.study_guides DROP COLUMN IF EXISTS related_verses_question;
ALTER TABLE public.study_guides DROP COLUMN IF EXISTS reflection_question;
ALTER TABLE public.study_guides DROP COLUMN IF EXISTS prayer_question;

NOTIFY pgrst, 'reload schema';
