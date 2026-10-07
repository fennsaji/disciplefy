# New-User Experience Redesign — Roadmap (master plan)

> **For agentic workers:** this is the index. Each phase has its own plan in this folder; execute those with superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps in phase plans use checkbox (`- [ ]`) syntax.

**Goal:** Make "today's verse + one learning path lesson" the first and main experience, with guest mode, a calmer Home, a simpler Generate/Topics/Memory/My Plan, and honest Hindi/Malayalam — shipped in independently releasable phases.

**Architecture:** Six phases. Phase A fixes data/flow bugs on the shipped screens with no flag. Phases B–D build new surfaces behind `feature_flags` rows read by `SystemConfigService`, so each can merge and deploy dark and be switched on per environment from admin-web. Phases E–F are simplifications and cross-cutting i18n/analytics that apply to both old and new surfaces.

**Tech Stack:** Flutter (BLoC, GetIt, go_router), Supabase Edge Functions (Deno/TS), PostgreSQL migrations, Supabase Auth (anonymous + identity linking).

**Spec:** `docs/ux/design-final/*.png` (14 boards), `docs/ux/2026-10-06-new-user-ux-audit.md`, `docs/ux/2026-10-07-tab-simplification-review.md`, `docs/ux/2026-10-07-final-design-review.md`, owner decisions (Global Constraints below).

## Global Constraints

Product decisions agreed with the owner (2026-10-06). Every task implicitly includes all of them.

- **First focus:** the daily verse plus one learning path. Everything else is secondary and disclosed progressively; no feature is ever gated by the disclosure system (every feature stays reachable from its tab).
- **First run:** Language (with "Log in" top-right and "Already have an account? Log in") → "What would you like to grow in?" (6 choices mapped to real paths, see table) → Lesson 1 in Quick Read (the shipped study guide screen + a small Quick/Full switch + one "Want the full study? Read the full guide →" line) → "Lesson 1 complete" with sign-up (Google / Apple / Email) or "Not now".
- **Goal → path map (slugs):** "I'm new to faith" → `new-believer-essentials`; "Forgiveness and a fresh start" → `sin-repentance-and-grace`; "Walking with God daily" → `growing-in-discipleship`; "Hope in hard times" → `theology-of-suffering`; "Reading a Gospel" → `gospel-of-mark`; "Understanding the gospel" → `romans-gospel-unfolded`. These six are also the guest-accessible paths (owner decision 2026-10-07; replaces Understanding the Bible and Rooted in Christ).
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

## Review Focus

- A guest (anonymous JWT) hitting an edge function that still checks `userContext.type === 'authenticated'` gets 401 and a blank screen — every guest-reachable function must be in Phase B's allow-list test.
- Sign-up from guest with a Google/Apple account that already exists: linking fails (`identity_already_exists`); the user must still end up signed in with guest progress merged, never stuck on an error.
- Hindi/Malayalam at 360px: dock labels, "Start lesson N", path header + "See path" must not overflow or ellipsize labels (only DB titles may ellipsize).
- A returning user who already has an enrolled path must never see the first run or "Choose your first path".
- Flags off = today's app exactly: each phase's tests include a flag-off assertion that the old screen renders.

---

## Phases

| # | Plan | Ships | Depends on | Flag |
|---|---|---|---|---|
| A | `2026-10-06-p0-bug-fixes.md` | One-tap Start, explicit "Mark complete · Lesson N of M", full-screen "Lesson N complete" page with tappable next-lesson row + "Continue to lesson N" + "Back to Home" (no per-day gate), lesson header "LESSON N OF M", single plan source + My Plan fixes, one streak, XP reconcile, hi/ml fonts + localized dates, Continue reading without path lessons, Discipler quota refresh | — | none (bug fixes) |
| B | `2026-10-06-first-run-and-guest-mode.md` | Language → goal → Lesson 1 Quick Read → Lesson complete + sign-up / Not now; guest (anonymous auth, server-side progress, identity linking + merge fallback); account-needed sheet; Skip/Log in branch; tours removed from first run | A (lesson context, Mark complete, LessonCompletePage hooks) | `new_first_run`, `guest_mode` |
| C | `2026-10-06-home-redesign.md` | New Home (header pill rules, verse "Reflect" link, path strip tiers, lesson card + Quick/Standard chip), "Choose your first path" card, New-for-you scheduler + 5 banners + 5 feature intros | A; B only for the guest row (renders nothing when `guest_mode` off) | `home_today_layout` |
| D | `2026-10-06-generate-simplification.md` | Single auto-detect input, chips, verse-of-day row, Quick/Standard + All 5 sheet, inline cost, honest out-of-credits sheet, opens streaming guide directly | A (Continue reading filter) | `generate_single_input` |
| E | `2026-10-06-topics-memory-plan-simplification.md` | Topics/All paths/category, path detail without XP, Memory verses (Save today's verse, neutral Due, one-line stats, Statistics/Champions in ⋮ menu; shipped practice flow kept), My Plan single summary + Credits simplification, Settings/Community tweaks, wording unification (lesson, credits), XP hidden from new-user surfaces | A; C Tasks 2–3 (`ActivePathSummary`, `PathProgressStrip`) | none (simplification of shipped screens) |
| F | `2026-10-06-i18n-and-analytics.md` | hi/ml short-string audit + rewrites, `short_title` for paths, 360px overflow tests, activation analytics events + SQL funnel views | Runs last for the string audit (covers B–E keys); analytics tasks can start right after A | none |

**Order:** A → (B ∥ D) → C → E → F (E may start once C Tasks 2–3 merge). C after B because Home's guest row and "Choose your first path" read B's goal/guest state; C can start in parallel with B if it stubs `GuestStatus` as "not a guest". F's analytics Tasks 5–7 may run any time after A; its string audit (Tasks 1–4) must run after B–E merge.

**Each phase ships independently:**
- A: deploy as normal; every fix is visible immediately.
- B: merges dark. Turn on `guest_mode` first in dev to soak anonymous auth, then `new_first_run`.
- C: merges dark; `home_today_layout` off keeps the current Home.
- D: merges dark; `generate_single_input` off keeps the current Generate.
- E, F: ship live.

## Rollout / feature-flag strategy

1. One migration per phase inserts its flag rows into `public.feature_flags` with `is_enabled=false`, `display_mode='hide'`, `enabled_for_plans=ARRAY['free','standard','plus','premium']`, `rollout_percentage=0`, `metadata={"category":"rollout"}` — `ON CONFLICT (feature_key) DO NOTHING`.
2. Flutter reads them through one helper, `RolloutFlags` (`frontend/lib/core/services/rollout_flags.dart`, created in Phase B Task 1 and reused by C/D): `bool get newFirstRun`, `guestMode`, `homeTodayLayout`, `generateSingleInput`. Plan type passed is `'free'` for guests and signed-out users so the flag is readable before login.
3. Turn-on order per environment: dev (all) → prod `guest_mode` → prod `new_first_run` → prod `home_today_layout` → prod `generate_single_input`. Flip from admin-web feature flags page (no deploy).
4. Kill switch = set `is_enabled=false`. Every new surface falls back to the shipped one; guest users created while on stay valid (they are normal anonymous users).
5. Owner dashboard steps for hosted projects (not deploy steps): enable **Anonymous sign-ins** and **Manual identity linking** in Supabase Auth settings for dev and prod before turning on `guest_mode`. Local `config.toml` is changed in Phase B.

## Risks

| Risk | Mitigation |
|---|---|
| ~90 edge-function call sites treat anonymous JWTs as `type:'anonymous'` with no `userId` → guests get 401 | Phase B Task 2 maps anonymous JWTs to `{type:'authenticated', userId, isGuest:true}` and adds `requireFullAccount` for fellowship/Discipler/payments; contract test lists guest-allowed functions |
| Anonymous-user abuse (cost) | Supabase `anonymous_users` per-IP rate limit (30/h local), path lessons are cached + free, custom Generate still metered by credits; guests get the free plan |
| Identity linking edge cases (account exists, email confirmation pending) | Merge fallback `user-profile?action=merge_guest`; email path keeps the anonymous session until confirmed |
| Path lesson in Quick Read costs credits on day 1 | Phase B Task 4 makes catalogue lessons free in `quick` and in the path's recommended mode |
| Two i18n systems (`context.tr` and `AppLocalizations`) | New strings only in `context.tr`; nav labels stay in `AppLocalizations` and are shortened there (Phase F) |
| No bundled Indic fonts → tofu on some web/Android | Phase A bundles Noto Sans Devanagari + Noto Sans Malayalam with `fontFamilyFallback` |
| Home/Generate rewrites are large files (`home_screen.dart` ~1400 lines, `generate_study_screen.dart` ~2200) | New layouts are new files selected by flag; old files untouched until flag cleanup |
| Low-RAM dev machine | Run Flutter build, Supabase, functions, browser one at a time; prefer widget tests |

## Metrics (owned by Phase F)

| Metric | Definition | Target |
|---|---|---|
| Activation | % of new users with `verse_viewed` AND `nux.lesson_completed{lesson_number:1}` within 24h of `first_open` | ≥45% |
| Time to first lesson complete | median `lesson_completed(1).created_at − first_open.created_at` | ≤6 min |
| First-run funnel | `first_open → language_selected → goal_selected → lesson_started → lesson_completed → signup_completed \| guest_continued` | no step >20% drop |
| D1 / D7 | % of activated users with any `verse_viewed` or `lesson_completed` on day 1 / day 7 | ≥35% / ≥20% |
| New for you | impressions, taps, dismissals per banner id | track; tap rate ≥10% |
| Guest conversion | % of guests with `signup_completed{from_guest:true}` within 14 days | track |
| Day-1 credit warnings | `credit_warning_shown` on day 0 | <5% |
| Language parity | activation hi/ml vs en | within 5pp |

## Open questions for the owner

1. **Hosted Supabase settings.** Turn on Anonymous sign-ins and Manual identity linking for dev and prod before `guest_mode`. These are dashboard toggles, not deploy steps.
2. **Free Quick Read path lessons for everyone.** Today a path lesson is free only in the path's recommended mode. Is it OK for it to also be free in Quick Read (Phase B Task 4)?
3. **Tab rename.** Should the hi/ml "Topics" dock label become "पथ"/"പാതകൾ"? The English label stays "Topics" (Phase F Task 2).
4. **Native review.** Who approves the shortened hi/ml strings and the `short_title` seeds (Phase F Task 2, Step 4)?
5. **Streak backfill timezone.** `last_activity_local_date` is backfilled assuming IST (Phase A Task 6).
6. **Discipler first-use polish.** Warning before quota use and asking for a rating only after the 3rd chat (audit P1-6) are not in any phase. Plan them separately?
7. **Fellowship lesson-state consistency.** Group progress vs personal progress (final review P0-4) is not in these plans; it touches rs-backend cron and fellowship_study. Plan it separately?

## Done when

All six plans are merged, flags on in prod, and the UAT pass bar in the audit §6 is met (S1–S4, S10 ≥80% success).
