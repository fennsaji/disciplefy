BEGIN;

-- fellowship_meetings
-- Stores mirrored Google Calendar events for in-app display.
-- Actual event creation, invites, and cancellation are handled by Edge Functions
-- via the Google Calendar API. This table is the source of truth for the Flutter app.

CREATE TABLE IF NOT EXISTS fellowship_meetings (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id     UUID        NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  created_by        UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title             TEXT        NOT NULL,
  description       TEXT,
  starts_at         TIMESTAMPTZ NOT NULL,
  ends_at           TIMESTAMPTZ NOT NULL,
  recurrence        TEXT        CHECK (recurrence IN ('daily', 'weekly', 'monthly')),
  meet_link         TEXT        NOT NULL DEFAULT '',
  calendar_event_id TEXT        NOT NULL DEFAULT '',
  -- 'service_account' = event lives on the SA calendar (GOOGLE_CALENDAR_ID).
  -- 'user_primary'    = event lives on the mentor's personal Google Calendar
  --                     (created via their OAuth token; Meet link attached).
  calendar_type     TEXT        NOT NULL DEFAULT 'service_account'
                                CHECK (calendar_type IN ('service_account', 'user_primary')),
  is_cancelled      BOOLEAN     NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE fellowship_meetings IS 'Mirrored Google Calendar events for fellowship meetings; actual scheduling and invites handled via Google Calendar API in Edge Functions';
COMMENT ON COLUMN fellowship_meetings.calendar_event_id IS 'Google Calendar event ID used to cancel the event; empty string when Calendar creation failed';
COMMENT ON COLUMN fellowship_meetings.meet_link         IS 'Google Meet URL; empty string when no Meet link was generated';
COMMENT ON COLUMN fellowship_meetings.calendar_type     IS 'Which Google Calendar holds this event: service_account (SA calendar) or user_primary (mentor personal calendar via OAuth)';
COMMENT ON COLUMN fellowship_meetings.recurrence IS 'Recurrence pattern: daily, weekly, monthly, or NULL for one-time meetings';
COMMENT ON COLUMN fellowship_meetings.is_cancelled IS 'Soft-cancel flag; set true when mentor cancels. Cancelled events are excluded from all queries.';

-- Fast lookup: upcoming meetings for a fellowship (most common query)
CREATE INDEX IF NOT EXISTS idx_fellowship_meetings_upcoming
  ON fellowship_meetings (fellowship_id, starts_at)
  WHERE is_cancelled = false;

-- RLS: service role only — membership checks done in Edge Functions (consistent with all other fellowship tables)
ALTER TABLE fellowship_meetings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fellowship_meetings_service_all"
  ON fellowship_meetings FOR ALL TO service_role USING (true) WITH CHECK (true);

COMMIT;
