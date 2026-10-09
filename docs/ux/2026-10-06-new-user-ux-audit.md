# New-User UX Audit — Disciplefy (2026-10-06)

**Method.** Two fresh accounts ("Asha Thomas", English; "Ravi Kumar", Hindi) on the local web release build (390×844, dark theme). I acted as a newcomer and took every step as a tap-by-tap walkthrough. Backend was local Supabase with `USE_MOCK=true`, so LLM content is placeholder text: judge flow and labels, not content quality. Screenshots are in `docs/ux/audit-screenshots/` (`NN-name.png`).

**Owner direction.** Make the **Daily Verse** and **one Learning Path** the main and first experience. Everything else is secondary and is disclosed progressively.

**Caveats.** Screens 13–19 and 14 ("Oops! Something went wrong") were captured while the local backend was down. They are environmental, but the generic error copy still counts as a finding. Memory-verse load times of about 45 s are probably caused by local resource pressure (three Supabase stacks running). They need re-measuring on staging.

---

## 1. Executive summary — top 5 problems

1. **The app asks for decisions before it gives any value, and the tours never stop.** A new user goes through: 4 marketing slides → Welcome/sign-in → sign-up → a language picker that is in English only → a 6-step coach-mark tour → a notification sheet → a "Personalize (3 questions)" card. After that, almost every screen opens another tour: guide 2, memory 1+2, practice modes 1, flip card 1, Topics 2, Generate 3, Community 2. That is **about 20 tooltips on day 1**, each with a "Watch video" button. The daily verse is visible from the first second but sits under an overlay most of the time.
2. **Home does not lead with the two jobs that matter.** Home shows about 6 features and about 15 tap targets: a Memory Verses chip, Settings, a verse card with 4 actions, streak and review tiles, the Personalize card, Continue learning, Find your fellowship plus Join, and the 5-tab bar. The learning path appears below the fold as "New Believer Essentials · Start here · 8 topics". Nothing tells the user "Today: read the verse → do lesson 1".
3. **Starting a learning path is broken and has no clear moment of starting.** Tapping **Start Path** shows "Enrolling…" and then a "Successfully enrolled" toast. It then reloads the same page with **Start Path** still showing and no progress. A second tap is needed, which shows the button as "Start Path · Who is Jesus Christ?", and a third tap opens lesson 1 (28→31c). Inside the lesson nothing says "Lesson 1 of 8". The completion sheet appears about 30 s after reaching the end, and "Continue learning path" goes back to the path list instead of lesson 2.
4. **Too many overlapping names for the same things.**
   - Learning content: *Topic*, *Topics tab*, *Learning Path*, *Lesson*, *Study Guide*, *Guide*, *Study*.
   - Groups: *Community*, *Fellowship*, *Group*.
   - Levels and tiers: *Seeker* is both the user's level and a path difficulty tier, alongside *Listener*, *Follower*, *Disciple* and *Leader*.
   - Gamification: *XP*, *Milestone*, *Champions*, *Achievements*.
   - Paid units: *Credits* (daily) and Discipler's "3 of 3 left this month" (conversations).
   - Memory verses: *Ease 2.5*, an SM-2 algorithm value shown to users.
   - Hindi mixes स्मृति आयतें with याद वर्सेज, स्ट्रीक and an untranslated "Discipler".
5. **Money and quota feel like penalties from day 1, and they contradict each other.** After one daily-verse study plus one generated Quick Read, the new user sees **"Getting Low — 10 of 40 left"** (57). Follow-ups say "5 credits each". Discipler is a separate 3-per-month quota, and the counter did not decrease after use (50b). Credits says "**Standard plan** · Free until March 31, 2027" while the Create Fellowship paywall says "**Your plan: Free**" (59). Practice modes show "0 of 2 modes unlocked today · Upgrade".

---

## 2. Findings by severity

Legend: **P0** blocks activation or is a broken core flow · **P1** major confusion or drop-off risk · **P2** friction or inconsistency · **P3** polish.

### P0

| # | Screen | Screenshot | Why it's confusing | Concrete fix |
|---|---|---|---|---|
| P0-1 | Learning path → Start Path | 28, 29, 29b, 30, 31, 31b | Enrolment succeeds (the DB row exists), but the page reloads still showing "Start Path" with no progress. The user taps again and sees "Enrolling in path…" a second time. It takes 3 taps and 2 loaders to reach lesson 1. | One tap on "Start" should enrol and open lesson 1 straight away. Re-render the button from enrolled state ("Continue · Lesson 1"). Never show a second "Enrolling…". |
| P0-2 | First run as a whole | 01–11-tour-7, 17, 21b, 39d, 41, 42b, 44, 52, 54, 58 | About 20 coach marks across 8 screens, plus a notification sheet and a questionnaire card. The tours block the real tap target: the memory-verse tooltip covered the verse card I was told to tap (41). Counters are inconsistent ("1/1" followed by "2/2"). | Remove the per-screen tours. Keep at most one contextual hint per session, shown only after the user's first success. Move "Watch video" to Help. |
| P0-3 | Home on day 1 | 10, 12, 17, 20 | No single "do this first" action. The path sits below the fold. "Personalize Your Experience" and "Find your fellowship" compete with it. | Use the Day-1 Home in §3: a verse card plus one "Today's lesson" card, and nothing else above the fold. |

### P1

| # | Screen | Screenshot | Why | Fix |
|---|---|---|---|---|
| P1-1 | Language step | 10, 71, 72 | The language picker appears only **after** account creation and is written in English. The 4 onboarding slides and the sign-in page are English only. "English · Hindi · Malayalam" on the Welcome page is static text, not tappable. A Hindi-only user cannot read anything until after sign-up. | Make language the very first screen, labelled in each script (EN / हिन्दी / മലയാളം). Make the Welcome-page language row tappable. |
| P1-2 | Hindi guide content | 75 | After choosing Hindi, "Study now" on the Hindi verse (यूहन्ना 3:16 IRV) opened a guide with Hindi headings but **English body text** and an English title ("Joh…"). This may be a mock or cache artifact and needs re-testing with the real LLM. The date label "OCTOBER 6, 2026" on the Hindi Home is also English. | Key the guide cache by language. Localise date formats. Add a Hindi and Malayalam smoke test to UAT (S12). |
| P1-3 | Sign-up | 08, 70 | The first run showed the error toast "Email Sign-Up succeeded but user data is missing". The second run stayed silently on the form, although the account had been created. | Show "Check your email to confirm" with the address and a resend button. Never show internal wording. |
| P1-4 | Credits on day 1 | 55, 57 | 2 studies used 30 of 40 credits and showed "Getting Low". Costs appear as coin chips (10/20/30/24) next to every depth. The new user is on Standard with a promo but is still shown upgrade CTAs everywhere. | On day 1, make the daily verse study and path lessons free and unmetered. Hide credit chips until the user starts a custom "Generate". Rename credits (see §4). |
| P1-5 | Plan contradictions | 57, 59, 49, 50b | Credits says "Standard plan · Free until Mar 2027", but the paywall says "Your plan: Free". Discipler said "3 of 3 left this month" before and after a conversation, while the server log showed 2 remaining. Standard is described as "Best for group leaders", yet it cannot create a fellowship. | Use one source of truth for the plan name in the UI. Refresh the Discipler counter after the first message. Fix the plan descriptions. |
| P1-6 | Discipler first use | 49, 50, 50b, 51 | Tapping a suggested question silently used 1 of 3 monthly conversations. The input stayed disabled while "Speaking" TTS played on web. Ending the chat opened a 5-star survey with Yes/No buttons and a feedback field on the very first conversation. | Warn before using quota ("Uses 1 of 3 free chats this month"). Keep the input usable during TTS. Ask for a rating only after the 3rd conversation. |
| P1-7 | Lesson completion | 33, 34, 34b, 35, 36 | A path lesson looks exactly like a generic guide: no "Lesson 1 of 8", no path name, no Complete button. The "Guide complete" sheet appears about 30 s after scrolling to the end, so users may leave first. "Continue learning path" goes to the path overview instead of the next lesson. | Add a path header ("New Believer Essentials · Lesson 1 of 8"). Add an explicit **Mark complete** button. The completion sheet should say "+50 XP · 1 of 8 done · Tomorrow: One God, Three Persons", with buttons "Remind me tomorrow" and "Start lesson 2". |
| P1-8 | Memory verses | 39, 39b–d, 48a–c | The list took about 45 s to load locally. Back was ignored while it was loading, so it needed a second tap. The Hindi and Malayalam filter chips rendered as **tofu boxes** (39d). | Use an optimistic or cached list. Make Back work during loading. Bundle or declare Noto Sans Devanagari and Malayalam for those chips. |
| P1-9 | Two learning entry points | 18, 52–53c, 54 | The "Topics" tab is titled "Study Topics" and actually lists **Learning Paths**, each made of "Topics". The "Generate" tab has a "Topic" mode and shows the path lesson under "Continue reading". The same content appears in 3 places under 3 names. | Rename the tab **Learn** (paths). Rename a path's items **Lessons**. Move Generate into Learn as "Study anything" (see §3). |

### P2

| # | Screen | Screenshot | Why | Fix |
|---|---|---|---|---|
| P2-1 | Verse card | 12, 13-verse-ref-tap | Tapping the reference "John 3:16 · BSB" opens **Bible copyright & attribution**, which is unexpected. Tapping the verse text opens a study (costs credits). | Reference tap → read the chapter. Move licence info to Settings/About. Make "Study now" the only action that costs credits. |
| P2-2 | Streaks | 10, 17, 64, 39d, 66, 74 | A brand-new user already sees "1-day streak" (also in Hindi, before doing anything). The same user then sees "No streak yet" (17), and Memory shows "0 day streak". That is two separate streaks with different rules. | Use one streak, defined as "read today's verse **or** finished a lesson". Start it at 0. |
| P2-3 | My Progress | 66 | Shows 25 XP total although the path lesson awarded +50 XP (DB `total_xp_earned=50`), "1 studies" after 3 guides, and "0 verses" with 1 memory verse. Level "Seeker → Listener" clashes with the path tiers Seeker/Follower/Disciple/Leader. | Reconcile the counters. Rename the user levels (see §4). |
| P2-4 | Achievement pop-up | 25 | A modal "First Steps +25 XP" interrupts reading partway through the guide. | Defer it to the completion sheet. |
| P2-5 | Guide page | 21–26 | 9 numbered sections, plus an inline "Follow-up Questions (5 credits)" chat, plus a sticky "Ask Discipler" button. That is two chat entry points on one page. | Keep one: the sticky "Ask a question" button. Collapse sections 4–7 by default for Quick Read. |
| P2-6 | Practice modes | 42b, 43, 45, 47 | 8 modes with Easy/Medium/Hard filters, an upgrade banner, "Ease 2.5", and a self-rated "80% Accuracy". The summary showed "Answer shown: No" although the user flipped the card. | Day 1: offer one default mode ("Flip & recall"). Unlock the others after 3 reviews. Hide SM-2 values. Label self-rating as "How well did you know it?". |
| P2-7 | Community Discover | 60, 61, 62, 63 | The default "All Languages" filter puts **Disciplefy हिन्दी** first for an English user, and I joined it by mistake. Joining gives no confirmation: the card simply disappears. The group tracks its own "Lesson 1 · 0 of 8" of the same path the user is already doing (1/8), so there are two progress bars for one path. The group page shows both "Post something" and "New Post". The "Mentor: Discipler" label calls the AI a mentor. | Filter by the user's language by default. After joining, open the group with a toast. Share path progress between personal and group. Keep one post button. Label it "Guided by Discipler (AI)". |
| P2-8 | Credits page | 57 | "View Purchase History" tooltip overlaps the header, and Back needed two taps. "Daily credits by plan" lists 4 plans to a promo user. | Simplify: balance, what one study costs, and "Need more?". |
| P2-9 | Generic error | 14, 18 | "Oops! Something went wrong. Please try again." is shown for a network or backend outage. | Say "Can't reach Disciplefy — check your connection". For the verse, fall back to a cached guide. |
| P2-10 | Settings | 65, 67 | "App Language" and "Content Language", and "Study Mode Preference" and "Learning Path Study Mode", come in pairs. "Resend Verification Email" is shown to a signed-in user. | Merge each pair under "Advanced". |

### P3

- Onboarding slides advertise 4 features: Study guides, Discipler, Memory, and Daily verse. Learning paths are not mentioned at all (01–04).
- Greeting subtitle "Continue your spiritual journey with guided study" is generic. Use it for the day's task instead.
- Hindi bottom tabs use "Discipler" in Latin script, and "बनाएँ" (Create) is ambiguous.
- Path metadata "14 days" next to "8 Topics" leaves it unclear whether it means one lesson per day.
- "Milestone" badges on lessons 4, 7 and 8 have no explanation.

---

## 3. Simplified first run and Home

### Target first run (≤ 60 s to the verse, ≤ 6 min to finishing lesson 1)

1. **Language** (first screen, each option in its own script). One tap.
2. **Today's verse** shown full screen with no account needed: verse, reference, and "Listen". CTA: **"Start your first lesson (5 min)"**.
3. **Lesson 1 of "New Believer Essentials"**, readable as a guest (or as an anonymous Supabase user). It ends with a **Mark complete** button.
4. **Save your progress**: Google / Apple / Email sign-up, shown *after* the first lesson is completed.
5. **Daily reminder** opt-in: "Remind me at 7 AM for tomorrow's verse and lesson 2". This is the only permission prompt.
6. Land on Home.

Removed from the first run: the 4 marketing slides (shrink to one Welcome screen with the language choice), the 6-step tour, the per-screen tours, the questionnaire card (move it to day 3 as "Pick your next path"), and the fellowship card.

### Day-1 Home (above the fold = the whole page)

```
Good morning, Asha                       [settings]
┌ TODAY ─────────────────────────────────┐
│ John 3:16  “For God so loved…”         │
│ [Listen]  [Reflect (study)]  ✓ Read    │
└────────────────────────────────────────┘
┌ YOUR PATH · New Believer Essentials ───┐
│ Lesson 2 of 8 · One God, Three Persons │
│ ▓░░░░░░░  5 min        [Continue]      │
└────────────────────────────────────────┘
🔥 1 day — read the verse + 1 lesson keeps it going
```

The tab bar on day 1 has 3 tabs: **Today** · **Learn** · **Me**. Discipler is available as "Ask a question" inside the verse and lesson.

### Progressive unlocks

| When | Unlock / surface | Trigger |
|---|---|---|
| Day 1 | Verse, path lesson, streak | — |
| After lesson 1 | "Save this verse to memory" prompt on the completion sheet | Lesson complete |
| Day 2 | **Memory review** card on Home (1 mode: Flip & recall) | Has ≥1 memory verse due |
| Day 2–3 | **Ask Discipler** as its own tab (shows quota once) | Used "Ask a question" once, or day 3 |
| Day 3 | **Study anything** (custom Generate, depth options, credits balance) inside Learn | 2 lessons done |
| Day 5 / lesson 4 milestone | **Groups** (Community tab), with an invite to study this path together | Milestone lesson |
| Week 2 | XP/levels page, leaderboard, achievements, extra practice modes | 7-day streak or 5 lessons |
| On demand | Plans / credits page | Out of credits or user opens it |

---

## 4. Terminology glossary and renames

| Current term(s) | Problem | Proposed (EN) | Hindi | Malayalam |
|---|---|---|---|---|
| Verse of the Day / Daily Verse / आपका दैनिक वचन / दिन की आयत | 2–3 names | **Today's Verse** | आज का वचन | ഇന്നത്തെ വചനം |
| Learning Path / Study plan / "For You" | OK, but hidden under "Topics" | **Path** (tab: **Learn**) | पथ | പാത |
| Topic (item inside a path) / Lesson (in groups) | Clashes with "Topic" generate mode and the tab name | **Lesson** | पाठ | പാഠം |
| Study Guide / Guide / Study | Users don't know a lesson is a guide | **Study** (generated); a lesson is shown as a lesson | अध्ययन | പഠനം |
| Generate tab | Sounds like a technical action | **Study anything** (inside Learn) | कुछ भी पढ़ें | എന്തും പഠിക്കൂ |
| Discipler | Coined word; untranslated in Hindi | Keep the brand, but always pair it: **"Ask Discipler (AI Bible guide)"**. Use "Ask a question" as the button | प्रश्न पूछें | ചോദ്യം ചോദിക്കൂ |
| Community / Fellowship / Group | 3 words for 1 thing | **Group** (tab: Groups). "Fellowship" only in marketing | समूह | ഗ്രൂപ്പ് |
| Mentor: Discipler | Implies a human | **Guided by Discipler (AI)** | — | — |
| Credits / tokens / "3 of 3 left this month" | 2 currencies | **Daily studies** ("2 studies left today") and **AI chats** ("2 chats left this month") | — | — |
| Seeker / Listener (user level) vs Seeker / Follower / Disciple / Leader (path tier) | Same word for two concepts | Path tier → **Beginner / Growing / Mature / Leader**. User levels stay as identity titles | — | — |
| XP | Gamer jargon | **Points** (keep the "+50" number) | अंक | പോയിന്റ് |
| Milestone | Unexplained | **Checkpoint** with a tooltip ("a key truth worth remembering") | — | — |
| Champions | Unexplained (memory leaderboard) | Hide until week 2. Then **Top memorizers** | — | — |
| Ease 2.5, intervals | Algorithm leak | Remove. Show "Next review: tomorrow" | — | — |
| स्मृति आयतें / याद वर्सेज | Two Hindi names | **याद करने के वचन** (one term everywhere) | — | — |
| स्ट्रीक | Loanword | लगातार दिन | — | — |

---

## 5. Metrics

**North-star activation (day 0):** the user **read today's verse** (verse card viewed ≥5 s, or Listen pressed) **and** **completed lesson 1** of a path, both within 24 h of install.

| Metric | Definition | Target (first 30 days after redesign) |
|---|---|---|
| Activation rate | % of new installs that meet the north-star within 24 h | ≥ 45 % |
| Time to first verse | Install/open → verse visible without an overlay | ≤ 30 s (median) |
| Time to first lesson complete | Install → lesson 1 complete | ≤ 6 min (median) |
| First-run drop-off by step | Funnel: language → verse → lesson start → lesson complete → sign-up → reminder opt-in | No step > 20 % drop |
| D1 retention | % of activated users who return on day 1 **and** do the verse or a lesson | ≥ 35 % |
| D7 retention | % of activated users active on day 7 | ≥ 20 % |
| Path continuation | % of lesson-1 completers who complete lesson 2 within 48 h | ≥ 50 % |
| Day-1 credit exhaustion | % of new users who see "Getting low" or "out of credits" on day 1 | < 5 % |
| Tour skip rate | % of hint dismissals using "Skip" | Track; aim to remove the tours |
| Language parity | Activation for hi/ml vs en | Within 5 pp |

Instrument these events: `language_selected`, `verse_viewed`, `verse_listened`, `lesson_started{path,lesson}`, `lesson_completed`, `signup_completed{method}`, `reminder_opt_in`, `credit_warning_shown`, `hint_shown/dismissed{screen,step}`, and `discipler_quota_used`.

---

## 6. UAT plan

### Participants (5–8 per round; 2 rounds)

- 3 × **new or returning believers** (0–2 years of faith), smartphone-comfortable, no Bible app habit.
- 2 × **regular Bible readers** who use YouVersion or similar (comparison anchor).
- 2 × **Hindi-first** speakers (at least 1 who cannot read English comfortably).
- 1–2 × **Malayalam-first** speakers.
- Mix: ages 18–60, at least 2 aged 45+, at least 2 on low-end Android, at least 1 small-group leader (for the group task).
- Exclude: Disciplefy staff, existing Disciplefy users.

### Method

- 45-minute **moderated think-aloud** sessions, remote (screen share) or in person, conducted in the participant's preferred language.
- Use a fresh install or an incognito web session per participant, on a staging account with **real** LLM output (not mock).
- The moderator reads each task verbatim, does not help unless the participant is stuck for more than 2 minutes, and records time on task, success/partial/fail, errors, and quotes.
- Each task ends with a **single ease question** (SEQ 1–7). The session ends with **SUS** (10 items, translated for hi/ml) and the question "What is this app for, in one sentence?".
- **Day-2 diary follow-up:** the next day the participant opens the app unprompted and completes S10 with a screen recording, plus a 5-minute call.
- Severity rating: P0 = blocks the task for ≥2 participants; P1 = slows or confuses ≥3; P2 = minor.

### Scenarios

| # | Task (read to participant) | Success criteria | Observe | Post-task question |
|---|---|---|---|---|
| S1 | "You just installed this app. Set it up in the language you're most comfortable with." | Reaches Home or the verse in the chosen language, ≤ 2 min | Finds the language choice before sign-up? Reads the slides? Number of taps, skips, tours | "Was anything asked of you that you didn't expect?" |
| S2 | "Read today's Bible verse." | Verse visible and read, ≤ 30 s from Home | Distracted by overlays or tiles? Taps the reference and lands on the copyright page? | "What would you do next after reading it?" |
| S3 | "Find a short Bible study plan for someone new to faith and start it." | Lesson 1 opened, ≤ 2 min, ≤ 1 enrol tap | Looks in Topics, Generate or Home? Re-taps Start Path? | "What is the difference between a path, a topic and a lesson?" |
| S4 | "Finish the first lesson." | Lesson marked complete and progress visible (1 of 8) | Knows when it's done? Waits for the sheet? Achievement modal interrupting? | "How do you know you finished?" |
| S5 | "Get a deeper explanation of today's verse." | Verse study opened and read | Notices the credit cost? Reaction to the 9 sections | "How much did that cost you? Is that OK?" |
| S6 | "Ask the app a question that's been on your mind about faith." | Discipler answer received | Finds Discipler? Understands the name? Voice vs type? Notices the quota? | "Who or what answered you?" |
| S7 | "Save today's verse so you can memorise it, then practise it once." | Verse in Memory, 1 practice done | Choice paralysis among 8 modes, "Ease" label, tofu text | "How will the app remind you to practise again?" |
| S8 | "Join a group of people studying the Bible together in your language." | Joined a group in the right language | Joins the wrong language? Fellowship vs community wording; confirmation | "What happens in this group?" |
| S9 | "You'd like to start your own group for your church. Try it." | Understands it needs an upgrade and which plan | Plan contradiction (Free vs Standard) | "Which plan are you on now?" |
| S10 | **Day 2:** "Open the app and continue where you left off." | Today's verse read + lesson 2 started, ≤ 1 min | Does Home show lesson 2 first? Does the streak make sense? Reminder received? | "Did the app remember you?" |
| S11 | "How many more studies can you do today, and what happens when you run out?" | Correct number stated | Credits vs chats vs plan understanding | "In your words, what is a credit?" |
| S12 | (hi/ml only) "Read today's verse and start the first lesson, in Hindi/Malayalam." | All UI and content in the chosen language | English leaks (dates, guide body, "Discipler"), tofu boxes | "Was there anything you couldn't read?" |
| S13 | "Turn off the daily reminder." | Found in ≤ 1 min | Settings depth | — |
| S14 | "Show me your progress so far." | Finds streak, lessons and points | XP vs studies counters mismatch; Seeker/Listener | "What does 'Seeker' mean here?" |

**Pass bar for the redesign:** S1–S4 and S10 succeed for ≥ 80 % of participants with median SEQ ≥ 6, SUS ≥ 72, and ≥ 4 of 5 participants describing the app as "a daily verse and a guided Bible plan".
