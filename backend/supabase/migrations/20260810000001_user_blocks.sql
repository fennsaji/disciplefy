-- =====================================================
-- Migration: User Blocks (Apple Guideline 1.2 compliance)
-- Date: 2026-08-10
-- Tables:  user_blocks
-- Helpers: blocked_user_ids(), block_user()
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_user_block UNIQUE (blocker_id, blocked_id),
  CONSTRAINT chk_no_self_block CHECK (blocker_id <> blocked_id)
);

COMMENT ON TABLE user_blocks IS 'Viewer-level blocks. Global across fellowships and mutual; filtered out of every post/comment list query via blocked_user_ids()';

-- =====================================================
-- SECTION 2: SECURITY DEFINER HELPERS
-- =====================================================

CREATE OR REPLACE FUNCTION blocked_user_ids(p_user_id UUID)
RETURNS TABLE(user_id UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT blocked_id FROM user_blocks WHERE blocker_id = p_user_id
  UNION
  SELECT blocker_id FROM user_blocks WHERE blocked_id = p_user_id;
$$;

COMMENT ON FUNCTION blocked_user_ids IS 'Union of both block directions for one viewer; single source of truth for feed filtering';

CREATE OR REPLACE FUNCTION block_user(
  p_blocker_id UUID,
  p_blocked_id UUID,
  p_fellowship_id UUID DEFAULT NULL,
  p_content_type TEXT DEFAULT NULL,
  p_content_id UUID DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rows INT;
BEGIN
  INSERT INTO user_blocks (blocker_id, blocked_id, reason)
  VALUES (p_blocker_id, p_blocked_id, p_reason)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  -- Only a genuinely new block notifies the developer, and only when the
  -- block was started from a specific post or comment. fellowship_reports
  -- requires a non-null content_id, so contentless blocks (member list)
  -- surface through the Blocks tab of the admin moderation page instead.
  IF v_rows > 0
     AND p_fellowship_id IS NOT NULL
     AND p_content_type IS NOT NULL
     AND p_content_id IS NOT NULL THEN
    INSERT INTO fellowship_reports (
      fellowship_id, reporter_user_id, content_type, content_id, reason
    )
    VALUES (
      p_fellowship_id, p_blocker_id, p_content_type, p_content_id, 'user_blocked'
    );
  END IF;

  RETURN v_rows > 0;
END;
$$;

COMMENT ON FUNCTION block_user IS 'Atomically records a block and, for content-originated blocks, the matching moderation report';

-- =====================================================
-- SECTION 3: INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

-- =====================================================
-- SECTION 4: RLS AND GRANTS
-- =====================================================

ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_blocks_service_all" ON user_blocks;
CREATE POLICY "user_blocks_service_all" ON user_blocks FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT ALL ON public.user_blocks TO service_role;

COMMIT;
