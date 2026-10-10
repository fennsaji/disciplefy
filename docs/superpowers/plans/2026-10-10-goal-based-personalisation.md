# Goal-based personalisation (option A) — implementation plan

**Owner decision 2026-10-10.** The first-run goal is the only personalisation
question. One backend engine answers "what next" everywhere. The 6-step
questionnaire and its scoring go away; older apps keep working.

Source review: `.superpowers/sdd/personalization-review.md` (S1 + S2 + S3).

## Decisions

- **Goal storage: a small table `user_growth_goals`** (one row per user, guests
  too), not a column on `user_personalization`. Reasons: `merge_guest_progress`
  deletes the guest's `user_personalization` row when the account already has
  finished answers, so a column there would lose the goal; a separate table
  merges with its own small function (same pattern as `merge_guest_new_for_you`)
  without rewriting the 400-line merge; and the deprecated questionnaire table
  can be dropped later without touching the goal. RLS: own-row SELECT; writes
  through `set_my_growth_goal(p_goal)` (validates, stamps `source`).
- **Goal values** (server, snake_case): `new_to_faith`, `fresh_start`,
  `walk_with_god`, `hope_hard_times`, `read_gospel`, `understand_gospel`. The
  app maps them to `GrowthGoal` (its Hive cache keeps the enum name).
- **Goal → paths mapping: table `growth_goal_paths(goal, path_slug, position)`**
  seeded by the migration. FK to `learning_paths(slug)` with `ON DELETE
  CASCADE / ON UPDATE CASCADE`, so a retired or renamed path can never leave a
  stale slug behind. Editable from the Supabase dashboard (admin-web has no
  screen for it yet; not needed now). The engine caches it for 10 minutes.
  Every active path appears in at least one list; each list starts with the
  goal's first-run path.
- **One engine: `_shared/personalization/next-paths.ts`.** Pure
  `rankNextPaths()` + loader `loadNextPaths(client, { userId, isGuest })`.
  Order: unfinished enrolled paths (latest activity first) → goal list (skip
  finished and enrolled) → featured (default path first) → the rest of the
  catalogue by display order. Guests: guest-accessible paths only. Also
  returns `lastFinishedPathId` (the most recently active enrolled path when it
  is finished and nothing else is active) for the "What next?" card on Home.
  Language only localises titles in the callers.
- **Old answers → goal** (`growth_goal_from_answers`, SQL, one source for the
  migration back-fill and the old `save` endpoint):
  1. `faith_stage = new_believer` or challenge `starting_basics` → `new_to_faith`
  2. goals contain `apologetics`/`theology`, challenge `handling_doubts` or
     focus `intellectual_growth` → `understand_gospel`
  3. goals contain `foundational_faith` → `new_to_faith`
  4. any other answers → `walk_with_god`
  5. nothing answered → no goal (featured fallback)
- **Study mode / notification prefs** are no longer derived from answers (old
  `save` stops writing them). Study mode stays a Settings choice; fallback
  Standard (already the app rule).

## Backward compatibility

- `save-personalization` keeps `save` / `get` / `skip` and the response shape
  (`data` = the `user_personalization` row; `recommendation` kept, now null).
  `save` still stores the answers and also sets the goal from them.
- `learning-paths?action=recommended` / `recommended_paths` keep their shapes and
  reason values (`active` | `personalized` | `featured`; a goal pick reports
  `personalized`). `recommended_paths` gains `finished_path` (new apps only).
- `topics-for-you` keeps `topics`, `hasCompletedQuestionnaire` (true when the
  user has a goal or finished answers) and `suggestedLearningPath.reason`
  (`active` | `personalized` | `default`).
- `user_personalization` and all its columns stay; `scoring_results` is no
  longer written. Marked deprecated in column comments. Cleanup later.

## Tasks

1. **Migration** `20261010200000_goal_based_personalisation.sql` (idempotent):
   tables, RLS, grants, seed, `growth_goal_from_answers`, back-fill,
   `set_my_growth_goal`, `merge_guest_growth_goal`, deprecation comments.
   SQL check script `backend/supabase/tests/goal_personalisation_check.sql`
   (all active paths reachable, each list starts with its goal path, mapping
   cases, back-fill idempotent). Run with local psql.
2. **Engine** `next-paths.ts` + deno tests (ordering, finished/enrolled skipping,
   guest restriction, featured/catalogue fallback, last finished path, all
   catalogue reachable).
3. **learning-paths** `recommended` and `recommended_paths` on the engine; drop
   scoring. Deno test for the reason mapping.
4. **topic-selector / topics-for-you** on the engine; delete questionnaire topic
   scoring, legacy `faith_journey` branches and the dead `selectTopicForUser`.
5. **Notification selector**: rotate through the engine's list instead of
   `scoring_results`; push copy says "lesson", not "topic".
6. **topic-completion**: remove score recalculation.
7. **save-personalization** compat rewrite; **user-profile merge_guest** calls
   `merge_guest_growth_goal`. Delete `scoring-algorithm.ts` (+ test).
8. **Flutter goal repository** (`features/personalization` rebuilt): server
   read/write via `user_growth_goals` / `set_my_growth_goal`, Hive cache
   `app_settings['growth_goal']` (the `first_run_goal` key keeps its "came
   through the new first run" meaning), one-time sync that uploads a
   device-only first-run goal. First run saves the goal to the server too.
9. **Change my goal** page (Settings › More), single pick, current goal
   selected, saves to the server. Route `/settings/goal`.
10. **What next? card** (`study_topics/presentation/widgets/what_next_card.dart`):
    next 3 paths from `recommended_paths`; on Lesson complete for the last
    lesson; on Home when the active path is finished (`finished_path`) or the
    Today card shows a finished path. Guest with no guest path left → account
    sheet row. "Choose your first path" uses the same engine list.
11. **Remove**: questionnaire page/bloc/entity/widgets/route, Home prompt card,
    `LoadForYouTopics` chain and For You topic fetch, Topics
    `LoadPersonalizedPaths` and the unmounted `ForYouLearningPathsSection`,
    unused translation keys.
12. **Copy** en/hi/ml for new strings; fit tests at 320/360 and 1.3x.

## Verification

`flutter analyze`; `flutter test --concurrency=2` for touched feature dirs and
`test/core`; deno tests for touched functions; `sh scripts/check-quick.sh`;
`supabase migration up --local` + SQL check.
