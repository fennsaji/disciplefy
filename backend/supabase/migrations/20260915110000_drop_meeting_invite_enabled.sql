-- Drop the unused meeting_invite_enabled preference.
--
-- The "added to a fellowship, here are your meetings" push is sent as
-- fellowship_meeting_invite and governed by fellowship_meeting_invite_enabled,
-- which the settings screen exposes. Nothing ever read this column, so it only
-- suggested a switch that did nothing.

ALTER TABLE user_notification_preferences
  DROP COLUMN IF EXISTS meeting_invite_enabled;
