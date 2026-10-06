# Hindi/Malayalam Fit and Activation Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:**
- Make every redesigned screen fit in Hindi and Malayalam at 360px. Shorten the strings to their meaning rather than translating them literally. Add short display titles for long path names.
- Instrument activation (verse read and lesson 1 finished on day 1), D1/D7, time to first lesson, the first-run funnel, and New-for-you impressions and taps.

**Architecture:**
- **Width audit.** A `flutter test` measures each hi/ml UI string with the real fonts (Inter/Poppins plus the Noto fonts from Phase A). It compares the result with English at the same style and fails with a table of offenders. That table becomes the rewrite worklist.
- **Short path titles.** Long path names get a nullable `short_title` column. Translations live in `learning_path_translations` and English lives in `learning_paths`; both get the column. The edge functions return it, and the Home and Topics headers use it. Detail screens keep the full title. Lesson (topic) titles use `maxLines: 2` plus an ellipsis everywhere outside detail screens.
- **Analytics.**
  - `ActivationAnalytics` inserts rows into the existing `analytics_events` table. RLS already allows `auth.uid() = user_id`. Event types are prefixed `nux.`.
  - Events that fire before a user exists are queued in Hive and flushed once a session appears (guest or login).
  - SQL views compute the metrics.
  - The 90-day cleanup job is changed to keep `nux.%` events for 400 days.

**Tech Stack:** Flutter test + `TextPainter`, PostgreSQL views, Supabase client inserts, Deno (`learning-paths`).

**Spec:**
- Owner requirement (2026-10-06): hi/ml short strings. UI labels are ≤ ~1.3× the English character width, prefer common short words, and drop filler. Long DB titles need short display titles. Widget tests at 360px.
- Audit §5 (metrics/events) and §4 (glossary).
- `docs/ux/design-final/hindi-malayalam.png`.
- Roadmap `docs/superpowers/plans/2026-10-06-new-user-experience-roadmap.md` (Metrics table).

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
- **Task order.** Tasks 1–4 (strings) run after Phases B–E are merged, because they audit those keys. Tasks 5–8 (analytics) can start after Phase A. Their hook points in Phase B/C/D code are listed per event, so add each hook when its phase is merged.
- **Short-title decision.** Add a `short_title` column, not a max-lines rule alone. Ellipsis on a path name hides the distinguishing word (for example "പുതിയ വിശ്വാസിയുടെ…"). Lesson titles get `maxLines: 2` plus an ellipsis instead, because they are always shown in full on the guide screen.
- **Privacy.** Analytics never sends raw user input (study text, questions) or verse text. It sends only ids, numbers, enums and language codes.

## Review Focus

- **Malayalam dock at 360px.** All five labels (Home, Generate, Discipler, Topics, Community) render on one line each and are not truncated.
- **A path whose `short_title` is NULL in one language.** The header falls back to the full title on one line with an ellipsis. It never shows an empty string.
- **Events fired while signed out** (`nux.first_open`, `nux.language_selected`). They are not lost. They flush with the correct `user_id` after `startGuest()` or login, and they keep their original `created_at`.
- **The same `nux.verse_viewed` sent many times a day.** Activation counts users, not events, and D1 uses calendar days in IST.
- **The analytics insert fails** (offline or an RLS error). It never blocks UI, never throws into widgets, and retries from the Hive queue on the next app start.

---

## File Structure

| File | Responsibility |
|---|---|
| `frontend/test/core/i18n/redesign_keys.dart` (new) | The list of keys used on redesigned screens + the style each renders in |
| `frontend/test/core/i18n/short_string_audit_test.dart` (new) | Width audit (fails with a table) |
| `frontend/lib/core/i18n/translations_hi.dart`, `translations_ml.dart`, `frontend/lib/core/localization/app_localizations.dart` | Shorter strings |
| `backend/supabase/migrations/20261006120000_learning_path_short_titles.sql` (new) | `short_title` columns + seeds |
| `backend/supabase/functions/learning-paths/index.ts:271-309` (+ list/recommended builders) | Return `short_title` |
| `frontend/lib/features/study_topics/data/models/learning_path_model.dart`, `domain/entities/learning_path.dart` | `shortTitle` |
| `frontend/test/features/home/presentation/fit_360_test.dart` (new) | 360px overflow tests |
| `backend/supabase/migrations/20261006120100_nux_analytics_views.sql` (new) | Indexes, views, retention exception |
| `frontend/lib/core/services/activation_analytics.dart` (new) | Event API + offline queue |
| Hook sites (listed in Task 7) | Event calls |

---

### Task 1: Width audit of hi/ml strings on redesigned screens

**Files:**
- Create: `frontend/test/core/i18n/redesign_keys.dart`
- Create: `frontend/test/core/i18n/short_string_audit_test.dart`
- Modify: `frontend/test/helpers/text_fit.dart` (`loadAppFonts()` also loads `NotoSansDevanagari` and `NotoSansMalayalam` from `assets/fonts/`, added in Phase A Task 8)

**Interfaces:**
- Produces:
  - `const redesignKeys = <AuditKey>[...]` with `class AuditKey { final String key; final double fontSize; final FontWeight weight; final double maxWidth; }`. `maxWidth` is the width the slot has at 360px:
    - 64 for dock labels
    - 296 for full-width buttons (360 − 2×16 page gutter − 2×16 card padding)
    - 140 for "See path" / "See all" links
    - 120 for chips
    - 230 for banner titles
  - The audit rule: a string fails when `width(hi|ml) > maxWidth` (it does not fit its slot) OR `width(hi|ml) > 1.3 × width(en)` for keys whose slot is a single-line label.

The key list must cover:
- **Dock:** `navHome`, `navGenerate`, `navTopics`, `navCommunity`, `navDiscipler` (AppLocalizations; read from `AppLocalizations` maps)
- **Home today:** `home_today.*` and `home.memory_verses` (pill)
- **Lesson:** `lesson.*`
- **First run:** `first_run.*`, `goal.*`
- **Account:** `account.*`
- **New for you:** `nfy.*.banner_title`, `nfy.*.banner_cta`, `nfy.eyebrow`
- **Intros:** `intro.*.primary`, `intro.*.secondary`
- **Generate:** `generate_simple.*`
- **Credits:** `credits.*`
- **Topics:** `topics.*`, `all_paths.*`
- **Memory:** `memory.save_todays_verse`, `memory.due`, `memory.header_line`
- **Plan:** `plan.*`
- **Learning paths:** `learning_paths.start_lesson`, `learning_paths.continue_lesson`, `learning_paths.review_lesson`

- [ ] **Step 1: Write the audit test**

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_en.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_hi.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_ml.dart';
import '../../helpers/text_fit.dart';
import 'redesign_keys.dart';

String? lookup(Map<String, dynamic> m, String key) {
  dynamic cur = m;
  for (final part in key.split('.')) { if (cur is! Map) return null; cur = cur[part]; }
  return cur is String ? cur.replaceAll(RegExp(r'\{[a-z_]+\}'), '88') : null;
}

double measure(String text, AuditKey k) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: const ['NotoSansDevanagari', 'NotoSansMalayalam'], fontSize: k.fontSize, fontWeight: k.weight)),
    textDirection: TextDirection.ltr, maxLines: 1)..layout();
  return tp.width;
}

void main() {
  setUpAll(loadAppFonts);
  test('hi/ml redesign strings fit their slot and stay ≤1.3× English', () {
    final rows = <String>[];
    for (final k in redesignKeys) {
      final en = lookup(englishTranslations, k.key);
      if (en == null) { rows.add('| ${k.key} | MISSING en | | |'); continue; }
      final enW = measure(en, k);
      for (final (code, map) in [('hi', hindiTranslations), ('ml', malayalamTranslations)]) {
        final v = lookup(map, k.key);
        if (v == null) { rows.add('| ${k.key} | $code MISSING | | |'); continue; }
        final w = measure(v, k);
        if (w > k.maxWidth || (k.singleLine && w > enW * 1.3)) {
          rows.add('| ${k.key} | $code | "$v" | ${w.toStringAsFixed(0)}px vs en ${enW.toStringAsFixed(0)}px, slot ${k.maxWidth.toStringAsFixed(0)}px |');
        }
      }
    }
    expect(rows, isEmpty, reason: '\n| key | lang | value | width |\n|---|---|---|---|\n${rows.join('\n')}');
  });
}
```

(Add `final bool singleLine;` to `AuditKey`. It is true for dock labels, buttons, chips and links, and false for body/subtitle lines that may wrap; those are checked only against `maxWidth × 2`.)

- [ ] **Step 2: Run it to produce the worklist**

Run: `cd frontend && flutter test test/core/i18n/short_string_audit_test.dart 2>&1 | tee /tmp/i18n_audit.txt`
Expected: FAIL, with a markdown table of offenders. Paste the table into the PR description; it is the worklist for Task 2.

- [ ] **Step 3: Commit the audit test** (only after owner approval). The test is expected to stay red until Task 2 lands, so commit both together, or mark it `skip: 'until Task 2'` in this commit.

```bash
git add frontend/test/core/i18n frontend/test/helpers/text_fit.dart
git commit -m "test(i18n): width audit for Hindi and Malayalam on redesigned screens"
```

---

### Task 2: Rewrite the long hi/ml strings (short, meaning-first)

**Files:**
- Modify: `frontend/lib/core/i18n/translations_hi.dart`, `translations_ml.dart`, `frontend/lib/core/localization/app_localizations.dart` (hi ~L1055-1058, L1456; ml ~L1849-1852, L2257)

**Interfaces:** none (values only).

Rules:
- Convey the meaning, not a literal translation.
- Use the most common short word.
- Drop filler such as "करें/ചെയ്യുക" when an imperative noun suffices, "कृपया", and "നിങ്ങളുടെ".
- Keep "Discipler" in Latin script; it is the brand.

Starting proposals for known long strings. Confirm each against the Task 1 table and add every remaining offender:

| key | current hi | proposed hi | current ml | proposed ml |
|---|---|---|---|---|
| `navGenerate` | बनाएँ | अध्ययन | ഉണ്ടാക്കുക | പഠനം |
| `navTopics` | विषय | पथ | വിഷയങ്ങൾ | പാതകൾ |
| `navCommunity` | समुदाय | समूह | കൂട്ടായ്മ | കൂട്ടായ്മ (keep) |
| `home.memory_verses` (pill) | स्मृति आयतें | याद वचन | സ്മരണ വാക്യങ്ങൾ | വാക്യങ്ങൾ |
| `home_today.see_path` | पथ देखें | पथ | പാത | പാത (keep) |
| `home_today.start_lesson` | पाठ {n} शुरू करें | पाठ {n} शुरू | പാഠം {n} തുടങ്ങാം | പാഠം {n} |
| `home.continue_journey` | — | — | ബൈബിൾ വായിച്ച് വിശ്വാസം വളർത്തൂ | വചനത്തിൽ വളരാം |
| `home.recommended_topics` | — | — | ശുപാര്‍ശ ചെയ്യപ്പെട്ട വിഷയങ്ങള്‍ | നിർദ്ദേശങ്ങൾ |
| `home.browse_paths` | — | — | പഠന പാതകൾ കാണൂ | പാതകൾ കാണാം |
| `lesson.mark_complete` | पूरा करें · पाठ {n}/{total} | पूरा · पाठ {n}/{total} | പൂർത്തിയായി · പാഠം {n}/{total} | തീർന്നു · {n}/{total} |
| `nfy.paths.banner_title` | (Phase C value) | और पथ देखें | (Phase C value) | കൂടുതൽ പാതകൾ |
| `generate_simple.title` | आज क्या पढ़ें? | (keep) | ഇന്ന് എന്ത് പഠിക്കാം? | (keep) |

Note: `navTopics` → "पथ"/"പാതകൾ" matches what the tab now holds (paths). This is a deliberate naming change, so check it with the owner (see the roadmap's open questions).

- [ ] **Step 1: Apply the rewrites from the Task 1 table**, one key at a time in all three places a key may live (`context.tr` maps and `AppLocalizations`).
- [ ] **Step 2: Re-run the audit**

Run: `cd frontend && flutter test test/core/i18n/short_string_audit_test.dart`
Expected: PASS (remove the `skip` if Task 1 added one).

- [ ] **Step 3: Run the full suite**, because widget tests may assert old hi/ml strings.

Run: `cd frontend && flutter test`
Expected: PASS. Update any asserting tests to the new values.

- [ ] **Step 4: Native review.** Send the before/after table to the owner for Hindi and Malayalam reviewers before release. Record the approved values in the PR.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "fix(i18n): shorter Hindi and Malayalam labels on the redesigned screens"
```

---

### Task 3: `short_title` for learning paths (migration + API + app)

**Files:**
- Create: `backend/supabase/migrations/20261006120000_learning_path_short_titles.sql`
- Modify: `backend/supabase/functions/learning-paths/index.ts` (`getLocalizedTitleDescription` L271-309 → also `short_title`; every path JSON builder adds `short_title`; `batch-loaders.ts` `groupPathTranslations` carries it)
- Modify: `backend/supabase/functions/admin-learning-paths/index.ts` (accept `short_title` per language on create/update; validate ≤ 28 chars)
- Modify: `frontend/lib/features/study_topics/domain/entities/learning_path.dart` (add `final String? shortTitle;` and `String get displayTitle`), `data/models/learning_path_model.dart` (parse `short_title`), `ActivePathSummaryModel` already reads it (Phase C)
- Modify: the usages that are headers or rows, not detail screens. Use `displayTitle` in `home_path_section.dart` (Phase C), `topics_current_path_card.dart` (Phase E), `path_list_row.dart`, `all_paths_page.dart`, `fellowship` "Studying" chips, and the `LessonCompletePage` subtitle. Detail-screen titles keep `title`.
- Test: `backend/supabase/functions/learning-paths/batch-loaders.test.ts` (extend), `frontend/test/features/study_topics/data/learning_path_short_title_test.dart`

**Interfaces:**
- Produces:
  - Column `learning_paths.short_title TEXT NULL CHECK (char_length(short_title) <= 28)` and `learning_path_translations.short_title TEXT NULL` (same check).
  - API field `short_title: string | null` on every path object.
  - Dart `LearningPath.displayTitle => (shortTitle?.trim().isNotEmpty ?? false) ? shortTitle! : title`.

- [ ] **Step 1: Write the failing tests**

```ts
Deno.test('groupPathTranslations keeps short_title', () => {
  const grouped = groupPathTranslations([{ learning_path_id: 'p', lang_code: 'ml', title: 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ', description: 'd', short_title: 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ' }])
  assertEquals(grouped.get('p')?.get('ml')?.short_title, 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ')
})
```

(Adapt to `groupPathTranslations`' real return shape in `learning-paths/batch-loaders.ts`.)

```dart
test('displayTitle falls back to title when short_title is null or blank', () {
  expect(LearningPathModel.fromJson(base..['short_title'] = null).displayTitle, base['title']);
  expect(LearningPathModel.fromJson(base..['short_title'] = '  ').displayTitle, base['title']);
  expect(LearningPathModel.fromJson(base..['short_title'] = 'Short').displayTitle, 'Short');
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend/supabase/functions && deno test learning-paths/` and `cd frontend && flutter test test/features/study_topics/data/learning_path_short_title_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** The migration (idempotent; seeds only the long titles, by slug):

```sql
ALTER TABLE public.learning_paths ADD COLUMN IF NOT EXISTS short_title TEXT;
ALTER TABLE public.learning_path_translations ADD COLUMN IF NOT EXISTS short_title TEXT;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_paths_short_title_len') THEN
    ALTER TABLE public.learning_paths ADD CONSTRAINT learning_paths_short_title_len CHECK (short_title IS NULL OR char_length(short_title) <= 28);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_path_translations_short_title_len') THEN
    ALTER TABLE public.learning_path_translations ADD CONSTRAINT learning_path_translations_short_title_len CHECK (short_title IS NULL OR char_length(short_title) <= 28);
  END IF;
END $$;

UPDATE public.learning_paths lp SET short_title = v.short_title
FROM (VALUES
  ('crucifixion-and-resurrection', 'Cross and Resurrection'),
  ('johns-letters-light-love-truth', 'John''s Letters'),
  ('mental-health-emotions-gospel', 'Emotions and the Gospel'),
  ('sin-repentance-and-grace', 'Sin and Grace'),
  ('peters-letters-hope-and-endurance', 'Peter''s Letters'),
  ('historical-reliability-bible', 'Is the Bible Reliable?')
) AS v(slug, short_title)
WHERE lp.slug = v.slug AND lp.short_title IS NULL;

UPDATE public.learning_path_translations t SET short_title = v.short_title
FROM (VALUES
  ('new-believer-essentials', 'hi', 'विश्वास की नींव'),
  ('new-believer-essentials', 'ml', 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ'),
  ('sin-repentance-and-grace', 'hi', 'पाप और अनुग्रह'),
  ('sin-repentance-and-grace', 'ml', 'പാപവും കൃപയും'),
  ('crucifixion-and-resurrection', 'hi', 'क्रूस और पुनरुत्थान'),
  ('crucifixion-and-resurrection', 'ml', 'ക്രൂശും പുനരുത്ഥാനവും'),
  ('mental-health-emotions-gospel', 'hi', 'मन और सुसमाचार'),
  ('mental-health-emotions-gospel', 'ml', 'മനസ്സും സുവിശേഷവും'),
  ('evangelism-everyday-life', 'ml', 'ദിവസവും സുവിശേഷം'),
  ('historical-reliability-bible', 'hi', 'बाइबल की विश्वसनीयता'),
  ('historical-reliability-bible', 'ml', 'ബൈബിളിന്റെ സത്യത'),
  ('johns-letters-light-love-truth', 'hi', 'यूहन्ना के पत्र'),
  ('johns-letters-light-love-truth', 'ml', 'യോഹന്നാന്റെ ലേഖനങ്ങൾ'),
  ('peters-letters-hope-and-endurance', 'hi', 'पतरस के पत्र'),
  ('peters-letters-hope-and-endurance', 'ml', 'പത്രോസിന്റെ ലേഖനങ്ങൾ'),
  ('work-and-vocation-as-worship', 'hi', 'काम भी आराधना'),
  ('work-and-vocation-as-worship', 'ml', 'ജോലിയും ആരാധന')
) AS v(slug, lang, short_title)
JOIN public.learning_paths lp ON lp.slug = v.slug
WHERE t.learning_path_id = lp.id AND t.lang_code = v.lang AND t.short_title IS NULL;
```

The seed values are proposals and need native review (Task 2, Step 4). After that, run Task 4's header test against the seeded titles. Any title still failing gets a seed row in a follow-up migration.

Backend:
- `getLocalizedTitleDescription` selects `title, description, short_title` and returns `shortTitle`.
- For `language === 'en'`, the caller passes `pathData.short_title`.
- Add `short_title` to the `learning_paths` selects that feed the list, recommended and detail responses.

- [ ] **Step 4: Apply and run the tests**

Run: `cd backend && supabase migration up`, then `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "select lang_code, short_title from learning_path_translations t join learning_paths p on p.id=t.learning_path_id where p.slug='new-believer-essentials'"`. Then run `cd backend/supabase/functions && deno test learning-paths/` and `cd frontend && flutter test test/features/study_topics`.
Expected: the seeded rows are present; PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(paths): short display titles for long path names"
```

---

### Task 4: 360px fit tests for hi/ml on the key surfaces

**Files:**
- Create: `frontend/test/features/home/presentation/fit_360_test.dart`
- Create: `frontend/test/core/presentation/dock_fit_360_test.dart`

**Interfaces:** Consumes `HomePathSection`, `TodayLessonCard`, `NewForYouBanner` (Phase C), `DisciplefyBottomNav` (`core/presentation/widgets/bottom_nav.dart`), `expectNoTruncatedText`, `loadAppFonts`.

- [ ] **Step 1: Write the tests**

```dart
for (final lang in ['hi', 'ml']) {
  group('$lang at 360px', () {
    setUpAll(loadAppFonts);
    void use360(WidgetTester tester) { tester.view.physicalSize = const Size(360, 780); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset); }

    testWidgets('Home path header (real long title via short_title)', (tester) async {
      use360(tester);
      await tester.pumpWidget(welcomeApp(language: lang, screen: HomePathSection(summary: nbeSummary(lang), loading: false, mode: StudyMode.standard, onModeChanged: (_) {})));
      expectNoTruncatedText(tester, allow: {nbeSummary(lang).next!.title});
      expect(tester.takeException(), isNull);
    });
    testWidgets('Lesson card', ...);       // use360(tester) first; TodayLessonCard with the localized lesson 4 title
    testWidgets('New for you banner (each kind)', ...); // for (kind in NewForYouKind.values)
    testWidgets('Dock', (tester) async {
      use360(tester);
      await tester.pumpWidget(welcomeApp(language: lang, screen: Scaffold(bottomNavigationBar: DisciplefyBottomNav(
          tabs: [...DisciplefyBottomNav.defaultTabs, DisciplefyBottomNav.disciplerTab], currentIndex: 0, onTap: (_) {}))));
      expectNoTruncatedText(tester);
    });
  });
}
```

`nbeSummary('ml')` uses `title: 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ'`, `shortTitle: 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ'` and lesson 4 `'നിങ്ങളുടെ രക്ഷയിലുള്ള വിശ്വാസം'`. The hi version uses `'नए विश्वासी की मूल बातें'` / `'विश्वास की नींव'` / `'अपने उद्धार में विश्वास'`. Match the `DisciplefyBottomNav` constructor to its real signature (L13-98).

- [ ] **Step 2: Run the tests**

Run: `cd frontend && flutter test test/features/home/presentation/fit_360_test.dart test/core/presentation/dock_fit_360_test.dart`
Expected: PASS once Tasks 2 and 3 are in. Any failure names the cut string; shorten it per Task 2.

- [ ] **Step 3: Commit** (only after owner approval)

```bash
git commit -am "test(i18n): Hindi and Malayalam fit at 360px on Home and the dock"
```

---

### Task 5: Analytics storage — indexes, retention exception, metric views

**Files:**
- Create: `backend/supabase/migrations/20261006120100_nux_analytics_views.sql`
- Test: a SQL check (below), run in a transaction

**Interfaces:**
- Produces these views, readable by `service_role` and admins (`REVOKE ALL ... FROM anon, authenticated`):
  - `public.nux_user_firsts(user_id, first_open_at, first_verse_at, first_lesson1_done_at, signup_at, language)`
  - `public.nux_activation_daily(cohort_date, new_users, activated, activation_rate)`: activated = `verse_viewed` and `lesson_completed` (lesson_number = 1), both within 24h of `first_open`.
  - `public.nux_retention_daily(cohort_date, activated, d1_returned, d7_returned)`: returned on day N = any `nux.verse_viewed` or `nux.lesson_completed` on cohort IST date + N.
  - `public.nux_time_to_first_lesson(cohort_date, median_seconds)`
  - `public.nux_funnel_daily(cohort_date, step, users)`, with steps `first_open`, `language_selected`, `goal_selected`, `lesson_started`, `lesson_completed`, `signup_completed`, `guest_continued`.
  - `public.nux_new_for_you_daily(day, kind, impressions, taps, dismissals)`.
- Event-type contract (`event_type` VARCHAR(50)): `nux.first_open`, `nux.language_selected`, `nux.goal_selected`, `nux.verse_viewed`, `nux.lesson_started`, `nux.lesson_completed`, `nux.signup_completed`, `nux.guest_continued`, `nux.account_needed_shown`, `nux.nfy_impression`, `nux.nfy_tap`, `nux.nfy_dismiss`, `nux.credit_warning_shown`, `nux.reminder_opt_in`.
- `event_data` keys: `language`, `goal`, `path_id`, `lesson_number`, `mode`, `first_run` (bool), `method`, `from_guest` (bool), `reason`, `kind`, `source`, `client_ts` (ISO; the original time for queued events).

- [ ] **Step 1: Write the SQL check first** (save as `/tmp/nux_check.sql`)

```sql
BEGIN;
INSERT INTO auth.users (id, instance_id, aud, role, email) VALUES
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nux-a@test.local'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nux-b@test.local');
INSERT INTO analytics_events (user_id, event_type, event_data, created_at) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'nux.first_open', '{}', '2026-10-06 04:00+00'),
  ('00000000-0000-0000-0000-0000000000a1', 'nux.verse_viewed', '{}', '2026-10-06 04:01+00'),
  ('00000000-0000-0000-0000-0000000000a1', 'nux.lesson_completed', '{"lesson_number":1}', '2026-10-06 04:07+00'),
  ('00000000-0000-0000-0000-0000000000a1', 'nux.verse_viewed', '{}', '2026-10-07 03:00+00'),
  ('00000000-0000-0000-0000-0000000000a2', 'nux.first_open', '{}', '2026-10-06 05:00+00'),
  ('00000000-0000-0000-0000-0000000000a2', 'nux.verse_viewed', '{}', '2026-10-06 05:01+00');
SELECT new_users, activated FROM nux_activation_daily WHERE cohort_date = '2026-10-06';  -- expect 2, 1
SELECT d1_returned FROM nux_retention_daily WHERE cohort_date = '2026-10-06';           -- expect 1
SELECT median_seconds FROM nux_time_to_first_lesson WHERE cohort_date = '2026-10-06';   -- expect 420
ROLLBACK;
```

- [ ] **Step 2: Run it to verify it fails**

Run: `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f /tmp/nux_check.sql`
Expected: ERROR, because the relation `nux_activation_daily` does not exist.

- [ ] **Step 3: Write the migration**

```sql
CREATE INDEX IF NOT EXISTS idx_analytics_events_nux ON public.analytics_events (event_type, user_id, created_at)
  WHERE event_type LIKE 'nux.%';

CREATE OR REPLACE VIEW public.nux_user_firsts AS
SELECT user_id,
  MIN(created_at) FILTER (WHERE event_type = 'nux.first_open') AS first_open_at,
  MIN(created_at) FILTER (WHERE event_type = 'nux.verse_viewed') AS first_verse_at,
  MIN(created_at) FILTER (WHERE event_type = 'nux.lesson_completed' AND (event_data->>'lesson_number')::int = 1) AS first_lesson1_done_at,
  MIN(created_at) FILTER (WHERE event_type = 'nux.signup_completed') AS signup_at,
  (ARRAY_AGG(event_data->>'language' ORDER BY created_at) FILTER (WHERE event_type = 'nux.language_selected'))[1] AS language
FROM public.analytics_events WHERE event_type LIKE 'nux.%' AND user_id IS NOT NULL
GROUP BY user_id;

CREATE OR REPLACE VIEW public.nux_activation_daily AS
SELECT (first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS cohort_date,
  COUNT(*) AS new_users,
  COUNT(*) FILTER (WHERE first_verse_at < first_open_at + interval '24 hours'
                     AND first_lesson1_done_at < first_open_at + interval '24 hours') AS activated,
  ROUND(100.0 * COUNT(*) FILTER (WHERE first_verse_at < first_open_at + interval '24 hours'
                     AND first_lesson1_done_at < first_open_at + interval '24 hours') / NULLIF(COUNT(*),0), 1) AS activation_rate
FROM public.nux_user_firsts WHERE first_open_at IS NOT NULL GROUP BY 1;

CREATE OR REPLACE VIEW public.nux_retention_daily AS
WITH act AS (
  SELECT user_id, (first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS d0 FROM public.nux_user_firsts
  WHERE first_verse_at < first_open_at + interval '24 hours' AND first_lesson1_done_at < first_open_at + interval '24 hours'),
days AS (
  SELECT DISTINCT user_id, (created_at AT TIME ZONE 'Asia/Kolkata')::date AS d FROM public.analytics_events
  WHERE event_type IN ('nux.verse_viewed','nux.lesson_completed'))
SELECT a.d0 AS cohort_date, COUNT(*) AS activated,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM days x WHERE x.user_id = a.user_id AND x.d = a.d0 + 1)) AS d1_returned,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM days x WHERE x.user_id = a.user_id AND x.d = a.d0 + 7)) AS d7_returned
FROM act a GROUP BY 1;

CREATE OR REPLACE VIEW public.nux_time_to_first_lesson AS
SELECT (first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS cohort_date,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM first_lesson1_done_at - first_open_at)) AS median_seconds
FROM public.nux_user_firsts WHERE first_lesson1_done_at IS NOT NULL AND first_open_at IS NOT NULL GROUP BY 1;

CREATE OR REPLACE VIEW public.nux_funnel_daily AS
SELECT (f.first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS cohort_date, replace(e.event_type, 'nux.', '') AS step, COUNT(DISTINCT e.user_id) AS users
FROM public.nux_user_firsts f JOIN public.analytics_events e ON e.user_id = f.user_id
WHERE e.event_type IN ('nux.first_open','nux.language_selected','nux.goal_selected','nux.lesson_started','nux.lesson_completed','nux.signup_completed','nux.guest_continued')
GROUP BY 1, 2;

CREATE OR REPLACE VIEW public.nux_new_for_you_daily AS
SELECT (created_at AT TIME ZONE 'Asia/Kolkata')::date AS day, event_data->>'kind' AS kind,
  COUNT(*) FILTER (WHERE event_type = 'nux.nfy_impression') AS impressions,
  COUNT(*) FILTER (WHERE event_type = 'nux.nfy_tap') AS taps,
  COUNT(*) FILTER (WHERE event_type = 'nux.nfy_dismiss') AS dismissals
FROM public.analytics_events WHERE event_type LIKE 'nux.nfy_%' GROUP BY 1, 2;

REVOKE ALL ON public.nux_user_firsts, public.nux_activation_daily, public.nux_retention_daily,
  public.nux_time_to_first_lesson, public.nux_funnel_daily, public.nux_new_for_you_daily FROM anon, authenticated;
GRANT SELECT ON public.nux_user_firsts, public.nux_activation_daily, public.nux_retention_daily,
  public.nux_time_to_first_lesson, public.nux_funnel_daily, public.nux_new_for_you_daily TO service_role;

-- Keep nux.* events 400 days (cohort trends); everything else keeps the 90-day rule.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('cleanup-old-analytics-events')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-old-analytics-events');
    PERFORM cron.schedule('cleanup-old-analytics-events', '30 3 * * *',
      $job$DELETE FROM public.analytics_events
           WHERE (event_type NOT LIKE 'nux.%' AND created_at < now() - interval '90 days')
              OR (event_type LIKE 'nux.%' AND created_at < now() - interval '400 days')$job$);
  END IF;
END $$;
```

Also give the views `WITH (security_invoker = true)`, so that admin reads go through the existing "Admins can view all analytics" policy. This requires Postgres 15+; the project runs PG17.

- [ ] **Step 4: Apply and re-run the check**

Run: `cd backend && supabase migration up && psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f /tmp/nux_check.sql`
Expected: `2 | 1`, `1`, `420`.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(analytics): activation, retention and New for you views"
```

---

### Task 6: `ActivationAnalytics` service with an offline queue

**Files:**
- Create: `frontend/lib/core/services/activation_analytics.dart`
- Modify: `frontend/lib/core/di/injection_container.dart` (LazySingleton); `frontend/lib/main.dart` (open the Hive box `nux_events` at startup; call `sl<ActivationAnalytics>().flush()` on `AuthChangeEvent.signedIn` / `tokenRefreshed`, via the existing `AuthNotifier` listener)
- Test: `frontend/test/core/services/activation_analytics_test.dart`

**Interfaces:**
- Produces:

```dart
enum NuxEvent { firstOpen, languageSelected, goalSelected, verseViewed, lessonStarted, lessonCompleted,
  signupCompleted, guestContinued, accountNeededShown, nfyImpression, nfyTap, nfyDismiss, creditWarningShown, reminderOptIn }
extension NuxEventName on NuxEvent { String get type; } // 'nux.first_open', … (snake_case)

class ActivationAnalytics {
  ActivationAnalytics({required SupabaseClient client, required Box<dynamic> queue, DateTime Function()? clock});
  Future<void> track(NuxEvent e, [Map<String, Object?> data = const {}]); // never throws
  Future<void> flush();                                                   // never throws
  Future<void> trackFirstOpenOnce();                                      // Hive flag 'first_open_sent'
}
```

- `track` behaviour:
  - Always set `client_ts`.
  - If `client.auth.currentUser == null`, append `{type, data}` to the queue.
  - Otherwise insert `{user_id, event_type, event_data, session_id: appSessionId}`. On any error, log with `Logger.warning` and append the event to the queue.
- `flush` inserts queued items in order, using `created_at = client_ts` (RLS allows the user's own rows), and removes each item after it is inserted.
- Allowed data values are `String`, `num` and `bool` only. Anything else is dropped. String values longer than 64 characters are dropped (a guard against sending raw input).

- [ ] **Step 1: Write the failing tests**

```dart
test('signed out: queued, then flushed with user id and original time', () async {
  when(() => auth.currentUser).thenReturn(null);
  await a.track(NuxEvent.languageSelected, {'language': 'ml'});
  expect(queue.length, 1);
  verifyNever(() => table.insert(any()));
  when(() => auth.currentUser).thenReturn(fakeUser(id: 'g1', anon: true));
  await a.flush();
  final row = verify(() => table.insert(captureAny())).captured.single as Map;
  expect(row['user_id'], 'g1');
  expect(row['event_type'], 'nux.language_selected');
  expect(row['created_at'], clockTime.toUtc().toIso8601String());
  expect(queue.length, 0);
});
test('insert failure never throws and requeues', () async {
  when(() => auth.currentUser).thenReturn(fakeUser(id: 'u1'));
  when(() => table.insert(any())).thenThrow(Exception('offline'));
  await a.track(NuxEvent.verseViewed);
  expect(queue.length, 1);
});
test('drops long strings and non-scalars', () async {
  when(() => auth.currentUser).thenReturn(fakeUser(id: 'u1'));
  await a.track(NuxEvent.goalSelected, {'goal': 'newToFaith', 'text': 'x' * 200, 'obj': {'a': 1}});
  final row = verify(() => table.insert(captureAny())).captured.single as Map;
  expect((row['event_data'] as Map).keys, containsAll(['goal', 'client_ts']));
  expect((row['event_data'] as Map).containsKey('text'), isFalse);
});
test('first_open only once per install', () async { ... });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd frontend && flutter test test/core/services/activation_analytics_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the service as specified, with `client.from('analytics_events').insert(row)`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd frontend && flutter test test/core/services/activation_analytics_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(analytics): activation event tracker with an offline queue"
```

---

### Task 7: Fire the events at their hook points

**Files and hooks.** Each call is `sl<ActivationAnalytics>().track(...)`, unawaited and wrapped in `unawaited(...)`.

| Event | Where | Data |
|---|---|---|
| `firstOpen` | `main.dart` after DI (`trackFirstOpenOnce()`) | `{language: device locale code}` |
| `languageSelected` | Phase B `first_run_language_page.dart` Continue; `features/onboarding/presentation/pages/language_selection_screen.dart:64` `_continueWithSelection` | `{language}` |
| `goalSelected` | Phase B `growth_goal_page.dart` "Start lesson 1" | `{goal: GrowthGoal.name}` |
| `verseViewed` | where Phase A Task 6 dispatches `MarkVerseAsViewed` (Home 5-second timer / copy / share / listen / reflect) | `{source: 'home'}` |
| `lessonStarted` | `study_guide_screen_v2.dart` when `widget.lesson != null` and generation or cached load begins | `{path_id, lesson_number, mode, first_run}` |
| `lessonCompleted` | `study_guide_screen_v2.dart` `_completeLessonNow` success (Phase A Task 4) | same as `lessonStarted` |
| `signupCompleted` | `AuthBloc` on a successful Google/Apple/Email sign-up; `GuestSessionService` on `linked` / `mergedIntoExisting` | `{method: google\|apple\|email, from_guest: bool}` |
| `guestContinued` | Phase B `SaveProgressBlock` "Not now" | `{}` |
| `accountNeededShown` | Phase B `AccountNeededSheet.show` | `{reason}` |
| `nfyImpression` | Phase C `NewForYouCubit.load` when a banner is emitted (once per kind per day) | `{kind}` |
| `nfyTap` / `nfyDismiss` | Phase C `NewForYouCubit.opened` / `dismiss` | `{kind}` |
| `creditWarningShown` | Phase D `OutOfCreditsSheet.show`; the shipped `InsufficientTokensDialog.show` | `{needed, have}` |
| `reminderOptIn` | `notifications/presentation/widgets/notification_enable_prompt.dart:207` when permission is granted | `{type}` |

- Test: one focused widget/bloc test per hook file, asserting the `track` call with a mocked `ActivationAnalytics` registered in `sl`. For example:

```dart
testWidgets('Mark complete tracks lesson_completed with lesson number', (tester) async {
  // pump StudyGuideScreenV2 with lesson: LessonRef(lessonNumber: 1, lessonTotal: 8, pathId: 'p'), tap Mark complete
  verify(() => analytics.track(NuxEvent.lessonCompleted, any(that: containsPair('lesson_number', 1)))).called(1);
});
```

- [ ] **Step 1: Write the failing hook tests** (one per row, in each feature's existing test folder).
- [ ] **Step 2: Run them to verify they fail.** Run: `cd frontend && flutter test test/features`. Expected: FAIL on the new tests.
- [ ] **Step 3: Add the calls.**
- [ ] **Step 4: Run them to verify they pass.** Run: `cd frontend && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** (only after owner approval)

```bash
git commit -am "feat(analytics): track the first-run funnel, activation and New for you"
```

---

### Task 8: Phase verification

- [ ] Run `cd frontend && flutter analyze && flutter test`. Expected: clean, PASS (the audit and the 360px tests are green).
- [ ] Run `cd backend/supabase/functions && deno test learning-paths/`. Expected: PASS.
- [ ] Local end-to-end, on web run alone with flags on: first run in Malayalam → lesson 1 → Mark complete → Not now. Then:

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "select event_type, event_data from analytics_events where event_type like 'nux.%' order by created_at desc limit 10"
```

You should see `first_open`, `language_selected{ml}`, `goal_selected`, `lesson_started`, `lesson_completed{lesson_number:1}` and `guest_continued`, all with the guest's `user_id`. `select * from nux_activation_daily` then shows the user (activated once `verse_viewed` fires).

## Self-review notes

- **Owner requirement coverage:**
  - (1) Audit of hi/ml strings on redesigned screens with proposed wording: Tasks 1–2.
  - (2) ≤1.3× rule: the Global Constraints, enforced by the Task 1 test.
  - (3) Long DB titles: `short_title` chosen and migrated in Task 3; lesson titles use the 2-line rule.
  - (4) 360px widget tests for the Home path header, lesson card, dock and banner: Task 4.
- **Metrics coverage** (activation, D1/D7, time to first lesson, funnel, New-for-you impressions and taps): Tasks 5–7.
- Native-speaker approval of the string table and of `short_title` seeds is an explicit step (Task 2, Step 4).
