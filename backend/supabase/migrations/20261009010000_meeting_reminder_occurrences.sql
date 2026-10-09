-- Meeting reminders: one per occurrence, stamped only after sending.
--
-- 1. Recurring meetings only ever got reminders for their FIRST occurrence:
--    fellowship-meetings/create inserted two meeting_reminders rows (1 hour,
--    10 minutes) for starts_at and nothing ever scheduled the next ones.
--    occurrence_starts_at records which occurrence a row is for; the reminder
--    cron now queues the next occurrence after each one. The unique index
--    makes that scheduling idempotent.
-- 2. The cron stamped sent_at BEFORE sending (to stop two runs sending twice),
--    so a failed member query or FCM error lost the reminder for good. It now
--    claims a row with a short lease (claimed_until) and stamps sent_at only
--    after the push went out, retrying up to 3 attempts.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS, and the
-- backfill skips meetings that already have a pending reminder per label.

BEGIN;

ALTER TABLE public.meeting_reminders
  ADD COLUMN IF NOT EXISTS occurrence_starts_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS claimed_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS attempts INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.meeting_reminders.occurrence_starts_at IS
  'Start of the occurrence this reminder is for (recurring meetings get one pair per occurrence). NULL on legacy rows = the meeting''s starts_at.';
COMMENT ON COLUMN public.meeting_reminders.claimed_until IS
  'Lease held by the reminder cron run that is sending this row; other runs skip it until then.';
COMMENT ON COLUMN public.meeting_reminders.sent_at IS
  'NULL = not yet sent; stamped by the reminder cron after the push went out (or was skipped / gave up).';

UPDATE public.meeting_reminders r
SET occurrence_starts_at = m.starts_at
FROM public.fellowship_meetings m
WHERE m.id = r.meeting_id
  AND r.occurrence_starts_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_meeting_reminders_occurrence
  ON public.meeting_reminders (meeting_id, offset_label, occurrence_starts_at);

-- Backfill: recurring meetings whose reminders were all used up get a pair for
-- their next occurrence still ahead.
DO $$
DECLARE
  m RECORD;
  lbl TEXT;
  off INTERVAL;
  step INTERVAL;
  occ TIMESTAMPTZ;
  i INTEGER;
BEGIN
  FOR m IN
    SELECT id, starts_at, recurrence
    FROM public.fellowship_meetings
    WHERE recurrence IN ('daily', 'weekly', 'monthly')
      AND COALESCE(is_cancelled, false) = false
  LOOP
    step := CASE m.recurrence
      WHEN 'daily' THEN INTERVAL '1 day'
      WHEN 'weekly' THEN INTERVAL '7 days'
      ELSE INTERVAL '1 month'
    END;
    FOREACH lbl IN ARRAY ARRAY['1 hour', '10 minutes'] LOOP
      off := CASE lbl WHEN '1 hour' THEN INTERVAL '1 hour' ELSE INTERVAL '10 minutes' END;
      CONTINUE WHEN EXISTS (
        SELECT 1 FROM public.meeting_reminders r
        WHERE r.meeting_id = m.id AND r.offset_label = lbl AND r.sent_at IS NULL
      );
      occ := m.starts_at;
      i := 0;
      WHILE occ - off <= NOW() AND i < 4000 LOOP
        occ := m.starts_at + step * (i + 1);
        i := i + 1;
      END LOOP;
      CONTINUE WHEN occ - off <= NOW();
      INSERT INTO public.meeting_reminders (meeting_id, remind_at, offset_label, occurrence_starts_at)
      VALUES (m.id, occ - off, lbl, occ)
      ON CONFLICT (meeting_id, offset_label, occurrence_starts_at) DO NOTHING;
    END LOOP;
  END LOOP;
END
$$;

COMMIT;
