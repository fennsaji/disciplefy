BEGIN;

-- meeting_reminders
-- Tracks scheduled FCM reminders for fellowship meetings.
-- Two rows are inserted per meeting: 1 hour before and 10 minutes before.
-- The cron Edge Function (fellowship-meetings-reminder) polls this table
-- every minute, sends unsent reminders, then stamps sent_at.

CREATE TABLE IF NOT EXISTS meeting_reminders (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id   UUID        NOT NULL REFERENCES fellowship_meetings(id) ON DELETE CASCADE,
  remind_at    TIMESTAMPTZ NOT NULL,
  offset_label TEXT        NOT NULL CHECK (offset_label IN ('1 hour', '10 minutes')),
  sent_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  meeting_reminders IS 'Pending FCM reminders for upcoming meetings; stamped with sent_at once dispatched by the cron Edge Function';
COMMENT ON COLUMN meeting_reminders.offset_label IS '1 hour = 60 min before, 10 minutes = 10 min before starts_at';
COMMENT ON COLUMN meeting_reminders.sent_at       IS 'NULL = not yet sent; set by fellowship-meetings-reminder cron function once FCM is dispatched';

-- Fast lookup: unsent reminders that are due (the cron query)
CREATE INDEX IF NOT EXISTS idx_meeting_reminders_pending
  ON meeting_reminders (remind_at)
  WHERE sent_at IS NULL;

ALTER TABLE meeting_reminders ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'meeting_reminders'
      AND policyname = 'meeting_reminders_service_all'
  ) THEN
    CREATE POLICY "meeting_reminders_service_all"
      ON meeting_reminders FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

COMMIT;
