-- =====================================================
-- Migration: Fellowship learning path defaults
-- =====================================================
-- Adds mentor-controlled daily-post cadence/advance prefs on `fellowships`,
-- a `default_learning_path_id()` helper (single source of the default path),
-- and backfills a `fellowship_study` row for every fellowship that has none.
-- =====================================================

BEGIN;

ALTER TABLE public.fellowships
  ADD COLUMN IF NOT EXISTS daily_post_frequency_days INTEGER NOT NULL DEFAULT 1
    CHECK (daily_post_frequency_days IN (1, 2, 7)),
  ADD COLUMN IF NOT EXISTS daily_post_auto_advance BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.fellowships.daily_post_frequency_days IS 'Mentor-set daily post cadence: 1=daily, 2=every 2 days, 7=weekly';
COMMENT ON COLUMN public.fellowships.daily_post_auto_advance IS 'When true, Discipler advances the group learning path lesson automatically';

CREATE OR REPLACE FUNCTION public.default_learning_path_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.learning_paths WHERE is_active = true ORDER BY display_order, created_at LIMIT 1
$$;

COMMENT ON FUNCTION public.default_learning_path_id() IS 'Single source of the default learning path assigned to new/backfilled fellowships (first active path by display_order)';

GRANT EXECUTE ON FUNCTION public.default_learning_path_id() TO service_role, authenticated;

-- Backfill: every fellowship without a fellowship_study row gets the default path.
INSERT INTO public.fellowship_study (fellowship_id, learning_path_id, current_guide_index)
SELECT f.id, public.default_learning_path_id(), 0
FROM public.fellowships f
LEFT JOIN public.fellowship_study fs ON fs.fellowship_id = f.id
WHERE fs.id IS NULL AND public.default_learning_path_id() IS NOT NULL
ON CONFLICT (fellowship_id) DO NOTHING;

COMMIT;
