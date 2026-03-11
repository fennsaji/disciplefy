BEGIN;

-- Add is_public column to fellowships table
ALTER TABLE fellowships ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;
COMMENT ON COLUMN fellowships.is_public IS 'Whether the fellowship is discoverable by all users in the Discover tab';

-- Add language column to fellowships table
ALTER TABLE fellowships ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'hi', 'ml'));
COMMENT ON COLUMN fellowships.language IS 'Primary language of the fellowship (en = English, hi = Hindi, ml = Malayalam)';

-- Create partial index for efficient public fellowship discovery queries
CREATE INDEX IF NOT EXISTS idx_fellowships_public_language ON fellowships (is_public, language) WHERE is_public = true;

-- Tighten fellowships RLS: replace the overly-broad "authenticated can read all"
-- policy so that private fellowships are only visible to their own members.
-- NOTE: is_fellowship_member() must remain SECURITY DEFINER so it can bypass
-- RLS on fellowship_members when evaluated inside this RLS policy expression.
DROP POLICY IF EXISTS "fellowships_select" ON fellowships;
CREATE POLICY "fellowships_select" ON fellowships FOR SELECT TO authenticated
  USING (
    is_public = true
    OR is_fellowship_member(id, auth.uid())
  );

-- Defensive guard: ensure no existing post_type values fall outside the new constraint set.
-- The OR post_type IS NULL guard is necessary because SQL NOT IN returns NULL (falsy)
-- for any row where post_type itself is NULL, so those rows would not be caught otherwise.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM fellowship_posts
    WHERE post_type NOT IN ('general', 'prayer', 'praise', 'question', 'system')
       OR post_type IS NULL
  ) THEN
    RAISE EXCEPTION 'fellowship_posts contains post_type values outside the allowed set — migration aborted';
  END IF;
END $$;

-- Update fellowship_posts post_type constraint to include 'system' type
ALTER TABLE fellowship_posts DROP CONSTRAINT IF EXISTS fellowship_posts_post_type_check;
ALTER TABLE fellowship_posts ADD CONSTRAINT fellowship_posts_post_type_check
  CHECK (post_type IN ('general', 'prayer', 'praise', 'question', 'system'));

COMMIT;
