-- ============================================================================
-- Stage 1 topic visibility: dedupe, defer, and split
-- ============================================================================
--
-- Hides 13 topic instances from Stage 1 paths. Every one of these topics
-- remains visible in at least one other path, or is deliberately deferred to a
-- later stage -- nothing is deleted and no recommended_topics row is touched.
--
-- Rationale is in docs/architecture/Learning_Paths_Catalog.md under
-- "Stage 1 configuration". Reviewed for doctrinal soundness.
--
-- GROUP 1 -- DEDUPE (7). These titles appear more than once inside Stage 1.
--   The instance kept is the one whose surrounding path gives it its proper
--   doctrinal home; the redundant instance is hidden.
--
-- GROUP 2 -- DEFER (5). Sound material, but polity/canon/hermeneutics that a
--   new believer does not need in months 1-4.
--
-- GROUP 3 -- SPLIT (1). 'Fasting and Prayer' is hidden and replaced by a new
--   'Learning to Pray' topic in migration 20260721000006. Fasting is an
--   advanced discipline and the most easily bent transactional; prayer method
--   is foundational. Net topic count is unchanged by this pair.
--
-- IDEMPOTENT within an IN-ORDER REPLAY of the full 20260721 sequence -- NOT
-- standalone. The UPDATEs themselves are re-runnable (setting is_active = false
-- twice is the same as once), but the verification block below asserts
-- `v_stage1 <> 62`. That holds on a fresh replay, because 20260721000006 --
-- which adds the two new topics that take the count to 64 -- runs after this
-- file. Re-running this file BY HAND on a database where 20260721000006 has
-- already landed makes v_stage1 = 64 and aborts.
-- ============================================================================

BEGIN;

WITH hides(path_slug, topic_title, reason) AS (
  VALUES
    -- Group 1: dedupe
    ('baptism-and-lords-supper',  'Baptism and Communion',              'dedupe: kept in new-believer-essentials; also redundant inside its own path (topics 1-2 cover baptism, 4-5 the Supper)'),
    ('the-local-church',          'Baptism and Communion',              'dedupe: kept in new-believer-essentials'),
    ('understanding-the-bible',   'Why Read the Bible?',                'dedupe: kept in new-believer-essentials; the whole path answers this question'),
    ('growing-in-discipleship',   'Overcoming Temptation',              'dedupe: kept in sin-repentance-and-grace, downstream of repentance'),
    ('understanding-the-bible',   'Meditation on God''s Word',          'dedupe: kept in growing-in-discipleship; meditation is a discipline, not a hermeneutic'),
    ('growing-in-discipleship',   'Living a Holy Life',                 'dedupe: kept in sin-repentance-and-grace; sanctification belongs downstream of grace'),
    ('growing-in-discipleship',   'How to Study the Bible',             'dedupe: kept in understanding-the-bible, where it is the milestone'),
    -- Group 2: defer
    ('understanding-the-bible',   'How We Got the Bible',               'defer: canon formation is the mechanism; "Is the Bible Reliable?" delivers the conclusion a new believer needs'),
    ('the-local-church',          'Church Leadership and Authority',    'defer: polity. NOTE follow-up -- fold "leaders are under Scripture, not a mediating authority" into "What is the Church?"'),
    ('the-local-church',          'Spiritual Gifts and Their Use',      'defer: secondary issue, and cross-taught in who-is-the-holy-spirit'),
    ('baptism-and-lords-supper',  'Baptism, the Lord''s Supper, and Church Membership','defer: membership polity; the underlying truth survives via the-local-church topics 1-2'),
    ('growing-in-discipleship',   'Discerning God''s Will',             'defer: requires rewrite onto God''s revealed will before it returns -- must not ground guidance in subjective impressions'),
    -- Group 3: split
    ('growing-in-discipleship',   'Fasting and Prayer',                 'split: replaced by "Learning to Pray" in 20260721000006; fasting defers to Stage 2')
)
UPDATE learning_path_topics lpt
SET is_active = false
FROM learning_paths lp, recommended_topics rt, hides h
WHERE lpt.learning_path_id = lp.id
  AND lpt.topic_id         = rt.id
  AND lp.slug              = h.path_slug
  AND rt.title             = h.topic_title;

-- Milestone reassignment. Hiding a milestone would leave a path with no
-- capstone, so promote a replacement in the same statement.
--
--   the-local-church: 'Spiritual Gifts and Their Use' was the milestone.
--   'Serving in the
--   Church' is the better capstone anyway -- service is the point gifts serve.
--
--   rooted-in-christ: 'Spiritual Warfare' held the milestone in a five-topic
--   path. It carries the highest drift risk in Stage 1 (territorial spirits,
--   deliverance substituted for sanctification). It stays visible, but
--   'Living by Faith, Not Feelings' is the doctrinally safer capstone for a
--   path named Rooted in Christ.
--
--   baptism-and-lords-supper: both of its milestones are hidden above --
--   'Baptism and Communion' as a dedupe (kept in new-believer-essentials) and
--   'Baptism, the Lord''s Supper, and Church Membership' as a defer (polity).
--   That leaves the path with no capstone, so 'Participating Worthily' is
--   promoted. It is the 1 Corinthians 11:27-32 self-examination topic -- the
--   guard against treating the Lord's Supper as either magic or a formality --
--   making it the right capstone for this path.
UPDATE learning_path_topics lpt
SET is_milestone = false
FROM learning_paths lp, recommended_topics rt
WHERE lpt.learning_path_id = lp.id AND lpt.topic_id = rt.id
  AND ((lp.slug = 'the-local-church' AND rt.title = 'Spiritual Gifts and Their Use')
    OR (lp.slug = 'rooted-in-christ' AND rt.title = 'Spiritual Warfare'));

UPDATE learning_path_topics lpt
SET is_milestone = true
FROM learning_paths lp, recommended_topics rt
WHERE lpt.learning_path_id = lp.id AND lpt.topic_id = rt.id
  AND ((lp.slug = 'the-local-church' AND rt.title = 'Serving in the Church')
    OR (lp.slug = 'rooted-in-christ' AND rt.title = 'Living by Faith, Not Feelings')
    OR (lp.slug = 'baptism-and-lords-supper' AND rt.title = 'Participating Worthily'));

DO $$
DECLARE
  v_hidden    INTEGER;
  v_stage1    INTEGER;
  v_orphaned  TEXT;
BEGIN
  SELECT COUNT(*) INTO v_hidden FROM learning_path_topics WHERE is_active = false;
  IF v_hidden <> 13 THEN
    RAISE EXCEPTION 'Expected 13 hidden topics, found %. A (slug, title) pair in this migration did not match -- check for a renamed topic.', v_hidden;
  END IF;

  -- Stage 1 = the 8 seeker-level paths set by 20260721000001.
  SELECT COUNT(*) INTO v_stage1
    FROM learning_path_topics lpt
    JOIN learning_paths lp ON lp.id = lpt.learning_path_id
   WHERE lp.disciple_level = 'seeker' AND lp.is_active = true AND lpt.is_active = true;
  IF v_stage1 <> 62 THEN
    RAISE EXCEPTION 'Expected 62 visible Stage 1 topics after hides, found %', v_stage1;
  END IF;

  -- No visible path may be left without a milestone.
  SELECT string_agg(lp.slug, ', ') INTO v_orphaned
    FROM learning_paths lp
   WHERE lp.is_active = true
     AND NOT EXISTS (
       SELECT 1 FROM learning_path_topics lpt
        WHERE lpt.learning_path_id = lp.id
          AND lpt.is_active = true AND lpt.is_milestone = true
     );
  IF v_orphaned IS NOT NULL THEN
    RAISE EXCEPTION 'These paths have no visible milestone: %', v_orphaned;
  END IF;

  RAISE NOTICE 'Hid 13 topics. Stage 1 now shows 62 topics.';
END $$;

COMMIT;
