-- Backfill user_id and session_id from event_data JSONB into indexed table columns
-- Previously, analytics-service.ts only stored these in event_data but not in the table columns
-- Only backfill user_id for users that still exist in auth.users (FK constraint)

UPDATE analytics_events ae
SET user_id = (ae.event_data->>'userId')::uuid
FROM auth.users u
WHERE ae.user_id IS NULL
  AND ae.event_data->>'userId' IS NOT NULL
  AND u.id = (ae.event_data->>'userId')::uuid;

UPDATE analytics_events
SET session_id = event_data->>'sessionId'
WHERE session_id IS NULL
  AND event_data->>'sessionId' IS NOT NULL;
