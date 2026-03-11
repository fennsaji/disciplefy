-- =====================================================
-- Migration: Community Management
-- =====================================================
-- Tables: fellowship_invites, fellowship_mutes, fellowship_reports,
--         fellowship_notification_queue
-- Helpers: is_fellowship_member(), is_fellowship_mentor()
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS fellowship_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token UUID NOT NULL DEFAULT gen_random_uuid(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  used_at TIMESTAMPTZ,
  used_by UUID REFERENCES auth.users(id),
  is_revoked BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_invite_token UNIQUE (token)
);

COMMENT ON TABLE fellowship_invites IS '7-day invite links; max 10 active per fellowship enforced by function';

-- -----

CREATE TABLE IF NOT EXISTS fellowship_mutes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  muted_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  muted_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_fellowship_mute UNIQUE (fellowship_id, muted_user_id)
);

COMMENT ON TABLE fellowship_mutes IS 'Mentor-muted members; posts/comments filtered in list queries';

-- -----

CREATE TABLE IF NOT EXISTS fellowship_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL CHECK (content_type IN ('post', 'comment')),
  content_id UUID NOT NULL,
  reason TEXT NOT NULL CHECK (char_length(reason) BETWEEN 5 AND 500),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE fellowship_reports IS 'Member-submitted content reports; reviewed by mentor or admin';

-- -----

CREATE TABLE IF NOT EXISTS fellowship_notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  recipient_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL CHECK (notification_type IN ('new_post', 'new_comment', 'study_advanced', 'new_member')),
  payload JSONB NOT NULL DEFAULT '{}',
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE fellowship_notification_queue IS 'Outbox pattern; rows inserted by functions, processed by cron (post-MVP)';

-- =====================================================
-- SECTION 2: SECURITY DEFINER HELPERS
-- =====================================================

CREATE OR REPLACE FUNCTION is_fellowship_member(p_fellowship_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fellowship_members
    WHERE fellowship_id = p_fellowship_id
      AND user_id = p_user_id
      AND is_active = true
  );
$$;

COMMENT ON FUNCTION is_fellowship_member IS 'Fast O(1) member check using indexed lookup; used by Edge Functions';

CREATE OR REPLACE FUNCTION is_fellowship_mentor(p_fellowship_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fellowship_members
    WHERE fellowship_id = p_fellowship_id
      AND user_id = p_user_id
      AND role = 'mentor'
      AND is_active = true
  );
$$;

COMMENT ON FUNCTION is_fellowship_mentor IS 'Fast mentor check; used by update/invite/study/moderation functions';

-- =====================================================
-- SECTION 3: INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_fellowship_invites_token ON fellowship_invites(token) WHERE is_revoked = false AND used_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_fellowship_invites_fellowship ON fellowship_invites(fellowship_id) WHERE is_revoked = false AND used_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_fellowship_mutes_fellowship ON fellowship_mutes(fellowship_id);
CREATE INDEX IF NOT EXISTS idx_fellowship_reports_fellowship ON fellowship_reports(fellowship_id, status);
CREATE INDEX IF NOT EXISTS idx_notification_queue_recipient ON fellowship_notification_queue(recipient_user_id, sent_at) WHERE sent_at IS NULL;

-- =====================================================
-- SECTION 4: RLS
-- =====================================================

ALTER TABLE fellowship_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_notification_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fellowship_invites_service_all" ON fellowship_invites FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "fellowship_mutes_service_all" ON fellowship_mutes FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "fellowship_reports_service_all" ON fellowship_reports FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "fellowship_notification_queue_service_all" ON fellowship_notification_queue FOR ALL TO service_role USING (true) WITH CHECK (true);

COMMIT;
