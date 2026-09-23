-- Splits "Discipler advances lessons" into two independent decisions: pacing
-- within the current learning path (existing daily_post_auto_advance), and
-- whether the Discipler picks a NEW path on its own once the current one runs
-- out. Until now the single toggle covered both, so a mentor who wanted
-- automatic lesson-by-lesson posting but manual control over which path comes
-- next had no way to express that — turning the toggle off stopped lesson
-- pacing too.
--
-- Default true preserves today's behaviour for every existing fellowship.

ALTER TABLE public.fellowships
  ADD COLUMN IF NOT EXISTS daily_post_auto_advance_path BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.fellowships.daily_post_auto_advance_path IS
  'When true, Discipler picks the next learning path automatically once the current one is finished or exhausted. Independent of daily_post_auto_advance, which only paces lessons within a path.';
