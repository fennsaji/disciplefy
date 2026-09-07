-- Tell someone when they are made a mentor.
--
-- Promotion changed what a person can do — post as mentor, manage members,
-- set contact channels, create fellowships — but nothing told them it had
-- happened. They found out by noticing new controls.

ALTER TABLE public.notification_logs
  DROP CONSTRAINT IF EXISTS notification_logs_notification_type_check;

ALTER TABLE public.notification_logs
  ADD CONSTRAINT notification_logs_notification_type_check
  CHECK (notification_type IN (
    'daily_verse', 'recommended_topic', 'continue_learning',
    'streak_reminder', 'streak_milestone', 'streak_lost',
    'memory_verse_reminder', 'memory_verse_overdue',
    'achievement_unlocked', 'meeting_invite',
    'fellowship_daily_post', 'fellowship_discipler_reply',
    'fellowship_discipler_activity', 'fellowship_new_post',
    'fellowship_new_comment', 'fellowship_reaction',
    'fellowship_meeting', 'fellowship_meeting_reminder',
    'fellowship_meeting_cancelled', 'fellowship_meeting_invite',
    'fellowship_mentor_promoted'
  ));

ALTER TABLE public.user_notification_preferences
  ADD COLUMN IF NOT EXISTS fellowship_mentor_promoted_enabled BOOLEAN NOT NULL DEFAULT true;
