-- ============================================================================
-- Learning path read paths honour per-path topic visibility and title overrides
-- ============================================================================
--
-- Companion to 20260721000002, which added:
--   * learning_path_topics.is_active   -- per-path visibility
--   * learning_path_topic_titles       -- (path, topic, language) title override
--
-- Until this migration lands, neither is consulted by any read path. This
-- migration redefines the seven functions that read learning_path_topics.
--
-- THE THREE RULES
--
--   Rule A -- every read of learning_path_topics gets the visibility filter,
--             COUNT(*) denominators included. The pre-existing bug is that
--             topic *lists* filtered but *denominators* did not, so a user
--             could complete every visible topic and watch the progress bar
--             stall below 100%.
--
--   Rule B -- every title selection prefers the path-specific override:
--             COALESCE(lptt.title, rtt.title, rt.title)
--
--   Rule C -- any ordinal shown to the user ("topic N of M") is derived from
--             ROW_NUMBER() over the visible rows, never from the raw
--             learning_path_topics.position column. Ordering and the stored
--             current_topic_position cursor still use raw position -- those
--             are matching keys, not display ordinals.
--
-- WHAT "VISIBLE" MEANS HERE
--
-- A topic is visible in a path when BOTH lpt.is_active = true (this path wants
-- it) AND rt.is_active = true (the topic itself is live). Both halves are
-- applied to every list AND every matching denominator, so numerator and
-- denominator always range over the identical set. Filtering only one half in
-- one place is exactly the class of bug this migration exists to remove.
--
-- SIGNATURES ARE UNCHANGED. Every function below keeps its exact argument
-- list, argument names, return type and return columns -- these are live RPCs
-- called by Edge Functions and the Flutter client.
--
-- IDEMPOTENT: CREATE OR REPLACE throughout; safe to re-run. Replacing a
-- function preserves its existing ownership and GRANTs.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1/7  get_available_learning_paths
-- ---------------------------------------------------------------------------
-- Baseline: 20260404000001_fix_learning_paths_function_ambiguity.sql
-- Changes: visibility filter on total_topics, on the progress numerator AND
--          denominator, and on the "has some completions" ordering predicate.
-- No topic titles are returned here, so Rule B does not apply.
-- No ordinal is returned here, so Rule C does not apply.
-- NOTE: alias `lpt` in this function is learning_path_TRANSLATIONS, not
--       learning_path_topics. Preserved as-is to keep the diff honest.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_available_learning_paths(
  p_user_id          UUID    DEFAULT NULL,
  p_language         VARCHAR DEFAULT 'en',
  p_include_enrolled BOOLEAN DEFAULT true,
  p_limit            INT     DEFAULT 10,
  p_offset           INT     DEFAULT 0,
  p_category         VARCHAR DEFAULT NULL,
  p_search           VARCHAR DEFAULT NULL
)
RETURNS TABLE(
  path_id            UUID,
  slug               VARCHAR,
  title              TEXT,
  description        TEXT,
  icon_name          VARCHAR,
  color              VARCHAR,
  total_xp           INTEGER,
  estimated_days     INTEGER,
  disciple_level     VARCHAR,
  recommended_mode   TEXT,
  is_featured        BOOLEAN,
  total_topics       INTEGER,
  is_enrolled        BOOLEAN,
  progress_percentage INTEGER,
  category           VARCHAR
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    lp.id                                     AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title)             AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    lp.is_featured,
    -- Rule A: only visible topics are counted.
    (SELECT COUNT(*)
       FROM learning_path_topics lpt_t
       JOIN recommended_topics rt_t ON rt_t.id = lpt_t.topic_id
      WHERE lpt_t.learning_path_id = lp.id
        AND lpt_t.is_active = true
        AND rt_t.is_active  = true)::INTEGER  AS total_topics,
    CASE WHEN p_user_id IS NOT NULL THEN
      EXISTS(
        SELECT 1 FROM user_learning_path_progress
         WHERE user_id = p_user_id AND learning_path_id = lp.id
      )
    ELSE false END                              AS is_enrolled,
    -- Compute progress from actual user_topic_progress records (not stale counter).
    -- Rule A: numerator and denominator both range over visible topics only, so
    -- completing every visible topic yields exactly 100 and never more.
    CASE WHEN p_user_id IS NOT NULL THEN
      COALESCE(
        (SELECT (
          COUNT(CASE WHEN utp.completed_at IS NOT NULL THEN 1 END) * 100
          / GREATEST(
              (SELECT COUNT(*)
                 FROM learning_path_topics lpt_d
                 JOIN recommended_topics rt_d ON rt_d.id = lpt_d.topic_id
                WHERE lpt_d.learning_path_id = lp.id
                  AND lpt_d.is_active = true
                  AND rt_d.is_active  = true),
              1)
        )::INTEGER
        FROM learning_path_topics lpt_inner
        JOIN recommended_topics rt_inner ON rt_inner.id = lpt_inner.topic_id
        LEFT JOIN user_topic_progress utp
               ON utp.topic_id = lpt_inner.topic_id AND utp.user_id = p_user_id
        WHERE lpt_inner.learning_path_id = lp.id
          AND lpt_inner.is_active = true
          AND rt_inner.is_active  = true
        ),
        0
      )
    ELSE 0 END                                  AS progress_percentage,
    lp.category
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lpt
         ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE lp.is_active = true
    AND (p_include_enrolled OR NOT EXISTS(
      SELECT 1 FROM user_learning_path_progress
       WHERE user_id = p_user_id AND learning_path_id = lp.id
    ))
    AND (p_category IS NULL OR lp.category = p_category)
    AND (
      p_search IS NULL
      OR COALESCE(lpt.title, lp.title) ILIKE '%' || p_search || '%'
      OR COALESCE(lpt.description, lp.description) ILIKE '%' || p_search || '%'
    )
  ORDER BY
    -- Completed paths always last
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp_c
       WHERE ulpp_c.user_id          = p_user_id
         AND ulpp_c.learning_path_id = lp.id
         AND ulpp_c.completed_at     IS NOT NULL
    ) THEN 1 ELSE 0 END,
    -- In-progress first (enrolled + has some completions + not finished)
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp2
       WHERE ulpp2.user_id           = p_user_id
         AND ulpp2.learning_path_id  = lp.id
         AND ulpp2.completed_at      IS NULL
    ) AND EXISTS(
      SELECT 1 FROM learning_path_topics lpt2
      JOIN recommended_topics rt2 ON rt2.id = lpt2.topic_id
      JOIN user_topic_progress utp2 ON utp2.topic_id = lpt2.topic_id AND utp2.user_id = p_user_id
      WHERE lpt2.learning_path_id = lp.id
        AND lpt2.is_active = true
        AND rt2.is_active  = true
        AND utp2.completed_at IS NOT NULL
    ) THEN 0 ELSE 1 END,
    -- Enrolled-incomplete next
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp3
       WHERE ulpp3.user_id          = p_user_id
         AND ulpp3.learning_path_id = lp.id
         AND ulpp3.completed_at     IS NULL
    ) THEN 0 ELSE 1 END,
    -- Featured next
    CASE WHEN lp.is_featured THEN 0 ELSE 1 END,
    lp.display_order,
    lp.title
  LIMIT p_limit
  OFFSET p_offset;
$$;

COMMENT ON FUNCTION get_available_learning_paths IS 'Returns active learning paths for browsing. Counts and progress range over visible topics only (learning_path_topics.is_active AND recommended_topics.is_active).';


-- ---------------------------------------------------------------------------
-- 2/7  get_learning_path_details
-- ---------------------------------------------------------------------------
-- Baseline: 20260418000001_add_allow_non_sequential_access_to_learning_paths.sql
-- Changes: visibility filter on the completed-count numerator, on the topics
--          list and on the total-topics denominator; path-specific title
--          override on each topic; topic `position` now a ROW_NUMBER ordinal
--          over the visible rows.
-- NOTE: alias `lptt` in the final RETURN QUERY is learning_path_TRANSLATIONS
--       (pre-existing). The topic-title override inside the topics subquery
--       therefore uses the distinct alias `lpttl` to avoid confusion.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_learning_path_details(
  p_path_id UUID,
  p_user_id UUID DEFAULT NULL,
  p_language VARCHAR DEFAULT 'en'
)
RETURNS TABLE(
  path_id UUID,
  slug VARCHAR,
  title TEXT,
  description TEXT,
  icon_name VARCHAR,
  color VARCHAR,
  total_xp INTEGER,
  estimated_days INTEGER,
  disciple_level VARCHAR,
  recommended_mode TEXT,
  allow_non_sequential_access BOOLEAN,
  is_enrolled BOOLEAN,
  progress_percentage INTEGER,
  topics_completed INTEGER,
  enrolled_at TIMESTAMPTZ,
  topics JSON
) AS $$
DECLARE
  v_topics JSON;
  v_is_enrolled BOOLEAN;
  v_progress_percentage INTEGER;
  v_topics_completed INTEGER;
  v_enrolled_at TIMESTAMPTZ;
  v_total_topics INTEGER;
BEGIN
  -- Get enrollment status
  IF p_user_id IS NOT NULL THEN
    SELECT true, ulpp.enrolled_at
    INTO v_is_enrolled, v_enrolled_at
    FROM user_learning_path_progress ulpp
    WHERE ulpp.user_id = p_user_id AND ulpp.learning_path_id = p_path_id;

    -- Count actual completed topics directly from user_topic_progress.
    -- Rule A: only completions of topics still VISIBLE in this path count,
    -- so this numerator matches the denominator computed below.
    SELECT COUNT(*)::INTEGER
    INTO v_topics_completed
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    JOIN user_topic_progress utp ON utp.topic_id = lpt.topic_id
    WHERE lpt.learning_path_id = p_path_id
      AND lpt.is_active = true
      AND rt.is_active  = true
      AND utp.user_id = p_user_id
      AND utp.completed_at IS NOT NULL;
  END IF;

  v_is_enrolled := COALESCE(v_is_enrolled, false);
  v_topics_completed := COALESCE(v_topics_completed, 0);

  -- Get topics with progress (including input_type)
  SELECT json_agg(topic_data ORDER BY topic_data.position)
  INTO v_topics
  FROM (
    SELECT
      -- Rule C: contiguous 0-based ordinal over the VISIBLE rows. Callers use
      -- this for display and sequential gating, so it must never contain gaps
      -- left behind by a hidden row.
      (ROW_NUMBER() OVER (ORDER BY lpt.position) - 1)::INTEGER AS position,
      lpt.is_milestone,
      rt.id AS topic_id,
      -- Rule B: path override > language translation > base title.
      COALESCE(lpttl.title, rtt.title, rt.title) AS title,
      COALESCE(rtt.description, rt.description) AS description,
      COALESCE(rtt.category, rt.category) AS category,
      COALESCE(rt.input_type, 'topic') AS input_type,
      COALESCE(rt.xp_value, 50) AS xp_value,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL)
      ELSE false END AS is_completed,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NULL)
      ELSE false END AS is_in_progress
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt ON rtt.topic_id = rt.id AND rtt.language_code = p_language
    LEFT JOIN learning_path_topic_titles lpttl
           ON lpttl.learning_path_id = lpt.learning_path_id
          AND lpttl.topic_id         = lpt.topic_id
          AND lpttl.language_code    = p_language
    WHERE lpt.learning_path_id = p_path_id
      AND lpt.is_active = true
      AND rt.is_active = true
  ) topic_data;

  -- Calculate progress percentage from actual count.
  -- Rule A: denominator counts visible topics only.
  SELECT COUNT(*)::INTEGER INTO v_total_topics
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
  WHERE lpt.learning_path_id = p_path_id
    AND lpt.is_active = true
    AND rt.is_active  = true;

  v_progress_percentage := CASE
    WHEN v_total_topics = 0 THEN 0
    ELSE (v_topics_completed * 100 / v_total_topics)::INTEGER
  END;

  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lptt.title, lp.title) AS title,
    COALESCE(lptt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    lp.allow_non_sequential_access,
    v_is_enrolled AS is_enrolled,
    v_progress_percentage AS progress_percentage,
    v_topics_completed AS topics_completed,
    v_enrolled_at AS enrolled_at,
    v_topics AS topics
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lptt ON lptt.learning_path_id = lp.id AND lptt.lang_code = p_language
  WHERE lp.id = p_path_id AND lp.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_learning_path_details IS 'Returns complete learning path details with topics, progress, recommended_mode, input_type, and allow_non_sequential_access. Hidden topics are excluded; topic titles prefer the path-specific override; topic position is a contiguous ordinal over visible topics.';


-- ---------------------------------------------------------------------------
-- 3/7  get_user_learning_paths
-- ---------------------------------------------------------------------------
-- Baseline: 20260119001000_learning_paths.sql lines 409-460
-- Changes: visibility filter on all three total-topics counts.
-- No topic titles and no ordinal are returned, so Rules B and C do not apply.
-- The numerator here is the stored ulpp.topics_completed counter rather than a
-- live count (pre-existing). Shrinking the denominator can now make a stale
-- counter exceed it, so the percentage is clamped to 100 -- a guard, not a
-- behaviour change: it can only fire on data that was already inconsistent.
-- NOTE: alias `lpt` in this function is learning_path_TRANSLATIONS.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_user_learning_paths(
  p_user_id UUID,
  p_language VARCHAR DEFAULT 'en'
)
RETURNS TABLE(
  path_id UUID,
  slug VARCHAR,
  title TEXT,
  description TEXT,
  icon_name VARCHAR,
  color VARCHAR,
  total_xp INTEGER,
  estimated_days INTEGER,
  disciple_level VARCHAR,
  recommended_mode TEXT,
  progress_percentage INTEGER,
  topics_completed INTEGER,
  total_topics INTEGER,
  enrolled_at TIMESTAMPTZ,
  last_activity_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title) AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    CASE
      WHEN (SELECT COUNT(*)
              FROM learning_path_topics lpt_a
              JOIN recommended_topics rt_a ON rt_a.id = lpt_a.topic_id
             WHERE lpt_a.learning_path_id = lp.id
               AND lpt_a.is_active = true
               AND rt_a.is_active  = true) = 0 THEN 0
      ELSE LEAST(
        (ulpp.topics_completed * 100 / (SELECT COUNT(*)
                                          FROM learning_path_topics lpt_b
                                          JOIN recommended_topics rt_b ON rt_b.id = lpt_b.topic_id
                                         WHERE lpt_b.learning_path_id = lp.id
                                           AND lpt_b.is_active = true
                                           AND rt_b.is_active  = true))::INTEGER,
        100)
    END AS progress_percentage,
    ulpp.topics_completed,
    (SELECT COUNT(*)::INTEGER
       FROM learning_path_topics lpt_c
       JOIN recommended_topics rt_c ON rt_c.id = lpt_c.topic_id
      WHERE lpt_c.learning_path_id = lp.id
        AND lpt_c.is_active = true
        AND rt_c.is_active  = true) AS total_topics,
    ulpp.enrolled_at,
    ulpp.last_activity_at,
    ulpp.completed_at
  FROM user_learning_path_progress ulpp
  JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
  LEFT JOIN learning_path_translations lpt ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE ulpp.user_id = p_user_id
    AND lp.is_active = true
  ORDER BY ulpp.last_activity_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_learning_paths IS 'Returns all learning paths user is enrolled in with progress data. Topic counts range over visible topics only.';


-- ---------------------------------------------------------------------------
-- 4/7  update_learning_path_progress_on_topic_complete  (TRIGGER FUNCTION)
-- ---------------------------------------------------------------------------
-- Baseline: 20260119001000_learning_paths.sql lines 640-696
--
-- HIGHEST-RISK FUNCTION IN THIS MIGRATION. It writes the authoritative
-- topics_completed / completed_at counters on every completion event. A wrong
-- denominator here does not self-correct on the next read -- it can leave a
-- path permanently uncompletable.
--
-- Changes:
--   * The path loop only considers paths where the completed topic is VISIBLE.
--     Completing a topic that a path has hidden no longer touches that path's
--     counters at all -- which is the whole point of per-path visibility.
--   * v_total_topics counts visible topics only (the denominator fix).
--   * current_topic_position now advances to the position of the next VISIBLE
--     topic instead of blindly adding 1. The old `v_topic_position + 1`
--     arithmetic assumed a gapless position sequence; with hidden rows that
--     assumption fails and the cursor would land on a hidden row, which
--     get_in_progress_topics matches against and would then find nothing.
--     COALESCE(next_visible, current) preserves the original clamp-at-last
--     behaviour exactly when there are no hidden rows.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_learning_path_progress_on_topic_complete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_learning_path_id UUID;
  v_topic_position INTEGER;
  v_next_position INTEGER;
  v_total_topics INTEGER;
  v_topic_xp INTEGER;
  v_visible_completed INTEGER;
BEGIN
  -- Only process when a topic is being marked as completed
  IF NEW.completed_at IS NOT NULL AND (OLD.completed_at IS NULL OR OLD IS NULL) THEN
    -- Find learning paths that include this topic AS A VISIBLE ENTRY and where
    -- the user is enrolled and not yet finished.
    FOR v_learning_path_id IN
      SELECT DISTINCT lpt.learning_path_id
      FROM learning_path_topics lpt
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
      JOIN user_learning_path_progress ulpp ON ulpp.learning_path_id = lpt.learning_path_id
      WHERE lpt.topic_id = NEW.topic_id
        AND lpt.is_active = true
        AND rt.is_active  = true
        AND ulpp.user_id = NEW.user_id
        AND ulpp.completed_at IS NULL
    LOOP
      -- Get topic position and XP value
      SELECT lpt.position, COALESCE(rt.xp_value, 50)
      INTO v_topic_position, v_topic_xp
      FROM learning_path_topics lpt
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.topic_id = NEW.topic_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      -- Get total VISIBLE topics in path (denominator for completion).
      SELECT COUNT(*) INTO v_total_topics
      FROM learning_path_topics lpt
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      -- Position of the next VISIBLE topic after this one; NULL when this was
      -- the last visible topic in the path.
      SELECT MIN(lpt.position) INTO v_next_position
      FROM learning_path_topics lpt
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.is_active = true
        AND rt.is_active  = true
        AND lpt.position > v_topic_position;

      -- Completion numerator, recomputed from the source of truth rather than
      -- read off the stored all-time `topics_completed` counter. The stored
      -- counter also counts completions of topics that are now hidden, so
      -- comparing it against the visible-only v_total_topics could both
      -- complete a path early and -- once a hidden topic is un-hidden -- leave
      -- a path permanently uncompletable (the trigger cannot re-fire for a row
      -- whose completed_at is already set).
      -- This is an AFTER INSERT OR UPDATE trigger, so NEW is already present in
      -- user_topic_progress and the topic that triggered this call is counted.
      SELECT COUNT(*)
      INTO v_visible_completed
      FROM learning_path_topics lpt
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
      JOIN user_topic_progress utp
        ON utp.topic_id = lpt.topic_id
       AND utp.user_id  = NEW.user_id
       AND utp.completed_at IS NOT NULL
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      -- Update progress
      UPDATE user_learning_path_progress
      SET
        topics_completed = topics_completed + 1,
        current_topic_position = COALESCE(v_next_position, v_topic_position),
        total_xp_earned = total_xp_earned + v_topic_xp,
        completed_at = CASE
          WHEN v_visible_completed >= v_total_topics THEN NOW()
          ELSE NULL
        END,
        last_activity_at = NOW()
      WHERE user_id = NEW.user_id
        AND learning_path_id = v_learning_path_id;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_learning_path_progress_on_topic_complete IS 'Trigger function to auto-update learning path progress when topics are completed. Only visible topics count toward progress, and the position cursor advances to the next visible topic.';


-- ---------------------------------------------------------------------------
-- 5/7  compute_learning_path_total_xp
-- ---------------------------------------------------------------------------
-- Baseline: 20260119001000_learning_paths.sql lines 724-747
-- Changes: visibility filter only -- XP totals must reflect what a user can
--          actually earn on the path.
-- The flat 50-per-topic rate (ignoring rt.xp_value) is pre-existing and
-- deliberately left alone.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION compute_learning_path_total_xp(p_path_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_xp INTEGER;
BEGIN
  -- Calculate total XP from all VISIBLE topics in the path (50 XP per topic)
  SELECT COALESCE(COUNT(*) * 50, 0)
  INTO v_total_xp
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
  WHERE lpt.learning_path_id = p_path_id
    AND lpt.is_active = true
    AND rt.is_active  = true;

  -- Update learning path with calculated XP
  UPDATE learning_paths
  SET total_xp = v_total_xp,
      updated_at = NOW()
  WHERE id = p_path_id;

  RETURN v_total_xp;
END;
$$;

COMMENT ON FUNCTION compute_learning_path_total_xp IS 'Calculates and updates total XP for a learning path based on its visible topics';


-- ---------------------------------------------------------------------------
-- 6/7  get_in_progress_topics
-- ---------------------------------------------------------------------------
-- Baseline: 20260119001000_learning_paths.sql lines 757-908
-- Changes:
--   * New `visible_path_topics` CTE is the single visible view of the join
--     table; both branches join it instead of learning_path_topics directly.
--     It carries the ROW_NUMBER ordinal and the COUNT window, which replaces
--     `lpt.position + 1` (Rule C) and the two unfiltered COUNT(*) subqueries
--     (Rule A) in one move.
--   * Path-specific title override applied where the path context exists.
--   * The `lpt.position = ulpp.current_topic_position` cursor match still uses
--     the RAW position -- that is a matching key against a stored value, not a
--     display ordinal, and must stay in the same coordinate space as the
--     trigger function that writes it.
-- NOTE: this function takes no p_language parameter, so per the plan the title
--       override joins on language_code = 'en'. It also does not consult
--       recommended_topics_translations at all (pre-existing); this migration
--       does not change that.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_in_progress_topics(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE(
  topic_id UUID,
  topic_title TEXT,
  topic_description TEXT,
  topic_category TEXT,
  started_at TIMESTAMPTZ,
  time_spent_seconds INTEGER,
  xp_value INTEGER,
  learning_path_id UUID,
  learning_path_name TEXT,
  position_in_path INTEGER,
  total_topics_in_path INTEGER,
  topics_completed_in_path INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH visible_path_topics AS (
    -- Rule A + Rule C: the visible rows of the join table, each carrying its
    -- 1-based ordinal and its path's visible total.
    SELECT
      lpt.learning_path_id,
      lpt.topic_id,
      lpt.position,
      (ROW_NUMBER() OVER (PARTITION BY lpt.learning_path_id ORDER BY lpt.position))::INTEGER AS visible_ordinal,
      (COUNT(*)     OVER (PARTITION BY lpt.learning_path_id))::INTEGER                       AS visible_total
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    WHERE lpt.is_active = true
      AND rt.is_active  = true
  ),
  visible_completed AS (
    -- Rule A (numerator): this user's completed topics that are still VISIBLE
    -- in the path. The stored ulpp.topics_completed is an all-time counter and
    -- would be paired with the visible-only visible_total below, which can
    -- render as "9 of 6" on the client. Computed here so the numerator and the
    -- denominator come from the same visible set.
    SELECT
      vpt.learning_path_id,
      COUNT(*)::INTEGER AS completed_total
    FROM visible_path_topics vpt
    JOIN user_topic_progress utp
      ON utp.topic_id = vpt.topic_id
     AND utp.user_id  = p_user_id
     AND utp.completed_at IS NOT NULL
    GROUP BY vpt.learning_path_id
  ),
  in_progress AS (
    -- Get topics user has started but not completed
    SELECT
      rt.id AS topic_id,
      rt.title AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      utp.started_at,
      utp.time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      utp.updated_at
    FROM user_topic_progress utp
    JOIN recommended_topics rt ON rt.id = utp.topic_id
    WHERE utp.user_id = p_user_id
      AND utp.completed_at IS NULL
      AND rt.is_active = true
  ),
  next_in_path AS (
    -- Get next topic from learning paths where user completed a topic
    SELECT DISTINCT ON (lp.id)
      rt.id AS topic_id,
      -- Rule B: path override wins over the base title.
      COALESCE(lptt.title, rt.title) AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      ulpp.last_activity_at AS started_at,
      0 AS time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      ulpp.last_activity_at AS updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      vpt.visible_ordinal AS position_in_path,
      vpt.visible_total   AS total_topics_in_path,
      COALESCE(vc.completed_total, 0)::INTEGER AS topics_completed_in_path
    FROM user_learning_path_progress ulpp
    JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
    JOIN visible_path_topics vpt ON vpt.learning_path_id = lp.id
    JOIN recommended_topics rt ON rt.id = vpt.topic_id
    LEFT JOIN visible_completed vc ON vc.learning_path_id = lp.id
    LEFT JOIN learning_path_topic_titles lptt
           ON lptt.learning_path_id = vpt.learning_path_id
          AND lptt.topic_id         = vpt.topic_id
          AND lptt.language_code    = 'en'
    WHERE ulpp.user_id = p_user_id
      AND ulpp.completed_at IS NULL
      AND lp.is_active = true
      AND rt.is_active = true
      -- Cursor match against the stored raw position (NOT the display ordinal).
      AND vpt.position = ulpp.current_topic_position
      AND NOT EXISTS (
        SELECT 1 FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id
      )
    ORDER BY lp.id, ulpp.last_activity_at DESC
  ),
  in_progress_with_path AS (
    -- Add learning path info to in-progress topics
    SELECT
      ip.topic_id,
      -- Rule B: override applies only when this topic is reached through a path.
      COALESCE(lptt.title, ip.topic_title) AS topic_title,
      ip.topic_description,
      ip.topic_category,
      ip.started_at,
      ip.time_spent_seconds,
      ip.xp_value,
      ip.updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      vpt.visible_ordinal AS position_in_path,
      vpt.visible_total   AS total_topics_in_path,
      COALESCE(vc.completed_total, 0)::INTEGER AS topics_completed_in_path
    FROM in_progress ip
    LEFT JOIN visible_path_topics vpt ON vpt.topic_id = ip.topic_id
    LEFT JOIN learning_paths lp ON lp.id = vpt.learning_path_id AND lp.is_active = true
    LEFT JOIN user_learning_path_progress ulpp ON ulpp.learning_path_id = lp.id AND ulpp.user_id = p_user_id
    LEFT JOIN visible_completed vc ON vc.learning_path_id = lp.id
    LEFT JOIN learning_path_topic_titles lptt
           ON lptt.learning_path_id = vpt.learning_path_id
          AND lptt.topic_id         = vpt.topic_id
          AND lptt.language_code    = 'en'
    WHERE lp.id IS NULL OR ulpp.id IS NOT NULL
  ),
  combined AS (
    SELECT
      ipwp.topic_id,
      ipwp.topic_title,
      ipwp.topic_description,
      ipwp.topic_category,
      ipwp.started_at,
      ipwp.time_spent_seconds,
      ipwp.xp_value,
      ipwp.updated_at,
      ipwp.learning_path_id,
      ipwp.learning_path_name,
      ipwp.position_in_path,
      ipwp.total_topics_in_path,
      ipwp.topics_completed_in_path,
      1 AS priority
    FROM in_progress_with_path ipwp

    UNION ALL

    SELECT
      nip.topic_id,
      nip.topic_title,
      nip.topic_description,
      nip.topic_category,
      nip.started_at,
      nip.time_spent_seconds,
      nip.xp_value,
      nip.updated_at,
      nip.learning_path_id,
      nip.learning_path_name,
      nip.position_in_path,
      nip.total_topics_in_path,
      nip.topics_completed_in_path,
      2 AS priority
    FROM next_in_path nip
    WHERE NOT EXISTS (
      SELECT 1 FROM in_progress_with_path ipwp
      WHERE ipwp.topic_id = nip.topic_id
    )
  )
  SELECT DISTINCT ON (c.topic_id)
    c.topic_id,
    c.topic_title,
    c.topic_description,
    c.topic_category,
    c.started_at,
    c.time_spent_seconds,
    c.xp_value,
    c.learning_path_id,
    c.learning_path_name,
    c.position_in_path,
    c.total_topics_in_path,
    c.topics_completed_in_path
  FROM combined c
  ORDER BY c.topic_id, c.priority, c.updated_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_in_progress_topics IS 'Returns in-progress topics for Continue Learning with learning path context. Hidden topics are excluded and position_in_path is an ordinal over visible topics.';


-- ---------------------------------------------------------------------------
-- 7/7  get_next_topic_in_learning_path
-- ---------------------------------------------------------------------------
-- Baseline: 20260119001000_learning_paths.sql lines 915-961
-- Changes: visibility filter on the candidate list and on total_topics;
--          path-specific title override; topic_position is now a ROW_NUMBER
--          ordinal over visible topics rather than `lpt.position + 1`.
-- Ordering still uses the raw position, which is the correct sequence key.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_next_topic_in_learning_path(
  p_user_id UUID,
  p_learning_path_id UUID,
  p_language VARCHAR DEFAULT 'en'
)
RETURNS TABLE(
  topic_id UUID,
  title TEXT,
  description TEXT,
  category TEXT,
  xp_value INTEGER,
  topic_position INTEGER,
  total_topics INTEGER,
  is_completed BOOLEAN,
  is_in_progress BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH visible AS (
    -- Rule A + Rule C: visible rows of this path, each with its 1-based
    -- ordinal and the path's visible total.
    SELECT
      lpt.topic_id,
      lpt.position,
      (ROW_NUMBER() OVER (ORDER BY lpt.position))::INTEGER AS visible_ordinal,
      (COUNT(*)     OVER ())::INTEGER                      AS visible_total
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    WHERE lpt.learning_path_id = p_learning_path_id
      AND lpt.is_active = true
      AND rt.is_active  = true
  )
  SELECT
    rt.id AS topic_id,
    -- Rule B: path override > language translation > base title.
    COALESCE(lptt.title, rtt.title, rt.title) AS title,
    COALESCE(rtt.description, rt.description) AS description,
    rt.category::TEXT AS category,
    COALESCE(rt.xp_value, 50) AS xp_value,
    v.visible_ordinal AS topic_position,
    v.visible_total   AS total_topics,
    EXISTS(
      SELECT 1 FROM user_topic_progress utp
      WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL
    ) AS is_completed,
    EXISTS(
      SELECT 1 FROM user_topic_progress utp
      WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NULL
    ) AS is_in_progress
  FROM visible v
  JOIN recommended_topics rt ON rt.id = v.topic_id
  LEFT JOIN recommended_topics_translations rtt ON rtt.topic_id = rt.id AND rtt.language_code = p_language
  LEFT JOIN learning_path_topic_titles lptt
         ON lptt.learning_path_id = p_learning_path_id
        AND lptt.topic_id         = v.topic_id
        AND lptt.language_code    = p_language
  WHERE NOT EXISTS (
      SELECT 1 FROM user_topic_progress utp
      WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL
    )
  ORDER BY v.position
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_next_topic_in_learning_path IS 'Returns the next uncompleted VISIBLE topic in a learning path for user, with a path-specific title override and an ordinal over visible topics.';


-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_missing TEXT;
BEGIN
  -- Every function that reads learning_path_topics must now mention is_active.
  SELECT string_agg(p.proname, ', ')
    INTO v_missing
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN (
       'get_available_learning_paths',
       'get_learning_path_details',
       'get_user_learning_paths',
       'update_learning_path_progress_on_topic_complete',
       'compute_learning_path_total_xp',
       'get_in_progress_topics',
       'get_next_topic_in_learning_path'
     )
     AND pg_get_functiondef(p.oid) LIKE '%learning_path_topics%'
     AND pg_get_functiondef(p.oid) NOT LIKE '%is_active%';

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'These functions read learning_path_topics without filtering is_active: %', v_missing;
  END IF;

  RAISE NOTICE 'All 7 learning-path functions filter is_active.';
END $$;

COMMIT;
