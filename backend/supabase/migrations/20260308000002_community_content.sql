-- =====================================================
-- Migration: Community Content
-- =====================================================
-- Tables: fellowship_posts, fellowship_comments, fellowship_reactions
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS fellowship_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  author_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
  post_type TEXT NOT NULL DEFAULT 'general' CHECK (post_type IN ('general', 'prayer', 'praise', 'question')),
  reaction_counts JSONB NOT NULL DEFAULT '{}',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE fellowship_posts IS 'Posts in a fellowship feed; soft-deleted only';
COMMENT ON COLUMN fellowship_posts.reaction_counts IS 'Denormalized counts e.g. {"👍":3,"🙏":1}; updated atomically by reactions/toggle';

-- -----

CREATE TABLE IF NOT EXISTS fellowship_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  author_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE fellowship_comments IS 'Comments on fellowship posts; soft-deleted only';
COMMENT ON COLUMN fellowship_comments.fellowship_id IS 'Denormalized for RLS policy convenience';

-- -----

CREATE TABLE IF NOT EXISTS fellowship_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (char_length(reaction_type) <= 10),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_user_post_reaction UNIQUE (post_id, user_id, reaction_type)
);

COMMENT ON TABLE fellowship_reactions IS 'One row per user per reaction per post; toggle deletes existing row';

-- =====================================================
-- SECTION 2: INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_fellowship_posts_feed ON fellowship_posts(fellowship_id, created_at DESC) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_fellowship_posts_author ON fellowship_posts(author_user_id);
CREATE INDEX IF NOT EXISTS idx_fellowship_comments_post ON fellowship_comments(post_id, created_at) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_fellowship_comments_fellowship ON fellowship_comments(fellowship_id);
CREATE INDEX IF NOT EXISTS idx_fellowship_reactions_post ON fellowship_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_fellowship_reactions_user ON fellowship_reactions(user_id, post_id);

-- =====================================================
-- SECTION 3: TRIGGERS
-- =====================================================

CREATE TRIGGER set_fellowship_posts_updated_at
  BEFORE UPDATE ON fellowship_posts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER set_fellowship_comments_updated_at
  BEFORE UPDATE ON fellowship_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- SECTION 4: RLS
-- =====================================================

ALTER TABLE fellowship_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_reactions ENABLE ROW LEVEL SECURITY;

-- All content: service role only (member checks done in functions)
CREATE POLICY "fellowship_posts_service_all" ON fellowship_posts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "fellowship_comments_service_all" ON fellowship_comments FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "fellowship_reactions_service_all" ON fellowship_reactions FOR ALL TO service_role USING (true) WITH CHECK (true);

COMMIT;
