-- ============================================================================
-- DRY RUN: what migrations 4-6 would do to every stored cursor.
--
-- READ-ONLY. No INSERT, UPDATE, DELETE or DDL. Safe on production.
--
-- Simulates, without applying:
--   1. the 13 hides from 20260721000004
--   2. the contiguous renumber from 20260721000005
--   3. the cursor remap (same four-branch COALESCE the migration uses)
--   4. the Trinity / Learning to Pray inserts and their +1 cursor bump
--   5. the completed-enrolment reopen from 20260721000006
--
-- The thing to check: for every row, currently_on and would_land_on must be the
-- SAME TITLE. A difference means the remap would move that user or fellowship
-- to a different lesson.
--
-- The one intended exception is a cursor parked on a topic that is being hidden
-- -- it moves forward to the next visible topic, which is correct.
-- ============================================================================
\pset pager off

-- This simulation assumes an UNMIGRATED database. Run against one that already
-- has 20260721000002-6 applied and it double-counts the inserts, reporting
-- mismatches that are artefacts rather than real. Refuse to run in that case.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
              WHERE table_schema='public' AND table_name='learning_path_topic_titles') THEN
    RAISE EXCEPTION
      'This database already has migrations 20260721000002-6 applied. The dry run only means something against an unmigrated database -- on a migrated one it double-applies the topic inserts and reports false mismatches.';
  END IF;
END $guard$;

WITH hides(path_slug, topic_title) AS (VALUES
  ('baptism-and-lords-supper','Baptism and Communion'),
  ('the-local-church','Baptism and Communion'),
  ('understanding-the-bible','Why Read the Bible?'),
  ('growing-in-discipleship','Overcoming Temptation'),
  ('understanding-the-bible','Meditation on God''s Word'),
  ('growing-in-discipleship','Living a Holy Life'),
  ('growing-in-discipleship','How to Study the Bible'),
  ('understanding-the-bible','How We Got the Bible'),
  ('the-local-church','Church Leadership and Authority'),
  ('the-local-church','Spiritual Gifts and Their Use'),
  ('baptism-and-lords-supper','Baptism, the Lord''s Supper, and Church Membership'),
  ('growing-in-discipleship','Discerning God''s Will'),
  ('growing-in-discipleship','Fasting and Prayer')
),
-- Mark each row as it WOULD be after migration 4.
marked AS (
  SELECT lpt.learning_path_id,
         lpt.topic_id,
         lpt.position AS old_position,
         rt.title,
         lp.slug,
         (h.path_slug IS NULL AND rt.is_active IS TRUE) AS would_be_visible
    FROM learning_path_topics lpt
    JOIN learning_paths lp      ON lp.id = lpt.learning_path_id
    JOIN recommended_topics rt  ON rt.id = lpt.topic_id
    LEFT JOIN hides h ON h.path_slug = lp.slug AND h.topic_title = rt.title
),
-- Renumber exactly as migration 5 does: running count of visible rows.
renumbered AS (
  SELECT m.*,
         (COUNT(*) FILTER (WHERE m.would_be_visible)
            OVER (PARTITION BY m.learning_path_id ORDER BY m.old_position) - 1) AS new_ordinal
    FROM marked m
),
-- The insert points from migration 6, and how many visible rows precede them.
insert_anchor AS (
  SELECT r.learning_path_id, r.new_ordinal AS anchor_ordinal
    FROM renumbered r
   WHERE (r.slug = 'new-believer-essentials'  AND r.title = 'Who is Jesus Christ?')
      OR (r.slug = 'growing-in-discipleship'  AND r.title = 'The Cost of Following Jesus')
)
-- ---------------------------------------------------------------------------
SELECT 'FELLOWSHIP' AS kind,
       lp.slug,
       fs.current_guide_index AS cur,
       (SELECT r.title FROM renumbered r
         WHERE r.learning_path_id = fs.learning_path_id
           AND r.old_position = fs.current_guide_index) AS currently_on,
       predicted.new_index,
       (SELECT r.title FROM renumbered r
         WHERE r.learning_path_id = fs.learning_path_id
           AND r.would_be_visible
           AND r.new_ordinal = predicted.new_index) AS would_land_on
  FROM fellowship_study fs
  JOIN learning_paths lp ON lp.id = fs.learning_path_id
  CROSS JOIN LATERAL (
    SELECT COALESCE(
      (SELECT r.new_ordinal FROM renumbered r
        WHERE r.learning_path_id = fs.learning_path_id
          AND r.old_position = fs.current_guide_index AND r.would_be_visible),
      (SELECT MIN(r.new_ordinal) FROM renumbered r
        WHERE r.learning_path_id = fs.learning_path_id
          AND r.old_position > fs.current_guide_index AND r.would_be_visible),
      (SELECT MAX(r.new_ordinal) FROM renumbered r
        WHERE r.learning_path_id = fs.learning_path_id AND r.would_be_visible),
      0)
      + CASE WHEN EXISTS (
          SELECT 1 FROM insert_anchor ia
           WHERE ia.learning_path_id = fs.learning_path_id
             AND fs.current_guide_index > ia.anchor_ordinal)
        THEN 1 ELSE 0 END AS new_index
  ) predicted
 WHERE fs.completed_at IS NULL

UNION ALL

SELECT 'ENROLMENT',
       lp.slug,
       u.current_topic_position,
       (SELECT r.title FROM renumbered r
         WHERE r.learning_path_id = u.learning_path_id
           AND r.old_position = u.current_topic_position),
       predicted.new_index,
       (SELECT r.title FROM renumbered r
         WHERE r.learning_path_id = u.learning_path_id
           AND r.would_be_visible AND r.new_ordinal = predicted.new_index)
  FROM user_learning_path_progress u
  JOIN learning_paths lp ON lp.id = u.learning_path_id
  CROSS JOIN LATERAL (
    SELECT COALESCE(
      (SELECT r.new_ordinal FROM renumbered r
        WHERE r.learning_path_id = u.learning_path_id
          AND r.old_position = u.current_topic_position AND r.would_be_visible),
      (SELECT MIN(r.new_ordinal) FROM renumbered r
        WHERE r.learning_path_id = u.learning_path_id
          AND r.old_position > u.current_topic_position AND r.would_be_visible),
      (SELECT MAX(r.new_ordinal) FROM renumbered r
        WHERE r.learning_path_id = u.learning_path_id AND r.would_be_visible),
      0)
      + CASE WHEN EXISTS (
          SELECT 1 FROM insert_anchor ia
           WHERE ia.learning_path_id = u.learning_path_id
             AND u.current_topic_position > ia.anchor_ordinal)
        THEN 1 ELSE 0 END AS new_index
  ) predicted
 WHERE u.completed_at IS NULL
   AND u.current_topic_position IS NOT NULL
   AND lp.slug IN ('new-believer-essentials','rooted-in-christ','sin-repentance-and-grace',
                   'understanding-the-bible','growing-in-discipleship','gospel-of-mark',
                   'baptism-and-lords-supper','the-local-church')
 ORDER BY 1, 2, 3;
