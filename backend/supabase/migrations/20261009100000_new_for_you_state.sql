-- ============================================================================
-- Home "New for you" banner state, per user, across sessions and devices.
--
-- The app shows one banner a day introducing a feature the person has not
-- tried, rotating through the kinds (paths, memory, generate, discipler,
-- fellowships), from the 7th day after the person's start. A kind is retired
-- for good once it is dismissed or the feature has been tried.
--
-- user_new_for_you holds what the devices report (retired kinds, the last
-- kind shown and when, the last time a banner was opened). Devices keep a
-- local cache and call sync_new_for_you(p_state) with it; the function merges
-- it with the stored row (union of retired kinds, latest dates win), adds the
-- features the person has already tried (derived from their own data), saves
-- and returns the result plus the person's start (auth.users.created_at).
--
-- Guests (anonymous users) get a row too. merge_guest_new_for_you carries a
-- guest's row into the account when user-profile?action=merge_guest runs.
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.user_new_for_you (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  retired TEXT[] NOT NULL DEFAULT '{}',
  last_shown_kind TEXT,
  last_shown_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_new_for_you_retired_kinds CHECK (
    retired <@ ARRAY['paths', 'memory', 'generate', 'discipler', 'fellowships']::TEXT[]
  ),
  CONSTRAINT user_new_for_you_last_kind CHECK (
    last_shown_kind IS NULL
    OR last_shown_kind IN ('paths', 'memory', 'generate', 'discipler', 'fellowships')
  )
);

COMMENT ON TABLE public.user_new_for_you IS
  'Home "New for you" banner state per user: kinds retired (tried or dismissed), '
  'last kind shown and when, last time a banner was opened. Written through '
  'sync_new_for_you().';

ALTER TABLE public.user_new_for_you ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own new for you state" ON public.user_new_for_you;
CREATE POLICY "Users read own new for you state" ON public.user_new_for_you
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- Writes go through sync_new_for_you only (it merges instead of overwriting).
REVOKE ALL ON public.user_new_for_you FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_new_for_you TO authenticated;
GRANT ALL ON public.user_new_for_you TO service_role;

-- ----------------------------------------------------------------------------
-- Features the user has tried, from their own data.
--   paths       - enrolled in a second learning path
--   memory      - saved a memory verse
--   generate    - has a study guide that is not a learning-path lesson
--   discipler   - had a Discipler conversation
--   fellowships - is an active member of a fellowship
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.new_for_you_tried_kinds(p_user UUID)
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT ARRAY_REMOVE(ARRAY[
    CASE WHEN (SELECT count(*) FROM public.user_learning_path_progress p
               WHERE p.user_id = p_user) >= 2 THEN 'paths' END,
    CASE WHEN EXISTS (SELECT 1 FROM public.memory_verses m
                      WHERE m.user_id = p_user) THEN 'memory' END,
    CASE WHEN EXISTS (
      SELECT 1
      FROM public.user_study_guides usg
      JOIN public.study_guides sg ON sg.id = usg.study_guide_id
      WHERE usg.user_id = p_user
        AND NOT EXISTS (
          SELECT 1 FROM public.learning_path_topics lpt
          WHERE lpt.topic_id = COALESCE(
            sg.topic_id,
            public.resolve_topic_id_for_guide(sg.input_value, sg.language))
        )
    ) THEN 'generate' END,
    CASE WHEN EXISTS (SELECT 1 FROM public.voice_conversations v
                      WHERE v.user_id = p_user) THEN 'discipler' END,
    CASE WHEN EXISTS (SELECT 1 FROM public.fellowship_members f
                      WHERE f.user_id = p_user AND f.is_active) THEN 'fellowships' END
  ]::TEXT[], NULL);
$$;

COMMENT ON FUNCTION public.new_for_you_tried_kinds(UUID) IS
  'New for you kinds whose feature the user has already used. Internal: called '
  'by sync_new_for_you (for auth.uid()) and the service role.';

REVOKE ALL ON FUNCTION public.new_for_you_tried_kinds(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.new_for_you_tried_kinds(UUID) TO service_role;

-- ----------------------------------------------------------------------------
-- Keeps only known kinds, without duplicates, in a stable order.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.new_for_you_clean_kinds(p_kinds TEXT[])
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(array_agg(k ORDER BY array_position(
           ARRAY['paths', 'memory', 'generate', 'discipler', 'fellowships']::TEXT[], k)),
         '{}'::TEXT[])
  FROM (
    SELECT DISTINCT k FROM unnest(COALESCE(p_kinds, '{}'::TEXT[])) AS k
    WHERE k IN ('paths', 'memory', 'generate', 'discipler', 'fellowships')
  ) s;
$$;

-- ----------------------------------------------------------------------------
-- sync_new_for_you(p_state): merge the caller's device state, add tried
-- kinds, save and return the merged state with the caller's start.
--   p_state: {"retired": [...], "last_shown_kind": "...",
--             "last_shown_at": "...", "opened_at": "..."} (all optional)
-- Returns the same shape plus "started_at". Only ever touches auth.uid()'s row.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_new_for_you(p_state JSONB DEFAULT '{}'::JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_state JSONB := COALESCE(p_state, '{}'::JSONB);
  v_retired TEXT[] := '{}';
  v_kind TEXT;
  v_shown_at TIMESTAMPTZ;
  v_opened_at TIMESTAMPTZ;
  v_row public.user_new_for_you%ROWTYPE;
  v_started TIMESTAMPTZ;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'sync_new_for_you: not signed in' USING ERRCODE = '42501';
  END IF;

  -- Lenient input: anything malformed is ignored, never an error.
  IF jsonb_typeof(v_state) <> 'object' THEN
    v_state := '{}'::JSONB;
  END IF;
  IF jsonb_typeof(v_state -> 'retired') = 'array' THEN
    SELECT COALESCE(array_agg(e), '{}') INTO v_retired
    FROM jsonb_array_elements_text(v_state -> 'retired') AS e;
  END IF;
  v_kind := v_state ->> 'last_shown_kind';
  IF v_kind IS NOT NULL
     AND v_kind NOT IN ('paths', 'memory', 'generate', 'discipler', 'fellowships') THEN
    v_kind := NULL;
  END IF;
  BEGIN
    v_shown_at := (v_state ->> 'last_shown_at')::TIMESTAMPTZ;
  EXCEPTION WHEN others THEN
    v_shown_at := NULL;
  END;
  BEGIN
    v_opened_at := (v_state ->> 'opened_at')::TIMESTAMPTZ;
  EXCEPTION WHEN others THEN
    v_opened_at := NULL;
  END;
  -- A kind needs its date and the reverse; a date in the future is not trusted.
  IF v_kind IS NULL OR v_shown_at IS NULL OR v_shown_at > now() + interval '1 day' THEN
    v_kind := NULL;
    v_shown_at := NULL;
  END IF;
  IF v_opened_at > now() + interval '1 day' THEN
    v_opened_at := NULL;
  END IF;

  v_retired := public.new_for_you_clean_kinds(
    v_retired || public.new_for_you_tried_kinds(v_user));

  INSERT INTO public.user_new_for_you AS t
    (user_id, retired, last_shown_kind, last_shown_at, opened_at, updated_at)
  VALUES (v_user, v_retired, v_kind, v_shown_at, v_opened_at, now())
  ON CONFLICT (user_id) DO UPDATE SET
    retired = public.new_for_you_clean_kinds(t.retired || EXCLUDED.retired),
    last_shown_kind = CASE
      WHEN EXCLUDED.last_shown_at IS NOT NULL
           AND (t.last_shown_at IS NULL OR EXCLUDED.last_shown_at > t.last_shown_at)
        THEN EXCLUDED.last_shown_kind
      ELSE t.last_shown_kind END,
    last_shown_at = CASE
      WHEN EXCLUDED.last_shown_at IS NOT NULL
           AND (t.last_shown_at IS NULL OR EXCLUDED.last_shown_at > t.last_shown_at)
        THEN EXCLUDED.last_shown_at
      ELSE t.last_shown_at END,
    opened_at = GREATEST(t.opened_at, EXCLUDED.opened_at),
    updated_at = now()
  RETURNING * INTO v_row;

  SELECT u.created_at INTO v_started FROM auth.users u WHERE u.id = v_user;

  RETURN jsonb_build_object(
    'retired', to_jsonb(v_row.retired),
    'last_shown_kind', v_row.last_shown_kind,
    'last_shown_at', v_row.last_shown_at,
    'opened_at', v_row.opened_at,
    'started_at', v_started
  );
END;
$$;

COMMENT ON FUNCTION public.sync_new_for_you(JSONB) IS
  'Merges the caller''s device New for you state into user_new_for_you (union '
  'of retired kinds, latest dates win), adds the features already tried, and '
  'returns the merged state plus started_at (account creation). auth.uid() only.';

REVOKE ALL ON FUNCTION public.sync_new_for_you(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_new_for_you(JSONB) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- merge_guest_new_for_you(p_guest, p_user): carries a guest's row into the
-- account (same merge rules) and deletes it. Service role only; called by
-- user-profile?action=merge_guest after merge_guest_progress has checked the
-- pair. Linking an identity keeps the same user id and needs no merge.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_guest_new_for_you(p_guest UUID, p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_guest public.user_new_for_you%ROWTYPE;
BEGIN
  IF p_guest IS NULL OR p_user IS NULL OR p_guest = p_user THEN
    RETURN;
  END IF;
  DELETE FROM public.user_new_for_you WHERE user_id = p_guest
  RETURNING * INTO v_guest;
  IF v_guest.user_id IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO public.user_new_for_you AS t
    (user_id, retired, last_shown_kind, last_shown_at, opened_at, updated_at)
  VALUES (p_user, v_guest.retired, v_guest.last_shown_kind, v_guest.last_shown_at,
          v_guest.opened_at, now())
  ON CONFLICT (user_id) DO UPDATE SET
    retired = public.new_for_you_clean_kinds(t.retired || EXCLUDED.retired),
    last_shown_kind = CASE
      WHEN EXCLUDED.last_shown_at IS NOT NULL
           AND (t.last_shown_at IS NULL OR EXCLUDED.last_shown_at > t.last_shown_at)
        THEN EXCLUDED.last_shown_kind
      ELSE t.last_shown_kind END,
    last_shown_at = CASE
      WHEN EXCLUDED.last_shown_at IS NOT NULL
           AND (t.last_shown_at IS NULL OR EXCLUDED.last_shown_at > t.last_shown_at)
        THEN EXCLUDED.last_shown_at
      ELSE t.last_shown_at END,
    opened_at = GREATEST(t.opened_at, EXCLUDED.opened_at),
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION public.merge_guest_new_for_you(UUID, UUID) IS
  'Moves a guest''s New for you state into the account (union of retired kinds, '
  'latest dates win). Service role only.';

REVOKE ALL ON FUNCTION public.merge_guest_new_for_you(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.merge_guest_new_for_you(UUID, UUID) TO service_role;

COMMIT;
