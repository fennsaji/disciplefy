# Personalization System — Gap Analysis & Recommendations

**Date:** February 27, 2026
**Author:** Engineering Analysis
**Scope:** End-to-end personalization system (onboarding questionnaire → scoring → content delivery)

---

## Executive Summary

The Disciplefy personalization system has a well-structured foundation: a 6-question onboarding questionnaire feeds a scoring algorithm that drives learning path recommendations and "For You" topic selection. However, the system stops at the **data collection and routing layer** — it does not yet influence the two most impactful areas: **study guide content quality** and **adaptive re-personalization over time**.

---

## Current Implementation (What Works)

| Layer | Status | Details |
|-------|--------|---------|
| Questionnaire UI | ✅ Complete | 6 questions, multi-select goals, skip option |
| Data persistence | ✅ Complete | `user_personalization` table, JSONB scoring_results |
| Scoring algorithm | ✅ Fixed (v1.2) | All 29 paths now covered; 21 were missing before fix |
| Learning path suggestions | ✅ Complete | faith_stage → path mapping at questionnaire time |
| "For You" topics API | ✅ Complete | Excludes completed/recently studied topics |
| "For You" UI (Home) | ✅ Complete | Personalization prompt card, topic cards |
| "For You" UI (Study Topics) | ✅ Complete | In-progress → featured → any, min 3 paths |

---

## Gaps Found

### 🚨 Critical Bug — Fixed

---

#### GAP-00: 21 of 29 Learning Paths Unreachable via Personalization ✅ FIXED

**Description:**
The database contains **29 learning paths** across two migrations:
- `20260119001000_learning_paths.sql` — 10 original paths
- `20260223000001_new_learning_paths.sql` — 19 new paths added Feb 23, 2026

The scoring algorithm (written against the original 10) was **never updated** after the 19 new paths were added. Additionally, 2 of the original 10 paths were also missing. In total, **21 of 29 paths scored 0 for every user** — permanently invisible through personalization.

**Paths missing from scoring algorithm (before fix):**

| Path | Category | Level | Featured |
|------|----------|-------|----------|
| `rooted-in-christ` | Foundations | follower | ✅ |
| `eternal-perspective` | Growth | disciple | No |
| `understanding-the-bible` | Foundations | seeker | ✅ |
| `baptism-and-lords-supper` | Foundations | follower | No |
| `who-is-the-holy-spirit` | Foundations | follower | No |
| `theology-of-suffering` | Growth | disciple | No |
| `money-generosity-gospel` | Growth | follower | No |
| `spiritual-warfare` | Growth | disciple | No |
| `the-local-church` | Service & Mission | follower | No |
| `evangelism-everyday-life` | Service & Mission | follower | ✅ |
| `work-and-vocation-as-worship` | Service & Mission | follower | No |
| `historical-reliability-bible` | Apologetics | disciple | No |
| `responding-to-cults` | Apologetics | disciple | No |
| `christianity-and-culture` | Apologetics | leader | No |
| `singleness-dating-marriage` | Life & Relationships | follower | No |
| `mental-health-emotions-gospel` | Life & Relationships | follower | No |
| `friendship-and-christian-community` | Life & Relationships | follower | No |
| `attributes-of-god` | Theology | disciple | ✅ |
| `law-grace-and-covenants` | Theology | disciple | No |
| `sin-repentance-and-grace` | Theology | seeker | No |
| `the-big-questions` | Theology | seeker | No |

**Root Cause:** 19 new paths added via migration `20260223000001_new_learning_paths.sql` with no corresponding update to `scoring-algorithm.ts`. `applyTimeAvailabilityScoring` and `applyLearningStyleScoring` work dynamically on all paths (path.recommended_mode), but the other 4 scoring functions use hardcoded slug lists.

**Fix Applied (algorithm v1.2):**
Added scoring mappings for all 21 missing paths across 4 questionnaire dimensions:
- `applyFaithStageScoring` — all 3 faith stages updated
- `applySpiritualGoalScoring` — all 6 goals updated
- `applyLifeStageFocusScoring` — all 4 life stages updated
- `applyBiggestChallengeScoring` — all 5 challenges updated
- `applyTimeAvailabilityScoring` — already dynamic (no change needed)
- `applyLearningStyleScoring` — already dynamic (no change needed)

**Status:** ✅ Fixed in `_shared/personalization/scoring-algorithm.ts` (v1.0 → v1.2)

> **Note:** All existing users whose `scoring_results` were computed with v1.0/v1.1 will not see the new paths until their scores are recalculated. This is a consequence of GAP-03 (static scoring). As a short-term workaround, the "For You" UI section shows all non-completed paths client-side regardless of score, so new paths can still surface through that route.

---

### 🔴 Critical — High User Impact

---

#### GAP-01: Study Guide Content Is Not Personalized

**Description:**
Study guides are generated once and **cached and shared across all users** by cache key: `input_value_hash + language + study_mode`. This means per-user LLM prompt injection is architecturally impossible for learning path topics — injecting a user's faith stage into the prompt would produce content that is wrong for every other user who hits the same cache.

The cache key is defined in `study-guide-repository.ts → findExistingContent()`:
```ts
.eq('input_type', input.type)
.eq('input_value_hash', inputHash)   // same topic → same hash
.eq('language', input.language)
.eq('study_mode', input.study_mode)  // mode IS part of key
```

**Constraint:** LLM prompt personalization is **only viable for user-generated/free-input topics** (where the cache hit rate is near 0%). It cannot be applied to the 29 curated learning path topics.

**Affected Files:**
- `backend/supabase/functions/study-generate-v2/index.ts`
- `backend/supabase/functions/_shared/repositories/study-guide-repository.ts`

**Impact:** Personalization data collected at onboarding has zero effect on study guide content depth or complexity.

**Correct Approach (3 viable alternatives):**

1. **Auto study mode selection from questionnaire** ← most impactful, works with caching
   - `study_mode` IS part of the cache key — different modes produce genuinely different content
   - Map questionnaire answers to the optimal mode automatically (this is GAP-02)
   - A `new_believer + 5_to_10_min + practical_application` user getting **Quick mode** vs a `committed_disciple + 20_plus_min + deep_understanding` user getting **Deep mode** is real, meaningful personalization

2. **Frontend personalized reading guide overlay** ← zero backend change needed
   - Display a thin card before the study guide based on user profile:
     - `new_believer` → "Focus on the Summary and Application sections"
     - `reflection_meditation` → "Take your time with the Reflection Questions"
     - `handling_doubts` → "Pay special attention to the Related Verses section"
   - Does not alter cached content; adds user-specific framing in the client

3. **Inject personalization into voice conversations and reflections** ← per-user, not cached
   - Voice conversations and study reflections are NOT cached — they are per-user sessions
   - These can safely include questionnaire context in the system prompt
   - Affected: `voice-conversation/index.ts`, `study-followup/index.ts`

---

#### GAP-02: Time Availability Not Linked to Study Mode Default ✅ FIXED

**Description:**
`time_availability` is collected but never used to set a study mode preference. A user who selects `5_to_10_min` is not defaulted to **Quick** mode, and a user who selects `20_plus_min` is not offered **Deep** or **Lectio** modes proactively.

**Affected Files:**
- `backend/supabase/functions/save-personalization/index.ts`
- `frontend/lib/features/personalization/data/repositories/personalization_repository_impl.dart`

**Impact:** Users who want quick sessions are shown standard-length study guides by default; users who want depth see no signal toward richer modes.

**Recommended Fix:**
After saving the questionnaire in `save-personalization`, set `default_study_mode` in `user_profiles`:

| time_availability | Suggested Default |
|-------------------|------------------|
| `5_to_10_min` | `quick` |
| `10_to_20_min` | `standard` |
| `20_plus_min` | `deep` |

Also respect `learning_style = reflection_meditation` → `lectio`.

---

### 🟠 Medium — Reduces Personalization Quality Over Time

---

#### GAP-03: Scoring Is Static — Never Recalculated ✅ FIXED

**Description:**
Personalization scores are computed once at questionnaire submission and stored in `scoring_results` JSONB. They are never recalculated based on:
- Topics the user has actually studied
- Learning paths completed
- Study modes chosen
- Session frequency or streak data

**Affected Files:**
- `backend/supabase/functions/topic-progress/index.ts`
- `backend/supabase/functions/_shared/personalization/scoring-algorithm.ts`

**Impact:** A user who was a `new_believer` and has now completed the "New Believer Essentials" path still receives beginner recommendations.

**Fix Applied:**
Score recalculation is now triggered in `topic-progress/index.ts` after `action: complete`, inside `maybeTriggerScoreRecalculation()`:

1. **Learning path completion** — detects a path where `completed_at` was set in the last 10 seconds (the DB trigger `trg_update_learning_path_progress` fires inside the `complete_topic_progress` RPC, so `completed_at` is already written when we check). Re-runs `calculatePathScores()` excluding all now-completed paths.
2. **Every 10 topic completions** — when the user's total completed topic count reaches a multiple of 10, triggers a milestone recalculation even without a path completion.
3. Non-fatal: errors are logged and swallowed so topic completion always succeeds.
4. Only fires on `is_first_completion = true` — repeat completions don't trigger recalculation.

**Status:** ✅ Fixed in `topic-progress/index.ts`

---

#### GAP-04: No Re-Questionnaire Flow in Settings ✅ ALREADY IMPLEMENTED

**Description:**
There is no UI for a user to update their questionnaire answers after onboarding. Faith stage and spiritual goals naturally evolve. A user who was a `new_believer` has no path to update to `committed_disciple` short of deleting their account.

**Affected Files:**
- `frontend/lib/features/settings/presentation/pages/settings_screen.dart`
- `frontend/lib/features/personalization/presentation/pages/personalization_questionnaire_page.dart`

**Impact:** Personalization data becomes stale, reducing recommendation quality over time.

**Status:** ✅ Already implemented. Settings screen has a "Personalization" section with a "Retake Questionnaire" option (`_buildPersonalizationSection` / `_navigateToQuestionnaire`). On return, personalization-dependent data is refreshed.

---

#### GAP-05: Profile Interests Collected But Never Used ✅ FIXED

**Description:**
The profile setup screen (`profile_setup_screen.dart`) collects user interests (topics of interest), but these are never incorporated into the scoring algorithm or topic selection logic.

**Affected Files:**
- `backend/supabase/functions/_shared/topic-selector.ts`

**Impact:** Collected data goes unused; missed signal for category weighting.

**Fix Applied (`topic-selector.ts`):**

1. **Learning path recommendation (Priority 2 — also fixed a silent bug):**
   Previously used `personalization.faith_journey` which doesn't exist in the new schema (new schema uses `faith_stage`). Priority 2 was **silently broken** — it never fired. Fixed to use `scoring_results.allScores` from the v1.2 algorithm (all 29 paths sorted by pre-computed score). Fetches all completed path slugs in a single query and picks the top-scored non-completed path. Falls back to `faith_stage` mapping and then legacy `faith_journey` mapping.

2. **Topic-level scoring bonus:** Added `INTEREST_TOPIC_CATEGORY_MAP` that maps each interest keyword to matching `recommended_topics` categories. `calculateTopicScore()` now accepts `interests: string[]` and applies a **+10 pt bonus** per topic whose category matches a declared interest. `selectTopicsForYou()` fetches `user_profiles.interests` and passes them through `scoreAndSortTopics()` → `calculateTopicScore()`.

**Interest → Category mapping:**
| Interest | Topic Categories |
|----------|-----------------|
| `prayer`, `worship` | Spiritual Disciplines |
| `community` | Church & Community, Family & Relationships |
| `bible_study` | Foundations of Faith |
| `theology` | Apologetics & Defense of Faith |
| `missions`, `evangelism` | Mission & Service |
| `youth_ministry` | Discipleship & Growth, Church & Community |
| `family` | Family & Relationships |
| `leadership` | Discipleship & Growth, Mission & Service |

**Status:** ✅ Fixed in `_shared/topic-selector.ts`

---

#### GAP-06: Next Learning Path Not Suggested After Completion ✅ ALREADY IMPLEMENTED + ENHANCED

**Description:**
When a user completes a learning path, there is no automatic suggestion for what to study next based on their personalization profile.

**Verification:**
This was already fully implemented via the `learning-paths/recommended` endpoint (`handleGetRecommendedPath`):
- **Priority 1**: Active (enrolled, not completed) path
- **Priority 2**: Calls `calculatePathScores()` excluding completed paths → picks top-scored path, returns with `reason: 'personalized'`
- **Priority 3**: Featured fallback

The home screen `HomeCombinedState` has `activeLearningPath` + `learningPathReason` fields. When a user completes a path, Priority 1 no longer applies and Priority 2 fires automatically.

**Enhancement added (GAP-05 fix improved this further):**
- The `selectTopicsForYouWithLearningPath` Priority 2 was silently broken (used non-existent `faith_journey` field). Fixed in GAP-05 to use `scoring_results.allScores` from the v1.2 algorithm.

**Home screen UI enhancement:**
Added a "You're ready for your next step" label above the path card in `home_screen.dart` when `learningPathReason == personalized`. This surfaces the proactive recommendation contextually.

**Status:** ✅ Already implemented (backend) + UI label enhanced in `home_screen.dart`

---

### 🟡 Low — Missed Enhancement Opportunities

---

#### GAP-07: No Notification Personalization Based on Goals ✅ FIXED

**Description:**
All users receive the same notification types regardless of their spiritual goals. A user with `staying_consistent` as their biggest challenge is the ideal target for streak notifications, yet `streakReminderEnabled` is applied uniformly.

**Fix Applied:**
Added `maybeUpdateNotificationPreferences()` to `save-personalization/index.ts` — called after questionnaire save (non-fatal):

| Answer | Notification Update |
|--------|-------------------|
| `biggest_challenge = staying_consistent` | `streak_reminder_enabled = true`, `streak_lost_enabled = true` |
| `spiritual_goals includes foundational_faith` | `recommended_topic_enabled = true` |
| `time_availability = 5_to_10_min` | `streak_reminder_time = '08:00:00'` (morning) |

Uses upsert with `onConflict: 'user_id'` — works for both new users and questionnaire retakes. Errors swallowed so questionnaire save always succeeds.

---

#### GAP-09: LLM Study Guides Not Tailored to Learning Style

**Description:**
The `learning_style` questionnaire field (`practical_application`, `deep_understanding`, `reflection_meditation`, `balanced_approach`) is stored but never injected into the LLM prompt to shape content structure.

**Affected Files:**
- `backend/supabase/functions/generate-study-guide/index.ts`

**Recommended Fix:**
Apply learning style to the study guide structure:

| learning_style | Guide Adjustment |
|----------------|-----------------|
| `practical_application` | Emphasise "Application" section, add real-life scenarios |
| `deep_understanding` | Expand "Theological Context", add cross-references |
| `reflection_meditation` | Expand "Reflection Questions", add Lectio-style prompts |
| `balanced_approach` | Standard output (current default) |

---

## Recommended Next Steps — Prioritised

| Priority | Gap | Effort | Impact |
|----------|-----|--------|--------|
| ✅ Done | GAP-00: 21 paths missing from scoring algorithm | Fixed | Critical |
| ✅ Done | GAP-02: Link time_availability → study mode default | Fixed | High |
| ✅ Done | GAP-03: Trigger score recalculation on path/milestone completion | Fixed | Medium |
| 2 | GAP-01a: Auto study mode from questionnaire (replaces LLM injection) | Low (1 day) | High |
| 2b | GAP-01b: Inject personalization into voice/reflections (not cached) | Medium (1–2 days) | Medium |
| 2c | GAP-01c: Frontend personalized reading guide overlay | Low (1 day) | Medium |
| ✅ Done | GAP-04: Re-questionnaire flow in Settings | Already implemented | High |
| ✅ Done | GAP-06: Next path suggestion after completion | Already implemented + label enhanced | High (retention) |
| ✅ Done | GAP-05: Wire profile interests into scoring | Fixed | Medium |
| 6 | GAP-09: Apply learning style to guide structure | Medium (2–3 days) | High |
| ✅ Done | GAP-07: Notification defaults from questionnaire | Fixed | Medium |
| 8 | GAP-08: Recommendation analytics | High (1 week) | Medium (long-term) |
| 9 | GAP-10: A/B testing on scoring weights | High (1 week+) | Low (long-term) |

---

## Sprint Recommendation

**Sprint: Personalization Depth (Version 2.4 candidate)**

**Sprint Goal:** Close the gap between collected personalization data and actual user experience.

**Sprint Scope (2-week sprint):**

### Week 1 — Quick Wins
- [x] GAP-02: Set `default_study_mode` from `time_availability` after questionnaire save
- [x] GAP-06: Return next suggested path after learning path completion
- [x] GAP-05: Apply profile interests as score bonus in `topics-for-you`
- [x] GAP-04: Add "Update Preferences" entry in Settings → Profile

### Week 2 — Core Depth
- [ ] GAP-01: Inject `faith_stage` + `spiritual_goals` + `learning_style` into LLM system prompt
- [ ] GAP-09: Apply learning style to study guide section emphasis
- [x] GAP-07: Auto-configure notification defaults based on `biggest_challenge`

**Deferred to Future Sprint:**
- GAP-03: Score recalculation (requires study history integration)
- GAP-08: Analytics infrastructure
- GAP-10: A/B testing framework

---

*This document should be reviewed alongside `docs/planning/Roadmap.md` and updated as gaps are resolved.*
