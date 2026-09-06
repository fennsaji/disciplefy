# Daily Post Follows Learning Path — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Every fellowship starts on the first learning path; Discipler's daily post is the group's current lesson, advancing it at a mentor-chosen frequency.

**Architecture:** One migration (two `fellowships` prefs, `default_learning_path_id()`, backfill of `fellowship_study`). Edge `fellowship` create + admin-web POST insert the default study row; PATCH accepts the two prefs. rs-backend cron reads `fellowship_study` instead of the global catalog, posts the current lesson, advances/switches path. Flutter settings exposes Frequency + Auto-advance.

**Tech Stack:** Supabase migrations (PG17), Deno Edge Functions, Rust (sqlx/axum), Flutter BLoC, Next.js.

**Spec:** `docs/superpowers/specs/2026-09-06-fellowship-discipler-addendum-learning-path.md` (amends `2026-09-06-fellowship-discipler-redesign-design.md`)

## Global Constraints

- No new Edge Functions. All API additions in `fellowship` (Edge) and rs-backend cron/admin routes.
- Never `supabase db push` / `--project-ref`. Local `supabase db reset` or `migration up` only.
- **Do not commit.** The controller commits once at the end.
- `daily_post_frequency_days` ∈ {1, 2, 7}, default 1. `daily_post_auto_advance` default true.
- Daily post language = `fellowships.language`; generation via `study-generate-v2` unchanged.
- One-line commit messages, no AI attribution (controller responsibility).

---

### Task 1: Migration + Edge `fellowship` + admin-web

**Files:**
- Create: `backend/supabase/migrations/20260906000008_fellowship_learning_path_defaults.sql`
- Modify: `backend/supabase/functions/fellowship/index.ts` (create ~:603-635, PATCH validation, list/settings payload)
- Modify: `admin-web/app/api/admin/fellowships/route.ts` (POST ~:126-137, GET select), `admin-web/app/(dashboard)/fellowships/page.tsx` (mentor-settings column)
- Test: `backend/supabase/functions/fellowship/__tests__/` (existing pattern) or SQL assertions run via psql

- [ ] Migration:
```sql
ALTER TABLE public.fellowships
  ADD COLUMN IF NOT EXISTS daily_post_frequency_days INTEGER NOT NULL DEFAULT 1
    CHECK (daily_post_frequency_days IN (1, 2, 7)),
  ADD COLUMN IF NOT EXISTS daily_post_auto_advance BOOLEAN NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.default_learning_path_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.learning_paths WHERE is_active = true ORDER BY display_order, created_at LIMIT 1
$$;
GRANT EXECUTE ON FUNCTION public.default_learning_path_id() TO service_role, authenticated;

INSERT INTO public.fellowship_study (fellowship_id, learning_path_id, current_guide_index)
SELECT f.id, public.default_learning_path_id(), 0
FROM public.fellowships f
LEFT JOIN public.fellowship_study fs ON fs.fellowship_id = f.id
WHERE fs.id IS NULL AND public.default_learning_path_id() IS NOT NULL
ON CONFLICT (fellowship_id) DO NOTHING;
```
  Match `fellowship_study` column names to the existing table definition (check migration that created it; include `started_at`/`completed_path_ids` defaults only if NOT NULL without default).
- [ ] Apply locally: `cd backend && supabase migration up` (or `db reset` if needed). Verify: `SELECT count(*) FROM fellowships f LEFT JOIN fellowship_study s ON s.fellowship_id=f.id WHERE s.id IS NULL` → 0.
- [ ] Edge `fellowship` POST: after member insert, `await supabase.rpc('default_learning_path_id')` then insert `fellowship_study` `{fellowship_id, learning_path_id, current_guide_index: 0}`; on error `console.error('[fellowship] default study insert failed', {fellowshipId})` and continue.
- [ ] Edge `fellowship` PATCH (mentor prefs branch): accept `daily_post_frequency_days` (validate 1|2|7 → 400 `VALIDATION_ERROR` otherwise) and `daily_post_auto_advance` (boolean). Include both in every select that returns the discipler prefs (list, detail, settings).
- [ ] admin-web POST: same default study insert after mentor insert (non-fatal). GET select adds the two columns; page mentor-settings column shows `Daily · every 2 days · weekly` and `auto-advance` chip.
- [ ] Run `cd backend && deno test` for fellowship tests if present; `cd admin-web && npx tsc --noEmit`.

### Task 2: rs-backend cron

**Files:**
- Modify: `rs-backend/src/models/fellowship_daily.rs`, `rs-backend/src/cron/fellowship_daily_post.rs`
- Test: unit tests in the same files

**Interfaces:** Consumes Task 1 columns. Produces nothing downstream.

- [ ] Replace `TOPIC_SELECT`/`find_next_topic_for_fellowship`/`reset_topic_cursor` with:
  - `load_study(fellowship_id) -> Option<FellowshipStudy {id, learning_path_id, current_guide_index, started_at, completed_path_ids: Vec<Uuid>}>` (active row: `completed_at IS NULL`; if row exists but completed, treat as needing switch).
  - `ensure_study(fellowship_id)` — inserts default path row when none (uses `default_learning_path_id()`).
  - `current_lesson(path_id, index) -> Option<Lesson {lpt_id, topic_id, title, description, category, position}>`: `learning_path_topics lpt JOIN recommended_topics rt ON rt.id=lpt.topic_id AND rt.is_active WHERE lpt.learning_path_id=$1 AND lpt.position >= $2 ORDER BY lpt.position LIMIT 1`.
  - `active_topic_count(path_id)`, `last_daily_post(fellowship_id) -> Option<(post_date, learning_path_topic_id)>`.
  - `advance_or_switch(study, fellowship_id) -> Advance { Advanced(new_index) | Switched{from_title, to_title} }`: mirrors `/advance` (`next >= total` → set `completed_at=now()`, append path to `completed_path_ids`, then pick next active path by `display_order` not in completed_path_ids, else first active path; update the same row with new path, index 0, `started_at=now()`, `completed_at=NULL`).
- [ ] Pure fns + tests: `should_post_today(last: Option<NaiveDate>, today: NaiveDate, freq: i32) -> bool` (None → true; else `(today - last).num_days() >= freq`); `next_index_or_complete(current: i32, total: i64) -> Option<i32>` (None when `current+1 >= total`).
- [ ] `post_for_fellowship`: read `daily_post_frequency_days`, `daily_post_auto_advance` from fellowship row; apply spec §4 order: frequency skip → already-posted check (advance if auto else skip) → post current lesson (unchanged format/notify) → insert `discipler_daily_posts` with `learning_path_topic_id`. On Switched write `discipler_activity` row `kind='daily_post'`, summary `Path completed: {from} → started {to}`.
- [ ] `cargo test`, `cargo clippy -- -D warnings` clean. Update `rs-backend/CLAUDE.md` cron description.

### Task 3: Flutter settings

**Files:**
- Modify: fellowship entity/model/datasource/repository (prefs fields), `fellowship_settings_bloc.dart` + screen, l10n (en/hi/ml) keys `dailyPostFrequency`, `frequencyDaily`, `frequencyEveryTwoDays`, `frequencyWeekly`, `disciplerAdvancesLessons`, `disciplerAdvancesLessonsSubtitle`.
- Test: existing `fellowship_settings_bloc_test.dart`, model tests.

- [ ] Entity + model: `dailyPostFrequencyDays` (int, default 1), `dailyPostAutoAdvance` (bool, default true); JSON keys snake_case; `copyWith`.
- [ ] Datasource `updateDisciplerPrefs` sends both keys.
- [ ] Settings screen under "Post a daily study": `SegmentedButton<int>` Daily / Every 2 days / Weekly, `SwitchListTile` "Discipler advances lessons" with subtitle "Moves the group to the next lesson after each post"; both disabled when daily post off.
- [ ] `flutter analyze` clean, `flutter test test/features/fellowship` green.
