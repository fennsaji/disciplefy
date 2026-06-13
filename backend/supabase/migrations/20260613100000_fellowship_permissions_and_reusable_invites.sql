-- Fellowship enhancements:
--   1) per-fellowship posting permission (all members vs mentor/admin only)
--   2) unlimited members (NULL = unlimited; app-admin only)
--   3) reusable invite links (one link, many joiners)

-- ── Feature 1: posting permission ───────────────────────────────────────────
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS posting_permission TEXT NOT NULL DEFAULT 'all_members'
    CHECK (posting_permission IN ('all_members', 'mentor_only'));

COMMENT ON COLUMN fellowships.posting_permission IS
  'all_members = any member can post; mentor_only = only the mentor (group admin) can post';

-- ── Feature 2: unlimited members (NULL = unlimited) ─────────────────────────
-- Keep DEFAULT 12 for normal creators; NULL is reserved for app-admins (enforced
-- in the edge function). Relax the old 2..50 cap to "NULL or >= 2".
ALTER TABLE fellowships ALTER COLUMN max_members DROP NOT NULL;
ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_max_members_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_max_members_check
  CHECK (max_members IS NULL OR max_members >= 2);

COMMENT ON COLUMN fellowships.max_members IS
  'Max members; NULL = unlimited (app-admin only); otherwise >= 2.';

-- ── Feature 3: reusable invite links ────────────────────────────────────────
ALTER TABLE fellowship_invites
  ADD COLUMN IF NOT EXISTS max_uses INTEGER CHECK (max_uses IS NULL OR max_uses >= 1),
  ADD COLUMN IF NOT EXISTS use_count INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN fellowship_invites.max_uses IS
  'Max successful joins via this link; NULL = unlimited (reusable).';
COMMENT ON COLUMN fellowship_invites.use_count IS
  'Number of successful joins via this link.';

-- Reflect prior single-use joins in the new counter.
UPDATE fellowship_invites SET use_count = 1 WHERE used_at IS NOT NULL AND use_count = 0;

-- Rebuild token/fellowship indexes WITHOUT the `used_at IS NULL` filter so that
-- reusable links remain discoverable after their first use.
DROP INDEX IF EXISTS idx_fellowship_invites_token;
DROP INDEX IF EXISTS idx_fellowship_invites_fellowship;
CREATE INDEX IF NOT EXISTS idx_fellowship_invites_token
  ON fellowship_invites(token) WHERE is_revoked = false;
CREATE INDEX IF NOT EXISTS idx_fellowship_invites_fellowship
  ON fellowship_invites(fellowship_id) WHERE is_revoked = false;
