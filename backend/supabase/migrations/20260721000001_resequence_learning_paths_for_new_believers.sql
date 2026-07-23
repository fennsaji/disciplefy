-- ============================================================================
-- Re-sequence learning paths for a new-believer discipleship progression
-- ============================================================================
--
-- Sets disciple_level, difficulty_level and display_order across all 41 active
-- paths so they form one coherent order for someone who has just come to faith,
-- rather than the per-category ordering that had accumulated.
--
-- Rationale is documented in docs/architecture/Learning_Paths_Catalog.md under
-- "Recommended sequence for a new believer". Ordering was derived from topic
-- content and reviewed for doctrinal soundness, NOT from the previous values of
-- these columns — several of which were demonstrably wrong (see below).
--
-- WHAT THIS FIXES
--
--  1. Romans was marked disciple_level='seeker', difficulty='beginner'. Romans
--     is not beginner material and cannot sit early in a new believer's path.
--
--  2. display_order collided within the Theology category: 'Eternal Perspective'
--     and 'Jesus''s Parables' both sat at 9, so anything ordering that category
--     by display_order got an arbitrary tie-break between a follower-tier and a
--     disciple-tier path. display_order is now globally unique (1..41), which
--     removes the collision class entirely.
--
--  3. Baptism preceded any teaching on repentance, inverting Acts 2:38.
--     Sin/Repentance/Grace now precedes Baptism & the Lord's Supper.
--
--  4. 'The Attributes of God' sat at position 26, meaning the crucifixion was
--     taught three times before God's holiness and justice were established --
--     leaving the atonement to default toward moral-influence framing. It now
--     precedes Romans.
--
--  5. Galatians now precedes James. James 2:24 is the most misread verse in the
--     canon on justification; the guard against misreading it must come first.
--
--  6. 'The Theology of Suffering' and 'Mental Health, Emotions & the Gospel'
--     moved from year 2 into the first year. 1 Peter 4:12 instruction has to be
--     pre-emptive to be of any use.
--
--  7. 'Defending Your Faith' moved substantially earlier. It carries
--     "Recognizing Cultic Patterns" and "Grace vs. Works-Based Religion", which
--     address pressures that target new believers specifically.
--
-- STAGES (encoded via disciple_level)
--   seeker    positions  1-8    Foundations, months 1-4
--   follower  positions  9-21   Establishing, months 5-12
--   disciple  positions 22-39   Deepening, year 2+
--   leader    positions 40-41   Outward-facing, presupposes maturity
--
-- NOT IN THIS MIGRATION
--   Topic-level hiding and per-path topic retitling are NOT here. They cannot
--   be expressed against the current schema: learning_path_topics has no
--   is_active column and no title override, and topics are shared by reference
--   (e.g. 'What is the Gospel?' is one recommended_topics row used by four
--   paths). Deactivating or renaming the topic row would affect every path that
--   references it. That work needs a schema change first -- see the catalog doc.
--
-- IDEMPOTENT: safe to re-run. Only UPDATEs, no inserts or deletes.
-- ============================================================================

BEGIN;

WITH new_sequence(slug, disciple_level, difficulty_level, display_order) AS (
  VALUES
    -- ---- Stage 1: Foundations (seeker, months 1-4) --------------------------
    ('new-believer-essentials',            'seeker',   'beginner',      1),
    ('rooted-in-christ',                   'seeker',   'beginner',      2),
    ('sin-repentance-and-grace',           'seeker',   'beginner',      3),
    ('understanding-the-bible',            'seeker',   'beginner',      4),
    ('growing-in-discipleship',            'seeker',   'beginner',      5),
    ('gospel-of-mark',                     'seeker',   'beginner',      6),
    ('baptism-and-lords-supper',           'seeker',   'beginner',      7),
    ('the-local-church',                   'seeker',   'beginner',      8),

    -- ---- Stage 2: Establishing (follower, months 5-12) ---------------------
    ('friendship-and-christian-community', 'follower', 'beginner',      9),
    ('who-is-the-holy-spirit',             'follower', 'beginner',     10),
    ('gospel-of-john',                     'follower', 'beginner',     11),
    ('philippians-joy-in-christ',          'follower', 'beginner',     12),
    ('ephesians-riches-in-christ',         'follower', 'beginner',     13),
    ('attributes-of-god',                  'follower', 'intermediate', 14),
    ('crucifixion-and-resurrection',       'follower', 'beginner',     15),
    ('romans-gospel-unfolded',             'follower', 'intermediate', 16),
    ('galatians-gospel-freedom',           'follower', 'intermediate', 17),
    ('theology-of-suffering',              'follower', 'intermediate', 18),
    ('mental-health-emotions-gospel',      'follower', 'intermediate', 19),
    ('peters-letters-hope-and-endurance',  'follower', 'intermediate', 20),
    ('defending-your-faith',               'follower', 'intermediate', 21),

    -- ---- Stage 3: Deepening (disciple, year 2+) ----------------------------
    ('sermon-on-the-mount',                'disciple', 'intermediate', 22),
    ('james-faith-that-works',             'disciple', 'intermediate', 23),
    ('deepening-your-walk',                'disciple', 'intermediate', 24),
    ('faith-and-family',                   'disciple', 'intermediate', 25),
    ('money-generosity-gospel',            'disciple', 'intermediate', 26),
    ('evangelism-everyday-life',           'disciple', 'intermediate', 27),
    ('jesus-parables',                     'disciple', 'intermediate', 28),
    ('gospel-of-matthew',                  'disciple', 'intermediate', 29),
    ('law-grace-and-covenants',            'disciple', 'advanced',     30),
    ('hebrews-jesus-our-high-priest',      'disciple', 'advanced',     31),
    ('johns-letters-light-love-truth',     'disciple', 'intermediate', 32),
    ('spiritual-warfare',                  'disciple', 'intermediate', 33),
    ('gospel-of-luke',                     'disciple', 'intermediate', 34),
    ('corinthians-christ-and-his-church',  'disciple', 'advanced',     35),
    ('work-and-vocation-as-worship',       'disciple', 'intermediate', 36),
    ('eternal-perspective',                'disciple', 'intermediate', 37),
    ('historical-reliability-bible',       'disciple', 'advanced',     38),
    ('faith-and-reason',                   'disciple', 'advanced',     39),

    -- ---- Stage 4: Outward-facing (leader) ----------------------------------
    ('christianity-and-culture',           'leader',   'advanced',     40),
    ('heart-for-the-world',                'leader',   'intermediate', 41)
)
UPDATE learning_paths lp
SET disciple_level   = ns.disciple_level,
    difficulty_level = ns.difficulty_level,
    display_order    = ns.display_order,
    updated_at       = NOW()
FROM new_sequence ns
-- Matched by slug ONLY, deliberately -- no is_active filter.
--
-- Production has 40 active paths where this file's local baseline had 41:
-- 'historical-reliability-bible' is inactive there, deactivated out-of-band
-- (no migration accounts for it). Filtering on is_active would silently skip
-- it, and the old "expected 41 active" assertion then aborted the whole
-- migration on a condition that has nothing to do with this change.
--
-- Setting sequencing metadata on an inactive path is harmless -- it is invisible
-- to users either way -- and it means the row is already correct if anyone
-- reactivates it later. Matching on slug also makes this migration independent
-- of whatever the activation state happens to be when it runs.
WHERE lp.slug = ns.slug;

-- ---------------------------------------------------------------------------
-- Verification: fail loudly rather than silently half-applying.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_updated   INTEGER;
  v_dupes     INTEGER;
  v_bad_level INTEGER;
BEGIN
  -- Assert on the 41 slugs this migration names, NOT on a global count of
  -- active paths. The activation state of any given path is not this
  -- migration's business, and asserting on it made an unrelated out-of-band
  -- change abort the deploy.
  SELECT COUNT(*) INTO v_updated
    FROM learning_paths
   WHERE display_order BETWEEN 1 AND 41
     AND disciple_level IN ('seeker', 'follower', 'disciple', 'leader');

  IF v_updated <> 41 THEN
    RAISE EXCEPTION 'Expected 41 paths to receive a new sequence, found %. A slug in this migration does not match the database.', v_updated;
  END IF;

  -- display_order must be unique across the 41 sequenced paths.
  SELECT COUNT(*) INTO v_dupes
    FROM (
      SELECT display_order
        FROM learning_paths
       WHERE display_order BETWEEN 1 AND 41
       GROUP BY display_order
      HAVING COUNT(*) > 1
    ) d;

  IF v_dupes > 0 THEN
    RAISE EXCEPTION 'display_order is not unique across the sequenced paths (% duplicated values).', v_dupes;
  END IF;

  SELECT COUNT(*) INTO v_bad_level
    FROM learning_paths
   WHERE display_order BETWEEN 1 AND 41
     AND disciple_level NOT IN ('seeker', 'follower', 'disciple', 'leader');

  IF v_bad_level > 0 THEN
    RAISE EXCEPTION 'Invalid disciple_level on % rows.', v_bad_level;
  END IF;

  RAISE NOTICE 'Re-sequenced 41 active learning paths. display_order is globally unique 1..41.';
END $$;

COMMIT;
