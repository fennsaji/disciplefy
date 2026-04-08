-- Fix H-02: anonymous_sessions UPDATE policy has no session_id filter
-- Previously used USING (true) allowing any anon user to update any session row.
--
-- Note: anonymous_study_guides (Fix H-01) was already dropped in migration
-- 20260307000004_drop_anonymous_study_guides.sql and is not applicable here.

DROP POLICY IF EXISTS "Allow anonymous session updates" ON anonymous_sessions;

CREATE POLICY "Allow anonymous session updates" ON anonymous_sessions
  FOR UPDATE
  USING (session_id = (current_setting('app.session_id', true))::uuid);
