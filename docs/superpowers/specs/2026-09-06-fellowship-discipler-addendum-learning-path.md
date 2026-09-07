# Addendum: Daily post follows the fellowship's learning path

**Date:** 2026-09-06 · **Status:** Approved by user ("default learning path should be the first one for all new groups"; daily post to follow the current lesson, mentor-controlled frequency and advance)
**Amends:** `2026-09-06-fellowship-discipler-redesign-design.md` §3 (Daily post) and §4 (mentor preferences)

## Decisions

1. **Every fellowship has a study path.** On creation (Edge `fellowship` POST and admin-web POST) a `fellowship_study` row is inserted for the first active learning path (`learning_paths.is_active` ordered by `display_order`, currently "New Believer Essentials"), `current_guide_index = 0`. A migration backfills existing fellowships that have no row. Helper `default_learning_path_id()` (SQL, STABLE) is the single source of that choice.
2. **Daily post = the group's current lesson.** The rs-backend cron no longer walks the global topic catalog. Per fellowship it reads the active `fellowship_study` row and posts the topic at `learning_path_topics.position = current_guide_index` (next higher position if that one is inactive). Language stays `fellowship.language`; generation still goes through `study-generate-v2` (cached per input + language).
3. **Mentor preferences (on `fellowships`, mentor-editable):**
   - `daily_post_frequency_days INTEGER NOT NULL DEFAULT 1 CHECK (IN (1, 2, 7))` — Daily / Every 2 days / Weekly.
   - `daily_post_auto_advance BOOLEAN NOT NULL DEFAULT true` — Discipler advances the group's lesson itself.
4. **Run rule per fellowship (allowed AND on AND active):**
   1. Skip when `today - last discipler_daily_posts.post_date < frequency_days`.
   2. If the current lesson was already posted for this study (`discipler_daily_posts.learning_path_topic_id` = current lesson's `lpt.id` and `post_date >= study.started_at`): if `auto_advance` → advance first (see 5); else skip quietly (the mentor advances manually, Discipler posts the new lesson the next eligible day).
   3. Post the current lesson (format unchanged), insert the cursor row, notify (unchanged).
5. **Advance** mirrors `fellowship-study /advance`: `next = current_guide_index + 1`; if `next >= count(active topics in path)` → `completed_at = now()`, `completed_path_ids += path`, then **switch** to the next active path by `display_order` not in `completed_path_ids` (upsert `fellowship_study` with `current_guide_index = 0`, `started_at = now()`, `completed_at = null`, history preserved). If every path is completed, start again from the first (history kept). Otherwise `current_guide_index = next`. A one-line activity row `kind = 'daily_post'` summary "Path completed: <title> → started <next title>" is written on a switch.
6. **Lessons tab stays truthful.** Because the advance happens before the post, the group's "Now" lesson equals the lesson Discipler posted most recently.
7. **Settings UI** (mentor, under "Post a daily study"): Frequency segmented control (Daily / Every 2 days / Weekly) and "Discipler advances lessons" switch; both disabled when daily post is off. Admin-web shows both in the mentor-settings column.
8. **Global-catalog cursor removed.** `find_next_topic_for_fellowship` / `reset_topic_cursor` and their wrap-around are deleted; `discipler_daily_posts` keeps `learning_path_topic_id` for the "already posted" check.

## Data changes

| Table | Change |
|---|---|
| `fellowships` | `daily_post_frequency_days`, `daily_post_auto_advance` |
| `fellowship_study` | backfill rows for fellowships without one (first active path) |
| function | `default_learning_path_id() RETURNS UUID` |

## API changes (no new Edge Functions)

- `fellowship` POST: inserts the default `fellowship_study` row (non-fatal on failure, logged).
- `fellowship` PATCH: accepts `daily_post_frequency_days` (1|2|7) and `daily_post_auto_advance` (mentor); list/settings payloads include both.
- admin-web `POST /api/admin/fellowships`: inserts the default study row; GET exposes the two prefs.

## Tests

- SQL: backfill leaves no fellowship without a study row; `default_learning_path_id()` returns the lowest active `display_order`.
- Rust unit: pure `should_post_today(last_post_date, today, frequency_days)`, `next_index_or_complete(current, total)`; cron dry run: post → index advanced on the next eligible run → path completion switches to the next path.
- Flutter: settings bloc diff includes the two prefs; entity/model round-trip.
