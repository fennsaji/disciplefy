-- A toggle for every push type.
--
-- user_notification_preferences covered 7 of the 20 types in the
-- notification_logs check constraint. The 13 below — every fellowship and
-- meeting notification, plus continue_learning and achievement_unlocked —
-- had no switch at all, so a member of an active group received every post,
-- comment, reaction and Discipler reply with no way to quieten any of it
-- short of disabling notifications for the whole app.
--
-- All default to true: this adds control without changing what anyone
-- currently receives.

ALTER TABLE public.user_notification_preferences
  -- Study
  ADD COLUMN IF NOT EXISTS continue_learning_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS achievement_unlocked_enabled BOOLEAN NOT NULL DEFAULT true,
  -- Fellowship activity
  ADD COLUMN IF NOT EXISTS fellowship_daily_post_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fellowship_new_post_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fellowship_new_comment_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fellowship_reaction_enabled BOOLEAN NOT NULL DEFAULT true,
  -- Discipler
  ADD COLUMN IF NOT EXISTS fellowship_discipler_reply_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fellowship_discipler_activity_enabled BOOLEAN NOT NULL DEFAULT true,
  -- Meetings
  ADD COLUMN IF NOT EXISTS fellowship_meeting_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fellowship_meeting_reminder_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fellowship_meeting_cancelled_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fellowship_meeting_invite_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS meeting_invite_enabled BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.user_notification_preferences.fellowship_reaction_enabled IS
  'Reactions are the noisiest fellowship push; kept default-on so behaviour is unchanged, but this is the first switch most members will reach for.';
