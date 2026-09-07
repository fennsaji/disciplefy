# Fellowship 1.0.5 — Plan 01: Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land every schema change the release needs: the Discipler system user, fellowship flags and mentor preferences, Discipler tables, the study-guide FTS index, notification types, and cron rows.

**Architecture:** Six timestamped migrations under `backend/supabase/migrations/`, each idempotent (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`). Verified against the local Supabase with `psql` assertions and the existing Deno drift test for notification types.

**Tech Stack:** PostgreSQL 17 (local Supabase) via Supabase CLI, psql, Deno test.

**Spec:** `docs/superpowers/specs/2026-09-06-fellowship-discipler-redesign-design.md` §1, §4, §9. Index: `2026-09-06-fellowship-discipler-00-index.md`.

## Global Constraints

See index. Relevant here:
- Discipler id `00000000-0000-4000-8000-00000000d15c`, email `discipler@disciplefy.in`.
- Post types: add `daily`, remove `system`, delete `system` rows.
- Notification types to add: `fellowship_daily_post`, `fellowship_discipler_reply`, `fellowship_discipler_activity`.
- Cron rows: `fellowship_daily_post` `0 0 1 * * *`, `discipler_reply_worker` `0 * * * * *`.
- Local only. Never `supabase db push`.

---

### Task 1: Discipler system user and profile flag

**Files:**
- Create: `backend/supabase/migrations/20260906000001_discipler_system_user.sql`

**Interfaces:**
- Produces: `user_profiles.is_system BOOLEAN`, `system_config` keys `discipler_user_id`, `discipler_global_enabled`, and the auth user row with `banned_until = '2999-12-31T00:00:00Z'`.

- [ ] **Step 1: Write the migration**

```sql
-- =====================================================
-- Migration: Discipler system user
-- Date: 2026-09-06
-- Adds the AI helper identity used by fellowship auto-replies and daily posts.
-- Pattern copied from 20260316000001_system_user.sql.
-- =====================================================

BEGIN;

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS is_system BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN user_profiles.is_system IS
  'True for machine authors (Discipler). Clients render an AI chip and hide report/block; counts exclude these rows.';

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token, raw_user_meta_data, banned_until
)
VALUES (
  '00000000-0000-4000-8000-00000000d15c',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'discipler@disciplefy.in',
  '',
  now(), now(), '', '', '', '',
  '{"full_name": "Discipler", "name": "Discipler", "display_name": "Discipler"}'::jsonb,
  '2999-12-31T00:00:00Z'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO user_profiles (id, is_admin, is_system)
VALUES ('00000000-0000-4000-8000-00000000d15c', false, true)
ON CONFLICT (id) DO UPDATE SET is_system = true;

INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES
  ('discipler_user_id', '00000000-0000-4000-8000-00000000d15c',
   'auth.users id of the Discipler AI helper', true, '{"category": "discipler"}'::jsonb),
  ('discipler_global_enabled', 'false',
   'Kill switch for all Discipler replies and reactions', true, '{"category": "discipler"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata;

COMMIT;
```

- [ ] **Step 2: Apply locally and verify**

Run:
```bash
cd backend && supabase migration up --local 2>&1 | tail -3
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select email, banned_until is not null from auth.users where id='00000000-0000-4000-8000-00000000d15c'; select is_system from user_profiles where id='00000000-0000-4000-8000-00000000d15c'; select key,value from system_config where key like 'discipler_%' order by 1;"
```
Expected:
```
discipler@disciplefy.in|t
t
discipler_global_enabled|false
discipler_user_id|00000000-0000-4000-8000-00000000d15c
```

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260906000001_discipler_system_user.sql
git commit -m "feat(db): add Discipler system user and is_system profile flag"
```

---

### Task 2: Fellowship flags, mentor preferences, post and comment columns, system-post removal

**Files:**
- Create: `backend/supabase/migrations/20260906000002_fellowship_discipler_flags.sql`

**Interfaces:**
- Produces columns: `fellowships.is_official, discipler_allowed, daily_post_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_on`; `fellowship_members.discipler_activity_push`; `fellowship_posts.to_mentors, mentions_discipler`; `fellowship_comments.is_pending_review, mentions_discipler, study_guide_id, guide_title, guide_input_type, guide_input_value, guide_language`; post_type CHECK with `daily`, without `system`.

- [ ] **Step 1: Write the migration**

```sql
-- =====================================================
-- Migration: Fellowship Discipler flags and mentor preferences
-- Date: 2026-09-06
-- =====================================================

BEGIN;

-- Admin-only flags
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS is_official        BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS discipler_allowed  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS daily_post_allowed BOOLEAN NOT NULL DEFAULT false;

-- Mentor-editable preferences
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS discipler_reply_mode TEXT NOT NULL DEFAULT 'auto',
  ADD COLUMN IF NOT EXISTS discipler_reply_scope TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS discipler_reply_delay_min INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discipler_react_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS daily_post_on BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_discipler_reply_mode_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_discipler_reply_mode_check
  CHECK (discipler_reply_mode IN ('off', 'auto', 'review'));
ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_discipler_reply_scope_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_discipler_reply_scope_check
  CHECK (discipler_reply_scope IN ('all', 'lessons_only'));
ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_discipler_reply_delay_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_discipler_reply_delay_check
  CHECK (discipler_reply_delay_min IN (0, 30, 120, 720));

COMMENT ON COLUMN fellowships.discipler_allowed IS 'Admin: Discipler may reply/react here. Mentors control mode/scope/delay.';
COMMENT ON COLUMN fellowships.daily_post_allowed IS 'Admin: rs-backend daily post cron may post here when daily_post_on is true.';

CREATE INDEX IF NOT EXISTS idx_fellowships_daily_post
  ON fellowships (id) WHERE daily_post_allowed = true AND daily_post_on = true AND is_active = true;

-- Per-mentor push preference
ALTER TABLE fellowship_members
  ADD COLUMN IF NOT EXISTS discipler_activity_push BOOLEAN NOT NULL DEFAULT true;

-- Posts
ALTER TABLE fellowship_posts
  ADD COLUMN IF NOT EXISTS to_mentors BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS mentions_discipler BOOLEAN NOT NULL DEFAULT false;

-- Remove join announcements; they become notifications only.
DELETE FROM fellowship_posts WHERE post_type = 'system';

ALTER TABLE fellowship_posts DROP CONSTRAINT IF EXISTS fellowship_posts_post_type_check;
ALTER TABLE fellowship_posts ADD CONSTRAINT fellowship_posts_post_type_check
  CHECK (post_type = ANY (ARRAY[
    'general'::text, 'prayer'::text, 'praise'::text,
    'question'::text, 'study_note'::text, 'shared_guide'::text,
    'daily'::text
  ]));

CREATE INDEX IF NOT EXISTS idx_fellowship_posts_daily
  ON fellowship_posts (fellowship_id, created_at DESC) WHERE post_type = 'daily' AND is_deleted = false;

-- Comments
ALTER TABLE fellowship_comments
  ADD COLUMN IF NOT EXISTS is_pending_review BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS mentions_discipler BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS study_guide_id UUID REFERENCES study_guides(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS guide_title TEXT,
  ADD COLUMN IF NOT EXISTS guide_input_type TEXT,
  ADD COLUMN IF NOT EXISTS guide_input_value TEXT,
  ADD COLUMN IF NOT EXISTS guide_language TEXT;

ALTER TABLE fellowship_comments DROP CONSTRAINT IF EXISTS fellowship_comments_guide_input_type_check;
ALTER TABLE fellowship_comments ADD CONSTRAINT fellowship_comments_guide_input_type_check
  CHECK (guide_input_type IS NULL OR guide_input_type IN ('topic', 'scripture'));

CREATE INDEX IF NOT EXISTS idx_fellowship_comments_pending
  ON fellowship_comments (fellowship_id, created_at) WHERE is_pending_review = true AND is_deleted = false;

-- Helper: every active mentor of a fellowship (the owner is also a mentor row).
CREATE OR REPLACE FUNCTION fellowship_mentor_ids(p_fellowship_id UUID)
RETURNS TABLE(user_id UUID, discipler_activity_push BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT user_id, discipler_activity_push
  FROM fellowship_members
  WHERE fellowship_id = p_fellowship_id AND role = 'mentor' AND is_active = true;
$$;

COMMIT;
```

- [ ] **Step 2: Apply and verify**

Run:
```bash
cd backend && supabase migration up --local 2>&1 | tail -3
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select count(*) from fellowship_posts where post_type='system'; select discipler_reply_mode, discipler_reply_delay_min, daily_post_on from fellowships limit 1; select count(*) from fellowship_mentor_ids('f0000000-0000-0000-0000-000000000001'); insert into fellowship_posts (fellowship_id, author_user_id, content, post_type) values ('f0000000-0000-0000-0000-000000000001','a5bff495-2fe0-4927-aff0-f519e4e3bcf0','x','system');"
```
Expected: `0`, `auto|0|t`, `1`, then an error `violates check constraint "fellowship_posts_post_type_check"`.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260906000002_fellowship_discipler_flags.sql
git commit -m "feat(db): fellowship Discipler flags, mentor preferences, drop system posts"
```

---

### Task 3: Discipler tables

**Files:**
- Create: `backend/supabase/migrations/20260906000003_discipler_tables.sql`

**Interfaces:**
- Produces tables `discipler_reply_queue`, `discipler_replies`, `discipler_activity`, `discipler_daily_posts` and helper `discipler_daily_budget(p_fellowship_id UUID, p_user_id UUID) RETURNS TABLE(user_count INT, fellowship_count INT)`.

- [ ] **Step 1: Write the migration**

```sql
-- =====================================================
-- Migration: Discipler tables
-- Date: 2026-09-06
-- Tables: discipler_reply_queue, discipler_replies, discipler_activity, discipler_daily_posts
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS discipler_reply_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES fellowship_comments(id) ON DELETE CASCADE,
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  trigger TEXT NOT NULL CHECK (trigger IN ('mention', 'question')),
  run_after TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'done', 'failed',
                      'skipped_mentor_answered', 'skipped_gate', 'skipped_injection', 'skipped_budget')),
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_discipler_queue_due
  ON discipler_reply_queue (run_after) WHERE status = 'pending';
-- One queue row per target; NULL comment_id means "the post itself" (PG15+ NULLS NOT DISTINCT).
ALTER TABLE discipler_reply_queue DROP CONSTRAINT IF EXISTS uq_discipler_queue_target;
ALTER TABLE discipler_reply_queue ADD CONSTRAINT uq_discipler_queue_target
  UNIQUE NULLS NOT DISTINCT (post_id, comment_id);

CREATE TABLE IF NOT EXISTS discipler_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id UUID REFERENCES discipler_reply_queue(id) ON DELETE SET NULL,
  post_id UUID NOT NULL REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES fellowship_comments(id) ON DELETE SET NULL,
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  asked_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trigger TEXT NOT NULL CHECK (trigger IN ('mention', 'question')),
  action TEXT NOT NULL CHECK (action IN ('reply', 'react')),
  reaction TEXT,
  guide_attached BOOLEAN NOT NULL DEFAULT false,
  language_detected TEXT,
  model TEXT NOT NULL,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cost_usd NUMERIC(10, 6) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_discipler_replies_day
  ON discipler_replies (fellowship_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_discipler_replies_user_day
  ON discipler_replies (asked_by, created_at DESC);

CREATE TABLE IF NOT EXISTS discipler_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('reply', 'react', 'draft', 'daily_post')),
  post_id UUID REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES fellowship_comments(id) ON DELETE CASCADE,
  reaction TEXT,
  language TEXT,
  summary TEXT NOT NULL,
  pushed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_discipler_activity_fellowship
  ON discipler_activity (fellowship_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_discipler_activity_unpushed
  ON discipler_activity (fellowship_id) WHERE pushed_at IS NULL;

CREATE TABLE IF NOT EXISTS discipler_daily_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  post_date DATE NOT NULL,
  topic_id UUID NOT NULL,
  learning_path_topic_id UUID NOT NULL,
  study_guide_id UUID REFERENCES study_guides(id) ON DELETE SET NULL,
  post_id UUID REFERENCES fellowship_posts(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_discipler_daily UNIQUE (fellowship_id, post_date)
);
CREATE INDEX IF NOT EXISTS idx_discipler_daily_topic
  ON discipler_daily_posts (fellowship_id, learning_path_topic_id);

-- Budget helper: replies today for a user and for a fellowship (UTC day).
CREATE OR REPLACE FUNCTION discipler_daily_budget(p_fellowship_id UUID, p_user_id UUID)
RETURNS TABLE(user_count INTEGER, fellowship_count INTEGER)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    (SELECT COUNT(*)::int FROM discipler_replies
      WHERE asked_by = p_user_id AND created_at >= date_trunc('day', now())),
    (SELECT COUNT(*)::int FROM discipler_replies
      WHERE fellowship_id = p_fellowship_id AND created_at >= date_trunc('day', now()));
$$;

-- RLS: service role only, like every other fellowship table.
ALTER TABLE discipler_reply_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE discipler_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE discipler_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE discipler_daily_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "discipler_reply_queue_service_all" ON discipler_reply_queue;
CREATE POLICY "discipler_reply_queue_service_all" ON discipler_reply_queue FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "discipler_replies_service_all" ON discipler_replies;
CREATE POLICY "discipler_replies_service_all" ON discipler_replies FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "discipler_activity_service_all" ON discipler_activity;
CREATE POLICY "discipler_activity_service_all" ON discipler_activity FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "discipler_daily_posts_service_all" ON discipler_daily_posts;
CREATE POLICY "discipler_daily_posts_service_all" ON discipler_daily_posts FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT ALL ON public.discipler_reply_queue TO service_role;
GRANT ALL ON public.discipler_replies TO service_role;
GRANT ALL ON public.discipler_activity TO service_role;
GRANT ALL ON public.discipler_daily_posts TO service_role;

COMMIT;
```

- [ ] **Step 2: Apply and verify**

Run:
```bash
cd backend && supabase migration up --local 2>&1 | tail -3
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select * from discipler_daily_budget('f0000000-0000-0000-0000-000000000001','3497fd41-200d-427e-9a50-17022d123c05'); select count(*) from pg_policies where tablename like 'discipler_%';"
```
Expected: `0|0` and `4`. Also `insert into discipler_reply_queue (post_id, fellowship_id, trigger) values ('a0000000-0000-0000-0000-000000000004','f0000000-0000-0000-0000-000000000001','question')` twice → the second fails with `uq_discipler_queue_target` (then delete the row).

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260906000003_discipler_tables.sql
git commit -m "feat(db): Discipler queue, replies, activity, and daily post tables"
```

---

### Task 4: Study guide full-text index

**Files:**
- Create: `backend/supabase/migrations/20260906000004_study_guides_fts.sql`

**Interfaces:**
- Produces: GIN index `idx_study_guides_fts` on `to_tsvector('simple', coalesce(input_value,'') || ' ' || coalesce(summary,''))`, and helper `discipler_related_guide(p_query TEXT, p_language TEXT) RETURNS TABLE(id UUID, input_value TEXT, summary TEXT, interpretation TEXT)`.

- [ ] **Step 1: Write the migration**

```sql
-- =====================================================
-- Migration: study_guides full-text index for Discipler context lookup
-- Date: 2026-09-06
-- =====================================================

BEGIN;

CREATE INDEX IF NOT EXISTS idx_study_guides_fts
  ON study_guides
  USING GIN (to_tsvector('simple', coalesce(input_value, '') || ' ' || coalesce(summary, '')));

-- Top-1 related guide in a language. 'simple' config works for all three scripts.
CREATE OR REPLACE FUNCTION discipler_related_guide(p_query TEXT, p_language TEXT)
RETURNS TABLE(id UUID, input_value TEXT, summary TEXT, interpretation TEXT)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT sg.id, sg.input_value, sg.summary, sg.interpretation
  FROM study_guides sg
  WHERE sg.language = p_language
    AND to_tsvector('simple', coalesce(sg.input_value, '') || ' ' || coalesce(sg.summary, ''))
        @@ plainto_tsquery('simple', p_query)
  ORDER BY ts_rank(
    to_tsvector('simple', coalesce(sg.input_value, '') || ' ' || coalesce(sg.summary, '')),
    plainto_tsquery('simple', p_query)) DESC
  LIMIT 1;
$$;

COMMIT;
```

- [ ] **Step 2: Apply and verify**

Run:
```bash
cd backend && supabase migration up --local 2>&1 | tail -3
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select indexname from pg_indexes where indexname='idx_study_guides_fts'; select count(*) from discipler_related_guide('prayer time', 'en');"
```
Expected: `idx_study_guides_fts` and `0` or `1` (no error).

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260906000004_study_guides_fts.sql
git commit -m "feat(db): full-text index and lookup for Discipler related guides"
```

---

### Task 5: Notification types

**Files:**
- Create: `backend/supabase/migrations/20260906000005_notification_types_discipler.sql`
- Modify: `backend/supabase/functions/_shared/services/notification-helper-service.ts:16-27`
- Modify: `backend/supabase/functions/_shared/services/notification-type-constraint.test.ts:20-30`

**Interfaces:**
- Produces: `NotificationType` includes `'fellowship_daily_post' | 'fellowship_discipler_reply' | 'fellowship_discipler_activity'`.

- [ ] **Step 1: Add the three types to `APPLICATION_TYPES` in the test and run it to see it fail**

Edit `notification-type-constraint.test.ts`: append the three strings to the `APPLICATION_TYPES` array.

Run: `cd backend/supabase/functions/_shared/services && deno test --allow-read notification-type-constraint.test.ts`
Expected: FAIL, "NotificationType union covers every type" lists the three new types as missing.

- [ ] **Step 2: Extend the union**

In `notification-helper-service.ts` replace the union with:
```ts
export type NotificationType =
  | 'daily_verse'
  | 'recommended_topic'
  | 'continue_learning'
  | 'streak_reminder'
  | 'streak_milestone'
  | 'streak_lost'
  | 'memory_verse_reminder'
  | 'memory_verse_overdue'
  | 'fellowship_daily_post'
  | 'fellowship_discipler_reply'
  | 'fellowship_discipler_activity'
```

- [ ] **Step 3: Write the migration re-listing every value**

```sql
-- =====================================================
-- Migration: notification_logs types for Discipler
-- Date: 2026-09-06
-- Keep in sync with NotificationType in notification-helper-service.ts.
-- =====================================================

BEGIN;

ALTER TABLE notification_logs
  DROP CONSTRAINT IF EXISTS notification_logs_notification_type_check;

ALTER TABLE notification_logs
  ADD CONSTRAINT notification_logs_notification_type_check
  CHECK (notification_type IN (
    'daily_verse',
    'recommended_topic',
    'continue_learning',
    'streak_reminder',
    'streak_milestone',
    'streak_lost',
    'memory_verse_reminder',
    'memory_verse_overdue',
    'achievement_unlocked',
    'fellowship_daily_post',
    'fellowship_discipler_reply',
    'fellowship_discipler_activity'
  ));

COMMIT;
```

- [ ] **Step 4: Run the test to verify it passes, apply migration**

Run: `deno test --allow-read notification-type-constraint.test.ts` → PASS (2 tests).
Run: `cd backend && supabase migration up --local 2>&1 | tail -2`.

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/migrations/20260906000005_notification_types_discipler.sql backend/supabase/functions/_shared/services/notification-helper-service.ts backend/supabase/functions/_shared/services/notification-type-constraint.test.ts
git commit -m "feat(notifications): add Discipler notification types"
```

---

### Task 6: Cron config rows and version bump

**Files:**
- Create: `backend/supabase/migrations/20260906000006_discipler_cron_config.sql`

**Interfaces:**
- Produces: `cron_config` rows `fellowship_daily_post`, `discipler_reply_worker`; `system_config.latest_app_version = '1.0.5'`.

- [ ] **Step 1: Write the migration**

```sql
-- =====================================================
-- Migration: cron rows for Discipler jobs (rs-backend) and 1.0.5 version
-- Date: 2026-09-06
-- =====================================================

BEGIN;

INSERT INTO cron_config (name, schedule, label, enabled) VALUES
  ('fellowship_daily_post', '0 0 1 * * *', 'Daily 06:30 IST — Discipler learning-path post', false),
  ('discipler_reply_worker', '0 * * * * *', 'Every minute — drain Discipler reply queue', false)
ON CONFLICT (name) DO NOTHING;

UPDATE system_config SET value = '1.0.5', updated_at = now() WHERE key = 'latest_app_version';

COMMIT;
```

Both rows start disabled; the rollout enables them from the admin cron page.

- [ ] **Step 2: Apply and verify**

Run:
```bash
cd backend && supabase migration up --local 2>&1 | tail -2
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select name, enabled from cron_config where name like '%discipler%' or name='fellowship_daily_post' order by 1; select value from system_config where key='latest_app_version';"
```
Expected: `discipler_reply_worker|f`, `fellowship_daily_post|f`, `1.0.5`.

- [ ] **Step 3: Full reset smoke test**

Run: `cd backend && supabase db reset 2>&1 | tail -3` then re-run the psql checks from Tasks 1–6.
Expected: all migrations apply cleanly from scratch, checks pass (the seeded test users from the session will be gone; re-seed with the commands in the index if needed).

- [ ] **Step 4: Commit**

```bash
git add backend/supabase/migrations/20260906000006_discipler_cron_config.sql
git commit -m "feat(db): register Discipler cron jobs and bump latest_app_version to 1.0.5"
```

---

## Self-Review Notes

- Spec §9 table rows all covered: `user_profiles` (T1), `fellowships`, `fellowship_members`, `fellowship_posts`, `fellowship_comments` (T2), four Discipler tables (T3), FTS (T4), `system_config` (T1, T6), `notification_logs` (T5), `cron_config` (T6).
- `discipler_daily_posts` gains `learning_path_topic_id` so the Rust cursor can exclude by `lpt.id` exactly like the blog query.
- Discipler membership rows dropped on purpose (index constraint), so no `fellowship_members` seed here.
