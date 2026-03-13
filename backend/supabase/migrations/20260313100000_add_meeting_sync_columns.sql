-- Migration: 20260313100000_add_meeting_sync_columns
-- Adds last_synced_at and google_refresh_token to fellowship_meetings.
--
-- RLS notes:
--   • service_role bypasses RLS by default — no policy changes needed for
--     the /invite-member internal path.
--   • Existing fellowship owner policies grant mentors full access to their
--     own fellowship_meetings rows, covering SELECT/UPDATE on both new columns.
--   • google_refresh_token is not exposed in SELECT responses returned to clients
--     (the list endpoint only selects specific columns excluding this field).

ALTER TABLE fellowship_meetings
  ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS google_refresh_token TEXT;

COMMENT ON COLUMN fellowship_meetings.last_synced_at IS
  'Timestamp of the last Google Calendar attendee sync for this meeting. '
  'NULL means the meeting has never been synced.';

COMMENT ON COLUMN fellowship_meetings.google_refresh_token IS
  'Google OAuth refresh token for the meeting creator. Stored at creation time '
  'so the backend can refresh the access token for /sync-calendar without '
  'requiring the mentor to re-authenticate. NULL for service_account or in-person meetings.';
