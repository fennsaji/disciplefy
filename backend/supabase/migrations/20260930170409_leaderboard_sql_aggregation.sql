-- Leaderboards: aggregate in SQL instead of per-user correlated subqueries / JS.
--
-- 1. Memory champions: the edge function loaded 1000 profiles + every mastered
--    verse + every streak row and ranked in JS. PostgREST max_rows=1000 truncated
--    those reads, so ranks were wrong once any table passed 1000 rows. Two RPCs
--    replace it: the global top list, and one caller's own rank/stats.
-- 2. get_leaderboard / get_user_gamification_stats: the per-user XP total was a
--    correlated subquery evaluated twice per profile (SELECT + HAVING). Both now
--    pre-aggregate XP once per table and hash-join. Results are unchanged; ties
--    on XP are now broken by user id (previously arbitrary) so ranks are stable.

-- Mastered verses (repetitions >= 5) grouped by user.
CREATE INDEX IF NOT EXISTS idx_memory_verses_mastered_user
  ON public.memory_verses (user_id)
  WHERE repetitions >= 5;

-- Ranked memory champions. Ordering: mastered verses, longest streak, total
-- practice days (all DESC), then user id for a stable order among ties.
-- Only users with some activity are ranked (same rule as the old JS code).
CREATE OR REPLACE FUNCTION public.memory_champions_ranked()
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  master_verses integer,
  current_streak integer,
  longest_streak integer,
  total_practice_days integer,
  rank bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH mastered AS (
    SELECT mv.user_id, COUNT(*)::integer AS n
      FROM public.memory_verses mv
     WHERE mv.repetitions >= 5
     GROUP BY mv.user_id
  ),
  candidates AS (
    SELECT
      up.id AS user_id,
      COALESCE(
        NULLIF(btrim(concat_ws(' ', NULLIF(up.first_name, ''), NULLIF(up.last_name, ''))), ''),
        'Anonymous User'
      ) AS display_name,
      up.profile_image_url AS avatar_url,
      COALESCE(m.n, 0) AS master_verses,
      COALESCE(s.current_streak, 0) AS current_streak,
      COALESCE(s.longest_streak, 0) AS longest_streak,
      COALESCE(s.total_practice_days, 0) AS total_practice_days
    FROM public.user_profiles up
    LEFT JOIN mastered m ON m.user_id = up.id
    LEFT JOIN public.memory_verse_streaks s ON s.user_id = up.id
    WHERE m.n > 0 OR s.longest_streak > 0 OR s.total_practice_days > 0
  )
  SELECT c.*,
         ROW_NUMBER() OVER (
           ORDER BY c.master_verses DESC, c.longest_streak DESC,
                    c.total_practice_days DESC, c.user_id
         ) AS rank
    FROM candidates c;
$$;

CREATE OR REPLACE FUNCTION public.get_memory_champions_leaderboard(p_limit integer DEFAULT 100)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  rank bigint,
  master_verses integer,
  longest_streak integer,
  total_practice_days integer,
  avatar_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT r.user_id, r.display_name, r.rank, r.master_verses,
         r.longest_streak, r.total_practice_days, r.avatar_url
    FROM public.memory_champions_ranked() r
   ORDER BY r.rank
   LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 100);
$$;

-- One user's rank and stats. Users with no activity are unranked and get
-- (number of ranked users + 1), i.e. placed after everyone ranked.
CREATE OR REPLACE FUNCTION public.get_memory_champion_rank(p_user_id uuid)
RETURNS TABLE (
  rank bigint,
  master_verses integer,
  current_streak integer,
  longest_streak integer,
  total_practice_days integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH ranked AS (SELECT * FROM public.memory_champions_ranked())
  SELECT
    COALESCE((SELECT r.rank FROM ranked r WHERE r.user_id = p_user_id),
             (SELECT COUNT(*) FROM ranked) + 1),
    (SELECT COUNT(*)::integer FROM public.memory_verses mv
      WHERE mv.user_id = p_user_id AND mv.repetitions >= 5),
    COALESCE(s.current_streak, 0),
    COALESCE(s.longest_streak, 0),
    COALESCE(s.total_practice_days, 0)
  FROM (SELECT 1) one
  LEFT JOIN public.memory_verse_streaks s ON s.user_id = p_user_id;
$$;

REVOKE ALL ON FUNCTION public.memory_champions_ranked() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_memory_champions_leaderboard(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_memory_champion_rank(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.memory_champions_ranked() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_memory_champions_leaderboard(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_memory_champion_rank(uuid) TO service_role;

-- XP per user (study XP + achievement XP) for users at or above the 200 XP
-- leaderboard threshold, pre-aggregated once per table.
CREATE OR REPLACE FUNCTION public.get_leaderboard(limit_count integer DEFAULT 10)
RETURNS TABLE(user_id uuid, display_name text, total_xp bigint, rank bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
    RETURN QUERY
    WITH study_xp AS (
        SELECT utp.user_id AS uid, SUM(utp.xp_earned) AS xp
          FROM user_topic_progress utp
         GROUP BY utp.user_id
    ),
    achievement_xp AS (
        SELECT ua.user_id AS uid, SUM(a.xp_reward) AS xp
          FROM user_achievements ua
          JOIN achievements a ON a.id = ua.achievement_id
         GROUP BY ua.user_id
    ),
    user_xp AS (
        SELECT
            up.id AS uid,
            (COALESCE(sx.xp, 0) + COALESCE(ax.xp, 0))::BIGINT AS xp,
            CASE
                WHEN up.first_name IS NOT NULL AND up.last_name IS NOT NULL AND up.last_name <> ''
                    THEN up.first_name || ' ' || LEFT(up.last_name, 1) || '.'
                WHEN up.first_name IS NOT NULL AND up.first_name <> ''
                    THEN up.first_name
                ELSE 'Anonymous'
            END AS dname
        FROM user_profiles up
        LEFT JOIN study_xp sx ON sx.uid = up.id
        LEFT JOIN achievement_xp ax ON ax.uid = up.id
        WHERE COALESCE(sx.xp, 0) + COALESCE(ax.xp, 0) >= 200
    )
    SELECT
        ux.uid                                                   AS user_id,
        ux.dname                                                 AS display_name,
        ux.xp                                                    AS total_xp,
        ROW_NUMBER() OVER (ORDER BY ux.xp DESC, ux.uid)::BIGINT  AS rank
    FROM user_xp ux
    ORDER BY ux.xp DESC, ux.uid
    LIMIT limit_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_gamification_stats(p_user_id uuid)
RETURNS TABLE(total_xp bigint, leaderboard_rank bigint, study_current_streak integer, study_longest_streak integer, study_last_date date, total_study_days integer, verse_current_streak integer, verse_longest_streak integer, total_studies_completed bigint, total_time_spent_seconds bigint, total_memory_verses bigint, total_voice_sessions bigint, total_saved_guides bigint, achievements_unlocked integer, achievements_total integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
    v_xp BIGINT;
    v_rank BIGINT;
BEGIN
    SELECT
        (COALESCE((SELECT SUM(utp.xp_earned) FROM user_topic_progress utp WHERE utp.user_id = p_user_id), 0)
       + COALESCE((SELECT SUM(a.xp_reward) FROM user_achievements ua
                     JOIN achievements a ON a.id = ua.achievement_id
                    WHERE ua.user_id = p_user_id), 0))::BIGINT
      INTO v_xp;

    -- Rank only exists for profiles at or above the 200 XP threshold; skip the
    -- all-users ranking otherwise (it would return no row for this user).
    IF v_xp >= 200 AND EXISTS (SELECT 1 FROM user_profiles WHERE id = p_user_id) THEN
        SELECT r.rank INTO v_rank
          FROM public.get_leaderboard(2147483647) r
         WHERE r.user_id = p_user_id;
    END IF;

    RETURN QUERY
    WITH study_streak_data AS (
        SELECT
            COALESCE(s.current_streak, 0) AS current_streak,
            COALESCE(s.longest_streak, 0) AS longest_streak,
            s.last_study_date,
            COALESCE(s.total_study_days, 0) AS total_study_days
        FROM user_study_streaks s
        WHERE s.user_id = p_user_id
    ),
    verse_streak_data AS (
        SELECT
            COALESCE(v.current_streak, 0) AS current_streak,
            COALESCE(v.longest_streak, 0) AS longest_streak
        FROM daily_verse_streaks v
        WHERE v.user_id = p_user_id
    ),
    counts AS (
        SELECT
            (SELECT COUNT(*) FROM user_topic_progress WHERE user_id = p_user_id AND completed_at IS NOT NULL) +
            (SELECT COUNT(*) FROM user_study_guides WHERE user_id = p_user_id AND completed_at IS NOT NULL) AS studies,
            (SELECT COALESCE(SUM(time_spent_seconds), 0) FROM user_topic_progress WHERE user_id = p_user_id) +
            (SELECT COALESCE(SUM(time_spent_seconds), 0) FROM user_study_guides WHERE user_id = p_user_id) AS time_spent,
            (SELECT COUNT(*) FROM memory_verses WHERE user_id = p_user_id) AS memory,
            (SELECT COUNT(*) FROM voice_conversations WHERE user_id = p_user_id AND status = 'completed') AS voice,
            (SELECT COUNT(*) FROM user_study_guides WHERE user_id = p_user_id AND is_saved = TRUE) AS saved
    ),
    achievement_counts AS (
        SELECT
            (SELECT COUNT(*) FROM user_achievements WHERE user_id = p_user_id)::INTEGER AS unlocked,
            (SELECT COUNT(*) FROM achievements)::INTEGER AS total
    )
    SELECT
        v_xp AS total_xp,
        v_rank AS leaderboard_rank,
        COALESCE(ssd.current_streak, 0) AS study_current_streak,
        COALESCE(ssd.longest_streak, 0) AS study_longest_streak,
        ssd.last_study_date AS study_last_date,
        COALESCE(ssd.total_study_days, 0) AS total_study_days,
        COALESCE(vsd.current_streak, 0) AS verse_current_streak,
        COALESCE(vsd.longest_streak, 0) AS verse_longest_streak,
        c.studies AS total_studies_completed,
        c.time_spent AS total_time_spent_seconds,
        c.memory AS total_memory_verses,
        c.voice AS total_voice_sessions,
        c.saved AS total_saved_guides,
        ac.unlocked AS achievements_unlocked,
        ac.total AS achievements_total
    FROM counts c
    CROSS JOIN achievement_counts ac
    LEFT JOIN study_streak_data ssd ON TRUE
    LEFT JOIN verse_streak_data vsd ON TRUE;
END;
$function$;
