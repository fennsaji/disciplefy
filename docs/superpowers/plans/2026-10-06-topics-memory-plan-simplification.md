# Topics, Memory Verses, My Plan Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the secondary tabs a new user meets, following the final designs:
- Topics opens on the current path and real categories, with an All paths screen behind it.
- Memory verses keeps its shipped flow but loses the guilt and the noise.
- My Plan becomes one honest summary.
- Settings and Community get small clarity fixes.
- The app uses one word for each thing ("lesson", "credits").
- XP, levels and leaderboards leave new-user surfaces.

**Architecture:** These are in-place edits to shipped screens; there is no flag. The new pieces are:
- `AllPathsPage` (route `/paths`)
- `PlanSummaryCard`
- `SettingsMorePage`
- `MemoryHeaderLine`
- a wording-guard test that scans the translation maps for banned words in user-visible namespaces

The tasks are independent of one another unless an Interfaces block says otherwise.

**Tech Stack:** Flutter (BLoC, go_router), translations in `frontend/lib/core/i18n/`.

**Spec:** `docs/ux/design-final/learning-paths.png`, `memory-verses.png`, `account-plans-credits.png`, `settings.png`, `community-fellowships.png`, `discipler.png`; tab simplification review; final design review P1 items 7–12; audit §4 glossary; roadmap `docs/superpowers/plans/2026-10-06-new-user-experience-roadmap.md`.

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
- **Dependencies.**
  - Phase A Task 5: `normalizePlanCode`, `currentPlanCode`, honest marketing copy.
  - Phase A Task 6: one streak.
  - Phase C Task 3: `PathProgressStrip`, which is used on the Topics current-path card. Task 1 also uses `ActivePathSummary` (Phase C Task 2). If Phase C has not merged, implement Phase C Tasks 2 and 3 first; they are self-contained.
- **Memory verses.** Keep the shipped flow: verse list → tap a verse → choose a practice mode → practice. Do not add "Practise now" or "Change mode".
- **Leaderboard and streak tiles.** Keep both tiles on Topics, as the design shows. The Leaderboard page is the only place XP appears outside My progress. Neither tile shows an XP number.
- **Lesson rows.** Milestone tags stay on path lesson rows; they are labelled "Milestone".

## Review Focus

- **A user with 0 paths enrolled opens Topics.** The current-path card is replaced by a "Start a path" prompt, not an empty strip. Categories still load.
- **A memory verse that is 30 days overdue.** It shows a neutral "Due" tag in the theme's muted colour, not red, with no "30 days" text. Tapping the verse still opens the practice mode chooser.
- **A Plus user on Android with a `google_play` subscription.** The My Plan summary shows "Plus", the renewal date, "Billed via Google Play" and "Cancel plan". A trial user sees none of the billing lines.
- **An English user opens Community → Discover.** It defaults to English groups, so "Disciplefy हिन्दी" is not first. Joining opens the group with a confirmation.
- **The wording guard.** No user-visible en string under the path, home, generate, credits or plan namespaces contains "Token", "Topic" (in path context) or "XP" on new-user surfaces. hi/ml use one term for memory verses.

---

## File Structure

| File | Responsibility |
|---|---|
| `frontend/lib/features/study_topics/presentation/pages/study_topics_screen.dart:556-660` | Topics layout |
| `frontend/lib/features/study_topics/presentation/widgets/topics_current_path_card.dart` (new) | Current path + strip + Continue |
| `frontend/lib/features/study_topics/presentation/pages/all_paths_page.dart` (new) | All paths + category chips |
| `frontend/lib/features/study_topics/presentation/widgets/path_list_row.dart:14-31` | Meta without level/XP |
| `frontend/lib/features/study_topics/presentation/widgets/learning_path_detail_parts.dart` | Lesson rows without XP/category |
| `frontend/lib/features/memory_verses/presentation/pages/memory_verses_home_page.dart:519-921` | Empty state, header line, ⋮ menu |
| `frontend/lib/features/memory_verses/presentation/widgets/memory_verse_list_item.dart:212-225` | Neutral Due tag |
| `frontend/lib/features/memory_verses/presentation/widgets/verse_flip_card.dart:261-263` | Remove "Ease" |
| `frontend/lib/features/subscription/presentation/widgets/plan_summary_card.dart` (new) | One summary |
| `frontend/lib/features/subscription/presentation/pages/my_plan_page.dart` | Use the summary card |
| `frontend/lib/features/tokens/presentation/pages/token_management_page.dart` | Simplified Credits page |
| `frontend/lib/features/settings/presentation/pages/settings_more_page.dart` (new), `settings_screen.dart:207-560` | Shorter Settings |
| `frontend/lib/features/community/presentation/screens/community_tab_screen.dart:468-600, 816-1000` | Discover defaults, join confirmation, single join entry |
| `frontend/lib/core/i18n/translations_*.dart` | Wording |
| `frontend/test/core/i18n/wording_guard_test.dart` (new) | Banned-words guard |

---

### Task 1: Topics — current path card, categories with "See all", "Browse all paths"

**Files:**
- Create: `frontend/lib/features/study_topics/presentation/widgets/topics_current_path_card.dart`
- Modify: `frontend/lib/features/study_topics/presentation/pages/study_topics_screen.dart`:
  - In `_buildBody` (L556), remove `ForYouLearningPathsSection` and the level filter chips (`LearningPathsSection._buildFilterChips` L532 is hidden through a new `showFilters: false` parameter).
  - Replace `_buildContinueCard` with `TopicsCurrentPathCard`.
  - Add a "Browse all paths" outlined button at the bottom that does `context.push(AppRoutes.allPaths)`.
- Modify: i18n
  - `topics.title`: "Topics" (unchanged); the "Study Topics" heading is removed.
  - `topics.browse_all` = "Browse all paths" / "सभी पथ देखें" / "എല്ലാ പാതകളും"
  - `topics.continue` = "Continue" / "जारी रखें" / "തുടരുക"
  - `topics.start_a_path` = "Start a path" / "पथ शुरू करें" / "പാത തുടങ്ങാം"
  - `topics.see_all` = "See all" / "सभी" / "എല്ലാം"
- Test: `frontend/test/features/study_topics/presentation/pages/topics_layout_test.dart`

**Interfaces:**
- Consumes:
  - `PathProgressStrip` (Phase C Task 3).
  - `buildLessonLaunchLocation` (Phase A Task 1).
  - The `HomeBloc` `activePathSummary` (Phase C Task 2) when it is available. Otherwise, the existing `TopicsContinueCard` data source (`LearningPathsRepository.getRecommendedPath`).
- Produces: `TopicsCurrentPathCard({required ActivePathSummary? summary, required VoidCallback onContinue, required VoidCallback onSeePath, required VoidCallback onBrowse})`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('Topics: current path, Continue, streak + Leaderboard tiles, categories with See all, Browse all paths; no For you, no level chips', (tester) async {
  await pumpTopics(tester, summary: summary4of8, categories: [cat('Foundations', 2), cat('Gospels', 1)]);
  expect(find.text('New Believer Essentials'), findsWidgets);
  expect(find.text('Continue'), findsOneWidget);
  expect(find.text('See all'), findsNWidgets(2));
  expect(find.text('Browse all paths'), findsOneWidget);
  expect(find.byType(ForYouLearningPathsSection), findsNothing);
  expect(find.text('Seeker'), findsNothing);
  expect(find.textContaining('XP'), findsNothing);
});
testWidgets('no enrolled path shows Start a path', ...);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/study_topics/presentation/pages/topics_layout_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the card. It shows:
  - a header row (title + "See path ›")
  - a `PathProgressStrip`
  - a 40px "Continue" button that opens `next` using `resolveNextLessonMode()`

  When `summary == null`, show "Start a path" with a button that does `onBrowse`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && flutter test test/features/study_topics`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(topics): lead with the current path and categories"
```

---

### Task 2: All paths screen with category chips

**Files:**
- Create: `frontend/lib/features/study_topics/presentation/pages/all_paths_page.dart`
- Modify: `frontend/lib/core/router/app_routes.dart` (`allPaths = '/paths'`) and `app_router.dart` (route under the Topics branch so the dock stays visible)
- Modify: i18n
  - `all_paths.title` = "All paths" / "सभी पथ" / "എല്ലാ പാതകളും"
  - `all_paths.count` = "{n} paths" / "{n} पथ" / "{n} പാതകൾ"
  - `all_paths.all` = "All" / "सभी" / "എല്ലാം"
  - `all_paths.current` = "Current" / "वर्तमान" / "ഇപ്പോൾ"
  - `all_paths.lesson_of` = "Lesson {n} of {total}" / "पाठ {n}/{total}" / "പാഠം {n}/{total}"
- Test: `frontend/test/features/study_topics/presentation/pages/all_paths_page_test.dart`

**Interfaces:**
- Consumes: the `LearningPathsBloc` events `LoadFlatLearningPaths` (existing; the flat list) and `LoadMorePathsForCategory`; `PathListRow` (Task 3).
- Produces:
  - `AllPathsPage({String? initialCategory})`.
  - The current path is pinned first with a gold "Current" tag and "Lesson N of M".
  - Category chips (`All`, then the categories in `display_order`) filter client-side. A search icon reuses the existing `SearchLearningPaths`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('current path pinned with Current tag; chips filter', (tester) async {
  await pumpAllPaths(tester, paths: [pathA(category: 'Foundations', enrolled: true, progress: 4, total: 8), pathB(category: 'Gospels')]);
  expect(tester.getTopLeft(find.text('Current')).dy < tester.getTopLeft(find.text(pathB.title)).dy, isTrue);
  expect(find.text('Lesson 4 of 8'), findsOneWidget);
  await tester.tap(find.text('Gospels')); await tester.pumpAndSettle();
  expect(find.text(pathA.title), findsNothing);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/study_topics/presentation/pages/all_paths_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** Chips are 32px; the selected chip is gold. Rows use `PathListRow`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && flutter test test/features/study_topics`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(topics): All paths screen with category chips"
```

---

### Task 3: Path rows and path detail without XP and level jargon; items are "lessons"

**Files:**
- Modify: `frontend/lib/features/study_topics/presentation/widgets/path_list_row.dart:26-31` (meta becomes `'{n} lessons · {d} days'`, plus "Lesson N of M" in gold for an enrolled path)
- Modify: `frontend/lib/features/study_topics/presentation/widgets/learning_path_detail_parts.dart` (lesson rows: remove the `+{xp} XP` and category chips; keep `Milestone`; the current lesson shows a "Today" caption)
- Modify: `frontend/lib/features/study_topics/presentation/pages/learning_path_category_page.dart` (rows use the same meta)
- Modify: `frontend/lib/features/study_generation/presentation/pages/study_guide_screen_v2.dart` `_completeTopicProgress` (L1818-1887): remove the "+{xp} XP earned" snackbar
- Modify: the achievement pop-up listener (find it with `grep -rn "QueueAchievementNotifications\|AchievementNotification" frontend/lib --include=*.dart`): while the current route starts with `/study-guide`, keep notifications queued and flush them when `LessonCompletePage` opens
- Modify: i18n (en / hi / ml)
  - `learning_paths.lessons_days` = "{n} lessons · {d} days" / "{n} पाठ · {d} दिन" / "{n} പാഠം · {d} ദിവസം"
  - Every en value under `learning_paths.*` that says "topic"/"Topics" changes to "lesson"/"Lessons"; hi uses पाठ, ml uses പാഠം.
- Test: `frontend/test/features/study_topics/presentation/widgets/path_list_row_test.dart`

**Interfaces:** Produces `PathListRow({required LearningPath path, int? currentLesson, VoidCallback? onTap})`, which Task 2 uses.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('row meta: lessons and days only', (tester) async {
  await tester.pumpWidget(welcomeApp(screen: PathListRow(path: lp(topicsCount: 5, estimatedDays: 21, totalXp: 250, discipleLevel: 'seeker'))));
  expect(find.text('5 lessons · 21 days'), findsOneWidget);
  expect(find.textContaining('XP'), findsNothing);
  expect(find.textContaining('Seeker'), findsNothing);
});
testWidgets('enrolled row shows Lesson N of M in gold', ...);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/study_topics/presentation/widgets/path_list_row_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the row and the detail changes. Keep `path_level_style.dart` only where the Leaderboard and admin views use it.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/study_topics test/features/study_generation`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(paths): lessons instead of topics and no XP on path lists"
```

---

### Task 4: Memory verses — "Save today's verse", neutral Due, one-line stats, ⋮ menu

**Files:**
- Modify: `frontend/lib/features/memory_verses/presentation/pages/memory_verses_home_page.dart`:
  - `_buildEmptyState` (L685-729): a verse-of-the-day card with the primary "Save today's verse" and a small "+ Add a verse" button. The footnote reads "Saved verses come back for a short review when they are due."
  - `_buildStatTiles` (L577) is replaced by `MemoryHeaderLine`.
  - `_buildQuickLinks` (L550) is removed from the body. An AppBar `PopupMenuButton` (⋮) holds Add verse, Statistics and Champions.
  - `_buildLanguageFilter` (L893-921) is shown only when the user has verses in ≥2 languages.
- Create: `frontend/lib/features/memory_verses/presentation/widgets/memory_header_line.dart`
- Modify: `frontend/lib/features/memory_verses/presentation/widgets/memory_verse_list_item.dart:212-225`: `_dueLabel` returns the key `memory.due` ("Due" / "आज दोहराएँ" / "ഇന്ന്") in `context.appTextSecondary` when `daysOverdue >= 0` and due. Never red, never "x days overdue". Also remove the difficulty tag.
- Modify: `frontend/lib/features/memory_verses/presentation/widgets/verse_flip_card.dart:261-263` (remove the "Ease {value}" text)
- Modify: i18n (en / hi / ml)
  - `memory.save_todays_verse` = "Save today's verse" / "आज का वचन सहेजें" / "ഇന്നത്തെ വചനം സേവ് ചെയ്യുക"
  - `memory.add_verse` = "Add a verse" / "वचन जोड़ें" / "വചനം ചേർക്കുക"
  - `memory.header_line` = "{streak}-day streak · {count} verses" / "{streak} दिन लगातार · {count} वचन" / "{streak} ദിവസം · {count} വാക്യം"
  - `memory.footnote` = "Saved verses come back for a short review when they are due." / "सहेजे वचन समय पर दोहराने के लिए लौटते हैं।" / "സേവ് ചെയ്ത വാക്യങ്ങൾ സമയത്ത് തിരികെ വരും."
  - `memory.statistics` = "Statistics" / "आँकड़े" / "സ്ഥിതിവിവരം"
  - `memory.champions` = "Champions" / "चैंपियन" / "ചാമ്പ്യന്മാർ"
- Test: `frontend/test/features/memory_verses/presentation/memory_home_simplified_test.dart`

**Interfaces:**
- Consumes: `DailyVerseBloc` (today's verse); the existing "add from daily" path used by `SuggestedVersesSheet.onAddFromDaily` (`suggested_verses_sheet.dart:29,44`). Call that same handler directly from the primary button.
- Produces:
  - `MemoryHeaderLine({required int streak, required int verseCount})`.
  - The shipped flow is unchanged: tapping a verse still pushes `PracticeModeSelectionPage`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('empty: Save today\'s verse is the primary action', (tester) async {
  await pumpMemoryHome(tester, verses: []);
  expect(find.widgetWithText(FilledButton, "Save today's verse"), findsOneWidget);
  expect(find.text('Add a verse'), findsOneWidget);
});
testWidgets('overdue verse: neutral Due, no red, no days, no difficulty', (tester) async {
  await pumpMemoryHome(tester, verses: [verse(daysOverdue: 30, ease: 1.8)]);
  final due = tester.widget<Text>(find.text('Due'));
  expect(due.style?.color, isNot(AppColors.error));
  expect(find.textContaining('overdue'), findsNothing);
  expect(find.text('Hard'), findsNothing);
});
testWidgets('stats one line; Statistics and Champions only in the menu', (tester) async {
  await pumpMemoryHome(tester, verses: [verse()], streak: 1);
  expect(find.text('1-day streak · 1 verses'), findsOneWidget); // en plural handled by key text "{count} verses"
  expect(find.text('Champions'), findsNothing);
  await tester.tap(find.byIcon(Icons.more_vert)); await tester.pumpAndSettle();
  expect(find.text('Champions'), findsOneWidget);
});
testWidgets('tapping a verse still opens the practice mode chooser', ...);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/memory_verses/presentation/memory_home_simplified_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the changes listed in Files. For English plurals use `{count} verse` / `{count} verses` with a `count == 1` check in Dart (two keys: `memory.header_line_one`, `memory.header_line`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/memory_verses`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(memory): calmer Memory Verses with a neutral Due tag"
```

---

### Task 5: My Plan as one honest summary; a simpler Credits page

**Files:**
- Create: `frontend/lib/features/subscription/presentation/widgets/plan_summary_card.dart`
- Modify: `frontend/lib/features/subscription/presentation/pages/my_plan_page.dart` (the body becomes `PlanSummaryCard` + the "Plan features" list + "View plans"; remove the duplicate status/billing blocks that Phase A already fixed)
- Modify: `frontend/lib/features/tokens/presentation/pages/token_management_page.dart`. Keep:
  - the balance ring "30 of 40"
  - "Resets at 5:30 AM"
  - the 3 tiles (used today / purchased / total)
  - "Get credits" and "Upgrade" buttons
  - one plan row (name + "Manage")
  - "What a study costs" as one line built from `TokenCostRepository` for the current content language, e.g. "Quick Read 10 · Standard 20 · Deep Dive 30 · Follow-up 5"

  Remove the `_PlanAllowances` multi-plan table and the per-language EN/HI/ML table.
- Modify: i18n (en / hi / ml)
  - `plan.trial_until` = "Free trial until {date}" / "{date} तक मुफ़्त ट्रायल" / "{date} വരെ സൗജന്യ ട്രയൽ"
  - `plan.left_today` = "{n} left today" / "आज {n} बचे" / "ഇന്ന് {n} ബാക്കി"
  - `plan.resets_at` = "Resets at {time}" / "{time} पर फिर से" / "{time}-ന് പുതുക്കും"
  - `plan.billed_via` = "Billed via {provider}" / "{provider} से बिलिंग" / "{provider} വഴി ബില്ലിംഗ്"
  - `plan.view_plans` = "View plans" / "प्लान देखें" / "പ്ലാനുകൾ"
  - `credits.study_costs` = "What a study costs" / "एक अध्ययन की लागत" / "ഒരു പഠനത്തിന്"
- Test: `frontend/test/features/subscription/presentation/widgets/plan_summary_card_test.dart`, `frontend/test/features/tokens/presentation/credits_simplified_test.dart`

**Interfaces:**
- Consumes: `normalizePlanCode`, `providerLabelOrNull`, `currentPlanCode` (Phase A Task 5); `TokenStatus`; `UserSubscriptionStatus.trialEndDate`.
- Produces: `PlanSummaryCard({required String planName, required bool isTrial, DateTime? trialEnds, DateTime? renewsOn, String? providerLabel, required int left, required int dailyLimit, required DateTime? resetsAt, required Map<StudyMode,int> costs})`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('trial: name, Trial tag, until date, ring, cost line; no billing', (tester) async {
  await tester.pumpWidget(welcomeApp(screen: PlanSummaryCard(planName: 'Standard', isTrial: true, trialEnds: DateTime(2027, 3, 31),
      left: 30, dailyLimit: 40, resetsAt: DateTime(2026, 10, 7, 5, 30), costs: {StudyMode.quick: 10, StudyMode.standard: 20})));
  expect(find.text('Standard'), findsOneWidget);
  expect(find.text('Trial'), findsOneWidget);
  expect(find.text('Free trial until March 31, 2027'), findsOneWidget);
  expect(find.text('30 left today'), findsOneWidget);
  expect(find.text('Quick Read 10 · Standard 20'), findsOneWidget);
  expect(find.textContaining('Billed via'), findsNothing);
});
testWidgets('paid Plus on Google Play: renewal and billing shown', ...);
testWidgets('Credits page: one cost line, no per-language table, no "Token"', ...);
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/subscription test/features/tokens`
Expected: FAIL.

- [ ] **Step 3: Implement** the card and both page edits. Format dates with `DateFormat.yMMMMd(localeFor(language))` (the same locale mapping as Phase A Task 8).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/subscription test/features/tokens`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(plan): one plan summary and a simpler Credits page"
```

---

### Task 6: Settings — one list; study, help and legal rows under "More"

**Files:**
- Create: `frontend/lib/features/settings/presentation/pages/settings_more_page.dart`
- Modify: `frontend/lib/features/settings/presentation/pages/settings_screen.dart` `_buildSettingsList` (L207-238). The main list keeps:
  - Profile, verify banner
  - **You:** My progress, Reflection journal, My plan
  - **Preferences:** Theme, App language, Content language, Notifications, Offline guides, Text size
  - **More** (one row → `SettingsMorePage`)
  - Sign out / Delete

  `SettingsMorePage` holds Study (Study mode, Learning path mode, Retake questionnaire), Help (Feedback, Report purchase issue, Contact, Replay walkthrough) and About (Support, Bible attribution, Privacy, Terms, Refund, Version).
- Modify: `frontend/lib/core/router/app_routes.dart` (`settingsMore = '/settings/more'`) and `app_router.dart`
- Modify: i18n `settings.more` = "More" / "और" / "കൂടുതൽ"
- Modify: My progress (`stats_dashboard_page.dart`): keep XP and levels here only, renamed per audit §4. "Seeker" level title stays, but the subtitle explains "Level 1". Do not remove the page.
- Test: `frontend/test/features/settings/settings_more_test.dart`

**Interfaces:** Produces `SettingsMorePage()`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('main Settings has ≤14 rows and a More row; policies live in More', (tester) async {
  await pumpSettings(tester);
  expect(find.text('Privacy Policy'), findsNothing);
  await tester.tap(find.text('More')); await tester.pumpAndSettle();
  expect(find.text('Privacy Policy'), findsOneWidget);
  expect(find.text('Learning Path Study Mode'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/settings/settings_more_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** Move the existing row builders as-is into the new page; do not duplicate them.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/settings`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(settings): shorter Settings with a More page"
```

---

### Task 7: Community — language-matched Discover, join confirmation, one join entry, "Guided by Discipler"

**Files:**
- Modify: `frontend/lib/features/community/presentation/screens/community_tab_screen.dart`:
  - L484-491: the first load uses `DiscoverLoadRequested(language: sl<TranslationService>().currentLanguage.code)` instead of all languages.
  - Remove the floating "Join a fellowship" button, which duplicates the key icon.
  - Label the header icons with tooltips / Semantics ("Join with a code", "Create a fellowship").
  - On a successful join from `DiscoverFellowshipCard`, `context.push('/community/fellowship/$id')` and show the snackbar `community.joined` = "You joined {name}" / "आप {name} से जुड़े" / "{name}-ൽ ചേർന്നു".
- Modify: `frontend/lib/features/community/presentation/screens/fellowship_home_screen.dart` / `widgets/fellowship_card_parts.dart`: the label "Mentor: Discipler" → `community.guided_by_discipler` = "Guided by Discipler" / "Discipler द्वारा" / "Discipler നയിക്കുന്നു". No "AI" wording.
- Modify: `frontend/lib/features/community/presentation/screens/fellowship_home_screen.dart`: hide the empty "Meetings" row when there are none; keep one post button (remove the duplicate "Post something" composer row when "New Post" exists).
- Test: `frontend/test/features/community/presentation/discover_defaults_test.dart`

**Interfaces:** Consumes the `DiscoverBloc` event `DiscoverLoadRequested({language, search})`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('Discover defaults to the app language', (tester) async {
  translations.setLanguage('en');
  await pumpCommunity(tester, tab: 'discover');
  verify(() => discoverBloc.add(const DiscoverLoadRequested(language: 'en'))).called(1);
});
testWidgets('joining opens the group with a confirmation', ...);
testWidgets('no "Mentor:" label', ...);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/community/presentation/discover_defaults_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/community`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(community): language-matched Discover and clear join"
```

---

### Task 8: Wording unification and a guard test

**Files:**
- Modify: `frontend/lib/core/i18n/translations_en.dart`, `translations_hi.dart`, `translations_ml.dart`, `frontend/lib/core/localization/app_localizations.dart` (nav and legacy strings)
- Create: `frontend/test/core/i18n/wording_guard_test.dart`

**Interfaces:** Produces the guard test. Later phases extend `guardedNamespaces` as they add namespaces.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_en.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_hi.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_ml.dart';

Iterable<MapEntry<String, String>> flatten(Map<String, dynamic> m, [String p = '']) sync* {
  for (final e in m.entries) {
    final k = p.isEmpty ? e.key : '$p.${e.key}';
    if (e.value is Map<String, dynamic>) { yield* flatten(e.value as Map<String, dynamic>, k); }
    else if (e.value is String) { yield MapEntry(k, e.value as String); }
  }
}

const guardedNamespaces = ['home', 'home_today', 'learning_paths', 'lesson', 'generate_simple', 'credits', 'plan', 'tokens', 'first_run', 'account', 'nfy', 'intro', 'topics', 'all_paths', 'memory'];

void main() {
  bool guarded(String k) => guardedNamespaces.any((n) => k.startsWith('$n.'));

  test('English: credits not tokens, lessons not topics in paths, no XP on new-user surfaces, no "AI"', () {
    final bad = <String>[];
    for (final e in flatten(englishTranslations).where((e) => guarded(e.key))) {
      final v = e.value;
      if (RegExp(r'\btokens?\b', caseSensitive: false).hasMatch(v)) bad.add('${e.key}: token');
      if (e.key.startsWith('learning_paths.') && RegExp(r'\btopics?\b', caseSensitive: false).hasMatch(v)) bad.add('${e.key}: topic');
      if (RegExp(r'\bXP\b').hasMatch(v) && !e.key.contains('leaderboard')) bad.add('${e.key}: XP');
      if (RegExp(r'\bAI\b').hasMatch(v)) bad.add('${e.key}: AI');
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('Hindi uses one memory-verse term and no स्ट्रीक', () {
    final values = flatten(hindiTranslations).map((e) => e.value);
    expect(values.where((v) => v.contains('याद वर्सेज') || v.contains('स्मृति आयतें')), isEmpty);
    expect(values.where((v) => v.contains('स्ट्रीक')), isEmpty);
  });

  test('every guarded en key exists in hi and ml', () {
    final hi = Map.fromEntries(flatten(hindiTranslations));
    final ml = Map.fromEntries(flatten(malayalamTranslations));
    final missing = flatten(englishTranslations).where((e) => guarded(e.key))
        .where((e) => !hi.containsKey(e.key) || !ml.containsKey(e.key)).map((e) => e.key).toList();
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
```

- [ ] **Step 2: Run the test to see the current violations**

Run: `cd frontend && flutter test test/core/i18n/wording_guard_test.dart`
Expected: FAIL, with a list of keys.

- [ ] **Step 3: Rewrite each flagged value.**
  - en: "tokens" → "credits", "topic(s)" → "lesson(s)" in path strings, drop "XP" from non-leaderboard strings, drop "AI".
  - hi: "याद वर्सेज" and "स्मृति आयतें" → "याद वचन" (short; the audit's "याद करने के वचन" is too long for the pill); "स्ट्रीक" → "लगातार दिन".
  - ml: "മെമ്മറി വേഴ്സ്" → "സ്മരണ വാക്യങ്ങൾ" (already used by `home.memory_verses`).
  - Keep all values short (≤1.3× English).
  - Apply the same replacements in `app_localizations.dart` for `navLabel` and memory strings.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/core/i18n && flutter test`
Expected: PASS. If widget tests assert the old strings, update them.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "chore(i18n): one word for lessons and credits across the app"
```

---

### Task 9: Phase verification

- [ ] Run `cd frontend && flutter analyze && flutter test`. Expected: clean, PASS.
- [ ] Manual check on web, running nothing else at the same time:
  - Topics leads with the current path.
  - "Browse all paths" opens All paths with the current path pinned.
  - Memory: the empty state works, and an overdue verse shows neutral "Due". Tapping a verse opens the practice modes.
  - My Plan shows the trial summary.
  - Discover is in English by default.

## Self-review notes

- Spec coverage:
  - Topics/All paths/category: Tasks 1–3.
  - XP off new-user surfaces: Tasks 1, 3, 8.
  - Memory verses (owner's reduced scope): Task 4.
  - My Plan and Credits: Task 5.
  - Settings: Task 6.
  - Community: Task 7.
  - Wording: Task 8.
- Discipler sheet polish (rating after the 3rd chat, warning before quota use, audit P1-6) is not in the owner's list for this phase. It is noted as an open question in the roadmap rather than planned here.
