# First Run and Guest Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Within about a minute, a new person can choose a language and a goal, read lesson 1 as a Quick Read, and then either sign up or carry on as a guest. Guest progress is stored on the server and moves into the account on sign-up.

**Architecture:**
- **Flags.** Two `feature_flags` rows, `new_first_run` and `guest_mode`, gate everything. They are read through a new `RolloutFlags` helper.
- **Guest identity.** Guests are Supabase anonymous users. The backend's user-context builder treats an anonymous JWT as an authenticated user with `isGuest: true`, so RLS and every `userId` check keep working. A new `requireFullAccount` option and an `ACCOUNT_REQUIRED` error close off fellowships, Discipler, payments and a second path.
- **Sign-up.** Sign-up links the identity on the same user id: Google and Apple through `linkIdentityWithIdToken` (`linkIdentity` on web), email through `updateUser`. If the identity already belongs to another account, the client signs in normally and calls `user-profile?action=merge_guest` with the guest JWT, which moves the progress across.
- **Screens.** The first run is two new screens (language and goal) in front of the shipped study guide and the Phase A `LessonCompletePage`.

**Tech Stack:** Flutter (BLoC, go_router, GetIt, supabase_flutter 2.9 / gotrue 2.27: `signInAnonymously`, `linkIdentityWithIdToken`, `linkIdentity`, `updateUser`), Deno Edge Functions, PostgreSQL.

**Spec:** `docs/ux/design-final/first-run.png`, `docs/ux/design-final/guest-mode.png`, audit §3 "Target first run", roadmap `docs/superpowers/plans/2026-10-06-new-user-experience-roadmap.md`. Supabase anonymous sign-ins and identity-linking docs: https://supabase.com/docs/guides/auth/auth-anonymous and https://supabase.com/docs/guides/auth/auth-identity-linking. Re-check both through the docs-explorer agent before Tasks 6–8, as `CLAUDE.md` requires.

## Global Constraints

Product decisions agreed with the owner (2026-10-06). Every task implicitly includes all of them.

- **First focus:** the daily verse plus one learning path. Everything else is secondary and disclosed progressively; no feature is ever gated by the disclosure system (every feature stays reachable from its tab).
- **First run:** Language (with "Log in" top-right and "Already have an account? Log in") → "What would you like to grow in?" (6 choices mapped to real paths, see table) → Lesson 1 in Quick Read (the shipped study guide screen + a small Quick/Full switch + one "Want the full study? Read the full guide →" line) → "Lesson 1 complete" with sign-up (Google / Apple / Email) or "Not now".
- **Goal → path map (slugs):** "I'm new to faith" → `new-believer-essentials`; "Understanding the Bible" → `understanding-the-bible`; "Knowing who I am in Christ" → `rooted-in-christ`; "Walking with God daily" → `growing-in-discipleship`; "Hope in hard times" → `theology-of-suffering`; "Reading a Gospel" → `gospel-of-mark`.
- **Guest mode:** "Not now" = Supabase anonymous auth; all progress is server-side under the anonymous user id; sign-up links the identity (same user id, nothing restarts). A guest can finish their whole first path. An account is required for a second path, Groups (fellowships) and Discipler; those show the "account needed" sheet with Google / Apple / Email and "Continue as guest".
- **Skip / Log in** on the first-run screens → the current login screen → Home. Home shows "Choose your first path" only when no goal was picked and no path is enrolled.
- **Welcome copy:** en "Grow in God's Word every day" / "A daily verse and a short lesson, in your language."; hi "हर दिन परमेश्वर के वचन में बढ़ें" / "आपकी भाषा में रोज़ एक वचन और छोटा पाठ।"; ml "ദിവസവും ദൈവവചനത്തിൽ വളരുക" / "നിങ്ങളുടെ ഭാഷയിൽ ദിവസവും ഒരു വചനവും ചെറിയ പാഠവും."
- **Lesson complete:** a full-screen "Lesson N complete" page (lesson title, "Lesson N of M", Up next list). The next-lesson row is tappable, and there are two buttons: primary "Continue to lesson N+1" and secondary "Back to Home". There is no one-lesson-per-day gate, and no "Tomorrow" lock or label: the next lesson is always available. On the last lesson, the primary button becomes "Back to Home" and the page shows "You finished <path>".
- **Lesson modes:** lesson 1 of the first-run path opens in Quick Read; lessons 2+ default to Standard. The mode is changed with the Quick/Standard chip on the Home lesson card (saved to `user_preferences.learning_path_study_mode`).
- **Home:** shipped header (logo, Memory Verses pill — no badge until the user has saved verses and some are due; badge colour gold, not red — settings icon) + verse hero with "Reflect on this verse →" link + copy/share/save icons + path section (path short title + "See path", progress strip: ≤10 lessons = dots, 11–20 = segmented bar, >20 = smooth bar with milestone ticks; the only label is "Today", no dates) + today's lesson card ("TODAY · LESSON N", Quick/Standard chip, title, single primary "Start lesson N"). No "Next:" line. Guest: a quiet "Save progress to your account" row.
- **New for you:** one photo-banner card on Home, at most one new banner per 7 days, dismissible (dismissal persists, never returns), never gates access. Banners, in order: Browse more learning paths, Memory verses, Generate ("Study any verse or topic"), Discipler, Fellowships (public "Disciplefy" / "Disciplefy हिन्दी" / "Disciplefy മലയാളം" by app language). Each opens a one-screen feature intro (3 steps, a real example, one primary + one secondary action). No designer-note text in UI.
- **Bottom dock unchanged:** Home, Generate, Discipler (centre), Topics, Community.
- **Generate:** one input that auto-detects verse / topic / question (no type tabs), ≤3 suggestion chips, a verse-of-the-day ready-start row, Quick Read / Standard switch + "All 5" depth sheet using the shipped mode names (Quick Read, Standard Study, Deep Dive, Lectio Divina, Sermon Outline), "Generate study" inline with "Using N credits" under it, "Continue reading" lists only the user's own studies (never path lessons), and generating opens the streaming guide directly.
- **Topics:** current path card + real categories each with "See all" + "Browse all paths" at the bottom → All paths screen with category chips (current path pinned with a "Current" tag).
- **Words:** one noun "lesson" for path items (never "topic" in path UI), one currency "credits" (never "tokens" / "Study Tokens" in UI copy). XP, levels, "Seeker", leaderboard and "Champions" are removed from new-user surfaces (path cards, lesson lists, intros, Home); they live only inside My progress / the opt-in Leaderboard.
- **Memory verses:** keep the shipped flow (verse list → tap verse → choose practice mode → practice). Changes only: empty state primary "Save today's verse"; neutral "Due" tags instead of red "x days overdue" (and no Easy/Medium/Hard or "Ease" on the main list); the stats row collapsed to one line ("1-day streak · 5 verses"); Statistics and Champions moved off the main screen into the ⋮ menu. No "Practise now" auto-pick and no "Change mode" button (auto-pick by mastery is out of scope).
- **My Plan:** one honest summary card; fix: Standard showing Free features, verse limit vs saved count, Discipler "Not included" while it works, "App Store" on web.
- **Visual:** compact buttons 40px (primary) / 32px (chips, small secondary); gold (`AppColors.brandGold` / `context.appBrandAccent`) — not indigo — for selected/primary in light theme; all text ≥12pt (`fontSize >= 12`); no "AI" wording in user copy (Discipler is "Discipler"); no design codenames (V2/K2/S3/…) in any new file, class, key or comment name.
- **i18n:** every new string gets a key in `frontend/lib/core/i18n/translation_keys.dart` and values in `translations_en.dart`, `translations_hi.dart`, `translations_ml.dart`. Hindi/Malayalam must be SHORT: convey the meaning, not a literal translation. UI labels (dock, buttons, chips, headers, card labels, links) ≤ ~1.3× the English character width; prefer common short words; drop filler words.
- **Analytics:** activation = read today's verse AND finished lesson 1 on day 1; also D1/D7 retention, time to first lesson, New-for-you impressions/taps.
- **Rollout:** the new first run, guest mode, new Home and new Generate ship dark behind `feature_flags` rows (`new_first_run`, `guest_mode`, `home_today_layout`, `generate_single_input`), read through `SystemConfigService.isFeatureEnabled(key, plan)`; default `is_enabled=false` in the migration.
- **Project rules:** BLoC + GetIt (`sl<T>()`), clean architecture (presentation → domain ← data), package imports only (`package:disciplefy_bible_study/...`), `Logger` never `print`, tests for every task (`flutter test`, `deno test`), migrations idempotent (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`, `CREATE OR REPLACE`) and applied by CI on deploy — locally use `cd backend && supabase migration up`; NEVER `supabase db reset`, NEVER `db push` / `--project-ref` / touching production.
- **Git:** never commit without the owner's explicit approval; work on `dev`; one-line `type(scope): description` messages; never add a `Co-Authored-By` trailer or any AI attribution.

Phase-specific:
- Depends on Phase A: `LessonRef`, `buildLessonLaunchLocation`, `LessonCompleteArgs`, `LessonCompletePage(extraSections:)`, `resolveNextLessonMode()`.
- Guest plan is `free`. Path lessons are free in Quick Read and in the path's recommended mode (Task 4). Custom Generate stays credit-metered.
- With `new_first_run` off, the app behaves exactly as today: slides, then login, then language.
- With `guest_mode` off, "Not now" and the guest entry are hidden. The first run then ends at "Lesson 1 complete" with sign-up only, and the person must sign in before lesson 1. The flow is Language → Goal → login screen → lesson 1.

## Review Focus

- **Sign-up from a guest with a Google or Apple identity that already has an account.** The user ends up signed into the existing account, the guest's lesson progress is merged, and they land on Home. They never see a raw `identity_already_exists` error.
- **A guest taps a tab that needs an account (Discipler centre button, Community "Join").** They get the account-needed sheet. "Continue as guest" closes it and leaves them on the previous tab, not on a blank screen.
- **A guest kills the app mid-lesson and reopens it.** The anonymous session persists, so they land on Home (or resume), not on the welcome screen. Losing the session must not lose the server progress silently: if the refresh token is gone, start a new first run.
- **An existing signed-in user with `new_first_run` on.** They never see `/welcome`. Deep links still work.
- **Email sign-up from a guest while confirmation is pending.** The guest session and progress stay usable until the email is confirmed, and the UI says "Check your email" with the address.

Tests for these are in Tasks 2, 7, 8, 9 and 10.

---

## File Structure

| File | Responsibility |
|---|---|
| `backend/supabase/migrations/20261006110000_rollout_flags_first_run.sql` | Flag rows `new_first_run`, `guest_mode`, `home_today_layout`, `generate_single_input` |
| `backend/supabase/config.toml:152` | `enable_manual_linking = true` (local only) |
| `backend/supabase/functions/_shared/auth/user-context.ts` (new) | Pure `toUserContext(identity)`, `isGuest`, `assertFullAccount` |
| `backend/supabase/functions/_shared/types/index.ts:17-23` | `UserContext.isGuest?: boolean` |
| `backend/supabase/functions/_shared/core/function-factory.ts:63-100, 610-620` | Use `toUserContext`; `requireFullAccount` option |
| `backend/supabase/functions/_shared/services/auth-service.ts:197-215` | Use `toUserContext` |
| `backend/supabase/functions/_shared/utils/lesson-pricing.ts` (new) | `isFreeCatalogueLesson` |
| `backend/supabase/functions/learning-paths/index.ts:913+` | Enrol by `slug`; guests are limited to one path |
| `backend/supabase/functions/user-profile/index.ts` | `action=merge_guest` |
| `backend/supabase/migrations/20261006110100_merge_guest_progress.sql` | `merge_guest_progress(p_guest, p_user)` |
| `frontend/lib/core/services/rollout_flags.dart` (new) | Flag getters |
| `frontend/lib/features/auth/data/services/guest_session_service.dart` (new) | Anonymous sign-in, linking, merge fallback |
| `frontend/lib/features/auth/presentation/widgets/account_needed_sheet.dart` (new) | "Groups need an account" sheet + `requireAccount()` guard |
| `frontend/lib/features/onboarding/presentation/pages/first_run_language_page.dart` (new) | Screen 1 |
| `frontend/lib/features/onboarding/presentation/pages/growth_goal_page.dart` (new) | Screen 2 |
| `frontend/lib/features/onboarding/domain/growth_goals.dart` (new) | Goal → slug map |
| `frontend/lib/features/onboarding/presentation/bloc/first_run_cubit.dart` (new) | Start-lesson-1 orchestration |
| `frontend/lib/features/study_generation/presentation/widgets/lesson_mode_switch.dart` (new) | Quick/Full switch |
| `frontend/lib/features/auth/presentation/widgets/save_progress_block.dart` (new) | Sign-up block on Lesson complete |
| `frontend/lib/core/router/router_guard.dart`, `app_router.dart`, `app_routes.dart` | `/welcome`, `/welcome/goal`; guest = authenticated |

---

### Task 1: Rollout flags (migration + `RolloutFlags`)

**Files:**
- Create: `backend/supabase/migrations/20261006110000_rollout_flags_first_run.sql`
- Create: `frontend/lib/core/services/rollout_flags.dart`
- Modify: `frontend/lib/core/di/injection_container.dart` (near the `SystemConfigService` registration, ~L282): `sl.registerLazySingleton(() => RolloutFlags(sl()))`
- Test: `frontend/test/core/services/rollout_flags_test.dart`

**Interfaces:**
- Produces: `class RolloutFlags { RolloutFlags(SystemConfigService config); bool get newFirstRun; bool get guestMode; bool get homeTodayLayout; bool get generateSingleInput; }`. Each getter calls `config.isFeatureEnabled(key, 'free')` and returns false when the key is missing.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';

class _Config extends Mock implements SystemConfigService {}

void main() {
  test('flags read the free plan and default off', () {
    final c = _Config();
    when(() => c.isFeatureEnabled(any(), any())).thenReturn(false);
    when(() => c.isFeatureEnabled('guest_mode', 'free')).thenReturn(true);
    final f = RolloutFlags(c);
    expect(f.guestMode, isTrue);
    expect(f.newFirstRun, isFalse);
    expect(f.homeTodayLayout, isFalse);
    expect(f.generateSingleInput, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/core/services/rollout_flags_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement**

```dart
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';

/// Dark-launch switches for the new-user redesign (admin-web → Feature flags).
class RolloutFlags {
  final SystemConfigService _config;
  RolloutFlags(this._config);

  static const newFirstRunKey = 'new_first_run';
  static const guestModeKey = 'guest_mode';
  static const homeTodayLayoutKey = 'home_today_layout';
  static const generateSingleInputKey = 'generate_single_input';

  bool _on(String key) => _config.isFeatureEnabled(key, 'free');
  bool get newFirstRun => _on(newFirstRunKey);
  bool get guestMode => _on(guestModeKey);
  bool get homeTodayLayout => _on(homeTodayLayoutKey);
  bool get generateSingleInput => _on(generateSingleInputKey);
}
```

```sql
INSERT INTO public.feature_flags
  (feature_key, feature_name, description, is_enabled, display_mode, enabled_for_plans, rollout_percentage, metadata)
VALUES
  ('new_first_run', 'New first run', 'Language → goal → lesson 1 → sign up / guest.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb),
  ('guest_mode', 'Guest mode', 'Anonymous users can finish their first path before signing up.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb),
  ('home_today_layout', 'Home today layout', 'Verse + path strip + today''s lesson + New for you.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb),
  ('generate_single_input', 'Generate single input', 'One auto-detecting input on Generate.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb)
ON CONFLICT (feature_key) DO NOTHING;
```

Check that `system-config` returns flags to anonymous and signed-out callers. `SystemConfigService.initialize` runs before login, so if `system-config` filters by plan, the `'free'` plan must be included as above.

- [ ] **Step 4: Run and verify**

Run: `cd backend && supabase migration up`, then `cd frontend && flutter test test/core/services/rollout_flags_test.dart`.
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(rollout): flags for first run, guest mode, Home and Generate"
```

---

### Task 2: Backend guest identity and `requireFullAccount`

**Files:**
- Create: `backend/supabase/functions/_shared/auth/user-context.ts`
- Modify: `backend/supabase/functions/_shared/types/index.ts:17-23`, `_shared/repositories/study-guide-repository.ts:46-50` (add `isGuest?`), `_shared/core/function-factory.ts` (config + L614-619 + the post-auth check), `_shared/services/auth-service.ts:197-215`, `_shared/utils/error-handler.ts` (add an `ACCOUNT_REQUIRED` 403 code)
- Modify (add `requireFullAccount: true` to the factory config, or call `assertFullAccount(userContext)` at the top of the handler for `createSimpleFunction` users):
  - `fellowship`, `fellowship-blocks`, `fellowship-comments`, `fellowship-invites`, `fellowship-meetings`, `fellowship-members`, `fellowship-posts`, `fellowship-study`
  - `voice-conversation`, `conversation-history`
  - `create-subscription`, `create-subscription-v2`, `create-standard-subscription`, `create-plus-subscription`, `purchase-tokens`, `confirm-token-purchase`, `confirm-apple-purchase`, `cancel-subscription`, `resume-subscription`, `start-premium-trial`, `validate-promo-code`
  - `upload-profile-image`
- Test: `backend/supabase/functions/_shared/auth/user-context.test.ts`

**Interfaces:**
- Produces:
  - `toUserContext(identity: VerifiedIdentity): UserContext`. For an anonymous identity it returns `{type:'authenticated', userId: identity.id, isGuest: true}`. For a full identity it returns `{type:'authenticated', userId, email, isGuest:false}`.
  - `assertFullAccount(ctx?: UserContext): void` throws `AppError('ACCOUNT_REQUIRED', 'Create an account to use this.', 403)`.
  - `FunctionConfig.requireFullAccount?: boolean`.
  - The legacy `x-session-id` guest path (`allowGuestOnJwtFailure`) is unchanged: still `type:'anonymous'`.

- [ ] **Step 1: Write the failing test**

```ts
// Run with: deno test _shared/auth/user-context.test.ts
import { assertEquals, assertThrows } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { toUserContext, assertFullAccount } from './user-context.ts'

Deno.test('anonymous Supabase user becomes an authenticated guest with a userId', () => {
  const ctx = toUserContext({ id: 'u1', email: undefined, isAnonymous: true } as never)
  assertEquals(ctx, { type: 'authenticated', userId: 'u1', isGuest: true, email: undefined })
})

Deno.test('full user is not a guest', () => {
  const ctx = toUserContext({ id: 'u2', email: 'a@b.c', isAnonymous: false } as never)
  assertEquals(ctx.isGuest, false)
  assertEquals(ctx.userId, 'u2')
})

Deno.test('assertFullAccount rejects guests with ACCOUNT_REQUIRED', () => {
  const err = assertThrows(() => assertFullAccount({ type: 'authenticated', userId: 'u1', isGuest: true }))
  assertEquals((err as { code?: string }).code, 'ACCOUNT_REQUIRED')
  assertFullAccount({ type: 'authenticated', userId: 'u2', isGuest: false }) // no throw
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend/supabase/functions && deno test _shared/auth/user-context.test.ts`
Expected: FAIL (module not found).

- [ ] **Step 3: Implement**

```ts
import type { UserContext } from '../types/index.ts'
import type { VerifiedIdentity } from './jwt-verifier.ts'
import { AppError } from '../utils/error-handler.ts'

/** A Supabase anonymous user is a real auth.users row: treat it as authenticated, flagged as a guest. */
export function toUserContext(identity: VerifiedIdentity): UserContext {
  return {
    type: 'authenticated',
    userId: identity.id,
    isGuest: identity.isAnonymous,
    email: identity.isAnonymous ? undefined : identity.email,
  }
}

export function assertFullAccount(ctx?: UserContext): void {
  if (!ctx || ctx.type !== 'authenticated' || ctx.isGuest) {
    throw new AppError('ACCOUNT_REQUIRED', 'Create an account to use this.', 403)
  }
}
```

Wiring:
- Match `AppError`'s real constructor signature in `error-handler.ts`, and register `ACCOUNT_REQUIRED` in its code → status map.
- In `function-factory.ts` L614-619, replace the inline object with `return { ...toUserContext(identity) }`.
- After `parseUserContext`, add `if (finalConfig.requireFullAccount) assertFullAccount(userContext)`.
- Add `requireFullAccount: false` to `DEFAULT_CONFIG`.
- In `auth-service.ts:197-215`, build the same shape: `type:'authenticated'`, `userId: user.id`, `isGuest: user.is_anonymous`. Still skip the profile/admin lookup for guests.

Contract check: run `grep -rn "type === 'anonymous'\|type !== 'authenticated'" backend/supabase/functions --include=*.ts` and review every hit:
- Hits in the account-required functions listed above are covered by `requireFullAccount`.
- Hits in guest-allowed functions (daily-verse, learning-paths, topic-progress, study-generate-v2, study-guides, mark-study-guide-complete, token-status, memory verse functions, user-profile, system-config) now pass for guests because guests have `type:'authenticated'`.
- Record the reviewed list as a comment block at the top of `user-context.ts`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend/supabase/functions && deno test _shared/auth/user-context.test.ts && deno check fellowship/index.ts voice-conversation/index.ts study-generate-v2/index.ts`
Expected: PASS, and type-check OK.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(auth): treat anonymous users as guests and close account-only functions"
```

---

### Task 3: Enrol by slug; a guest gets one path

**Files:**
- Modify: `backend/supabase/functions/learning-paths/index.ts` `handleEnroll` (L913+). Accept `{pathId?, slug?}`; resolve the slug via `learning_paths.slug` with `is_active`. Guest rule.
- Create: `backend/supabase/functions/learning-paths/guest-rules.ts`
- Modify: `frontend/lib/features/study_topics/data/datasources/learning_paths_remote_datasource.dart:360` (`enrollInPath({String? pathId, String? slug})`), the repository interface and impl (`enrollInPathBySlug(String slug)` → `Either<Failure, EnrollmentResult>`)
- Test: `backend/supabase/functions/learning-paths/guest-rules.test.ts`

**Interfaces:**
- Produces:
  - `canGuestEnroll(enrolledPathIds: string[], pathId: string): boolean`. Returns true when the path is already enrolled, or when no other path is enrolled.
  - Error `ACCOUNT_REQUIRED` with `details.reason = 'second_path'`.
  - `EnrollmentResult.learningPathId` is returned for slug enrolment.
  - Dart: `LearningPathsRepository.enrollInPathBySlug(String slug)`.

- [ ] **Step 1: Write the failing test**

```ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { canGuestEnroll } from './guest-rules.ts'
Deno.test('guest can enrol the first path and re-enrol it, not a second', () => {
  assertEquals(canGuestEnroll([], 'p1'), true)
  assertEquals(canGuestEnroll(['p1'], 'p1'), true)
  assertEquals(canGuestEnroll(['p1'], 'p2'), false)
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend/supabase/functions && deno test learning-paths/guest-rules.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement**

```ts
export function canGuestEnroll(enrolledPathIds: string[], pathId: string): boolean {
  return enrolledPathIds.length === 0 || enrolledPathIds.includes(pathId)
}
```

In `handleEnroll`:
- Resolve `pathId` from `slug` when given.
- If `userContext.isGuest`, load `user_learning_path_progress.learning_path_id` for the user. When `!canGuestEnroll`, throw `AppError('ACCOUNT_REQUIRED', 'Create an account to start another path.', 403, { reason: 'second_path' })`.
- Then call the existing RPC.

Dart:
- Map an HTTP 403 with `error.code == 'ACCOUNT_REQUIRED'` to a new `AccountRequiredFailure extends Failure` (`frontend/lib/core/error/failures.dart`) carrying `reason`.
- In the datasource, send `{'slug': slug}` when a slug is given.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend/supabase/functions && deno test learning-paths/` and `cd frontend && flutter test test/features/study_topics`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(paths): enrol by slug and limit guests to one path"
```

---

### Task 4: Path lessons are free in Quick Read

**Files:**
- Create: `backend/supabase/functions/_shared/utils/lesson-pricing.ts`
- Modify: `backend/supabase/functions/study-generate-v2/index.ts:625-627, 691-701`
- Test: `backend/supabase/functions/_shared/utils/lesson-pricing.test.ts`

**Interfaces:**
- Produces: `isFreeCatalogueLesson(recommendedMode: string | null, studyMode: string): boolean`. It returns true when `recommendedMode !== null` (the topic is in a path) and (`studyMode === 'quick'` or `studyMode === recommendedMode`).

- [ ] **Step 1: Write the failing test**

```ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { isFreeCatalogueLesson } from './lesson-pricing.ts'
Deno.test('path lessons are free in quick and in the recommended mode', () => {
  assertEquals(isFreeCatalogueLesson('standard', 'quick'), true)
  assertEquals(isFreeCatalogueLesson('standard', 'standard'), true)
  assertEquals(isFreeCatalogueLesson('standard', 'deep'), false)
  assertEquals(isFreeCatalogueLesson(null, 'quick'), false)
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend/supabase/functions && deno test _shared/utils/lesson-pricing.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement**

The helper is a one-liner. In `study-generate-v2`, fetch `getLearningPathRecommendedMode` once into `const lpMode`. Then set `const isCataloguePath = isFreeCatalogueLesson(lpMode, study_mode)` and `isFreeGeneration = isCataloguePath`. This replaces both duplicated lookups at L625 and L691.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend/supabase/functions && deno test _shared/utils/lesson-pricing.test.ts && deno check study-generate-v2/index.ts`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(study): path lessons are free in Quick Read"
```

---

### Task 5: Guest progress merge (SQL + `user-profile?action=merge_guest`)

**Files:**
- Create: `backend/supabase/migrations/20261006110100_merge_guest_progress.sql`
- Modify: `backend/supabase/functions/user-profile/index.ts` (new action)
- Test: SQL check below; `backend/supabase/functions/user-profile/merge-guest.test.ts` (pure validation)

**Interfaces:**
- Produces:
  - RPC `public.merge_guest_progress(p_guest uuid, p_user uuid) RETURNS jsonb`. It returns `{"topics":n,"paths":n,"guides":n,"verses":n}`. SECURITY DEFINER, EXECUTE granted to `service_role` only.
  - `POST /functions/v1/user-profile?action=merge_guest` with header `x-guest-token: <guest access JWT>`, called by a full (non-guest) user. The function verifies the guest JWT with the shared jwt-verifier, requires `isAnonymous === true` and `id !== caller`, then calls the RPC with the service client.
  - Pure `validateMergeRequest(callerId: string, guest: {id:string,isAnonymous:boolean}|null): string | null` (an error code or null).

- [ ] **Step 1: Write the failing test**

```ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { validateMergeRequest } from './merge-guest.ts'
Deno.test('merge requires a different, anonymous guest', () => {
  assertEquals(validateMergeRequest('u', null), 'GUEST_TOKEN_INVALID')
  assertEquals(validateMergeRequest('u', { id: 'g', isAnonymous: false }), 'GUEST_TOKEN_INVALID')
  assertEquals(validateMergeRequest('u', { id: 'u', isAnonymous: true }), 'GUEST_TOKEN_INVALID')
  assertEquals(validateMergeRequest('u', { id: 'g', isAnonymous: true }), null)
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend/supabase/functions && deno test user-profile/merge-guest.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement**

```sql
CREATE OR REPLACE FUNCTION public.merge_guest_progress(p_guest uuid, p_user uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE t int; p int; g int; v int;
BEGIN
  IF p_guest = p_user THEN RETURN '{}'::jsonb; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_guest AND is_anonymous) THEN
    RAISE EXCEPTION 'not a guest';
  END IF;

  INSERT INTO user_topic_progress (user_id, topic_id, started_at, completed_at, time_spent_seconds, xp_earned)
  SELECT p_user, topic_id, started_at, completed_at, time_spent_seconds, xp_earned
  FROM user_topic_progress WHERE user_id = p_guest
  ON CONFLICT (user_id, topic_id) DO UPDATE SET
    completed_at = COALESCE(user_topic_progress.completed_at, EXCLUDED.completed_at),
    time_spent_seconds = GREATEST(user_topic_progress.time_spent_seconds, EXCLUDED.time_spent_seconds);
  GET DIAGNOSTICS t = ROW_COUNT;

  INSERT INTO user_learning_path_progress (user_id, learning_path_id, enrolled_at, topics_completed, current_topic_position, total_xp_earned, completed_at, last_activity_at)
  SELECT p_user, learning_path_id, enrolled_at, topics_completed, current_topic_position, total_xp_earned, completed_at, last_activity_at
  FROM user_learning_path_progress WHERE user_id = p_guest
  ON CONFLICT (user_id, learning_path_id) DO UPDATE SET
    topics_completed = GREATEST(user_learning_path_progress.topics_completed, EXCLUDED.topics_completed),
    current_topic_position = GREATEST(user_learning_path_progress.current_topic_position, EXCLUDED.current_topic_position);
  GET DIAGNOSTICS p = ROW_COUNT;

  UPDATE user_study_guides SET user_id = p_user
  WHERE user_id = p_guest
    AND study_guide_id NOT IN (SELECT study_guide_id FROM user_study_guides WHERE user_id = p_user);
  GET DIAGNOSTICS g = ROW_COUNT;

  UPDATE memory_verses SET user_id = p_user WHERE user_id = p_guest;
  GET DIAGNOSTICS v = ROW_COUNT;

  UPDATE daily_verse_streaks u SET
    current_streak = GREATEST(u.current_streak, s.current_streak),
    longest_streak = GREATEST(u.longest_streak, s.longest_streak)
  FROM daily_verse_streaks s WHERE s.user_id = p_guest AND u.user_id = p_user;

  RETURN jsonb_build_object('topics', t, 'paths', p, 'guides', g, 'verses', v);
END $$;
REVOKE ALL ON FUNCTION public.merge_guest_progress(uuid, uuid) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.merge_guest_progress(uuid, uuid) TO service_role;
```

Before applying, confirm each column name against the table definitions:
- `user_topic_progress` and `user_learning_path_progress`: `20260119001000_learning_paths.sql:34,172`
- `user_study_guides`: `20260119000100_study_guides.sql`
- `memory_verses`: its create migration

If `memory_verses` has a unique `(user_id, verse_reference, language)` key, use `UPDATE … WHERE NOT EXISTS (same key for p_user)`.

The `user-profile` handler:
1. Reads `x-guest-token`.
2. Verifies it with `createJwtVerifier().verify(token)` (same verifier the factory uses).
3. Runs `validateMergeRequest`.
4. Calls `services.supabaseServiceClient.rpc('merge_guest_progress', { p_guest, p_user })`.
5. Returns the counts.

Logs contain counts only, never tokens.

SQL check (local):

```sql
-- create a guest with progress via supabase auth admin or reuse a test anonymous user, then:
SELECT public.merge_guest_progress('<guest-id>', '<user-id>');
SELECT count(*) FROM user_topic_progress WHERE user_id = '<user-id>';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && supabase migration up && cd supabase/functions && deno test user-profile/merge-guest.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(auth): merge guest progress into an existing account"
```

---

### Task 6: `GuestSessionService` — start guest, link, merge fallback

**Files:**
- Modify: `backend/supabase/config.toml:152` → `enable_manual_linking = true`
- Create: `frontend/lib/features/auth/data/services/guest_session_service.dart`
- Modify: `frontend/lib/core/di/injection_container.dart` (register a LazySingleton)
- Modify: `frontend/lib/features/auth/data/services/oauth_service.dart` (expose `Future<({String idToken, String? accessToken, String? nonce})> obtainGoogleIdToken()` and `obtainAppleIdToken()`, split out of `_signInWithGoogleMobile` L38 and `signInWithApple` L287 without changing current behaviour)
- Test: `frontend/test/features/auth/data/guest_session_service_test.dart`

**Interfaces:**
- Produces:
  - `class GuestSessionService { bool get isGuest; bool get hasSession; /* currentSession != null */ Future<void> startGuest(); Future<LinkOutcome> linkGoogle(); Future<LinkOutcome> linkApple(); Future<LinkOutcome> linkEmail({required String email, required String password, required String fullName}); }`
  - `enum LinkOutcome { linked, mergedIntoExisting, emailConfirmationSent, cancelled }`
  - Linking a guest with Google/Apple calls `auth.linkIdentityWithIdToken(provider:, idToken:, accessToken:, nonce:)` on mobile and `auth.linkIdentity(OAuthProvider.google, redirectTo: …)` on web.
  - When the error message or code contains `identity_already_exists` / `already linked`:
    1. Keep `final guestJwt = auth.currentSession!.accessToken`.
    2. Sign in with the same id token: `signInWithIdToken`.
    3. Call `functions.invoke('user-profile?action=merge_guest', headers: {'x-guest-token': guestJwt})`.
    4. Return `mergedIntoExisting`.
  - Email: `auth.updateUser(UserAttributes(email: email, data: {'full_name': fullName}))`, then `auth.updateUser(UserAttributes(password: password))` after confirmation. Return `emailConfirmationSent` when `user.emailConfirmedAt == null`.

- [ ] **Step 1: Write the failing test** (mock `GoTrueClient` with mocktail)

```dart
test('startGuest signs in anonymously once', () async {
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.signInAnonymously()).thenAnswer((_) async => AuthResponse(session: fakeSession(anon: true)));
  await service.startGuest();
  verify(() => auth.signInAnonymously()).called(1);
});

test('startGuest is a no-op when a session exists', () async {
  when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
  await service.startGuest();
  verifyNever(() => auth.signInAnonymously());
});

test('Google link conflict falls back to sign-in + merge', () async {
  when(() => auth.currentUser).thenReturn(fakeUser(anon: true));
  when(() => auth.currentSession).thenReturn(fakeSession(anon: true, token: 'guest.jwt'));
  when(() => oauth.obtainGoogleIdToken()).thenAnswer((_) async => (idToken: 'id', accessToken: 'at', nonce: null));
  when(() => auth.linkIdentityWithIdToken(provider: OAuthProvider.google, idToken: 'id', accessToken: 'at', nonce: null))
      .thenThrow(const AuthException('Identity is already linked to another user', code: 'identity_already_exists'));
  when(() => auth.signInWithIdToken(provider: OAuthProvider.google, idToken: 'id', accessToken: 'at', nonce: null))
      .thenAnswer((_) async => AuthResponse(session: fakeSession(anon: false)));
  when(() => functions.invoke('user-profile?action=merge_guest', headers: {'x-guest-token': 'guest.jwt'}))
      .thenAnswer((_) async => FunctionResponse(data: {'topics': 1}, status: 200));
  expect(await service.linkGoogle(), LinkOutcome.mergedIntoExisting);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/auth/data/guest_session_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** `GuestSessionService(this._auth, this._functions, this._oauth)`.
  - `isGuest => _auth.currentUser?.isAnonymous ?? false`.
  - For web Google: `linkIdentity` redirects. After the OAuth callback, `AuthChangeEvent.userUpdated` fires; the AuthBloc listener refreshes the profile. Conflicts on web come back on the callback URL as `error_code=identity_already_exists`. Handle them in the existing `GoogleOAuthCallbackRequested` path: sign in normally, then merge with the guest token stashed in Hive `app_settings['pending_guest_token']` before the redirect.
  - Use `Logger` for every branch. Never log tokens.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/auth`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(auth): guest sessions with identity linking and merge fallback"
```

---

### Task 7: The router treats a guest as signed in; `/welcome` routes behind `new_first_run`

**Files:**
- Modify: `frontend/lib/core/router/app_routes.dart` (`welcome = '/welcome'`, `welcomeGoal = '/welcome/goal'`)
- Modify: `frontend/lib/core/router/router_guard.dart`:
  - `_isPublicRoute` (L533) and the onboarding-route analysis: include `/welcome*`.
  - `_determineUnauthenticatedRedirect` (L854-897): replace `AppRoutes.onboarding` with `_firstRunEntry()`.
  - `_handleFullyAuthenticatedUser` (L961): a guest on `/welcome*` → home.
- Modify: `app_router.dart` (two `GoRoute`s near L148-166)
- Test: `frontend/test/core/router/router_guard_first_run_test.dart` (use the `debug*Redirect` hooks at `router_guard.dart:782-798`, as in `router_guard_terms_gate_test.dart`)

**Interfaces:**
- Produces:
  - `static String _firstRunEntry()` returns `sl<RolloutFlags>().newFirstRun ? AppRoutes.welcome : AppRoutes.onboarding`.
  - The `/welcome` routes are reachable while unauthenticated and skip the terms gate. Terms are accepted on the goal screen (Task 8).

- [ ] **Step 1: Write the failing tests**

```dart
test('new user on / goes to /welcome when new_first_run is on', () {
  when(() => flags.newFirstRun).thenReturn(true);
  expect(RouterGuard.debugUnauthenticatedRedirect('/', onboardingCompleted: false), AppRoutes.welcome);
});
test('flag off keeps the slides', () {
  when(() => flags.newFirstRun).thenReturn(false);
  expect(RouterGuard.debugUnauthenticatedRedirect('/', onboardingCompleted: false), AppRoutes.onboarding);
});
test('/welcome/goal is allowed unauthenticated', () {
  when(() => flags.newFirstRun).thenReturn(true);
  expect(RouterGuard.debugUnauthenticatedRedirect('/welcome/goal', onboardingCompleted: false), '/welcome/goal');
});
test('signed-in (or guest) user on /welcome is sent home', () {
  expect(RouterGuard.debugAuthenticatedRedirect('/welcome', languageCompleted: true), AppRoutes.home);
});
```

If `debugUnauthenticatedRedirect` / `debugAuthenticatedRedirect` do not take these parameters, add thin `@visibleForTesting` wrappers next to the existing debug hooks.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/core/router/router_guard_first_run_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the guard changes above.
  - A guest has `isAuthenticated: true`. `currentUser != null` already covers that, so no change is needed in `_getAuthState`.
  - Language completion for a guest: the language page calls `LanguagePreferenceService.saveLanguagePreference` before `startGuest()`. After `startGuest()`, call `RouterGuard.markLanguageSelectionCompleted()` so a guest is never bounced to `/language-selection`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/core/router`
Expected: PASS (all existing router tests too).

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(router): welcome routes for the new first run"
```

---

### Task 8: First-run screens (language, goal) and `FirstRunCubit`

**Files:**
- Create: `frontend/lib/features/onboarding/domain/growth_goals.dart`
- Create: `frontend/lib/features/onboarding/presentation/bloc/first_run_cubit.dart` (+ `first_run_state.dart`)
- Create: `frontend/lib/features/onboarding/presentation/pages/first_run_language_page.dart`
- Create: `frontend/lib/features/onboarding/presentation/pages/growth_goal_page.dart`
- Modify: i18n (keys below), `injection_container.dart` (`registerFactory(() => FirstRunCubit(...))`)
- Test: `frontend/test/features/onboarding/first_run_cubit_test.dart`, `frontend/test/features/onboarding/first_run_pages_test.dart`

**Interfaces:**
- Consumes:
  - `GuestSessionService.startGuest` (Task 6)
  - `LearningPathsRepository.enrollInPathBySlug` (Task 3) and `getLearningPathDetails`
  - `buildLessonLaunchLocation` (Phase A)
  - `RolloutFlags.guestMode` (Task 1)
- Produces:
  - `enum GrowthGoal { newToFaith, understandBible, identityInChrist, walkWithGod, hopeHardTimes, readGospel }` with `String get pathSlug`.
  - `class FirstRunCubit extends Cubit<FirstRunState> { Future<void> startLessonOne(GrowthGoal goal, String language); }`
  - States: `FirstRunIdle`, `FirstRunStarting`, `FirstRunReady(String location)`, `FirstRunNeedsLogin`, `FirstRunFailed(String messageKey)`.
  - Hive `app_settings['first_run_goal']` = goal name. Phase C reads it.
  - Query param `first_run=1` is added to the lesson location. The guide and the complete page use it to show the sign-up block.

i18n keys (en / hi / ml):
- `first_run.welcome_eyebrow` = "Welcome" / "स्वागत है" / "സ്വാഗതം"
- `first_run.welcome_title` = "Grow in God's Word every day" / "हर दिन परमेश्वर के वचन में बढ़ें" / "ദിവസവും ദൈവവചനത്തിൽ വളരുക"
- `first_run.welcome_subtitle` = "A daily verse and a short lesson, in your language." / "आपकी भाषा में रोज़ एक वचन और छोटा पाठ।" / "നിങ്ങളുടെ ഭാഷയിൽ ദിവസവും ഒരു വചനവും ചെറിയ പാഠവും."
- `first_run.continue` = "Continue" / "आगे" / "തുടരുക"
- `first_run.log_in` = "Log in" / "लॉग इन" / "ലോഗിൻ"
- `first_run.have_account` = "Already have an account?" / "पहले से खाता है?" / "അക്കൗണ്ട് ഉണ്ടോ?"
- `first_run.goal_title` = "What would you like to grow in?" / "आप किसमें बढ़ना चाहते हैं?" / "എന്തിൽ വളരണം?"
- `first_run.goal_subtitle` = "Pick one. It sets your first path; switch any time." / "एक चुनें। इससे पहला पथ तय होगा; कभी भी बदलें।" / "ഒന്ന് തിരഞ്ഞെടുക്കൂ. പിന്നീട് മാറ്റാം."
- `first_run.skip` = "Skip" / "छोड़ें" / "ഒഴിവാക്കുക"
- `first_run.start_lesson_one` = "Start lesson 1" / "पाठ 1 शुरू करें" / "പാഠം 1 തുടങ്ങാം"
- `first_run.terms` = "By continuing you agree to our Terms and Privacy Policy." / "आगे बढ़कर आप हमारी शर्तें और गोपनीयता नीति मानते हैं।" / "തുടരുമ്പോൾ നിബന്ധനകളും സ്വകാര്യതാ നയവും അംഗീകരിക്കുന്നു."
- `first_run.path_prefix` = "Path: {title}" / "पथ: {title}" / "പാത: {title}"
- Goals:
  - `goal.new_to_faith` = "I'm new to faith" / "मैं विश्वास में नया हूँ" / "വിശ്വാസത്തിൽ പുതിയതാണ്"
  - `goal.understand_bible` = "Understanding the Bible" / "बाइबल समझना" / "ബൈബിൾ മനസ്സിലാക്കാൻ"
  - `goal.identity_in_christ` = "Knowing who I am in Christ" / "मसीह में मेरी पहचान" / "ക്രിസ്തുവിൽ ഞാൻ ആര്"
  - `goal.walk_with_god` = "Walking with God daily" / "रोज़ परमेश्वर के साथ" / "ദിവസവും ദൈവത്തോടൊപ്പം"
  - `goal.hope_hard_times` = "Hope in hard times" / "कठिन समय में आशा" / "പ്രയാസത്തിൽ പ്രത്യാശ"
  - `goal.read_gospel` = "Reading a Gospel" / "एक सुसमाचार पढ़ना" / "ഒരു സുവിശേഷം വായിക്കാൻ"

The language page shows the three language options in their own script ("English", "हिन्दी", "മലയാളം"). Those labels are not translated keys.

- [ ] **Step 1: Write the failing tests**

```dart
// first_run_cubit_test.dart
blocTest<FirstRunCubit, FirstRunState>(
  'guest mode: starts a guest, enrols by slug, opens lesson 1 in Quick Read',
  build: () {
    when(() => flags.guestMode).thenReturn(true);
    when(() => guest.startGuest()).thenAnswer((_) async {});
    when(() => paths.enrollInPathBySlug('new-believer-essentials')).thenAnswer((_) async => Right(fakeEnrollment(pathId: 'p1')));
    when(() => paths.getLearningPathDetails(pathId: 'p1', language: 'hi', forceRefresh: true))
        .thenAnswer((_) async => Right(fakePath8(id: 'p1')));
    return FirstRunCubit(guest: guest, paths: paths, flags: flags, settings: settingsBox);
  },
  act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'hi'),
  expect: () => [
    isA<FirstRunStarting>(),
    isA<FirstRunReady>()
        .having((s) => Uri.parse(s.location).queryParameters['mode'], 'mode', 'quick')
        .having((s) => Uri.parse(s.location).queryParameters['lesson_number'], 'n', '1')
        .having((s) => Uri.parse(s.location).queryParameters['first_run'], 'first_run', '1')
        .having((s) => Uri.parse(s.location).queryParameters['language'], 'lang', 'hi'),
  ],
  verify: (_) => expect(settingsBox.get('first_run_goal'), 'newToFaith'),
);

blocTest<FirstRunCubit, FirstRunState>(
  'guest mode off and signed out: asks to log in (goal remembered)',
  build: () { when(() => flags.guestMode).thenReturn(false); when(() => guest.hasSession).thenReturn(false); return cubit(); },
  act: (c) => c.startLessonOne(GrowthGoal.readGospel, 'en'),
  expect: () => [isA<FirstRunStarting>(), isA<FirstRunNeedsLogin>()],
);
```

```dart
// first_run_pages_test.dart
testWidgets('language page: welcome copy, three scripts, Log in, Continue → goal', ...);
testWidgets('goal page: six choices with path names; Start lesson 1 disabled until one is picked; Skip → /login', ...);
testWidgets('goal page fits at 360x780 in Malayalam without truncation', (tester) async {
  await loadAppFonts();
  tester.view.physicalSize = const Size(360, 780); tester.view.devicePixelRatio = 1;
  await pumpGoalPage(tester, language: 'ml');
  expectNoTruncatedText(tester);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/onboarding/first_run_cubit_test.dart test/features/onboarding/first_run_pages_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`startLessonOne`:
1. Emit `FirstRunStarting`.
2. Save the goal to Hive.
3. Set Hive `terms_accepted = true` and `onboarding_completed = true`.
4. If there is no session: with `flags.guestMode` call `guest.startGuest()`, otherwise emit `FirstRunNeedsLogin` and return.
5. `enrollInPathBySlug(goal.pathSlug)`.
6. `getLearningPathDetails(..., forceRefresh: true)`.
7. Take the first topic by position.
8. Emit `FirstRunReady(buildLessonLaunchLocation(path:, topic:, mode: StudyMode.quick, language:, source: 'learningPath') + '&first_run=1')`.
9. On any `Left`, emit `FirstRunFailed('first_run.error')`; add the key "Couldn't start the lesson. Check your connection and try again." with short hi/ml versions.

Pages:
- Both use the dark photo hero (reuse `PhotoWash` from `learning_path_detail_page.dart`).
- Gold selected rows (`AppColors.brandGold` border + check). Language rows are 56px tall; goal rows show two lines (goal, "Path: <localized path title>").
- 40px primary buttons. "Skip" and "Log in" are text buttons that call `context.go(AppRoutes.login)`.
- The goal page listens to the cubit:
  - `FirstRunReady` → `context.go(location)`.
  - `FirstRunNeedsLogin` → `context.go(AppRoutes.login)`. After login, Phase C's "Choose your first path" uses `first_run_goal` to pre-highlight.
- Path titles come from `LearningPathsRepository.getLearningPaths` (cached). If loading fails, hide the "Path:" line rather than block the screen.
- The language page calls `LanguagePreferenceService.saveLanguagePreference(AppLanguage)` and `sl<TranslationService>().changeLanguage(...)` so the goal page renders in the chosen script immediately.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/onboarding`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(onboarding): language and goal screens that open lesson 1"
```

---

### Task 9: Quick/Full switch on lessons and "Read the full guide"

**Files:**
- Create: `frontend/lib/features/study_generation/presentation/widgets/lesson_mode_switch.dart`
- Modify: `study_guide_screen_v2.dart` (render the switch under the title when `widget.lesson != null`, and the "Read the full guide" line above `LessonMarkCompleteBar` when `widget.studyMode == StudyMode.quick`)
- Modify: i18n `lesson.quick_read` ("Quick read · {min} min" / "क्विक · {min} मिनट" / "ക്വിക്ക് · {min} മിനിറ്റ്") and `lesson.full_guide` ("Full guide · {min} min" / "पूरी गाइड · {min} मिनट" / "മുഴുവൻ · {min} മിനിറ്റ്")
- Test: `frontend/test/features/study_generation/presentation/widgets/lesson_mode_switch_test.dart`

**Interfaces:**
- Produces:
  - `LessonModeSwitch({required StudyMode current, required ValueChanged<StudyMode> onChanged})`. It offers two segments, `StudyMode.quick` and `StudyMode.standard`, each 32px high, with gold for the selected segment.
  - Switching calls `context.pushReplacement(<same location with mode=newMode>)`, built by `Uri.parse(GoRouterState.of(context).uri.toString()).replace(queryParameters: {...q, 'mode': newMode.name})`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('tapping Full guide reports standard; selected segment is gold', (tester) async {
  StudyMode? picked;
  await tester.pumpWidget(welcomeApp(screen: LessonModeSwitch(current: StudyMode.quick, onChanged: (m) => picked = m)));
  await tester.tap(find.textContaining('Full guide'));
  expect(picked, StudyMode.standard);
  final quick = tester.widget<DecoratedBox>(find.byKey(const Key('lesson_mode_quick')));
  expect((quick.decoration as BoxDecoration).color, AppColors.brandGold);
  expect(tester.getSize(find.byKey(const Key('lesson_mode_quick'))).height, 32);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/study_generation/presentation/widgets/lesson_mode_switch_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the widget and the two insertions.
  - The "Read the full guide" line is a `TextButton` styled as a link (gold, 13pt) that does the same mode swap to `standard`.
  - While a stream is in flight, switching cancels it: dispatch `CancelStudyStreamingRequested` before `pushReplacement`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/study_generation`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(study): Quick and Full switch on lessons"
```

---

### Task 10: Sign-up block on "Lesson complete" and the account-needed sheet

**Files:**
- Create: `frontend/lib/features/auth/presentation/widgets/save_progress_block.dart`
- Create: `frontend/lib/features/auth/presentation/widgets/account_needed_sheet.dart`
- Modify:
  - `frontend/lib/core/router/app_router.dart` lesson-complete route, guest nudges per `guest-mode.png` "Guest rules":
    - lesson 1 of the first run (`first_run=1`) → `extraSections: [SaveProgressBlock(...)]` (full sign-up block + "Not now");
    - lessons 3 and 6 → `extraSections: [KeepProgressCard(...)]`, a dismissible one-line card "Keep these {n} days safe · Sign up to keep them →" (key `account.keep_days_safe` = "Keep these {n} days safe" / "ये {n} दिन सुरक्षित रखें" / "ഈ {n} ദിവസം സൂക്ഷിക്കൂ"; dismissal stored in Hive `guest_nudge_dismissed_<lesson>`; tapping opens `AccountNeededSheet.show(context, AccountReason.saveProgress)`);
    - otherwise no extra section. Last lesson of the path (guest) → `SaveProgressBlock` with title "Sign up to keep your progress and start your next path".
  - `frontend/lib/core/presentation/widgets/app_shell.dart` `_onTabTapped`: Discipler branch 4 → `requireAccount(context, AccountReason.discipler)`.
  - `frontend/lib/features/community/presentation/screens/community_tab_screen.dart`: join/create/discover actions → `requireAccount(context, AccountReason.groups)`.
  - `learning_path_detail_page.dart`: on `LearningPathsError` with `AccountRequiredFailure(reason: 'second_path')` → `AccountNeededSheet.show(context, AccountReason.secondPath)`.
- Modify: i18n keys (en / hi / ml)
  - `account.save_progress_title` = "Sign up to save your progress and continue" / "प्रगति सहेजने के लिए साइन अप करें" / "പുരോഗതി സൂക്ഷിക്കാൻ സൈൻ അപ്പ്"
  - `account.continue_google` = "Continue with Google" / "Google से जारी रखें" / "Google വഴി തുടരുക"
  - `account.continue_apple` = "Continue with Apple" / "Apple से जारी रखें" / "Apple വഴി തുടരുക"
  - `account.continue_email` = "Continue with email" / "ईमेल से जारी रखें" / "ഇമെയിൽ വഴി തുടരുക"
  - `account.not_now` = "Not now" / "अभी नहीं" / "ഇപ്പോൾ വേണ്ട"
  - `account.continue_guest` = "Continue as guest" / "मेहमान के रूप में जारी रखें" / "അതിഥിയായി തുടരുക"
  - `account.groups_title` = "Groups need an account" / "समूह के लिए खाता चाहिए" / "ഗ്രൂപ്പിന് അക്കൗണ്ട് വേണം"
  - `account.discipler_title` = "Discipler needs an account" / "Discipler के लिए खाता चाहिए" / "Discipler-ന് അക്കൗണ്ട് വേണം"
  - `account.second_path_title` = "Your next path needs an account" / "अगले पथ के लिए खाता चाहिए" / "അടുത്ത പാതയ്ക്ക് അക്കൗണ്ട് വേണം"
  - `account.body` = "So your progress and groups stay with you on any phone." / "ताकि आपकी प्रगति हर फ़ोन पर साथ रहे।" / "ഏത് ഫോണിലും പുരോഗതി കൂടെയുണ്ടാകാൻ."
  - `account.benefit_moves` = "Your progress on this phone moves over" / "इस फ़ोन की प्रगति साथ आएगी" / "ഈ ഫോണിലെ പുരോഗതി നിലനിൽക്കും"
  - `account.benefit_paths` = "Start a second path any time" / "कभी भी दूसरा पथ" / "എപ്പോഴും രണ്ടാം പാത"
  - `account.benefit_groups` = "Ask Discipler and join groups" / "Discipler से पूछें, समूह से जुड़ें" / "Discipler, ഗ്രൂപ്പുകൾ"
  - `account.check_email` = "Check your email to confirm: {email}" / "पुष्टि के लिए ईमेल देखें: {email}" / "സ്ഥിരീകരിക്കാൻ ഇമെയിൽ നോക്കൂ: {email}"
- Test: `frontend/test/features/auth/presentation/account_needed_sheet_test.dart`, `frontend/test/features/auth/presentation/save_progress_block_test.dart`

**Interfaces:**
- Consumes: `GuestSessionService` (Task 6), `LessonCompletePage.extraSections` (Phase A).
- Produces:
  - `enum AccountReason { groups, discipler, secondPath, saveProgress }`
  - `Future<bool> requireAccount(BuildContext context, AccountReason reason)` returns true when the user is not a guest or has just linked an account. It returns false (and the caller does nothing) on "Continue as guest". When `guestMode` is off, it is always true.
  - `SaveProgressBlock({required VoidCallback onNotNow})`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('guest tapping Discipler sees the sheet; Continue as guest returns false', (tester) async {
  when(() => guest.isGuest).thenReturn(true);
  late Future<bool> result;
  await tester.pumpWidget(welcomeApp(screen: Builder(builder: (c) => TextButton(
      onPressed: () => result = requireAccount(c, AccountReason.discipler), child: const Text('go')))));
  await tester.tap(find.text('go')); await tester.pumpAndSettle();
  expect(find.text('Discipler needs an account'), findsOneWidget);
  await tester.tap(find.text('Continue as guest')); await tester.pumpAndSettle();
  expect(await result, isFalse);
});

testWidgets('non-guest passes straight through', (tester) async {
  when(() => guest.isGuest).thenReturn(false);
  // requireAccount resolves true and no sheet is shown
});

testWidgets('email link pending shows Check your email with the address', (tester) async {
  when(() => guest.linkEmail(email: 'a@b.c', password: any(named: 'password'), fullName: any(named: 'fullName')))
      .thenAnswer((_) async => LinkOutcome.emailConfirmationSent);
  // fill the inline email form in SaveProgressBlock, submit, expect find.text('Check your email to confirm: a@b.c')
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/auth/presentation`
Expected: FAIL.

- [ ] **Step 3: Implement**

`AccountNeededSheet`:
- A `showModalBottomSheet` over a dimmed real screen (the default barrier).
- Gold icon circle, title by reason, body, three check rows.
- Google (white), Apple (black), Email (outlined) buttons at 40px, and a "Continue as guest" text button.
- Hide Apple on Android and web unless Apple sign-in is already shown on `LoginScreen` (reuse its condition).

`SaveProgressBlock`:
- The same three buttons plus "Not now".
- On `linked` / `mergedIntoExisting`: `context.read<AuthBloc>().add(const RefreshUserProfileRequested())`, then `context.go(AppRoutes.home)`.
- Email opens an inline form with name, email and password. Reuse `EmailAuthScreen` validators.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/auth test/core`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(auth): save-progress block and account-needed sheet for guests"
```

---

### Task 11: Quiet first run — no tours or prompts; guest Settings

**Files:**
- Modify: `frontend/lib/features/onboarding/presentation/bloc/first_run_cubit.dart` (on `FirstRunReady`, mark every `WalkthroughScreen` seen via `sl<WalkthroughRepository>().markSeen(screen)` for `WalkthroughScreen.values`)
- Modify: `frontend/lib/features/home/presentation/pages/home_screen.dart:241,277,299` (the notification prompt stays, but only after `lesson_completed` exists — read Hive `app_settings['first_lesson_completed']`, set by `LessonCompletePage` on first show)
- Modify: `frontend/lib/features/settings/presentation/pages/settings_screen.dart` `_accountSection` (L532-560): for a guest, replace "Sign Out" with "Save progress to your account" (opens `AccountNeededSheet.show(context, AccountReason.saveProgress)`) and hide "Delete account" and "Resend verification"
- Modify: `frontend/lib/features/auth/presentation/bloc/auth_state.dart:71-77` (`needsEmailVerification` → false when `user.isAnonymous`)
- Test: `frontend/test/features/onboarding/first_run_quiet_test.dart`, `frontend/test/features/settings/settings_guest_test.dart`

**Interfaces:**
- Consumes: `WalkthroughRepository.markSeen`, `GuestSessionService.isGuest`.
- Produces: Hive keys `app_settings['first_lesson_completed']` (bool), read by Phase C and F.

- [ ] **Step 1: Write the failing tests**

```dart
blocTest<FirstRunCubit, FirstRunState>('marks all tours seen when lesson 1 opens', ...,
  verify: (_) { for (final s in WalkthroughScreen.values) verify(() => walkthrough.markSeen(s)).called(1); });

testWidgets('guest settings shows Save progress, not Sign out', (tester) async { ... });
test('anonymous user never needs email verification', () {
  final s = AuthenticatedState(user: fakeUser(anon: true), profile: null);
  expect(s.needsEmailVerification, isFalse);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/onboarding/first_run_quiet_test.dart test/features/settings/settings_guest_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** as described.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/onboarding test/features/settings test/features/auth`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(onboarding): no tours on the first run and guest-aware Settings"
```

---

### Task 12: Phase verification

- [ ] Run `cd frontend && flutter analyze && flutter test`. Expected: clean, PASS.
- [ ] Run `cd backend/supabase/functions && deno test _shared learning-paths user-profile`. Expected: PASS.
- [ ] Locally enable both flags: `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "update feature_flags set is_enabled=true, rollout_percentage=100 where feature_key in ('new_first_run','guest_mode')"`. Then run web alone and:
  1. Fresh incognito → `/welcome`.
  2. Pick Malayalam, then "I'm new to faith", then "Start lesson 1". Lesson 1 opens in Quick Read with "LESSON 1 OF 8", with no credits used (check the `token-status` total is unchanged).
  3. Tap "Mark complete" → "Lesson 1 complete" with the sign-up block.
  4. Tap "Not now" → Home.
  5. Tap Discipler → sheet. Tap "Continue as guest" → back.
  6. Sign up with email → "Check your email".
  7. Turn both flags off and repeat with a fresh incognito: slides → login, as today.

## Self-review notes

- **Spec coverage.**
  - Language with Log in: Task 8.
  - Goal (6 → real slugs): Task 8.
  - Lesson 1 in Quick Read + switch + full-guide line: Tasks 4, 8, 9.
  - Lesson complete + sign-up / Not now: Task 10 + Phase A.
  - Guest (anonymous, server progress, linking): Tasks 2, 5, 6.
  - First path only: Task 3.
  - Account needed for groups, Discipler and a second path: Tasks 2, 3, 10.
  - "Continue as guest": Task 10.
  - Skip / Log in → login → Home: Tasks 7, 8.
  - Tours off: Task 11.
- **Moved to Phase C:** "Choose your first path" on Home.
- **Moved to Phase F:** analytics events.
- **Owner prerequisite (dashboard, not deploy):** enable Anonymous sign-ins and Manual linking on hosted dev and prod.
