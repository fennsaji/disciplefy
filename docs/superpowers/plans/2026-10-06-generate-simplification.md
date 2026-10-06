# Generate Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate becomes one screen with one decision before value. The user types (or taps) a verse, topic or question, keeps Quick Read or Standard, and taps "Generate study" (the cost shows under it). The streaming guide then opens straight away.

**Architecture:**
- A new `GenerateSimpleScreen` is selected in the Generate branch route by `RolloutFlags.generateSingleInput`. The shipped `GenerateStudyScreen` stays for flag-off.
- Input type detection is a pure function, `detectStudyInput`, built on `BibleBooks.createScriptureRegex()`.
- Navigation reuses the shipped `/study-guide-v2` streaming route and cache/credit checks. Those are extracted from `generate_study_screen.dart:1913-1990` into a shared `StudyLaunchService`, so both screens use the same code.
- The out-of-credits sheet reads one `TokenStatus`, so the header pill and the sheet always show the same number.
- The backend sends the real section total per mode, so a Quick Read stream shows only Quick Read segments.

**Tech Stack:** Flutter (BLoC, go_router), Deno (`study-generate-v2`, `streaming-json-parser`).

**Spec:** `docs/ux/design-final/study-generate.png`, `docs/ux/2026-10-07-tab-simplification-review.md` (Generate), final design review (Study (Generate) + P0-3, P0-6), roadmap `docs/superpowers/plans/2026-10-06-new-user-experience-roadmap.md`.

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
- Depends on Phase A Task 9 (`ownOnly` "Continue reading") and Phase B Task 1 (`RolloutFlags`).
- **Depth names.** Use the shipped names exactly (Quick Read, Standard Study, Deep Dive, Lectio Divina, Sermon Outline) through the existing `StudyMode.localizedName`. The two-segment switch uses the short names "Quick Read · 3 min" / "Standard · 8 min".
- **Credits.** No credit chips on the depth switch. The only cost line is "Using N credits" under the button. The header pill shows the balance.
- **Tours.** No tours on this screen.

## Review Focus

- **Ambiguous input.** "Psalm 23" (chapter only), "1 Cor 13:4-7", "यूहन्ना 3:16", "യോഹന്നാൻ 3:16", "Why did Jesus die" (no "?"), "Grace" and "John" (a book with no chapter) must be classified as scripture / scripture / scripture / scripture / question / topic / topic. The user can fix a wrong guess by tapping the type tag.
- **Not enough credits.** The header shows 5, Standard costs 20, and the sheet says "You need 20 credits — 5 left today". The two numbers come from the same `TokenStatus`.
- **Cached guide.** Opening a guide the user already has must not ask for credits, matching today's `StudyLocalDataSource` cache check.
- **Quick Read streaming** shows only Quick Read sections and a matching segment count. There is no "Context" skeleton.
- **Malayalam UI at 360px.** The title, input hint, switch, button and "Using N credits" fit. `ml` costs are higher (15/35), and the line must show the `ml` number.

---

## File Structure

| File | Responsibility |
|---|---|
| `frontend/lib/features/study_generation/domain/utils/detect_study_input.dart` (new) | Pure verse/question/topic detection + validation |
| `frontend/lib/features/study_generation/presentation/services/study_launch_service.dart` (new) | Cache check, credit check, navigation (extracted) |
| `frontend/lib/features/study_generation/presentation/pages/generate_simple_screen.dart` (new) | The new screen |
| `frontend/lib/features/study_generation/presentation/widgets/simple/depth_switch.dart` (new) | Quick/Standard + "All 5" |
| `frontend/lib/features/study_generation/presentation/widgets/simple/verse_of_day_row.dart` (new) | Ready-start row |
| `frontend/lib/features/study_generation/presentation/widgets/simple/input_type_tag.dart` (new) | Detected-type tag (tappable to change) |
| `frontend/lib/features/subscription/presentation/widgets/out_of_credits_sheet.dart` (new) | Honest sheet |
| `frontend/lib/core/router/app_router.dart:193-196` | Flag switch |
| `backend/supabase/functions/_shared/services/streaming-json-parser.ts:60-80,457-460` | Mode-aware total |

---

### Task 1: `detectStudyInput`

**Files:**
- Create: `frontend/lib/features/study_generation/domain/utils/detect_study_input.dart`
- Test: `frontend/test/features/study_generation/domain/detect_study_input_test.dart`

**Interfaces:**
- Consumes: `BibleBooks.createScriptureRegex()` (`frontend/lib/core/constants/bible_books.dart:381`).
- Produces:
  - `enum DetectedInputType { scripture, topic, question }`, with `String get apiValue` returning `'scripture' | 'topic' | 'question'`.
  - `class DetectedInput { final DetectedInputType type; final String text; final bool isValid; }`
  - `DetectedInput detectStudyInput(String raw)`. The rules:
    1. Trim the input and collapse whitespace.
    2. If the whole string matches the scripture regex (`^…$`), or it is a known book name followed by a chapter, it is scripture.
    3. If it ends with `?`, or starts with a question word, it is a question. Question words: en `what why how who when where which is are can does do did should will`, hi `क्या क्यों कैसे कौन कब कहाँ`, ml `എന്ത് എന്തുകൊണ്ട് എങ്ങനെ ആര് എപ്പോൾ എവിടെ`, or a ml word ending with `ോ?`.
    4. Otherwise it is a topic.
    5. `isValid` is: scripture always, question when length ≥ 10, topic when length ≥ 2.

- [ ] **Step 1: Write the failing test**

```dart
void main() {
  final cases = <String, DetectedInputType>{
    'John 3:16': DetectedInputType.scripture,
    'Psalm 23': DetectedInputType.scripture,
    '1 Cor 13:4-7': DetectedInputType.scripture,
    'Romans 8': DetectedInputType.scripture,
    'यूहन्ना 3:16': DetectedInputType.scripture,
    'യോഹന്നാൻ 3:16': DetectedInputType.scripture,
    'What is the purpose of prayer?': DetectedInputType.question,
    'Why did Jesus die': DetectedInputType.question,
    'क्या परमेश्वर मुझसे प्रेम करता है': DetectedInputType.question,
    'Grace': DetectedInputType.topic,
    'Forgiveness': DetectedInputType.topic,
    'John': DetectedInputType.topic,
  };
  cases.forEach((input, type) {
    test('"$input" → $type', () => expect(detectStudyInput(input).type, type));
  });
  test('validity', () {
    expect(detectStudyInput('a').isValid, isFalse);
    expect(detectStudyInput('Why?').isValid, isFalse);
    expect(detectStudyInput('  John   3:16 ').text, 'John 3:16');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/study_generation/domain/detect_study_input_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
DetectedInput detectStudyInput(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  final re = BibleBooks.createScriptureRegex();
  final m = re.firstMatch(text);
  if (m != null && m.start == 0 && m.end == text.length) {
    return DetectedInput(DetectedInputType.scripture, text, true);
  }
  final lower = text.toLowerCase();
  final firstWord = lower.split(' ').first;
  if (text.endsWith('?') || text.endsWith('？') || _questionWords.contains(firstWord)) {
    return DetectedInput(DetectedInputType.question, text, text.length >= 10);
  }
  return DetectedInput(DetectedInputType.topic, text, text.length >= 2);
}
```

If `createScriptureRegex()` requires a verse number, check the "Psalm 23" case. If chapter-only references do not match, extend the check with `BibleBooks.getScripturePattern()` (L346), which already allows an optional `:verse`. Add a unicode-aware `^(<books>)\s+\d+$` fallback built from `BibleBooks.allEnglish/allHindi/allMalayalam`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && flutter test test/features/study_generation/domain/detect_study_input_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(generate): detect verse, topic or question from one input"
```

---

### Task 2: Extract `StudyLaunchService` (shared cache → credits → navigate)

**Files:**
- Create: `frontend/lib/features/study_generation/presentation/services/study_launch_service.dart`
- Modify: `frontend/lib/features/study_generation/presentation/pages/generate_study_screen.dart:1913-1990` (call the service; behaviour unchanged)
- Test: `frontend/test/features/study_generation/presentation/services/study_launch_service_test.dart`

**Interfaces:**
- Produces:
  - `enum LaunchDecision { openCached, openNew, needCredits }`
  - `class StudyLaunchService { StudyLaunchService(this._local); Future<LaunchDecision> decide({required String input, required String type, required String language, required StudyMode mode, required TokenStatus? status, required int cost}); String location({required String input, required String type, required String language, required StudyMode mode, String source = 'generate'}); }`
  - The location is `/study-guide-v2?input=…&type=…&language=…&mode=…&source=generate`.

- [ ] **Step 1: Write the failing test**

```dart
test('cached guide never needs credits', () async {
  when(() => local.getCachedStudyGuides()).thenAnswer((_) async => [cachedGuide(input: 'John 3:16', type: 'scripture', language: 'en', mode: 'quick')]);
  expect(await svc.decide(input: 'John 3:16', type: 'scripture', language: 'en', mode: StudyMode.quick, status: statusWith(total: 0), cost: 10), LaunchDecision.openCached);
});
test('not enough credits', () async {
  when(() => local.getCachedStudyGuides()).thenAnswer((_) async => []);
  expect(await svc.decide(input: 'Romans 8', type: 'scripture', language: 'en', mode: StudyMode.standard, status: statusWith(total: 5), cost: 20), LaunchDecision.needCredits);
});
test('premium never needs credits', () async { /* status.isPremium → openNew */ });
test('location encodes input', () {
  expect(svc.location(input: 'What is grace?', type: 'question', language: 'ml', mode: StudyMode.quick),
      '/study-guide-v2?input=What%20is%20grace%3F&type=question&language=ml&mode=quick&source=generate');
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/study_generation/presentation/services/study_launch_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** by moving the cache match logic from `_navigateToStudyGuide` (L1935+) verbatim into `decide`. Register it in DI as a LazySingleton. Make `GenerateStudyScreen` call it, and keep its existing tests green.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/study_generation`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "refactor(generate): share the study launch checks"
```

---

### Task 3: Honest out-of-credits sheet

**Files:**
- Create: `frontend/lib/features/subscription/presentation/widgets/out_of_credits_sheet.dart`
- Modify: i18n (en / hi / ml)
  - `credits.out_eyebrow` = "Out of credits" / "क्रेडिट खत्म" / "ക്രെഡിറ്റ് തീർന്നു"
  - `credits.out_title` = "Out of study credits" / "अध्ययन क्रेडिट खत्म" / "പഠന ക്രെഡിറ്റ് തീർന്നു"
  - `credits.out_body` = "Come back tomorrow when your credits refresh, or get more now." / "कल क्रेडिट फिर मिलेंगे, या अभी और लें।" / "നാളെ വീണ്ടും ലഭിക്കും, അല്ലെങ്കിൽ ഇപ്പോൾ വാങ്ങാം."
  - `credits.out_need` = "You need {need} credits — {have} left today." / "{need} क्रेडिट चाहिए — आज {have} बचे हैं।" / "{need} വേണം — ഇന്ന് {have} ബാക്കി."
  - `credits.get` = "Get credits" / "क्रेडिट लें" / "ക്രെഡിറ്റ് വാങ്ങുക"
  - `credits.view_saved` = "View saved guides" / "सहेजी गाइड देखें" / "സേവ് ചെയ്തവ"
  - `credits.maybe_later` = "Maybe later" / "बाद में" / "പിന്നീട്"
- Test: `frontend/test/features/subscription/presentation/widgets/out_of_credits_sheet_test.dart`

**Interfaces:**
- Produces: `OutOfCreditsSheet.show(BuildContext context, {required TokenStatus status, required int needed})`.
  - "have" = `status.totalTokens`, the same number the header pill renders (`generate_hero.dart` `TokenBalancePill`).
  - "Get credits" → `context.push(AppRoutes.tokenPurchase, extra: status)` when `status.canPurchaseTokens`. Otherwise → `context.push(AppRoutes.myPlan)`.
  - "View saved guides" → `context.push('/saved?tab=saved&source=generate')`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('header and sheet agree', (tester) async {
  final status = tokenStatus(total: 5);
  await tester.pumpWidget(welcomeApp(screen: Builder(builder: (c) => TextButton(
      onPressed: () => OutOfCreditsSheet.show(c, status: status, needed: 20), child: const Text('go')))));
  await tester.tap(find.text('go')); await tester.pumpAndSettle();
  expect(find.text('You need 20 credits — 5 left today.'), findsOneWidget);
  expect(find.textContaining('Token'), findsNothing);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && flutter test test/features/subscription/presentation/widgets/out_of_credits_sheet_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** a bottom sheet over a dimmed screen. It has a gold icon circle, the eyebrow, title and body, the gold `out_need` line, and three buttons (40px primary, 40px outlined, text button). Do not show a plan table.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && flutter test test/features/subscription`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(credits): out-of-credits sheet that matches the balance"
```

---

### Task 4: `GenerateSimpleScreen`

**Files:**
- Create: `frontend/lib/features/study_generation/presentation/pages/generate_simple_screen.dart`
- Create: `frontend/lib/features/study_generation/presentation/widgets/simple/depth_switch.dart`, `verse_of_day_row.dart`, `input_type_tag.dart`
- Modify: `frontend/lib/core/router/app_router.dart:193-196`:

```dart
builder: (context, state) => MaxWidthWrapper(
    child: sl<RolloutFlags>().generateSingleInput
        ? GenerateSimpleScreen(prefill: state.uri.queryParameters['prefill'])
        : const GenerateStudyScreen()),
```

- Modify: i18n (en / hi / ml)
  - `generate_simple.eyebrow` = "GENERATE A STUDY" / "अध्ययन बनाएँ" / "പഠനം തയ്യാറാക്കാം"
  - `generate_simple.title` = "What shall we study today?" / "आज क्या पढ़ें?" / "ഇന്ന് എന്ത് പഠിക്കാം?"
  - `generate_simple.hint` = "e.g., John 3:16, Forgiveness, or a question" / "जैसे यूहन्ना 3:16, क्षमा, या कोई प्रश्न" / "ഉദാ: യോഹന്നാൻ 3:16, ക്ഷമ, ഒരു ചോദ്യം"
  - `generate_simple.type_scripture` = "Scripture" / "वचन" / "വചനം"
  - `generate_simple.type_topic` = "Topic" / "विषय" / "വിഷയം"
  - `generate_simple.type_question` = "Question" / "प्रश्न" / "ചോദ്യം"
  - `generate_simple.choose_depth` = "Choose depth" / "गहराई चुनें" / "ആഴം"
  - `generate_simple.all_depths` = "All 5" / "सभी 5" / "എല്ലാം 5"
  - `generate_simple.generate` = "Generate study" / "अध्ययन बनाएँ" / "പഠനം തയ്യാറാക്കുക"
  - `generate_simple.using_credits` = "Using {n} credits" / "{n} क्रेडिट लगेंगे" / "{n} ക്രെഡിറ്റ്"
  - `generate_simple.verse_of_day` = "VERSE OF THE DAY" / "आज का वचन" / "ഇന്നത്തെ വചനം"
- Test: `frontend/test/features/study_generation/presentation/pages/generate_simple_screen_test.dart`

**Interfaces:**
- Consumes:
  - `detectStudyInput` (Task 1), `StudyLaunchService` (Task 2), `OutOfCreditsSheet` (Task 3)
  - `TokenBloc`, `DailyVerseBloc`
  - `TokenCostRepository.getTokenCost(language, mode)` (existing)
  - `ModeSelectionSheet.show` (existing, for "All 5")
  - `RecentGuidesSection(ownOnly: true)` (Phase A)
  - `LanguagePreferenceService.getStudyContentLanguage / saveStudyContentLanguage`
  - `SystemConfigService.shouldHideFeature/isFeatureLocked` with `StudyMode.featureKey` (locked modes in "All 5" open `UpgradeDialog`, as today)
- Produces: `GenerateSimpleScreen({String? prefill})`.
  - **Layout (top to bottom):**
    - photo header with the eyebrow and the credits pill (`TokenBalancePill`, reused)
    - the title
    - an input with an inline language pill (reuse `_buildCompactLanguageSelector` logic by moving it into `widgets/simple/language_pill.dart`)
    - `InputTypeTag` (shown once the input is valid; tapping it cycles through scripture → topic → question as a manual override)
    - 3 suggestion chips when the input is empty: the first three of `TranslationKeys.generateStudyTopicSuggestions` / `ScriptureSuggestions`, e.g. "John 3:16", "Forgiveness", "Hope"
    - `VerseOfDayRow` when the input is empty
    - "Choose depth" with the "All 5 ›" link
    - `DepthSwitch(Quick Read · 3 min | Standard · 8 min)`
    - the "Generate study" button (40px; disabled until the input is valid)
    - "Using N credits" (12pt)
    - `RecentGuidesSection(ownOnly: true)` when the keyboard is hidden
  - Tapping `VerseOfDayRow` launches immediately with type scripture and the current depth.
  - When the depth chosen in "All 5" is not quick or standard, the switch shows neither segment selected, and a small label "Deep Dive · 12 min" with the `localizedName` appears under it.
  - **Generate:**
    1. Compute `decide(...)`.
    2. On `needCredits`, show `OutOfCreditsSheet`.
    3. Otherwise, `context.go(location)`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('typing a question tags it and shows cost under the button', (tester) async {
  when(() => costs.getTokenCost('en', 'quick')).thenAnswer((_) async => const Right(10));
  await pumpSimple(tester);
  await tester.enterText(find.byType(TextField), 'What is the purpose of prayer?');
  await tester.pumpAndSettle();
  expect(find.text('Question'), findsOneWidget);
  expect(find.text('Using 10 credits'), findsOneWidget);
  expect(find.text('Scripture'), findsNothing); // no type tabs
});
testWidgets('no type tabs, ≤3 chips, verse row, two depths + All 5', (tester) async {
  await pumpSimple(tester);
  expect(find.byType(InputTypeTabs), findsNothing);
  expect(find.byKey(const Key('suggestion_chip')), findsNWidgets(3));
  expect(find.byType(VerseOfDayRow), findsOneWidget);
  expect(find.text('All 5'), findsOneWidget);
});
testWidgets('Generate opens the streaming guide directly', (tester) async {
  // enter 'Romans 8', tap Generate study → router location starts with /study-guide-v2 and type=scripture&mode=quick
});
testWidgets('not enough credits opens the honest sheet', ...);
testWidgets('verse of the day row starts immediately', ...);
testWidgets('ml at 360px: no truncation', (tester) async {
  await loadAppFonts(); tester.view.physicalSize = const Size(360, 800); tester.view.devicePixelRatio = 1;
  await pumpSimple(tester, language: 'ml');
  expectNoTruncatedText(tester);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/features/study_generation/presentation/pages/generate_simple_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the screen as a `StatefulWidget`. The fields are `TextEditingController`, `DetectedInputType? _override`, `StudyMode _mode = StudyMode.quick`, and `Map<StudyMode,int> _costs` (loaded per language through `TokenCostRepository`). Use `Logger` for failures. Do not call `WalkthroughRepository`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/features/study_generation`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(generate): single-input Generate behind generate_single_input"
```

---

### Task 5: Quick Read streams only Quick Read sections

**Files:**
- Modify: `backend/supabase/functions/_shared/services/streaming-json-parser.ts` (constructor takes `mode`; `getTotalSections()` returns `expectedSectionTotal(mode)`)
- Create: `backend/supabase/functions/_shared/services/mode-sections.ts`
- Modify: `backend/supabase/functions/study-generate-v2/index.ts` (pass `study_mode` when creating the parser; cached-guide total at ~L837 uses the guide's real non-empty sections, as today)
- Modify: `frontend/lib/features/study_generation/domain/entities/study_stream_event.dart:204` (default `totalSections` from `StudyMode`: `expectedSectionsFor(mode)` instead of `14`) and the body placeholders (`study_guide_body.dart:123-160`: render skeletons only for sections in `expectedSectionKeysFor(mode)`)
- Test: `backend/supabase/functions/_shared/services/mode-sections.test.ts`, `frontend/test/features/study_generation/domain/expected_sections_test.dart`

**Interfaces:**
- Produces:
  - TS: `MODE_SECTIONS: Record<StudyMode, SectionType[]>` and `expectedSectionTotal(mode): number`.
  - Dart: `List<String> expectedSectionKeysFor(StudyMode)` and `int expectedSectionsFor(StudyMode)`. The two must list the same keys.
  - Fill the lists from the JSON schema each mode's prompt actually asks for. Find the per-mode schemas with `grep -rn "quick" backend/supabase/functions/_shared/services/llm* backend/supabase/functions/_shared/prompts`. Quick Read must not include `context` if its schema omits it (the final design review says it does not include it).

- [ ] **Step 1: Write the failing tests**

```ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { MODE_SECTIONS, expectedSectionTotal } from './mode-sections.ts'
Deno.test('quick has fewer sections than standard and no multipass parts', () => {
  assertEquals(MODE_SECTIONS.quick.includes('interpretationPart1' as never), false)
  assertEquals(expectedSectionTotal('quick') < expectedSectionTotal('standard'), true)
})
```

```dart
test('dart and backend agree on quick', () {
  expect(expectedSectionKeysFor(StudyMode.quick), isNot(contains('context')));
  expect(expectedSectionsFor(StudyMode.quick), expectedSectionKeysFor(StudyMode.quick).length);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend/supabase/functions && deno test _shared/services/mode-sections.test.ts` and `cd frontend && flutter test test/features/study_generation/domain/expected_sections_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the maps, then thread `mode` into the parser. Update `_shared/services/streaming-json-parser.test.ts` so the existing tests construct the parser with `'standard'`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend/supabase/functions && deno test _shared/services/` and `cd frontend && flutter test test/features/study_generation`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "fix(study): Quick Read streams only its own sections"
```

---

### Task 6: Phase verification

- [ ] Run `cd frontend && flutter analyze && flutter test`. Expected: clean, PASS.
- [ ] Run `cd backend/supabase/functions && deno test _shared/services/`. Expected: PASS.
- [ ] Locally set `update feature_flags set is_enabled=true, rollout_percentage=100 where feature_key='generate_single_input'`. On web, run alone and check each of these:
  - "Romans 8" → Scripture tag → Generate study opens the stream with Quick Read segments only.
  - "Why does God allow suffering" → Question.
  - Spend credits until short → the sheet numbers match the pill.
  - Continue reading never shows a path lesson.
  - With the flag off, the old Generate is unchanged.

## Self-review notes

- **Spec coverage:**
  - single auto-detect input → Tasks 1 and 4
  - few chips → Task 4
  - verse-of-day ready start → Task 4
  - Quick/Standard + All 5 with the shipped names → Task 4
  - inline "Using N credits" → Task 4
  - Continue reading own studies only → Phase A Task 9, consumed here
  - opens the streaming guide directly → Tasks 2 and 4
  - out of credits honest → Task 3
  - Quick Read stream sections → Task 5
- "Your library" naming is left as shipped. Phase E unifies wording.
