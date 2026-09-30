-- RLS performance (Supabase advisor 0003 auth_rls_initplan).
--
-- Policies that call auth.uid() / auth.jwt() / auth.role() directly re-evaluate the
-- call for every row. Wrapping the call as (SELECT auth.uid()) lets Postgres run it
-- once per statement (initPlan). The value is identical, so policy semantics do not
-- change: only the expression text is rewritten; name, command, roles and
-- permissive/restrictive mode are kept because ALTER POLICY edits in place.
--
-- Applied to every policy in the public schema that still has an unwrapped call,
-- so it is safe to re-run and covers policies whatever migration created them.

DO $$
DECLARE
  pol record;
  v_using text;
  v_check text;
  v_sql text;
  -- Unwrapped call = not already preceded by "SELECT " (deparsed wrapped form is
  -- "( SELECT auth.uid() AS uid)").
  c_pattern constant text := '(?<!SELECT )auth\.(uid|jwt|role)\(\)';
  c_replace constant text := '( SELECT auth.\1() AS \1)';
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname, qual, with_check
      FROM pg_policies
     WHERE schemaname = 'public'
       AND (qual ~ c_pattern OR with_check ~ c_pattern)
  LOOP
    v_using := regexp_replace(pol.qual, c_pattern, c_replace, 'g');
    v_check := regexp_replace(pol.with_check, c_pattern, c_replace, 'g');

    v_sql := format('ALTER POLICY %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    IF v_using IS NOT NULL THEN
      v_sql := v_sql || format(' USING (%s)', v_using);
    END IF;
    IF v_check IS NOT NULL THEN
      v_sql := v_sql || format(' WITH CHECK (%s)', v_check);
    END IF;

    EXECUTE v_sql;
  END LOOP;
END $$;
