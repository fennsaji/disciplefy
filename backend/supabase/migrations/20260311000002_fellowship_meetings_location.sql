BEGIN;

ALTER TABLE fellowship_meetings
  ADD COLUMN IF NOT EXISTS location TEXT;

COMMENT ON COLUMN fellowship_meetings.location IS
  'Physical gathering location. When set, the meeting is in-person and no Meet link is generated. NULL = online meeting.';

COMMIT;
