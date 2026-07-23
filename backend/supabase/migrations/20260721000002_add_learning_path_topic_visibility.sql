-- ============================================================================
-- Learning path topic visibility and path-specific titles
-- ============================================================================
--
-- WHY THIS SHAPE
--
-- recommended_topics rows are shared by reference. 'What is the Gospel?' is one
-- row used by four learning paths. So:
--
--   * Hiding a topic from ONE path cannot use recommended_topics.is_active --
--     that hides it from all four. The flag must live on the join table.
--
--   * Retitling a topic for ONE path cannot use recommended_topics.title, nor
--     recommended_topics_translations, because that table is keyed
--     (topic_id, language_code) and has no path dimension. A path-specific
--     title needs a (learning_path_id, topic_id, language_code) key, which is
--     what learning_path_topic_titles provides.
--
-- No read path consults either of these yet -- see migration 20260721000003.
-- Applying this migration alone is a no-op for users.
--
-- IDEMPOTENT within an IN-ORDER REPLAY of the full 20260721 sequence -- NOT
-- standalone. The DDL is all IF NOT EXISTS, but the verification block below
-- asserts `v_false <> 0` (zero rows with is_active = false). That holds on a
-- fresh replay, because 20260721000004 is what first flips rows to false and it
-- runs after this file. Re-running this file BY HAND on a database where
-- 20260721000004 has already landed makes v_false = 13 and aborts.
-- ============================================================================

BEGIN;

ALTER TABLE learning_path_topics
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN learning_path_topics.is_active IS
  'Per-path topic visibility. false hides this topic from THIS path only; the '
  'same recommended_topics row stays visible in other paths that reference it.';

-- Partial index: every user-facing read filters is_active = true.
CREATE INDEX IF NOT EXISTS idx_learning_path_topics_active
  ON learning_path_topics(learning_path_id, position)
  WHERE is_active = true;

CREATE TABLE IF NOT EXISTS learning_path_topic_titles (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
  topic_id         UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
  language_code    VARCHAR(5) NOT NULL,
  title            TEXT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (learning_path_id, topic_id, language_code),
  CONSTRAINT learning_path_topic_titles_language_code_check
    CHECK (language_code IN ('en', 'hi', 'ml')),
  CONSTRAINT learning_path_topic_titles_title_not_blank
    CHECK (length(btrim(title)) > 0)
);

COMMENT ON TABLE learning_path_topic_titles IS
  'Path-specific topic titles, per language. Overrides recommended_topics.title '
  'and recommended_topics_translations.title for one path only. Used where the '
  'same topic serves a different teaching purpose in different paths.';

-- Note: no separate lookup index is needed here -- the UNIQUE constraint above
-- already creates an index on (learning_path_id, topic_id, language_code)
-- with the identical column order.

-- A title override is meaningless without a matching join row.
ALTER TABLE learning_path_topic_titles
  DROP CONSTRAINT IF EXISTS learning_path_topic_titles_join_fk;
ALTER TABLE learning_path_topic_titles
  ADD CONSTRAINT learning_path_topic_titles_join_fk
  FOREIGN KEY (learning_path_id, topic_id)
  REFERENCES learning_path_topics(learning_path_id, topic_id)
  ON DELETE CASCADE;

-- -----------------------------------------------------
-- RLS Policies: learning_path_topic_titles
-- -----------------------------------------------------
-- Same trust class as learning_path_translations: public reference content,
-- readable by anyone viewing an active path, writable only by service_role.

ALTER TABLE learning_path_topic_titles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS learning_path_topic_titles_select_all ON learning_path_topic_titles;
CREATE POLICY learning_path_topic_titles_select_all
  ON learning_path_topic_titles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM learning_paths lp
      WHERE lp.id = learning_path_id AND lp.is_active = true
    )
  );

DROP POLICY IF EXISTS learning_path_topic_titles_service_role_all ON learning_path_topic_titles;
CREATE POLICY learning_path_topic_titles_service_role_all
  ON learning_path_topic_titles FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DO $$
DECLARE
  v_col   INTEGER;
  v_table INTEGER;
  v_false INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_col FROM information_schema.columns
   WHERE table_name = 'learning_path_topics' AND column_name = 'is_active';
  IF v_col <> 1 THEN
    RAISE EXCEPTION 'learning_path_topics.is_active was not created';
  END IF;

  SELECT COUNT(*) INTO v_table FROM information_schema.tables
   WHERE table_name = 'learning_path_topic_titles';
  IF v_table <> 1 THEN
    RAISE EXCEPTION 'learning_path_topic_titles was not created';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
     WHERE schemaname = 'public'
       AND tablename  = 'learning_path_topic_titles'
       AND rowsecurity = true
  ) THEN
    RAISE EXCEPTION 'RLS is not enabled on learning_path_topic_titles';
  END IF;

  -- This migration must not hide anything.
  SELECT COUNT(*) INTO v_false FROM learning_path_topics WHERE is_active = false;
  IF v_false <> 0 THEN
    RAISE EXCEPTION 'Expected 0 inactive topics after schema-only migration, found %', v_false;
  END IF;

  RAISE NOTICE 'Schema ready. No behaviour change until 20260721000003 lands.';
END $$;

COMMIT;
