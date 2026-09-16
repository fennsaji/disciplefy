-- Let a member mute one fellowship's notifications.
--
-- Until now the only per-fellowship switch was discipler_activity_push, which
-- is mentor-only and covers the Discipler digest alone. A member in several
-- groups had no way to quieten a busy one without turning a whole category off
-- for every group in Settings.
--
-- fellowship_mutes is a different thing: a mentor silencing a member's posts.
-- This column is the member's own choice about their notifications.

ALTER TABLE fellowship_members
  ADD COLUMN IF NOT EXISTS notifications_muted BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN fellowship_members.notifications_muted IS
  'Member muted this fellowship''s push notifications for themselves';
