-- ============================================================================
-- Stage 1: path-specific retitles and two new foundational topics
-- ============================================================================
--
-- RETITLES (2)
--   Two topics are shared across several paths and serve a different function
--   in each. Rather than duplicate the topic, the Sin/Repentance instance gets
--   a path-specific title so its distinct purpose is visible to the learner.
--
--   'What is the Gospel?' -- in new-believer-essentials this is the gospel as
--   announcement. In sin-repentance-and-grace it sits directly after 'The
--   Nature and Wages of Sin', making it the gospel as answer to wrath.
--
--   'Understanding God's Grace' -- in rooted-in-christ this is grace as
--   identity. In sin-repentance-and-grace it sits between assurance and
--   temptation, making it grace as the engine of sanctification (Titus 2:11-12).
--
-- NEW TOPICS (2)
--   'One God, Three Persons' -- the Trinity was taught nowhere in Stage 1.
--   It is a primary doctrine and, in the Hindi- and Malayalam-speaking contexts
--   this app serves, the most-attacked Christian claim. A new believer who
--   cannot articulate it is defenceless at the first family conversation.
--
--   'Learning to Pray' -- pairs with the hiding of 'Fasting and Prayer' in
--   20260721000004. Stage 1 previously offered motivation for prayer but no
--   method. Fasting defers; the Lord's Prayer as pattern does not. It takes the
--   reading-order slot 'Fasting and Prayer' vacated, mid-path, NOT the end of
--   the list -- see the growing-in-discipleship block below for the anchor.
--
-- CURSOR COUPLING (see 20260721000005)
--   Both insertions shift learning_path_topics.position. Two tables store
--   cursors in that same coordinate space --
--   user_learning_path_progress.current_topic_position and
--   fellowship_study.current_guide_index -- and both are bumped in step with
--   each shift, inside the same idempotency guard. Task 5's invariant is that
--   a moved position without a moved cursor is silent incorrect content, not a
--   stall.
--
-- ENGLISH ONLY. Hindi and Malayalam titles must be written and reviewed by a
-- native speaker before insertion. Until then those users fall back to the
-- existing translation or base title, which is safe.
--
-- IDEMPOTENT: safe to re-run.
-- ============================================================================

BEGIN;

-- ---- Retitles -------------------------------------------------------------
INSERT INTO learning_path_topic_titles (learning_path_id, topic_id, language_code, title)
SELECT lp.id, rt.id, 'en', v.new_title
  FROM (VALUES
    ('sin-repentance-and-grace', 'What is the Gospel?',       'The Gospel: God''s Answer to Sin'),
    ('sin-repentance-and-grace', 'Understanding God''s Grace','Grace That Teaches Us to Say No')
  ) AS v(path_slug, old_title, new_title)
  JOIN learning_paths      lp ON lp.slug  = v.path_slug
  JOIN recommended_topics  rt ON rt.title = v.old_title
  JOIN learning_path_topics lpt
    ON lpt.learning_path_id = lp.id AND lpt.topic_id = rt.id
ON CONFLICT (learning_path_id, topic_id, language_code)
DO UPDATE SET title = EXCLUDED.title, updated_at = NOW();

-- ---- New topic: the Trinity ----------------------------------------------
-- display_order 823, NOT 0. get_recommended_topics orders the GLOBAL topic
-- browser by (display_order ASC, created_at DESC) with no path scoping, so a 0
-- here would make this row the first result app-wide, ahead of 'Who is Jesus
-- Christ?' (display_order 1).
--
-- 823/824 were chosen by QUERYING max(display_order) = 822 against the database,
-- not by parsing the migration files. An earlier attempt read the files and
-- concluded the span was 1..805, which was wrong -- two John topics already sit
-- at 806 and 807, so those values would have tied rather than appended. There
-- is no unique constraint on display_order, so a tie is not an error; it just
-- silently fails to do what this comment claims.
--
-- Placement INSIDE the learning paths is governed by learning_path_topics.position
-- below, which is independent of this column.
INSERT INTO recommended_topics (id, title, description, category, input_type, tags, is_active, xp_value, display_order)
VALUES (
  '111e8400-e29b-41d4-a716-4466554400f1',
  'One God, Three Persons',
  'Scripture teaches that God is one in essence and three in person: Father, Son, and Holy Spirit — not three gods, and not one God wearing three masks. This study traces the biblical foundation across the Old and New Testaments, from the Shema''s declaration that the LORD is one (Deuteronomy 6:4) through the baptism of Jesus, where Father, Son, and Spirit are present together (Matthew 3:16-17), to Christ''s command to baptise in the singular name of all three (Matthew 28:19). You will learn why the Trinity is not a puzzle to be solved but the God who has revealed Himself, how the doctrine safeguards the gospel — only a divine Son can save, only a divine Spirit can indwell — and how to answer the question a new believer is most often asked: "so do Christians worship three gods?" Your answer will affirm the Shema rather than work around it: the same Scripture that declares the LORD is one also names the Son and the Spirit as God, so you are not offering a third option beyond monotheism but confessing, with Israel, that the LORD is one.',
  'Foundations of Faith',
  'topic',
  ARRAY['trinity', 'new believer', 'salvation', 'father', 'son', 'holy spirit'],
  true, 50, 823
)
ON CONFLICT (id) DO NOTHING;

-- ---- New topic: prayer ----------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, input_type, tags, is_active, xp_value, display_order)
VALUES (
  '111e8400-e29b-41d4-a716-4466554400f2',
  'Learning to Pray',
  'Jesus''s disciples did not ask Him to teach them to preach or to heal — they asked Him to teach them to pray (Luke 11:1). This study takes the pattern He gave them, the Lord''s Prayer (Matthew 6:9-13), and walks through it line by line: worship before request, God''s kingdom before our needs, daily dependence, forgiveness given as it has been received, and rescue from temptation. You will learn that prayer is not performance, that God is not persuaded by length or eloquence (Matthew 6:7-8), and that when you have no words at all the Spirit intercedes for you (Romans 8:26-27). Practical help for building a daily habit is included, so that prayer becomes conversation with a Father rather than a duty to be discharged.',
  'Spiritual Disciplines',
  'topic',
  ARRAY['prayer', 'lords prayer', 'spiritual disciplines', 'devotion'],
  true, 50, 824
)
ON CONFLICT (id) DO NOTHING;

-- ---- Wire the new topics into their paths ---------------------------------
-- Trinity goes immediately after 'Who is Jesus Christ?' in new-believer-essentials.
-- Everything at or after that slot shifts down by one. Park first to dodge the
-- unique constraint, exactly as in 20260721000005.
DO $$
DECLARE
  v_path_id     UUID;
  v_after_pos   INTEGER;
BEGIN
  SELECT id INTO v_path_id FROM learning_paths WHERE slug = 'new-believer-essentials';

  SELECT lpt.position INTO v_after_pos
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
   WHERE lpt.learning_path_id = v_path_id AND rt.title = 'Who is Jesus Christ?' AND lpt.is_active;

  IF v_after_pos IS NULL THEN
    RAISE EXCEPTION 'Anchor topic "Who is Jesus Christ?" not found in new-believer-essentials';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM learning_path_topics
     WHERE learning_path_id = v_path_id AND topic_id = '111e8400-e29b-41d4-a716-4466554400f1'
  ) THEN
    UPDATE learning_path_topics SET position = position + 100000
     WHERE learning_path_id = v_path_id AND position > v_after_pos AND is_active;
    -- AND is_active mirrors the park above. Hidden rows are parked at 1000+ by
    -- 20260721000005 and so never exceed 100000 today, but matching the two
    -- predicates removes the dependency on that happening to be true.
    UPDATE learning_path_topics SET position = position - 100000 + 1
     WHERE learning_path_id = v_path_id AND position > 100000 AND is_active;

    INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
    VALUES (v_path_id, '111e8400-e29b-41d4-a716-4466554400f1', v_after_pos + 1, false, true);

    -- Cursor remap -- coupled to Task 5's invariant (20260721000005).
    --
    -- current_topic_position and current_guide_index are stored in the SAME
    -- coordinate space as learning_path_topics.position, which the shift above
    -- just moved. 20260721000005 exists largely to keep these in step and is
    -- explicit that failing to do so is "silent incorrect content, not a
    -- stall": a learner sitting at position 2 ('Assurance of Salvation') would
    -- be rewound to 'What is the Gospel?', which they already completed.
    --
    -- Deliberately INSIDE the IF NOT EXISTS guard so it fires exactly when the
    -- shift fires and cannot double-bump on a re-run.
    --
    -- The asymmetry between the two statements is intentional and matches the
    -- column definitions:
    --   * user_learning_path_progress.current_topic_position is INTEGER
    --     DEFAULT 0 but NULLABLE, so it needs the IS NOT NULL guard -- a NULL
    --     cursor is inert today and must stay NULL, not become 1.
    --   * that table has NO updated_at column. Its activity column is
    --     last_activity_at, meaning the USER's last activity; a migration is
    --     not user activity and must not stamp it (same reasoning as phase 5
    --     of 20260721000005).
    --   * fellowship_study.current_guide_index is INTEGER NOT NULL, so no NULL
    --     guard is possible or needed, and that table DOES have updated_at.
    UPDATE user_learning_path_progress
       SET current_topic_position = current_topic_position + 1
     WHERE learning_path_id = v_path_id
       AND completed_at IS NULL
       AND current_topic_position IS NOT NULL
       AND current_topic_position > v_after_pos;

    UPDATE fellowship_study
       SET current_guide_index = current_guide_index + 1,
           updated_at          = NOW()
     WHERE learning_path_id = v_path_id
       AND completed_at IS NULL
       AND current_guide_index > v_after_pos;
  END IF;
END $$;

-- 'Learning to Pray' takes the slot vacated by the hidden 'Fasting and Prayer'
-- in growing-in-discipleship -- mid-path, where prayer method belongs, not
-- appended after the capstone.
--
-- ANCHOR CHOICE. The catalog order for this path is:
--   1 What is Discipleship?        pos 0  visible
--   2 Walking with God Daily       pos 1  visible
--   3 Daily Devotions           🏁 pos 2  visible
--   4 The Cost of Following Jesus  pos 3  visible   <-- ANCHOR
--   5 Overcoming Temptation        pos 4  HIDDEN (dedupe, 20260721000004)
--   6 Fasting and Prayer           pos 5  HIDDEN (split, 20260721000004)
--   7 Bearing Fruit             🏁 pos 6  visible
--   8 Meditation on God's Word     pos 7  visible
--   9 Living a Holy Life        🏁 pos 8  HIDDEN (dedupe, 20260721000004)
--  10 How to Study the Bible       pos 9  HIDDEN (dedupe, 20260721000004)
--  11 Discerning God's Will     🏁 pos 10 HIDDEN (defer,  20260721000004)
--
-- 'Meditation on God's Word' is NOT hidden here. 20260721000004 hides it from
-- understanding-the-bible, and its own reason string says "dedupe: kept in
-- growing-in-discipleship" -- this path is where it is kept. So this path takes
-- 5 hides, not 6, and has 6 visible topics before the insert below.
--
-- 'Fasting and Prayer' is hidden and parked at 1000+ by 20260721000005, so it
-- cannot be anchored on directly. Walking BACKWARD from its old slot to the
-- first still-visible topic gives 'The Cost of Following Jesus' -- 'Overcoming
-- Temptation' immediately before it is also hidden. After renumbering, that
-- anchor sits at visible position 3, so 'Learning to Pray' lands at 4,
-- 'Bearing Fruit' shifts 4 -> 5 and 'Meditation on God's Word' shifts 5 -> 6,
-- taking the path from 6 visible topics to 7.
--
-- Anchoring FORWARD instead (on 'Overcoming Temptation''s visible successor,
-- 'Bearing Fruit') would place prayer AFTER the milestone capstone, which is
-- the same defect as the original append and contradicts this file's own
-- rationale that prayer method is foundational. Backward is the correct
-- reading of "the slot it vacated".
DO $$
DECLARE
  v_path_id   UUID;
  v_after_pos INTEGER;
BEGIN
  SELECT id INTO v_path_id FROM learning_paths WHERE slug = 'growing-in-discipleship';

  SELECT lpt.position INTO v_after_pos
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
   WHERE lpt.learning_path_id = v_path_id
     AND rt.title = 'The Cost of Following Jesus'
     AND lpt.is_active;

  IF v_after_pos IS NULL THEN
    RAISE EXCEPTION 'Anchor topic "The Cost of Following Jesus" not found in growing-in-discipleship';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM learning_path_topics
     WHERE learning_path_id = v_path_id AND topic_id = '111e8400-e29b-41d4-a716-4466554400f2'
  ) THEN
    UPDATE learning_path_topics SET position = position + 100000
     WHERE learning_path_id = v_path_id AND position > v_after_pos AND is_active;
    UPDATE learning_path_topics SET position = position - 100000 + 1
     WHERE learning_path_id = v_path_id AND position > 100000 AND is_active;

    INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone, is_active)
    VALUES (v_path_id, '111e8400-e29b-41d4-a716-4466554400f2', v_after_pos + 1, false, true);

    -- Same cursor remap as the Trinity block above, for the same reason and
    -- with the same NULL / updated_at asymmetry. See that block's comment.
    UPDATE user_learning_path_progress
       SET current_topic_position = current_topic_position + 1
     WHERE learning_path_id = v_path_id
       AND completed_at IS NULL
       AND current_topic_position IS NOT NULL
       AND current_topic_position > v_after_pos;

    UPDATE fellowship_study
       SET current_guide_index = current_guide_index + 1,
           updated_at          = NOW()
     WHERE learning_path_id = v_path_id
       AND completed_at IS NULL
       AND current_guide_index > v_after_pos;
  END IF;
END $$;

-- ---- XP totals now reflect the visible topic set --------------------------
-- Scoped to the paths this change actually touches, NOT every active path.
-- compute_learning_path_total_xp stamps learning_paths.updated_at = NOW() on
-- every path it is called for, so looping over all 41 active paths would
-- falsify the edit timestamp of the 33 whose XP total is provably unchanged.
-- This mirrors the falsified-history concern handled in phase 5 of
-- 20260721000005, where last_activity_at and completed_at are deliberately not
-- set to NOW().
--
-- Affected = paths with at least one hidden topic row (their visible XP set
-- shrank in 20260721000004) plus the two paths receiving a new topic above.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT lp.id
      FROM learning_paths lp
     WHERE lp.is_active = true
       AND (
         EXISTS (
           SELECT 1 FROM learning_path_topics lpt
            WHERE lpt.learning_path_id = lp.id
              AND lpt.is_active = false
         )
         OR lp.slug IN ('new-believer-essentials', 'growing-in-discipleship')
       )
  LOOP
    PERFORM compute_learning_path_total_xp(r.id);
  END LOOP;
END $$;

-- ---- Reopen enrolments on paths that just gained a topic -------------------
--
-- 20260721000005 phase 6 recomputed topics_completed for COMPLETED enrolments,
-- but it ran before this migration inserted two topics. So a user who had
-- finished new-believer-essentials sits at topics_completed = 7 against a
-- visible total that is now 8: the home screen renders "7 of 8" and 87% with a
-- completed badge, permanently, on the most-trafficked path. Nothing re-fires,
-- because the completion trigger is AFTER INSERT OR UPDATE on
-- user_topic_progress and no further event will ever occur for them.
--
-- A path that gained required content is genuinely no longer complete, so the
-- honest repair is to reopen it rather than to paper over the denominator.
-- This is safe: user_topic_progress is untouched, so every topic they finished
-- stays finished and they are exactly one topic away from completing again.
-- Verified before writing this: nothing in the gamification schema references
-- learning paths, and no achievement or badge logic reads
-- user_learning_path_progress.completed_at -- so no award is revoked.
--
-- current_topic_position is left alone. Their cursor was already bumped past
-- the insert by the blocks above; pointing them back at the new topic would
-- contradict that and rewind anyone mid-path.
UPDATE user_learning_path_progress ulpp
SET completed_at = NULL
FROM learning_paths lp
WHERE lp.id = ulpp.learning_path_id
  AND lp.slug IN ('new-believer-essentials', 'growing-in-discipleship')
  AND ulpp.completed_at IS NOT NULL
  AND ulpp.topics_completed < (
    SELECT COUNT(*)
      FROM learning_path_topics lpt
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
     WHERE lpt.learning_path_id = ulpp.learning_path_id
       AND lpt.is_active = true
       AND rt.is_active IS TRUE
  );

DO $$
DECLARE
  v_overrides INTEGER;
  v_stage1    INTEGER;
  v_stale     INTEGER;
BEGIN
  -- No enrolment may claim completion while short of its visible topic count.
  SELECT COUNT(*) INTO v_stale
    FROM user_learning_path_progress ulpp
   WHERE ulpp.completed_at IS NOT NULL
     AND ulpp.topics_completed < (
       SELECT COUNT(*)
         FROM learning_path_topics lpt
         JOIN recommended_topics rt ON rt.id = lpt.topic_id
        WHERE lpt.learning_path_id = ulpp.learning_path_id
          AND lpt.is_active = true
          AND rt.is_active IS TRUE
     );
  IF v_stale > 0 THEN
    RAISE EXCEPTION '% completed enrolments claim completion below their visible topic count', v_stale;
  END IF;

  -- Scoped to the two (learning_path_id, topic_id) pairs THIS migration
  -- inserts, not to the whole table. An unscoped COUNT over language_code='en'
  -- asserts a global property this migration does not own, so it would fire
  -- spuriously the moment any later migration adds a third override.
  --
  -- rt.title is the BASE title in recommended_topics, which the retitles above
  -- deliberately do not touch -- the new wording lives only in
  -- learning_path_topic_titles.title -- so matching on it stays correct
  -- after the override is applied and on every re-run.
  SELECT COUNT(*) INTO v_overrides
    FROM learning_path_topic_titles lptt
    JOIN learning_paths     lp ON lp.id = lptt.learning_path_id
    JOIN recommended_topics rt ON rt.id = lptt.topic_id
   WHERE lptt.language_code = 'en'
     AND lp.slug = 'sin-repentance-and-grace'
     AND rt.title IN ('What is the Gospel?', 'Understanding God''s Grace');
  IF v_overrides <> 2 THEN
    RAISE EXCEPTION 'Expected 2 English title overrides for sin-repentance-and-grace, found %', v_overrides;
  END IF;

  SELECT COUNT(*) INTO v_stage1
    FROM learning_path_topics lpt
    JOIN learning_paths lp ON lp.id = lpt.learning_path_id
   WHERE lp.disciple_level = 'seeker' AND lp.is_active = true AND lpt.is_active = true;
  IF v_stage1 <> 64 THEN
    RAISE EXCEPTION 'Expected 64 visible Stage 1 topics, found %', v_stage1;
  END IF;

  RAISE NOTICE 'Stage 1 configured: 64 visible topics, 2 retitles, 2 new topics.';
END $$;

COMMIT;
