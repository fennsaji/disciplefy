-- =====================================================
-- Migration: Community Fellowships Core
-- =====================================================
-- Tables: fellowships, fellowship_members, fellowship_study
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS fellowships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 3 AND 60),
  description TEXT CHECK (char_length(description) <= 500),
  mentor_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  max_members INTEGER NOT NULL DEFAULT 12 CHECK (max_members BETWEEN 2 AND 50),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE fellowships IS 'Private invite-only study groups led by a mentor';
COMMENT ON COLUMN fellowships.mentor_user_id IS 'Current mentor; updated on transfer-mentor';
COMMENT ON COLUMN fellowships.max_members IS 'Soft cap enforced by join function';

-- -----

CREATE TABLE IF NOT EXISTS fellowship_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('mentor', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT true,

  CONSTRAINT uq_fellowship_member UNIQUE (fellowship_id, user_id)
);

COMMENT ON TABLE fellowship_members IS 'Membership roster; is_active=false = soft-removed member';
COMMENT ON COLUMN fellowship_members.role IS 'mentor or member; only one mentor per fellowship enforced by functions';

-- -----

CREATE TABLE IF NOT EXISTS fellowship_study (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE RESTRICT,
  current_guide_index INTEGER NOT NULL DEFAULT 0 CHECK (current_guide_index >= 0),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_fellowship_active_study UNIQUE (fellowship_id)
);

COMMENT ON TABLE fellowship_study IS 'One active learning path per fellowship; replaced by study/set';

-- =====================================================
-- SECTION 2: INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_fellowships_mentor ON fellowships(mentor_user_id);
CREATE INDEX IF NOT EXISTS idx_fellowship_members_fellowship ON fellowship_members(fellowship_id);
CREATE INDEX IF NOT EXISTS idx_fellowship_members_user ON fellowship_members(user_id);
CREATE INDEX IF NOT EXISTS idx_fellowship_members_lookup ON fellowship_members(fellowship_id, user_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_fellowship_study_fellowship ON fellowship_study(fellowship_id);
CREATE INDEX IF NOT EXISTS idx_fellowships_active ON fellowships(is_active) WHERE is_active = true;

-- =====================================================
-- SECTION 3: TRIGGERS
-- =====================================================

CREATE TRIGGER set_fellowships_updated_at
  BEFORE UPDATE ON fellowships
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER set_fellowship_study_updated_at
  BEFORE UPDATE ON fellowship_study
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- SECTION 4: RLS
-- =====================================================

ALTER TABLE fellowships ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_study ENABLE ROW LEVEL SECURITY;

-- fellowships: authenticated users can read; service role manages writes
CREATE POLICY "fellowships_select" ON fellowships FOR SELECT TO authenticated USING (true);
CREATE POLICY "fellowships_service_all" ON fellowships FOR ALL TO service_role USING (true) WITH CHECK (true);

-- fellowship_members: service role only (functions bypass RLS)
CREATE POLICY "fellowship_members_service_all" ON fellowship_members FOR ALL TO service_role USING (true) WITH CHECK (true);

-- fellowship_study: service role only
CREATE POLICY "fellowship_study_service_all" ON fellowship_study FOR ALL TO service_role USING (true) WITH CHECK (true);

COMMIT;
