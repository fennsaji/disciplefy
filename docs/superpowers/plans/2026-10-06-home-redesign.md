# Home Redesign and "New for you" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Behind `home_today_layout`, Home shows only today's verse, one path with its progress strip, today's lesson with one "Start lesson N" button, and at most one "New for you" banner a week. Each banner opens a one-screen introduction to a feature that is already reachable from its tab.

**Architecture:**
- **Data.** The `learning-paths?action=recommended` response gains a `next_lesson` object, `topics_completed` and `milestone_positions`. Flutter maps them into a new `ActivePathSummary` entity, which `HomeBloc` already loads via `LoadActiveLearningPath`.
- **Layout.** A new `HomeTodayLayout` widget tree is selected inside `HomeScreen` by `RolloutFlags.homeTodayLayout`. The old widget tree stays untouched for flag-off.
- **New for you.** A pure `NewForYouScheduler` (no Flutter imports) decides which banner to show. A small `NewForYouCubit` persists the state per user in `SharedPreferences`. Each banner opens `FeatureIntroPage(kind)`.

**Tech Stack:** Flutter (BLoC/Cubit, go_router, GetIt, shared_preferences), Deno edge function `learning-paths`.

**Spec:** `docs/ux/design-final/home.png`, `new-for-you.png`, `feature-introductions.png`, `guest-mode.png` (guest row), `first-run.png` screens 5 and 9, `hindi-malayalam.png`; final design review §Home / New for you / Feature introductions; roadmap `docs/superpowers/plans/2026-10-06-new-user-experience-roadmap.md`.

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
- **Depends on Phase A:**
  - `LessonRef`
  - `buildLessonLaunchLocation` (the URL shape)
  - `resolveNextLessonMode()`
  - the one-streak fix
  - localized dates
- **Depends on Phase B:**
  - `RolloutFlags`
  - `GuestSessionService.isGuest`
  - `requireAccount`
  - `AccountNeededSheet`
  - Hive `first_run_goal`
  - Hive `first_lesson_completed`

  If Phase B has not merged, stub `isGuest` as false and treat `first_lesson_completed` as "any completed topic".
- **Home shows no streak tile, no Personalize card, no fellowship card and no tours** when the flag is on. Streak stays in My progress.
- **Path header text** is `ActivePathSummary.displayTitle`, which is `shortTitle ?? title`. Phase F fills `short_title`. Until then the title is one line with ellipsis, and the full title is shown on the path detail screen.
- **"New for you" never appears before lesson 1 is completed**, so day 1 stays focused.

## Review Focus

- **A path with 25 lessons where the user is on lesson 12.**
  - The strip is a smooth bar with milestone ticks and the label "Today". It has no dates and no "Tomorrow".
  - The card says "TODAY · LESSON 12" and "Start lesson 12".
- **The user completed all lessons of the active path.**
  - The lesson card shows "You finished <path>" with "Choose your next path".
  - Tapping it opens Topics.
  - A guest gets the account-needed sheet for the second path.
  - The card never shows "Start lesson 9 of 8".
- **A dismissed banner never returns** after an app restart or a language switch. Signing out and in as another user on the same device does not inherit the dismissals.
- **Hindi/Malayalam at 360px.** Path header + "See path", the lesson card chip + title + button, the banner and the dock do not overflow. Lesson titles may wrap to 2 lines, then ellipsize. The overflow tests are in Phase F, Task 4; here, Tasks 3, 4 and 7 each include a `ml` 360px pump.
- **Memory Verses pill.** The badge shows only when the user has ≥1 saved verse and ≥1 due. It is gold, not red, and it is never shown with 0 saved verses.

---

## File Structure

| File | Responsibility |
|---|---|
| `backend/supabase/functions/learning-paths/next-lesson.ts` (new) | Pure `buildNextLesson`, `milestonePositions` |
| `backend/supabase/functions/learning-paths/index.ts` (recommended branch ~L1340-1640, path interface L70-91) | Add `next_lesson`, `topics_completed`, `milestone_positions` |
| `frontend/lib/features/home/domain/entities/active_path_summary.dart` (new) | `ActivePathSummary`, `NextLesson` |
| `frontend/lib/features/home/data/models/active_path_summary_model.dart` (new) | JSON → entity |
| `frontend/lib/features/home/presentation/widgets/today/path_progress_strip.dart` (new) | Dots / segmented / smooth bar |
| `frontend/lib/features/home/presentation/widgets/today/today_lesson_card.dart` (new) | Lesson card + mode chip |
| `frontend/lib/features/home/presentation/widgets/today/home_path_section.dart` (new) | Header + strip + card, or "Choose your first path", or "finished" |
| `frontend/lib/features/home/presentation/widgets/today/home_today_layout.dart` (new) | The whole Home body for the flag |
| `frontend/lib/features/home/presentation/widgets/today/memory_pill_badge.dart` (new) | Badge rule |
| `frontend/lib/features/home/domain/new_for_you/new_for_you_scheduler.dart` (new) | Pure scheduling rules |
| `frontend/lib/features/home/presentation/bloc/new_for_you_cubit.dart` (new) | Persistence + eligibility |
| `frontend/lib/features/home/presentation/widgets/today/new_for_you_banner.dart` (new) | Photo banner |
| `frontend/lib/features/home/presentation/pages/feature_intro_page.dart` (new) | One-screen intros |
| `frontend/lib/features/home/presentation/pages/home_screen.dart:519-645` | Select layout by flag |
| `frontend/lib/core/router/app_router.dart`, `app_routes.dart` | `/intro/:kind` |

---

### Task 1: Backend — `next_lesson`, `topics_completed`, `milestone_positions` on the recommended path

**Files:**
- Create: `backend/supabase/functions/learning-paths/next-lesson.ts`
- Modify: `backend/supabase/functions/learning-paths/index.ts` (the path response interface at L70-91; every place that builds the recommended path response in the `recommended` action, ~L1340-1640)
- Test: `backend/supabase/functions/learning-paths/next-lesson.test.ts`

**Interfaces:**
- Produces:
  - `buildNextLesson(topics: PathTopicRow[], completedTopicIds: Set<string>): NextLessonJson | null`
    - `PathTopicRow = { topic_id: string; position: number; is_milestone: boolean; title: string; description: string; input_type: string }`
    - `NextLessonJson = { topic_id; title; description; input_type; lesson_number: number; lesson_total: number }`
    - Returns null when every lesson is complete.
  - `milestonePositions(topics): number[]` returns the 1-based lesson numbers where `is_milestone` is true.
  - Response fields: `next_lesson: NextLessonJson | null`, `topics_completed: number`, `milestone_positions: number[]`.
  - Titles are localized with the same translation lookup the detail endpoint uses (`learning_path_topic_titles` / `recommended_topics_translations`).

- [ ] **Step 1: Write the failing test**

```ts
// Run with: deno test learning-paths/next-lesson.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildNextLesson, milestonePositions } from './next-lesson.ts'

const rows = [3, 1, 2].map(p => ({ topic_id: `t${p}`, position: p * 10, is_milestone: p === 3, title: `L${p}`, description: '', input_type: 'topic' }))

Deno.test('next lesson is the first incomplete by position, numbered 1-based', () => {
  assertEquals(buildNextLesson(rows, new Set(['t1'])), { topic_id: 't2', title: 'L2', description: '', input_type: 'topic', lesson_number: 2, lesson_total: 3 })
})
Deno.test('all complete → null', () => {
  assertEquals(buildNextLesson(rows, new Set(['t1', 't2', 't3'])), null)
})
Deno.test('milestones are lesson numbers', () => {
  assertEquals(milestonePositions(rows), [3])
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend/supabase/functions && deno test learning-paths/next-lesson.test.ts`
Expected: FAIL (module not found).

- [ ] **Step 3: Implement**

```ts
export interface PathTopicRow { topic_id: string; position: number; is_milestone: boolean; title: string; description: string; input_type: string }
export interface NextLessonJson { topic_id: string; title: string; description: string; input_type: string; lesson_number: number; lesson_total: number }

const ordered = (t: PathTopicRow[]) => [...t].sort((a, b) => a.position - b.position)

export function buildNextLesson(topics: PathTopicRow[], completed: Set<string>): NextLessonJson | null {
  const list = ordered(topics)
  const i = list.findIndex(t => !completed.has(t.topic_id))
  if (i < 0) return null
  const t = list[i]
  return { topic_id: t.topic_id, title: t.title, description: t.description, input_type: t.input_type, lesson_number: i + 1, lesson_total: list.length }
}

export function milestonePositions(topics: PathTopicRow[]): number[] {
  return ordered(topics).flatMap((t, i) => (t.is_milestone ? [i + 1] : []))
}
```

In the `recommended` handler, once the chosen path id is known:
1. Load its active topics. Use one query on `learning_path_topics` (`is_active = true`) joined to `recommended_topics`, plus the localized titles (reuse the helper the detail endpoint uses).
2. Load the user's completed topic ids (`user_topic_progress.completed_at IS NOT NULL`).
3. Attach `next_lesson`, `topics_completed: completed ∩ path topics`, and `milestone_positions`.

Guest and signed-out callers get the same shape, with `topics_completed: 0`.

- [ ] **Step 4: Run tests and type-check**

Run: `cd backend/supabase/functions && deno test learning-paths/ && deno check learning-paths/index.ts`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(paths): recommended path returns the next lesson and milestones"
```

---

### Task 2: `ActivePathSummary` entity and model; `HomeBloc` exposes it

**Files:**
- Create: `frontend/lib/features/home/domain/entities/active_path_summary.dart`
- Create: `frontend/lib/features/home/data/models/active_path_summary_model.dart`
- Modify:
  - `frontend/lib/features/study_topics/domain/entities/learning_path.dart` (add `final ActivePathSummary? summary;` to `RecommendedPathResult`, L296+)
  - `frontend/lib/features/study_topics/data/datasources/learning_paths_remote_datasource.dart:551` (parse into `summary`)
  - `frontend/lib/features/home/presentation/bloc/home_state.dart` (`HomeCombinedState.activePathSummary`)
  - `home_bloc.dart:323-431` (set it)
- Test: `frontend/test/features/home/data/active_path_summary_model_test.dart`

**Interfaces:**
- Produces:
  - `class NextLesson { final String topicId, title, description, inputType; final int number, total; }`
  - `class ActivePathSummary { final String pathId, title, description, discipleLevel; final String? shortTitle; final int lessonTotal, lessonsCompleted; final NextLesson? next; final List<int> milestoneNumbers; final String? recommendedMode; String get displayTitle => (shortTitle?.isNotEmpty ?? false) ? shortTitle! : title; bool get isFinished => next == null && lessonsCompleted >= lessonTotal && lessonTotal > 0; }`
  - `ActivePathSummaryModel.fromJson(Map<String,dynamic> pathJson)`. It reads `short_title` if present, which Phase F adds.
  - `HomeCombinedState.activePathSummary` (`ActivePathSummary?`).

- [ ] **Step 1: Write the failing test**

```dart
test('parses next_lesson, completion and milestones', () {
  final s = ActivePathSummaryModel.fromJson({
    'id': 'p1', 'title': 'New Believer Essentials', 'description': 'd', 'disciple_level': 'seeker',
    'topics_count': 8, 'topics_completed': 3, 'milestone_positions': [4, 7, 8], 'recommended_mode': 'standard',
    'next_lesson': {'topic_id': 't4', 'title': 'Confidence in Your Salvation', 'description': '', 'input_type': 'topic', 'lesson_number': 4, 'lesson_total': 8},
  });
  expect(s.next!.number, 4);
  expect(s.lessonsCompleted, 3);
  expect(s.milestoneNumbers, [4, 7, 8]);
  expect(s.displayTitle, 'New Believer Essentials');
  expect(s.isFinished, isFalse);
});
test('short_title wins when present', () {
  final s = ActivePathSummaryModel.fromJson({'id': 'p', 'title': 'Long', 'short_title': 'Short', 'topics_count': 1, 'topics_completed': 1, 'next_lesson': null});
  expect(s.displayTitle, 'Short');
  expect(s.isFinished, isTrue);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/home/data/active_path_summary_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the entity (Equatable), the model, and the wiring.
  - When building `HomeCombinedState` in `_onLoadActiveLearningPath`, set `activePathSummary: result.summary`.
  - Keep `activeLearningPath` as it is for the old layout.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/home test/features/study_topics`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(home): active path summary with the next lesson"
```

---

### Task 3: `PathProgressStrip` — three tiers, "Today" only

**Files:**
- Create: `frontend/lib/features/home/presentation/widgets/today/path_progress_strip.dart`
- Modify: i18n `home_today.today_label` ("Today" / "आज" / "ഇന്ന്")
- Test: `frontend/test/features/home/presentation/widgets/path_progress_strip_test.dart`

**Interfaces:**
- Produces:
  - `enum StripTier { dots, segments, smooth }`
  - `StripTier stripTierFor(int total)`: ≤10 → dots; 11–20 → segments; >20 → smooth.
  - `PathProgressStrip({required int total, required int completed, required int current, List<int> milestones = const []})`, where `current` is the next lesson number, or `total` when finished.
  - Keys: `Key('strip_dot_$n')`, `Key('strip_segment_$n')`, `Key('strip_tick_$n')`, `Key('strip_today')`.

- [ ] **Step 1: Write the failing tests**

```dart
test('tiers', () {
  expect(stripTierFor(8), StripTier.dots);
  expect(stripTierFor(10), StripTier.dots);
  expect(stripTierFor(11), StripTier.segments);
  expect(stripTierFor(20), StripTier.segments);
  expect(stripTierFor(21), StripTier.smooth);
});

testWidgets('8 lessons: 8 dots, done ones checked, Today under current, no dates', (tester) async {
  await tester.pumpWidget(welcomeApp(screen: const PathProgressStrip(total: 8, completed: 3, current: 4)));
  for (var n = 1; n <= 8; n++) expect(find.byKey(Key('strip_dot_$n')), findsOneWidget);
  expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
  expect(find.text('Today'), findsOneWidget);
  expect(find.text('Tomorrow'), findsNothing);
});

testWidgets('16 lessons: 16 segments', (tester) async { /* findsNWidgets via keys strip_segment_1..16 */ });

testWidgets('29 lessons: smooth bar with ticks at milestones', (tester) async {
  await tester.pumpWidget(welcomeApp(screen: const PathProgressStrip(total: 29, completed: 11, current: 12, milestones: [5, 17, 22, 27])));
  for (final m in [5, 17, 22, 27]) expect(find.byKey(Key('strip_tick_$m')), findsOneWidget);
  expect(find.byKey(const Key('strip_dot_1')), findsNothing);
});

testWidgets('fits 360px in Malayalam', (tester) async {
  await loadAppFonts();
  tester.view.physicalSize = const Size(360, 200); tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(welcomeApp(screen: const PathProgressStrip(total: 10, completed: 9, current: 10), language: 'ml'));
  expectNoTruncatedText(tester);
  expect(tester.takeException(), isNull);
});
```

If `welcomeApp` has no `language:` parameter, add one to `test/helpers/welcome_test_harness.dart`. It sets `FakeTranslationService` to the given code.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/home/presentation/widgets/path_progress_strip_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
  - **Dots tier.** A `Row` of `Expanded` slots, each centring a 22px circle:
    - completed: gold fill + white check
    - current: gold fill + number, 12pt bold
    - future: a 1.5px outline in `ReaderPalette.of(context).hairline`
    - A 2px connector between the circles.
  - **Segments tier.** A `Row` of `Expanded` 6px rounded bars. Completed and current are gold; the current one is 1.5× taller.
  - **Smooth tier.** A `LayoutBuilder` with a 6px track and a gold fill to `completed/total`. A 10px gold knob sits at `(current-0.5)/total`, and 2×10px ticks sit at each milestone `(m-0.5)/total`.
  - **"Today" label.** Placed under the current item via `Align(alignment: Alignment(x, 0))`, 12pt, gold.
  - The strip and its container card (`palette.card`, radius 16) are tappable with an `onTap`. Callers open the path.
  - Add `VoidCallback? onTap` to the constructor.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/home/presentation/widgets/path_progress_strip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(home): path progress strip with dots, segments and smooth bar"
```

---

### Task 4: `TodayLessonCard` with the Quick/Standard chip

**Files:**
- Create: `frontend/lib/features/home/presentation/widgets/today/today_lesson_card.dart`
- Create: `frontend/lib/features/home/domain/utils/lesson_launch_from_summary.dart`
- Modify: i18n
  - `home_today.lesson_eyebrow` = "TODAY · LESSON {n}" / "आज · पाठ {n}" / "ഇന്ന് · പാഠം {n}"
  - `home_today.start_lesson` = "Start lesson {n}" / "पाठ {n} शुरू करें" / "പാഠം {n} തുടങ്ങാം"
  - `home_today.mode_quick` = "Quick read · {min} min" / "क्विक · {min} मि" / "ക്വിക്ക് · {min} മി"
  - `home_today.mode_standard` = "Full guide · {min} min" / "पूरी गाइड · {min} मि" / "മുഴുവൻ · {min} മി"
  - `home_today.path_finished` = "You finished {path}" / "आपने {path} पूरा किया" / "{path} പൂർത്തിയാക്കി"
  - `home_today.choose_next_path` = "Choose your next path" / "अगला पथ चुनें" / "അടുത്ത പാത"
- Test: `frontend/test/features/home/presentation/widgets/today_lesson_card_test.dart`

**Interfaces:**
- Consumes: `ActivePathSummary`, `NextLesson` (Task 2), `LessonRef` (Phase A), `resolveNextLessonMode()` (Phase A), `UserProfileService.updateLearningPathStudyModePreference(String)` and `LanguagePreferenceService.cacheLearningPathStudyModePreference(String)` (existing).
- Produces:
  - `String buildLessonLaunchFromSummary(ActivePathSummary s, StudyMode mode, String language)`. It uses the same query keys as `buildLessonLaunchLocation`: `input`, `type`, `language`, `mode`, `source=learningPath`, `topic_id`, `description`, `path_description`, `disciple_level`, and `LessonRef.toQuery()`.
  - `TodayLessonCard({required ActivePathSummary summary, required StudyMode mode, required ValueChanged<StudyMode> onModeChanged, required VoidCallback onStart, VoidCallback? onChooseNextPath})`.

- [ ] **Step 1: Write the failing tests**

```dart
test('launch location from summary', () {
  final loc = Uri.parse(buildLessonLaunchFromSummary(summary4of8, StudyMode.standard, 'en'));
  expect(loc.queryParameters['lesson_number'], '4');
  expect(loc.queryParameters['lesson_total'], '8');
  expect(loc.queryParameters['topic_id'], 't4');
  expect(loc.queryParameters['mode'], 'standard');
});

testWidgets('one primary button, no Next: line, chip toggles mode', (tester) async {
  StudyMode? changed;
  await tester.pumpWidget(welcomeApp(screen: TodayLessonCard(summary: summary4of8, mode: StudyMode.standard,
      onModeChanged: (m) => changed = m, onStart: () {})));
  expect(find.text('TODAY · LESSON 4'), findsOneWidget);
  expect(find.text('Start lesson 4'), findsOneWidget);
  expect(find.textContaining('Next:'), findsNothing);
  expect(find.byType(FilledButton), findsOneWidget);
  expect(tester.getSize(find.byType(FilledButton)).height, 40);
  await tester.tap(find.textContaining('Full guide'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Quick read').last);
  expect(changed, StudyMode.quick);
});

testWidgets('finished path shows Choose your next path', (tester) async { ... });

testWidgets('Malayalam 360px: no overflow, title may wrap to 2 lines', (tester) async {
  await loadAppFonts();
  tester.view.physicalSize = const Size(360, 400); tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(welcomeApp(language: 'ml', screen: TodayLessonCard(summary: mlSummary, mode: StudyMode.standard, onModeChanged: (_) {}, onStart: () {})));
  expectNoTruncatedText(tester, allow: {mlSummary.next!.title});
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/home/presentation/widgets/today_lesson_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
  - The card is `palette.card` with radius 16 and padding 16.
  - **Row 1:** the eyebrow (12pt gold, letterSpacing 1) on the left; a 32px chip on the right, `OutlinedButton` with a book icon and the current mode label plus a chevron.
    - Tapping the chip opens a `PopupMenuButton<StudyMode>` with two items, quick and standard.
  - **Row 2:** the title (Poppins 17 semibold, `maxLines: 2`, ellipsis).
  - **Row 3:** a full-width gold `FilledButton` (light) or white (dark, matching the design), 40px high.
  - **Finished state:** a "You finished {path}" title plus an outlined "Choose your next path" button.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/home/presentation/widgets/today_lesson_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(home): today's lesson card with a Quick and Full chip"
```

---

### Task 5: Path section, "Choose your first path", guest row, header pill badge

**Files:**
- Create: `frontend/lib/features/home/presentation/widgets/today/home_path_section.dart`
- Create: `frontend/lib/features/home/presentation/widgets/today/choose_first_path_card.dart`
- Create: `frontend/lib/features/home/presentation/widgets/today/memory_pill_badge.dart`
- Create: `frontend/lib/features/home/presentation/widgets/today/save_progress_row.dart`
- Modify: i18n
  - `home_today.see_path` = "See path" / "पथ देखें" / "പാത"
  - `home_today.choose_first_path` = "Choose your first path" / "अपना पहला पथ चुनें" / "ആദ്യ പാത തിരഞ്ഞെടുക്കൂ"
  - `home_today.choose_first_path_sub` = "One short lesson a day. Switch any time." / "रोज़ एक छोटा पाठ। कभी भी बदलें।" / "ദിവസം ഒരു ചെറിയ പാഠം."
  - `home_today.lessons_days` = "{lessons} lessons · {days} days" / "{lessons} पाठ · {days} दिन" / "{lessons} പാഠം · {days} ദിവസം"
  - `home_today.see_all_paths` = "See all paths" / "सभी पथ" / "എല്ലാ പാതകളും"
  - `home_today.save_progress` = "Save progress to your account" / "प्रगति खाते में सहेजें" / "പുരോഗതി സൂക്ഷിക്കൂ"
- Test: `frontend/test/features/home/presentation/widgets/home_path_section_test.dart`, `memory_pill_badge_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4; `GuestSessionService.isGuest`, `requireAccount`, `AccountReason.secondPath` (Phase B); `LearningPathsRepository.getLearningPaths` (existing, for the 3 suggestions).
- Produces:
  - `int? memoryBadgeCount({required int savedCount, required int dueCount})` returns null when `savedCount == 0 || dueCount == 0`, otherwise `dueCount`.
  - `HomePathSection({required ActivePathSummary? summary, required bool loading, required StudyMode mode, required ValueChanged<StudyMode> onModeChanged})`. Inside it:
    - `summary == null && !loading` → `ChooseFirstPathCard`, showing 3 paths: the `first_run_goal` path first if set, then featured by `display_order`. Each row → `/learning-path/:id?source=home`. A "See all paths" link → `AppRoutes.studyTopics`.
    - summary present → header row (displayTitle 15pt semibold, 1 line + ellipsis; "See path ›" 13pt gold) + `PathProgressStrip` + `TodayLessonCard`.
  - `SaveProgressRow({required VoidCallback onTap})` is shown only for guests.

- [ ] **Step 1: Write the failing tests**

```dart
test('badge rule', () {
  expect(memoryBadgeCount(savedCount: 0, dueCount: 0), isNull);
  expect(memoryBadgeCount(savedCount: 0, dueCount: 3), isNull);
  expect(memoryBadgeCount(savedCount: 5, dueCount: 0), isNull);
  expect(memoryBadgeCount(savedCount: 5, dueCount: 2), 2);
});

testWidgets('no enrolled path → Choose your first path, never the lesson card', ...);
testWidgets('summary → header, strip, card; See path opens detail', ...);
testWidgets('guest finished path: Choose your next path opens account sheet', (tester) async {
  when(() => guest.isGuest).thenReturn(true);
  // tap Choose your next path → expect find.text('Your next path needs an account')
});
testWidgets('ml 360px header fits', (tester) async {
  // displayTitle = 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ', 'See path' = 'പാത'
  // expectNoTruncatedText(tester, allow: {summary.displayTitle}); and the See path text must not be truncated
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/home/presentation/widgets/home_path_section_test.dart test/features/home/presentation/widgets/memory_pill_badge_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** as specified.
  - The header row is `Row(children: [Expanded(child: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis)), TextButton(...)])`, so "See path" never truncates.
  - The badge is a gold (`AppColors.brandGold`) 16px pill with dark text, ≥12pt.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/home`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(home): path section, first-path chooser and guest save row"
```

---

### Task 6: `NewForYouScheduler` (pure rules) and `NewForYouCubit`

**Files:**
- Create: `frontend/lib/features/home/domain/new_for_you/new_for_you_scheduler.dart`
- Create: `frontend/lib/features/home/presentation/bloc/new_for_you_cubit.dart`
- Modify: `frontend/lib/core/di/injection_container.dart` (`registerFactory(() => NewForYouCubit(sl(), sl(), ...))`)
- Test: `frontend/test/features/home/domain/new_for_you_scheduler_test.dart`, `frontend/test/features/home/presentation/bloc/new_for_you_cubit_test.dart`

**Interfaces:**
- Produces:
  - `enum NewForYouKind { paths, memory, generate, discipler, fellowships }`. This order is the schedule.
  - `class NewForYouState { final Map<NewForYouKind, DateTime> firstShownAt; final Set<NewForYouKind> done; Map<String,dynamic> toJson(); factory NewForYouState.fromJson(Map<String,dynamic>); }`. `done` means dismissed or tapped.
  - `class NewForYouEligibility { final bool firstLessonCompleted; final Set<NewForYouKind> available; }`. A kind is available when its feature is not hidden, not already used, and the user is not a guest for discipler/fellowships.
  - `NewForYouKind? pickBanner(NewForYouState s, NewForYouEligibility e, DateTime now)`. Rules:
    1. Nothing until `firstLessonCompleted`.
    2. If a kind was shown, is not done, and was first shown < 7 days ago, keep showing it.
    3. A new kind can start only when no kind has `firstShownAt` within the last 7 days. This holds whether or not that kind was dismissed, so there is at most one new banner per week.
    4. The new kind is the first `available` kind in enum order that has not been shown yet. A shown, not-done kind older than 7 days is treated as done (retired) and never returns.
  - `NewForYouCubit` (state `NewForYouKind?`):
    - `load(String userId, NewForYouEligibility e)` reads prefs key `new_for_you_v1_<userId>`, picks a banner, records `firstShownAt` when it is newly shown, and saves.
    - `dismiss()` and `opened()` add the kind to `done`, save, and emit null.

- [ ] **Step 1: Write the failing tests**

```dart
final t0 = DateTime(2026, 10, 1);
const all = {NewForYouKind.paths, NewForYouKind.memory, NewForYouKind.generate, NewForYouKind.discipler, NewForYouKind.fellowships};
NewForYouEligibility e({bool lesson = true, Set<NewForYouKind> available = all}) =>
    NewForYouEligibility(firstLessonCompleted: lesson, available: available);

test('nothing before lesson 1', () {
  expect(pickBanner(NewForYouState.empty(), e(lesson: false), t0), isNull);
});
test('first banner is paths', () {
  expect(pickBanner(NewForYouState.empty(), e(), t0), NewForYouKind.paths);
});
test('same banner stays during its week', () {
  final s = NewForYouState(firstShownAt: {NewForYouKind.paths: t0}, done: {});
  expect(pickBanner(s, e(), t0.add(const Duration(days: 3))), NewForYouKind.paths);
});
test('dismissed: nothing new until 7 days after it was first shown', () {
  final s = NewForYouState(firstShownAt: {NewForYouKind.paths: t0}, done: {NewForYouKind.paths});
  expect(pickBanner(s, e(), t0.add(const Duration(days: 2))), isNull);
  expect(pickBanner(s, e(), t0.add(const Duration(days: 7))), NewForYouKind.memory);
});
test('unavailable kinds are skipped (e.g. guest: no discipler/fellowships)', () {
  final s = NewForYouState(firstShownAt: {NewForYouKind.paths: t0, NewForYouKind.memory: t0.add(const Duration(days: 7)), NewForYouKind.generate: t0.add(const Duration(days: 14))},
      done: {NewForYouKind.paths, NewForYouKind.memory, NewForYouKind.generate});
  expect(pickBanner(s, e(available: {NewForYouKind.paths, NewForYouKind.memory, NewForYouKind.generate}), t0.add(const Duration(days: 30))), isNull);
});
test('a dismissed banner never returns', () {
  final s = NewForYouState(firstShownAt: {NewForYouKind.paths: t0}, done: {NewForYouKind.paths});
  for (var d = 0; d < 100; d += 7) {
    expect(pickBanner(s, e(), t0.add(Duration(days: d))), isNot(NewForYouKind.paths));
  }
});
test('json round trip', () {
  final s = NewForYouState(firstShownAt: {NewForYouKind.memory: t0}, done: {NewForYouKind.paths});
  expect(NewForYouState.fromJson(s.toJson()).done, {NewForYouKind.paths});
});
```

```dart
// cubit: per-user key
blocTest<NewForYouCubit, NewForYouKind?>('dismissals are per user',
  build: () => NewForYouCubit(prefs: prefs, clock: () => t0),
  act: (c) async { await c.load('u1', e()); await c.dismiss(); await c.load('u2', e()); },
  expect: () => [NewForYouKind.paths, null, NewForYouKind.paths]);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/home/domain/new_for_you_scheduler_test.dart test/features/home/presentation/bloc/new_for_you_cubit_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** `pickBanner`:

```dart
NewForYouKind? pickBanner(NewForYouState s, NewForYouEligibility e, DateTime now) {
  if (!e.firstLessonCompleted) return null;
  const week = Duration(days: 7);
  for (final entry in s.firstShownAt.entries) {
    final active = now.difference(entry.value) < week;
    if (active && !s.done.contains(entry.key) && e.available.contains(entry.key)) return entry.key;
  }
  final recent = s.firstShownAt.values.any((t) => now.difference(t) < week);
  if (recent) return null;
  for (final k in NewForYouKind.values) {
    if (e.available.contains(k) && !s.firstShownAt.containsKey(k)) return k;
  }
  return null;
}
```

The cubit takes an injected `DateTime Function() clock` for tests and uses `SharedPreferences` from `sl<SharedPreferences>()`. Eligibility is built in `HomeTodayLayout` (Task 7) from:
- `first_lesson_completed` (Hive), or `summary.lessonsCompleted > 0`
- `SystemConfigService.shouldHideFeature('memory_verses' | 'ai_discipler', plan)`
- `isGuest`
- the user's saved memory verse count (>0 → memory is not "new", so drop `memory`)
- fellowship membership (`CommunityRepository` my-fellowships non-empty → drop `fellowships`)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/home`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(home): New for you schedule, one banner a week"
```

---

### Task 7: Banner widget and the five feature intro screens

**Files:**
- Create: `frontend/lib/features/home/presentation/widgets/today/new_for_you_banner.dart`
- Create: `frontend/lib/features/home/presentation/pages/feature_intro_page.dart`
- Create: `frontend/lib/features/home/domain/new_for_you/feature_intro_content.dart` (keys, photo asset and actions per kind)
- Modify: `frontend/lib/core/router/app_routes.dart` (`featureIntro = '/intro/:kind'`), `app_router.dart` (top-level route; `kind` parsed with `NewForYouKind.values.byName`; unknown kinds redirect to `/`)
- Modify: i18n, one block per kind. `nfy.<kind>.banner_title`, `nfy.<kind>.banner_sub`, `nfy.<kind>.banner_cta`, `intro.<kind>.eyebrow`, `intro.<kind>.title`, `intro.<kind>.step1_title`, `intro.<kind>.step1_body`, the same for step2 and step3, `intro.<kind>.primary`, `intro.<kind>.secondary`, plus `nfy.eyebrow` ("New for you" / "आपके लिए नया" / "നിങ്ങൾക്കായി പുതിയത്") and `intro.start_with` ("Start with" / "यहाँ से शुरू करें" / "ഇവിടെ തുടങ്ങാം"). English copy is taken verbatim from `new-for-you.png` and `feature-introductions.png`:

| kind | banner_title / banner_sub / banner_cta | intro title | primary / secondary |
|---|---|---|---|
| paths | Explore more learning paths / From the Gospels to prayer and hard times. / Browse paths | Grow step by step, one path at a time | Browse paths / Maybe later |
| memory | Keep today's verse with you / Practise {ref} in one minute. / Practise · 1 min | Hide God's word in your heart, a minute a day | Practise this verse · 1 min / Choose my own verse |
| generate | Study any verse or topic / A guide for whatever is on your mind. / Start a study | Study any passage or question on your mind | Start a study / See an example |
| discipler | Ask a question about the Bible / Answers that point back to Scripture. / Ask Discipler | Ask your Bible questions | Ask a question / Not now |
| fellowships | Join the Disciplefy fellowship / Study {path} with others. / Join Disciplefy | Study together with your church or friends | Join {name} / Find or create a group |

  Steps (en) follow the board text: paths "Pick a path / One short lesson a day / Track your progress"; memory "Save a verse / Practise for one minute / We bring it back"; generate "Type a verse or topic / Choose quick or full guide / Read, reflect, save"; discipler "Ask anything / Answers point you to Scripture / Continue from any lesson"; fellowships "Join a fellowship / Follow the same lesson / Share, pray and meet". Write hi/ml translations short (≤1.3× English); Phase F audits them.
- Test: `frontend/test/features/home/presentation/widgets/new_for_you_banner_test.dart`, `frontend/test/features/home/presentation/pages/feature_intro_page_test.dart`

**Interfaces:**
- Consumes: `NewForYouCubit.dismiss/opened` (Task 6), `requireAccount` (Phase B), `CommunityRepository.joinPublicFellowship(id)` and `pickSuggestedFellowships` (`home_community_section.dart:209`), the `AddToMemoryButton` save logic (extract its save call into `MemoryVerseBloc` event `AddVerseFromDaily`; use the existing event if it exists, otherwise call the existing `add-memory-verse-from-daily` use case).
- Produces:
  - `NewForYouBanner({required NewForYouKind kind, required VoidCallback onOpen, required VoidCallback onDismiss})`. Photo (`assets/images/hero/*.webp`: paths `valley_mist`, memory `night_stars`, generate `snow_peaks`, discipler `mountains_fog`, fellowships `wheat_dawn`), a dark gradient scrim so subtext contrast is ≥4.5:1, 12pt+ text, an × button (Semantics label "Dismiss"), and a 32px CTA.
  - `FeatureIntroPage({required NewForYouKind kind})` actions:
    - paths → `context.go(AppRoutes.studyTopics)`
    - memory → save today's verse (if not saved), then `context.go(AppRoutes.memoryVerses)`
    - generate → `context.go('${AppRoutes.generateStudy}?prefill=Romans%208')`; "See an example" also opens Romans 8 Quick Read
    - discipler → `if (await requireAccount(context, AccountReason.discipler)) context.go('${AppRoutes.discipler}?prefill=${Uri.encodeComponent(question)}')`
    - fellowships → `requireAccount(groups)`, then join the language's official public fellowship, then `context.go('/community')`. "Find or create a group" → `/community`.
  - No designer-note text anywhere.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('banner: CTA opens, × dismisses, text ≥12pt', (tester) async {
  var opened = 0, dismissed = 0;
  await tester.pumpWidget(welcomeApp(screen: NewForYouBanner(kind: NewForYouKind.paths, onOpen: () => opened++, onDismiss: () => dismissed++)));
  await tester.tap(find.text('Browse paths')); expect(opened, 1);
  await tester.tap(find.bySemanticsLabel('Dismiss')); expect(dismissed, 1);
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    expect((t.style?.fontSize ?? 14) >= 12, isTrue, reason: t.data);
  }
});

for (final kind in NewForYouKind.values) {
  testWidgets('intro $kind renders 3 steps and two actions, no designer note', (tester) async {
    await tester.pumpWidget(welcomeApp(screen: FeatureIntroPage(kind: kind)));
    expect(find.textContaining('Opened from'), findsNothing);
    expect(find.textContaining('Explore all features'), findsNothing);
    expect(find.byKey(const Key('intro_step_3')), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}

testWidgets('guest discipler intro asks for an account', ...);
testWidgets('ml banner at 360px fits', ...);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/home/presentation`
Expected: FAIL.

- [ ] **Step 3: Implement** the widgets and route.
  - The intro uses a 220px photo header with an × (close → `context.pop()`) and gold eyebrow + Poppins 24 title.
  - Below it, three numbered steps (gold number circle 24px, title 14pt semibold, body 13pt muted) and a "Start with" card. The card's content per kind: paths shows 2 path rows from `getLearningPaths`; memory shows today's verse; generate shows 3 chips; discipler shows 1 gold question chip; fellowships shows the official fellowship card + 2 other-language rows.
  - The bottom has a primary (40px) and a secondary outlined (40px) button.
  - Opening the intro from the banner calls `cubit.opened()`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/home`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(home): New for you banners and feature introductions"
```

---

### Task 8: `HomeTodayLayout` assembled and selected by flag

**Files:**
- Create: `frontend/lib/features/home/presentation/widgets/today/home_today_layout.dart`
- Modify: `frontend/lib/features/home/presentation/pages/home_screen.dart`:
  - `initState` L133-152: skip `LoadForYouTopics` and the walkthrough when the flag is on.
  - `build` L582-636: `if (sl<RolloutFlags>().homeTodayLayout) return HomeTodayLayout(...)` inside the existing `HomeScrollView(headerBuilder: _buildAppHeader)`, keeping the header.
  - `_buildMemoryVersesIconButton` L700-758: use `memoryBadgeCount`, gold badge.
- Modify: `frontend/lib/features/home/presentation/widgets/home_verse_hero.dart` / `HomeDailyVerseView._loaded` (L314-360): when `todayLayout: true`, replace `_StudyNowButton` with a text link "Reflect on this verse →" (gold, 13pt) calling `onStudy`; the reference is not tappable; the action icons are copy/share/save (`DailyVerseActions`). Key `home_today.reflect` = "Reflect on this verse" / "इस वचन पर मनन करें" / "ഈ വചനം ധ്യാനിക്കാം".
- Test: `frontend/test/features/home/presentation/pages/home_today_layout_test.dart`

**Interfaces:**
- Consumes: everything above; `HomeBloc` (`HomeCombinedState.activePathSummary`, `isLoadingActivePath`); `DailyVerseBloc`; `NewForYouCubit`; `GuestSessionService`.
- Produces: `HomeTodayLayout()`. The section order is verse hero → `HomePathSection` → `NewForYouBanner` (if any) → `SaveProgressRow` (guest). Nothing else.
  - The mode chip default is `resolveNextLessonMode()`, except that when `summary.next.number == 1` and `first_run_goal` is set, it is `StudyMode.quick`.
  - Changing the mode persists via `UserProfileService.updateLearningPathStudyModePreference(mode.name)` (signed-in and guest) and `cacheLearningPathStudyModePreference`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('flag on: verse, path section, lesson card; no streak tile, no personalize, no fellowship', (tester) async {
  when(() => flags.homeTodayLayout).thenReturn(true);
  await pumpHome(tester, summary: summary4of8);
  expect(find.text('Reflect on this verse'), findsOneWidget);
  expect(find.text('Start lesson 4'), findsOneWidget);
  expect(find.byType(HomeTodayTiles), findsNothing);
  expect(find.byType(PersonalizationPromptCard), findsNothing);
  expect(find.byType(HomeCommunitySection), findsNothing);
  expect(find.text('Study now'), findsNothing);
});
testWidgets('flag off: old Home unchanged', (tester) async {
  when(() => flags.homeTodayLayout).thenReturn(false);
  await pumpHome(tester, summary: summary4of8);
  expect(find.byType(HomeTodayTiles), findsOneWidget);
});
testWidgets('Start lesson 4 navigates to lesson 4 with chosen mode', ...);
testWidgets('no enrolled path → Choose your first path', ...);
testWidgets('guest sees Save progress row', ...);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/home/presentation/pages/home_today_layout_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the assembly and flag switch. Starting a lesson does `context.push(buildLessonLaunchFromSummary(summary, mode, language))`, then on return `homeBloc.add(const LoadActiveLearningPath(forceRefresh: true))`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/home`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(home): today layout behind the home_today_layout flag"
```

---

### Task 9: Phase verification

- [ ] Run `cd frontend && flutter analyze && flutter test`. Expected: clean, PASS.
- [ ] Run `cd backend/supabase/functions && deno test learning-paths/`. Expected: PASS.
- [ ] Locally: `update feature_flags set is_enabled=true, rollout_percentage=100 where feature_key='home_today_layout'`. On web (run alone), check:
  - a new account sees "Choose your first path"
  - after lesson 1, Home shows lesson 2 with "Today" under dot 2
  - completing lesson 1 then reopening the next day shows the paths banner
  - dismissing it, restarting and switching to Hindi does not bring it back
  - a 22-lesson path shows the smooth bar

## Self-review notes

- **Spec coverage:**
  - shipped header + pill rule → Tasks 5, 8
  - verse "Reflect" link + icons → Task 8
  - strip tiers + "Today" only → Task 3
  - lesson card + chip + single primary + no "Next:" → Task 4
  - lessons 2+ default Standard → Task 8 via `resolveNextLessonMode`
  - first-path chooser only when no goal/path → Task 5
  - guest row → Task 5
  - New for you (max 1/week, dismissible, persisted, never gating, 5 kinds incl. language-matched public fellowships) → Tasks 6–7
  - intros → Task 7
  - dock unchanged (no change)
- Lesson-complete "continue now" (no day gate) is owned by Phase A; Home never says "Tomorrow".
- Explore access: every feature remains in its tab, so no Explore screen is built and no UI text references one.
