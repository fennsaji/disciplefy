-- ============================================================================
-- Renumber topic positions contiguously and remap fellowship progress
-- ============================================================================
--
-- After 20260721000004 hid 13 topics, positions have gaps. This renumbers
-- visible topics to a contiguous 0..N-1 per path.
--
-- THREE HAZARDS, EACH HANDLED EXPLICITLY
--
-- 1. UNIQUE(learning_path_id, position) means a naive UPDATE collides
--    mid-statement. Handled by parking every row at position + 100000 first,
--    then assigning final values.
--
-- 2. Hidden rows still occupy the unique key. They are parked at 1000 + n so
--    they cannot collide with the visible 0..N-1 range and are obviously
--    "out of band" to anyone reading the table.
--
-- 3. fellowship_study.current_guide_index is a 0-based ordinal into the
--    path's topic list. Renumbering silently repoints it. Every in-flight
--    study is remapped in the same transaction:
--      - index maps to however many VISIBLE topics precede the topic it
--        currently points at
--      - if it points at a topic that is now hidden, it moves to the next
--        visible topic
--      - completed studies are left alone
--
-- IDEMPOTENT: re-running produces the same final numbering.
--
-- DEFINITION OF "VISIBLE"
--
-- A topic is visible in a path when BOTH lpt.is_active (this path wants it) AND
-- rt.is_active (the topic itself is live). That is exactly the definition the 7
-- RPCs in 20260721000003 use. This migration uses the SAME definition
-- everywhere, because the raw-position coordinate space the cursors live in must
-- contain precisely the slots the RPCs render. If this file renumbered on
-- lpt.is_active alone, a row with lpt.is_active = true AND rt.is_active = false
-- would be pulled INTO the contiguous visible range, and fellowship auto-advance
-- could land on a lesson get_learning_path_detail refuses to return.
--
-- recommended_topics.is_active is NULLABLE (BOOLEAN DEFAULT true), so the test
-- is written `rt.is_active IS TRUE`, never a bare `rt.is_active`. That keeps the
-- expression a non-NULL boolean, which is what makes the phase 2 / phase 3
-- partition TOTAL: phase 2 takes the rows where it is true, phase 3 takes
-- NOT(...) which is then exactly the complement. A three-valued expression here
-- would strand NULL rows at +100000 forever.
-- ============================================================================

BEGIN;

-- Precondition guard for the CURSOR REMAP, not for the renumber itself.
--
-- Phases 1-3 renumber correctly from any starting arrangement. What needs a
-- guarantee is phases 4 and 5: they translate stored cursors, and a cursor is
-- only translatable if the coordinate space it was written in is the one this
-- snapshot describes. Two arrangements are safe:
--
--   Shape A (pre-renumber): every row of the path, visible or hidden, occupies
--   a contiguous 0..N-1 range. This is the state 20260721000004 left behind --
--   it flipped is_active only and never touched position.
--
--   Shape B (already renumbered): visible rows occupy 0..V-1 and every hidden
--   row is parked at >= 1000. This is the state THIS migration leaves behind,
--   so a re-run lands here and must not abort. Cursors still resolve exactly:
--   a visible row at position p has new_ordinal p, so the remap is a no-op.
--
-- Anything else means positions were hand-edited into an arrangement where a
-- stored cursor cannot be mapped to a topic with confidence. Abort loudly
-- rather than silently repoint every user at the wrong study.
DO $$
DECLARE v_bad TEXT;
BEGIN
  -- Aggregated over a subquery, not straight off the GROUP BY: SELECT ... INTO
  -- keeps only the FIRST row, so a bare grouped query would name one offending
  -- path and hide the rest.
  -- Visibility is the widened lpt.is_active AND rt.is_active definition, so this
  -- guard checks the same arrangement the renumber below actually produces.
  SELECT string_agg(slug, ', ') INTO v_bad FROM (
    SELECT lp.slug
      FROM learning_paths lp
      JOIN learning_path_topics lpt ON lpt.learning_path_id = lp.id
      JOIN recommended_topics   rt  ON rt.id = lpt.topic_id
     GROUP BY lp.slug
    HAVING NOT (
      -- Shape A: contiguous 0..N-1 across all rows.
      (MIN(lpt.position) = 0 AND MAX(lpt.position) = COUNT(*) - 1)
      OR
      -- Shape B: visible 0..V-1, hidden parked out of band at >= 1000.
      -- The COALESCE defaults make a path with no visible (or no hidden) rows
      -- satisfy the clause vacuously instead of comparing against NULL.
      (COALESCE(MIN(lpt.position) FILTER (WHERE lpt.is_active AND rt.is_active IS TRUE), 0) = 0
       AND COALESCE(MAX(lpt.position) FILTER (WHERE lpt.is_active AND rt.is_active IS TRUE), -1)
           = COUNT(*) FILTER (WHERE lpt.is_active AND rt.is_active IS TRUE) - 1
       AND COALESCE(MIN(lpt.position) FILTER (WHERE NOT (lpt.is_active AND rt.is_active IS TRUE)), 1000) >= 1000)
    )
  ) bad;

  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Positions are neither contiguous 0-based nor already renumbered, so stored cursors cannot be mapped reliably. Affected paths: %', v_bad;
  END IF;
END $$;

-- Snapshot the old -> new ordinal mapping BEFORE any position changes.
-- Materialised as a temp table because both the fellowship remap (phase 4) and
-- the individual-progress repair (phase 5) read it after the positions move.
--
-- new_ordinal uses COUNT(*) FILTER, NOT ROW_NUMBER() FILTER. PostgreSQL allows
-- the FILTER clause only on AGGREGATE window functions; ROW_NUMBER() is a
-- non-aggregate window function and raises
--   "FILTER is not implemented for non-aggregate window functions".
-- COUNT(*) is an aggregate, so with an ORDER BY in the window it becomes a
-- running count: for an ACTIVE row it yields the number of active rows up to
-- and including itself, minus one -- exactly the 0-based visible ordinal.
--
-- DO NOT "fix" this back to ROW_NUMBER(). The one semantic difference is that
-- an INACTIVE row gets the ordinal of the last preceding visible topic rather
-- than NULL. That value is never consumed: every lookup of new_ordinal below
-- (phase 4 and phase 5, fallback branches 1-3) constrains AND o.is_active.
--
-- The lookup key is old_position, the RAW position column -- deliberately NOT a
-- dense rank. Both consumers store and match raw position:
--   * topic-progress/index.ts        .eq('position', study.current_guide_index)
--   * get_in_progress_topics         vpt.position = ulpp.current_topic_position
-- A dense rank happens to equal raw position while positions are contiguous and
-- 0-based, but keying on the raw column removes the dependency on that
-- invariant entirely, so the remap cannot silently mis-map if it is ever
-- violated. new_ordinal stays an ordinal: the TARGET is the new contiguous
-- ordinal, which after phase 2 is exactly the new raw position.
--
-- The is_active column of this snapshot is the WIDENED visibility expression
-- (lpt.is_active AND rt.is_active IS TRUE), not the raw lpt column, so every
-- `AND o.is_active` consumer below skips exactly the rows the RPCs skip.
CREATE TEMP TABLE ordered_positions ON COMMIT DROP AS
SELECT lpt.learning_path_id,
       lpt.topic_id,
       (lpt.is_active AND rt.is_active IS TRUE) AS is_active,
       lpt.position AS old_position,
       COUNT(*) FILTER (WHERE lpt.is_active AND rt.is_active IS TRUE) OVER (PARTITION BY lpt.learning_path_id ORDER BY lpt.position) - 1 AS new_ordinal
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id;

CREATE INDEX ON ordered_positions (learning_path_id, old_position);

CREATE TEMP TABLE fellowship_remap ON COMMIT DROP AS
SELECT fs.id AS fellowship_study_id,
       fs.current_guide_index AS old_index,
       COALESCE(
         -- the topic it points at, if still visible
         (SELECT o.new_ordinal FROM ordered_positions o
           WHERE o.learning_path_id = fs.learning_path_id
             AND o.old_position = fs.current_guide_index
             AND o.is_active),
         -- otherwise the next visible topic after it
         (SELECT MIN(o.new_ordinal) FROM ordered_positions o
           WHERE o.learning_path_id = fs.learning_path_id
             AND o.old_position > fs.current_guide_index
             AND o.is_active),
         -- otherwise it was past the end: clamp to the last visible topic
         (SELECT MAX(o.new_ordinal) FROM ordered_positions o
           WHERE o.learning_path_id = fs.learning_path_id
             AND o.is_active),
         0
       ) AS new_index
  FROM fellowship_study fs
 WHERE fs.completed_at IS NULL;
-- No NULL guard is needed on current_guide_index the way phase 5 needs one on
-- current_topic_position: fellowship_study.current_guide_index is declared
-- INTEGER NOT NULL DEFAULT 0 CHECK (current_guide_index >= 0)
-- (20260308000001_community_fellowships.sql), so branch 3 can never be reached
-- by a NULL and mis-map a cursor to the last topic.

-- Phase 1: park everything out of the way to dodge the unique constraint.
UPDATE learning_path_topics SET position = position + 100000;

-- Phase 2: visible topics get 0..N-1, preserving relative order.
-- Visible = lpt.is_active AND rt.is_active IS TRUE, matching the RPCs.
WITH renumbered AS (
  SELECT lpt.id,
         ROW_NUMBER() OVER (PARTITION BY lpt.learning_path_id ORDER BY lpt.position) - 1 AS new_position
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
   WHERE lpt.is_active AND rt.is_active IS TRUE
)
UPDATE learning_path_topics lpt
SET position = r.new_position
FROM renumbered r
WHERE lpt.id = r.id;

-- Phase 3: hidden topics parked at 1000+, clearly out of band.
--
-- The predicate is the exact negation of phase 2's, NOT `lpt.is_active = false`.
-- With the widened definition, "hidden" includes a row whose path still wants it
-- but whose recommended_topics row is dead. Phases 2 and 3 must remain a TOTAL
-- partition of learning_path_topics -- both predicates are non-NULL booleans
-- (topic_id is NOT NULL with an FK, so the join drops nothing; `IS TRUE`
-- collapses a NULL rt.is_active to false), so every row lands in exactly one
-- phase and none can strand at the +100000 parking position from phase 1.
WITH parked AS (
  SELECT lpt.id,
         1000 + (ROW_NUMBER() OVER (PARTITION BY lpt.learning_path_id ORDER BY lpt.position) - 1) AS new_position
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
   WHERE NOT (lpt.is_active AND rt.is_active IS TRUE)
)
UPDATE learning_path_topics lpt
SET position = p.new_position
FROM parked p
WHERE lpt.id = p.id;

-- Phase 4: move the fellowships.
UPDATE fellowship_study fs
SET current_guide_index = fr.new_index,
    updated_at          = NOW()
FROM fellowship_remap fr
WHERE fs.id = fr.fellowship_study_id
  AND fs.current_guide_index <> fr.new_index;

-- Phase 5: repair INDIVIDUAL user progress.
--
-- fellowship_study is not the only cursor into a path. Every enrolled user has
-- user_learning_path_progress.current_topic_position, which is stored in the
-- SAME coordinate space that phases 1-3 just rewrote. Leaving it alone means
-- get_in_progress_topics (which matches position exactly) surfaces the WRONG
-- topic, or none at all if the stored value now exceeds the visible count.
-- That is silent incorrect content, not a stall.
--
-- topics_completed has a second, independent problem: it is an all-time counter
-- that may include topics now hidden, so it can exceed the shrunken visible
-- denominator and render as "9 of 6". It is recomputed here from the source of
-- truth -- user_topic_progress intersected with the visible topic set -- rather
-- than adjusted, so this is correct on a hide, on an un-hide, and on re-run.
--
-- NOTE: no activity timestamp is stamped here, deliberately. This table has no
-- updated_at column; its activity column is last_activity_at, which means the
-- USER's last activity. A backfill migration is not user activity, and writing
-- NOW() into it would falsify history and corrupt anything keyed on it
-- (resume ordering, dormancy detection, re-engagement). This is the same reason
-- completed_at below takes the real completion timestamp instead of NOW().
UPDATE user_learning_path_progress ulpp
-- A NULL cursor must survive as NULL. Unlike fellowship_study, this column is
-- INTEGER DEFAULT 0 but NULLABLE. Fed a NULL, the COALESCE chain below would
-- fall all the way through -- branch 1 matches nothing, branch 2's
-- `old_position > NULL` matches nothing -- and branch 3 would return
-- MAX(new_ordinal), i.e. the END of the path. Today a NULL cursor is inert
-- (get_in_progress_topics' `position = NULL` matches no row); mapping it to the
-- last topic would turn that inert state into confidently wrong content.
--
-- The guard is a CASE on the cursor rather than a predicate in the WHERE
-- clause, so these rows are still repaired by the topics_completed and
-- completed_at recomputations below. Excluding them from the statement outright
-- would leave exactly the stale all-time counter this phase exists to fix.
SET current_topic_position = CASE
      WHEN ulpp.current_topic_position IS NULL THEN NULL
      ELSE COALESCE(
        (SELECT o.new_ordinal FROM ordered_positions o
          WHERE o.learning_path_id = ulpp.learning_path_id
            AND o.old_position = ulpp.current_topic_position
            AND o.is_active),
        (SELECT MIN(o.new_ordinal) FROM ordered_positions o
          WHERE o.learning_path_id = ulpp.learning_path_id
            AND o.old_position > ulpp.current_topic_position
            AND o.is_active),
        (SELECT MAX(o.new_ordinal) FROM ordered_positions o
          WHERE o.learning_path_id = ulpp.learning_path_id
            AND o.is_active),
        0
      )
    END,
    topics_completed = (
      SELECT COUNT(*)
        FROM learning_path_topics lpt
        JOIN recommended_topics rt ON rt.id = lpt.topic_id
        JOIN user_topic_progress utp
          ON utp.topic_id = lpt.topic_id
         AND utp.user_id  = ulpp.user_id
         AND utp.completed_at IS NOT NULL
       WHERE lpt.learning_path_id = ulpp.learning_path_id
         AND lpt.is_active = true
         AND rt.is_active  = true
    ),
    -- completed_at must be recomputed here too, not only in the trigger.
    -- The trigger is AFTER INSERT OR UPDATE on user_topic_progress, so it is
    -- event-driven: if hiding topics means a user has now finished everything
    -- visible, no completion event will ever fire again on that path and the
    -- trigger can never notice. Without this, such a user's path stays
    -- perpetually incomplete. Set it to the moment of their last relevant
    -- completion rather than NOW(), so history is not falsified.
    completed_at = CASE
      WHEN (
        SELECT COUNT(*)
          FROM learning_path_topics lpt
          JOIN recommended_topics rt ON rt.id = lpt.topic_id
          JOIN user_topic_progress utp
            ON utp.topic_id = lpt.topic_id
           AND utp.user_id  = ulpp.user_id
           AND utp.completed_at IS NOT NULL
         WHERE lpt.learning_path_id = ulpp.learning_path_id
           AND lpt.is_active = true
           AND rt.is_active  = true
      ) >= (
        SELECT COUNT(*)
          FROM learning_path_topics lpt
          JOIN recommended_topics rt ON rt.id = lpt.topic_id
         WHERE lpt.learning_path_id = ulpp.learning_path_id
           AND lpt.is_active = true
           AND rt.is_active  = true
      )
      -- rt.is_active is filtered here too, matching the two COUNTs above.
      -- Without it the timestamp could be drawn from a globally-inactive topic
      -- that is not part of the visible set whose completion triggered this
      -- branch, marking the path complete at the wrong moment.
      THEN (
        SELECT MAX(utp.completed_at)
          FROM learning_path_topics lpt
          JOIN recommended_topics rt ON rt.id = lpt.topic_id
          JOIN user_topic_progress utp
            ON utp.topic_id = lpt.topic_id
           AND utp.user_id  = ulpp.user_id
         WHERE lpt.learning_path_id = ulpp.learning_path_id
           AND lpt.is_active = true
           AND rt.is_active  = true
      )
      ELSE NULL
    END
WHERE ulpp.completed_at IS NULL;

-- Phase 6: clamp the counter on COMPLETED enrolments.
--
-- Phase 5 skips rows with completed_at IS NOT NULL, which leaves their all-time
-- topics_completed able to exceed the now-shrunken visible denominator.
-- get_user_learning_paths returns that raw pair to the client, and the
-- percentage clamp added alongside this migration only bounds the ratio -- so a
-- finished path could still render "9 of 6".
--
-- Deliberately narrow: topics_completed ONLY, using the identical visible-set
-- count as phase 5 (lpt.is_active AND rt.is_active). current_topic_position and
-- completed_at are settled history on these rows and are not touched -- moving
-- either would rewrite the record of a journey the user already finished.
--
-- The IS DISTINCT FROM guard makes a re-run touch zero rows.
UPDATE user_learning_path_progress ulpp
SET topics_completed = (
      SELECT COUNT(*)
        FROM learning_path_topics lpt
        JOIN recommended_topics rt ON rt.id = lpt.topic_id
        JOIN user_topic_progress utp
          ON utp.topic_id = lpt.topic_id
         AND utp.user_id  = ulpp.user_id
         AND utp.completed_at IS NOT NULL
       WHERE lpt.learning_path_id = ulpp.learning_path_id
         AND lpt.is_active = true
         AND rt.is_active  = true
    )
WHERE ulpp.completed_at IS NOT NULL
  AND ulpp.topics_completed IS DISTINCT FROM (
      SELECT COUNT(*)
        FROM learning_path_topics lpt
        JOIN recommended_topics rt ON rt.id = lpt.topic_id
        JOIN user_topic_progress utp
          ON utp.topic_id = lpt.topic_id
         AND utp.user_id  = ulpp.user_id
         AND utp.completed_at IS NOT NULL
       WHERE lpt.learning_path_id = ulpp.learning_path_id
         AND lpt.is_active = true
         AND rt.is_active  = true
    );

DO $$
DECLARE
  v_gap      TEXT;
  v_parked   INTEGER;
  v_beyond   INTEGER;
BEGIN
  -- Visible positions must be exactly 0..N-1 with no gaps, per path.
  -- Same widened visibility as the renumber above, so this verifies what the
  -- migration actually did rather than a narrower property.
  SELECT string_agg(slug, ', ') INTO v_gap FROM (
    SELECT lp.slug
      FROM learning_paths lp
      JOIN learning_path_topics lpt ON lpt.learning_path_id = lp.id
      JOIN recommended_topics   rt  ON rt.id = lpt.topic_id
     WHERE lpt.is_active AND rt.is_active IS TRUE
     GROUP BY lp.slug
    HAVING MAX(lpt.position) <> COUNT(*) - 1 OR MIN(lpt.position) <> 0
  ) bad;
  IF v_gap IS NOT NULL THEN
    RAISE EXCEPTION 'Non-contiguous visible positions in: %', v_gap;
  END IF;

  SELECT COUNT(*) INTO v_parked
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
   WHERE NOT (lpt.is_active AND rt.is_active IS TRUE)
     AND lpt.position < 1000;
  IF v_parked > 0 THEN
    RAISE EXCEPTION '% hidden topics were not parked above 1000', v_parked;
  END IF;

  -- No fellowship may point past the end of its path's visible topics.
  --
  -- Scoped to paths that still have at least one visible topic. A path with
  -- ZERO visible topics would make current_guide_index >= 0 trivially true and
  -- fire this exception on a case the remap deliberately handles -- COALESCE
  -- branch 4 above maps such a cursor to 0. No path is in that state today;
  -- this guard is defence against a future hide-everything, not a live
  -- condition.
  SELECT COUNT(*) INTO v_beyond
    FROM fellowship_study fs
   WHERE fs.completed_at IS NULL
     AND EXISTS (
       SELECT 1 FROM learning_path_topics lpt
        JOIN recommended_topics rt ON rt.id = lpt.topic_id
        WHERE lpt.learning_path_id = fs.learning_path_id
          AND lpt.is_active AND rt.is_active IS TRUE
     )
     AND fs.current_guide_index >= (
       SELECT COUNT(*) FROM learning_path_topics lpt
        JOIN recommended_topics rt ON rt.id = lpt.topic_id
        WHERE lpt.learning_path_id = fs.learning_path_id
          AND lpt.is_active AND rt.is_active IS TRUE
     );
  IF v_beyond > 0 THEN
    RAISE EXCEPTION '% in-flight fellowships point past the end of their path', v_beyond;
  END IF;

  RAISE NOTICE 'Positions renumbered; in-flight fellowships remapped.';
END $$;

COMMIT;
