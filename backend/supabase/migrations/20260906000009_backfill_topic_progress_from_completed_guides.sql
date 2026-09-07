-- Fellowship/learning-path progress counted only `user_topic_progress`, but that
-- row is written by the client and only when the study guide was opened through
-- a route that carries `topic_id` in the URL (learning path detail, fellowship
-- lesson, notification). Guides finished from Saved, Recent, Continue, the
-- generate flow or a shared link marked `user_study_guides.completed_at` and
-- nothing else, so a member who genuinely finished a lesson still showed 0.
--
-- This migration adds a title-based resolver (study guides are generated from
-- the topic title, and `study_guides.topic_id` has never been populated) and
-- backfills the missing completions.
--
-- Backfilled rows carry xp_earned = 0 on purpose: the XP leaderboard sums
-- user_topic_progress.xp_earned, and awarding XP retroactively would reshuffle
-- historical standings. Progress counts are corrected; rankings are untouched.

CREATE OR REPLACE FUNCTION public.resolve_topic_id_for_guide(
  p_input_value TEXT,
  p_language TEXT DEFAULT 'en'
)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH needle AS (
    SELECT lower(btrim(COALESCE(p_input_value, ''))) AS v
  )
  SELECT id FROM (
    -- Localized title first when the guide is not English
    SELECT rtt.topic_id AS id, 1 AS pref
    FROM recommended_topics_translations rtt, needle n
    WHERE n.v <> ''
      AND COALESCE(p_language, 'en') <> 'en'
      AND rtt.language_code = p_language
      AND lower(btrim(rtt.title)) = n.v
    UNION ALL
    -- Canonical English title
    SELECT rt.id, 2 AS pref
    FROM recommended_topics rt, needle n
    WHERE n.v <> ''
      AND lower(btrim(rt.title)) = n.v
  ) m
  ORDER BY m.pref
  LIMIT 1
$$;

GRANT EXECUTE ON FUNCTION public.resolve_topic_id_for_guide(TEXT, TEXT)
  TO service_role, authenticated;

COMMENT ON FUNCTION public.resolve_topic_id_for_guide(TEXT, TEXT) IS
  'Maps a generated study guide (by its input_value/title) back to the recommended topic it came from. Used to record topic progress when the guide was opened without a topic_id.';

-- One row per (user, topic): the earliest completion wins.
WITH resolved AS (
  SELECT
    usg.user_id,
    public.resolve_topic_id_for_guide(sg.input_value, sg.language) AS topic_id,
    MIN(usg.completed_at) AS completed_at,
    MIN(usg.created_at)   AS started_at
  FROM user_study_guides usg
  JOIN study_guides sg ON sg.id = usg.study_guide_id
  WHERE usg.completed_at IS NOT NULL
  GROUP BY 1, 2
)
INSERT INTO user_topic_progress (user_id, topic_id, started_at, completed_at, time_spent_seconds, xp_earned)
SELECT r.user_id, r.topic_id, COALESCE(r.started_at, r.completed_at), r.completed_at, 0, 0
FROM resolved r
WHERE r.topic_id IS NOT NULL
ON CONFLICT (user_id, topic_id) DO UPDATE
  SET completed_at = COALESCE(user_topic_progress.completed_at, EXCLUDED.completed_at),
      updated_at   = NOW()
  WHERE user_topic_progress.completed_at IS NULL;
