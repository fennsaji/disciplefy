# Fellowship 1.0.5 — Discipler, Daily Posts, Mentors, Community Redesign

**Date:** 2026-09-06
**Status:** Approved 2026-09-06 (all assumptions A1–A10 accepted); implementation plan in `docs/superpowers/plans/2026-09-06-fellowship-discipler-redesign.md`
**Version target:** 1.0.5 (`frontend/pubspec.yaml` → `1.0.5+5`; `system_config.latest_app_version` → `1.0.5`)

## Background

The fellowship feature (route `/community`, tables `fellowships`, `fellowship_posts`, `fellowship_comments`, `fellowship_members`) works but has gaps surfaced by running the official "Disciplefy fellowship" groups:

- No daily content, so official groups go quiet.
- Questions from members wait for a human mentor.
- "X has joined the fellowship" system posts flood feeds and render as ordinary posts (blank type label, reactions, report/block menu).
- One mentor per fellowship (`fellowships.mentor_user_id`), no way for members to reach a mentor directly.
- Posts cannot be shared outside the app.
- Discover defaults to the user's locale instead of All.
- Admin web has no fellowship management; admin-only flags are set from the Flutter create screen.

## Requirements → decisions

| # | Request (chat 06/09) | Decision |
|---|---|---|
| R1 | Scheduled post every day in Disciplefy fellowship | **Daily post** by Discipler: rs-backend cron picks the next learning-path topic and generates a guide through `study-generate-v2` in the fellowship language, as blog generation does |
| R2 | Auto reply to question posts not from mentor, short, cheap model, related study guides as context | **Discipler auto-reply** as a comment; `claude-haiku-4-5`; context = lesson guide when in a lesson discussion, else FTS top-1 study guide |
| R3 | Only official Disciplefy groups, more than one, controllable via admin | Admin flags `is_official`, `discipler_allowed`, `daily_post_allowed`; mentors then set preferences (reply mode, scope, delay, daily post on/off) |
| R4 | Admin can add group with this feature | Admin-web **Fellowships** page (list, create, edit flags) + Flutter create screen toggles for admins |
| R5 | Member joins are not posts; notify per group. Community needs redesign | Drop system posts; join → push to mentors (existing) + in-app group activity; feed/detail redesign (below) |
| R6 | Questions inside study-guide discussion forum should be answered | Same auto-reply path; posts with `topic_id` use that lesson's guide as context |
| R7 | Answer in the question's language: English / Hindi / Malayalam / Hinglish / Manglish, theologically sound | Fellowship language is the default; script or Hinglish/Manglish in the question overrides it; `THEOLOGICAL_FOUNDATION` injected |
| R8 | Delete all "joined" posts from all groups | Migration hard-deletes `post_type = 'system'` rows; creation code removed |
| R9 | Share post from fellowship | Share action on post card → OS share sheet with text + deep link |
| R10 | Discover defaults to All, not user language | Remove locale default in `community_tab_screen.dart:830-843` |
| R11 | Auto-replier named **Discipler** | Seeded system user; `user_profiles.is_system = true`, display name "Discipler" |
| R12 | Discipler posts/comments deletable by mentor | Already true via `is_fellowship_mentor`; add admin override; hide report/block for Discipler |
| R13 | Multiple mentors; any member can connect with mentors | `fellowship_members.role = 'mentor'` for N users; **Ask a mentor** flow; mentors strip on fellowship home |
| R14 | Version 1.0.5 | pubspec + system_config |
| R15 | Admin toggles Discipler at group creation like unlimited members | Create screen: Official, Discipler allowed, Daily post allowed toggles gated on `isAdmin` |
| R16 | Mentors set preferences on what Discipler can do | New fellowship settings screen: reply mode off/auto/review, scope, wait-for-mentor delay, reactions on/off, daily post on/off |
| R17 | Members can tag Discipler to ask a question | `@Discipler` mention in posts and comments; mention always triggers a reply, bypassing the question heuristic and scope |
| R18 | Discipler replies only when needed, otherwise reacts | Typed posts get rule-based reactions (no model); question-like posts get one model call that returns `reply` or `react` |
| R19 | Discipler may attach a study guide, only when asked | Model returns `guide_request` only on explicit request; backend links an existing guide by id or a generate-on-open URL, never generates itself |
| R20 | Mentors get notifications for all Discipler activity, to review and act | Every reply, reaction, draft, and daily post pushes `fellowship_discipler_activity` to all mentors with a deep link; mentor-only **Discipler activity** screen lists everything with Delete / Approve / Discard |
| R21 | No new Edge Functions (100-function limit, 94 used) | All new capabilities are routes inside existing functions |

## 1. Discipler — the system user

**Identity.** One seeded `auth.users` row (fixed id `00000000-0000-4000-8000-00000000d15c`, email `discipler@disciplefy.in`, no password, `banned_until = '2999-12-31'`, `raw_user_meta_data.full_name = 'Discipler'` so the existing display-name resolution in `fellowship-posts` picks it up) and a matching `user_profiles` row with `is_system = true` (new column). Avatar is a bundled asset the client shows whenever `author_is_system` is true. ID stored in `system_config.discipler_user_id`. Backend reads it through `SystemConfigService`.

**Membership.** Discipler is not a `fellowship_members` row. It writes through the service-role client, so membership checks never apply to it, and it never affects `member_count` or `max_members`. Clients show it under "Helpers" whenever `discipler_allowed` is true. (Decided during planning, 2026-09-06.)

**Client rendering.** `FellowshipPostEntity` / `FellowshipCommentEntity` gain `authorIsSystem`. Card shows an "AI" chip next to the name, indigo tinted background, footer line "Discipler is an AI helper. Mentors review its answers." Overflow menu: mentors and admins see Delete; nobody sees Report or Block on Discipler content.

**Moderation.** `fellowship-posts` and `fellowship-comments` DELETE already allow `is_fellowship_mentor`. Add: `user_profiles.is_admin` may delete any post/comment. Report and block endpoints reject targets where author `is_system`.

## 2. Auto-reply pipeline

Two halves. The Edge Function decides eligibility and enqueues; rs-backend runs a minute cron that honours the mentor's delay and calls back into an Edge Function for the model call. LLM code stays in the Deno backend (prompts, validators, cost tracking live there); scheduling stays in Rust (every other cron lives there).

```
POST /fellowship-posts, POST /fellowship-comments (Edge)
  └─ insert row → respond 201
  ├─ trigger = mention   (@Discipler in content)        → enqueue, run_after = now()
  ├─ trigger = question  (post_type question or `?`)    → enqueue, run_after = now() + delay
  └─ trigger = react     (prayer, praise, study_note, shared_guide, general) → rule-based reaction, no queue
        queue row: { post_id, comment_id?, fellowship_id, trigger, run_after, status = 'pending' }

rs-backend cron discipler_reply_worker  (0 * * * * *, CronGuard)
  └─ SELECT due pending rows LIMIT 20
        ├─ mentor already commented on the post?  → status 'skipped_mentor_answered'
        └─ POST {SUPABASE_URL}/functions/v1/fellowship-posts/discipler-reply  (X-Internal-Api-Key)
              { queue_id }  → status 'done' | 'failed' (3 attempts, then 'failed')

fellowship-posts/discipler-reply (route inside the existing function, internal key only)
  ├─ re-check gates (settings may have changed)
  ├─ security-validator: injection?           yes → skipped_injection
  ├─ budget: user 10/day, group 100/day, global cost cap → skipped_budget
  ├─ context = lessonGuide(topic_id) ?? ftsTopGuide(content) ?? none
  ├─ LLM (claude-haiku-4-5, max_tokens 350, temp 0.3)
  │     → { action: reply | react, reaction?, language, reply?, guide_request? }
  ├─ action = react   → insert fellowship_reactions as Discipler, bump reaction_counts, done
  ├─ action = reply   → resolve guide_request (see below)
  │                   → insert comment as Discipler (in the post thread, or under the mentioning comment)
  │                     is_pending_review = (reply_mode == 'review')
  ├─ insert discipler_replies log (trigger, action, tokens, cost, language)
  └─ push: auto → fellowship_discipler_reply to asker
           always → fellowship_discipler_activity to every mentor (reply, react, draft)
```

**Gates (evaluated at enqueue and again at reply).**
- Fellowship `discipler_allowed` (admin) AND `discipler_reply_mode != 'off'` (mentor).
- Author is not system. Mentors are answered only when they mention Discipler.
- `to_mentors` is false, unless Discipler is mentioned.
- Mention trigger: content contains `@Discipler` (case-insensitive; the composer inserts it from a mention chip). Bypasses the question heuristic and the scope setting.
- Question trigger: `post_type = 'question'`, or content ≥ 15 chars containing `?` / `？`. Prayer, praise, shared-guide, daily posts never qualify. Subject to scope: `'all'`, or `'lessons_only'` and the post has a `topic_id`.
- React trigger (no model): `discipler_react_enabled` (mentor) and post type prayer → `amen`, praise → `hands`, study_note or shared_guide → `heart`, general without a question mark → `heart`. Written inline from the post endpoint through the existing reaction path, as Discipler. Never on daily posts or Discipler's own content.

**Mentions in comments.** A comment containing `@Discipler` enqueues with `comment_id`. The reply context is the post plus the last 5 comments of that thread, truncated, and the reply is inserted as a comment on the same post, quoting the asker's name. Mentioning Discipler in a comment on a `to_mentors` post is allowed; the human path stays open because mentors were already pushed.

**Reply or react (model decision).** For question triggers the model may answer `react` instead of `reply` when the question is rhetorical, is a testimony phrased as a question, or a mentor has already answered it in the thread (the last 5 comments are in the prompt). Mention triggers always reply.

**Context.**
- Lesson discussion (`topic_id` set): load the study guide for that topic; take `summary` + `interpretation` truncated to ~1,200 tokens.
- General feed: new GIN index `study_guides_fts` on `to_tsvector('simple', input_value || ' ' || coalesce(summary,''))`; `plainto_tsquery` on the question, top-1 guide in the fellowship language, same truncation. No pgvector.
- Nothing found: answer from Scripture alone.

**Guide attachment (only on request).** The model sets `guide_request: { input_type: 'topic' | 'scripture', input_value }` only when the user explicitly asks for a study, guide, or lesson ("share a guide on grace", "@Discipler guide for John 15"). The reply function then:
1. Looks up `study_guides` by the same normalized input + language hash `study-generate-v2` uses for its cache. Found → attach `study_guide_id`, `guide_title`.
2. Not found → attach `guide_input_type`, `guide_input_value`, `guide_language` only. The client renders "Open study guide" which routes to `/study-guide-v2?input=…&type=…&language=…&source=discipler`, the existing generate-or-load page, so generation runs under the tapping user's own quota and never from the bot.
3. Share URL form: `https://disciplefy.in/study?input=…&type=…&lang=…`, handled by the deep-link service the same way.
Discipler never calls the study generator itself.

**Prompt.** System prompt = `THEOLOGICAL_FOUNDATION` (from `prompt-builder.ts`) + Discipler rules:
- Answer in ≤ 120 words, warm, pastoral, one or two Scripture references in Arabic digits.
- Reply language: the fellowship language is the default. If the question is written in a different script or in Hinglish/Manglish, mirror the question: Devanagari → Hindi; Malayalam script → Malayalam; Latin-script Hindi → Hinglish; Latin-script Malayalam → Manglish; otherwise fellowship language.
- Close with "A mentor may add more." (localized).
- If the question is not about faith, Scripture, or Christian life, reply with one line pointing to a mentor.
- Never claim to be a human; never give medical, legal, or financial direction.

Output schema: `{ "action": "reply" | "react", "reaction": "amen" | "heart" | "fire" | "hands" | null, "language": "en|hi|ml|hinglish|manglish", "reply": string | null, "guide_request": { "input_type": "topic" | "scripture", "input_value": string } | null }`, validated before any write. `i_prayed` is never used by Discipler.

**Mentor oversight (R20).** Every Discipler action, including rule-based reactions and daily posts, writes a `discipler_activity` row (fellowship_id, kind: reply | react | draft | daily_post, post_id, comment_id, reaction, language, summary, pushed_at) and pushes `fellowship_discipler_activity` to every mentor of that fellowship. Push body: "Discipler replied to Rahul in Disciplefy Fellowship" / "Discipler reacted 🙏 to Meera's prayer" / "Discipler posted today's study". Tapping opens the item with Delete, and Approve / Discard for drafts. Reactions and daily posts are batched into one push per fellowship per hour to avoid noise (rows with `pushed_at IS NULL` are flushed by the rs-backend `discipler_reply_worker` on its minute-0 tick through `fellowship-posts/notify` with `{ kind: 'activity_digest', fellowship_id }`); replies and drafts push immediately. Mentors can mute this per fellowship from the settings screen (`discipler_activity_push` on `fellowship_members` for the mentor row), but the in-app list always fills.

**Discipler activity screen (mentors only).** Reached from the fellowship home badge. Tabs: Needs review (drafts), Replies, Reactions, Daily posts. Each row shows the member's post, Discipler's action, language, and time, with Delete (any) and Approve / Discard (drafts). Admin web shows the same list across fellowships.

**Review mode.** A pending comment is returned only to mentors (`fellowship-comments` GET filters `is_pending_review` for non-mentors) with Approve and Discard actions. Approve clears the flag and pushes the asker. Discard soft-deletes. Pending comments older than 7 days are discarded by the worker.

**Cost.** ~1,500 input + 250 output tokens on `claude-haiku-4-5` ≈ $0.0028 per reply. 200 replies/day ≈ $0.56/day, under the $15 daily cap. Logged through `CostTrackingService` (add `claude-haiku-4-5` to `LLM_PRICING`). Kill switch: `system_config.discipler_global_enabled`.

**Fallback.** If Anthropic is unavailable, `LLMService` falls back to `gpt-4o-mini-2024-07-18` (existing behaviour). Any LLM error → no comment, queue row `failed` with reason.

## 3. Daily post (rs-backend cron, generated from learning paths)

Runs in `rs-backend` as cron job `fellowship_daily_post`, built on the blog generator's mechanism: pick the next learning-path topic, call `study-generate-v2` through `services::study_api::generate_study_guide`, format the result. Language is always the **fellowship's `language`**.

**Schedule.** `0 0 1 * * *` (01:00 UTC = 06:30 IST). Row in `cron_config` via migration; `CronGuard` static `FELLOWSHIP_DAILY_POST_RUNNING`; admin trigger, status, enable/disable, and schedule endpoints extended. The `cron_update_schedule` catch-all arm that reroutes unknown names to blog generation is replaced with an explicit match.

**Files.** `src/cron/schedules.rs`, new `src/cron/fellowship_daily_post.rs`, `src/cron/mod.rs`, new `src/models/fellowship_daily.rs`, `src/services/study_api.rs` (capture `studyGuideId` from the `complete` event), `src/services/content_formatter.rs` (new `format_daily_post`), `src/routes/admin.rs`, one migration.

**Algorithm, per fellowship with `daily_post_allowed AND daily_post_on AND is_active`:**

1. Skip if a `discipler_daily_posts` row exists for `(fellowship_id, today)`.
2. Pick the next topic: `learning_path_topics` → `recommended_topics` → `learning_paths`, `lp.is_active AND rt.is_active`, ordered `lp.display_order, lpt.position`, excluding topics already posted in this fellowship. Same query shape as `find_next_ungenerated_topic`, minus the blog join. Localized title and description from `recommended_topics_translations` / `learning_path_translations` with English fallback, as the blog does. When every topic is used, the cursor wraps.
3. Generate: `generate_study_guide(input_type = 'topic', input_value = title, language = fellowship.language, mode = COALESCE(lp.recommended_mode,'standard') with recommended/ask coerced to standard, topic_description, path_title, path_description, disciple_level)`, the blog's exact parameters. `study-generate-v2` caches by input and language, so the second fellowship to reach the same topic in the same language gets `fromCache = true` at no cost.
4. Format (`format_daily_post`): localized topic title, first two sentences of `summary`, one `relatedVerses` reference, first `reflectionQuestions` item as the discussion prompt, "Open the full study".
5. Insert `fellowship_posts` with `author_user_id = system_config.discipler_user_id`, `post_type = 'daily'`, `topic_id`, `topic_title`, `guide_title`, `study_guide_id` (from the `complete` event), `guide_language`. The existing shared-guide card link opens the full guide in-app. Insert `discipler_daily_posts (fellowship_id, post_date, topic_id, study_guide_id, post_id)`.
6. Notify: POST `{SUPABASE_URL}/functions/v1/fellowship-posts/notify` with the service-role bearer (same pattern as `subscription_reconciler`), body `{ post_id }`. The Edge Function sends `fellowship_daily_post` with the existing block filter and spacing. Failure is logged; the post stays.

**Failure handling.** Generation error → log, no cursor row, retry the same topic tomorrow. No topic → skip the fellowship. Errors in one fellowship never stop the loop. Fellowships run sequentially so only one generation is in flight; the blog job runs an hour earlier.

**Cost.** A fresh standard-mode guide on `claude-sonnet-4-5` is roughly $0.05–0.10 (`estimateStudyGenerationCost`, 1.3× for hi/ml). Bounded by topics × languages once, cached afterwards. Three official groups (en/hi/ml) ≈ $0.25/day at most.

Daily post is pinned at the top of the feed for its date.

## 4. Fellowship flags: admin allows, mentor decides

Two layers. Admin flags say what a fellowship *may* use. Mentor preferences say what Discipler *does*. Effective behaviour is the AND of both.

```sql
ALTER TABLE fellowships
  -- admin-only
  ADD COLUMN is_official          BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN discipler_allowed    BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN daily_post_allowed   BOOLEAN NOT NULL DEFAULT false,
  -- mentor-editable
  ADD COLUMN discipler_reply_mode  TEXT NOT NULL DEFAULT 'auto'
      CHECK (discipler_reply_mode IN ('off','auto','review')),
  ADD COLUMN discipler_reply_scope TEXT NOT NULL DEFAULT 'all'
      CHECK (discipler_reply_scope IN ('all','lessons_only')),
  ADD COLUMN discipler_reply_delay_min INTEGER NOT NULL DEFAULT 0
      CHECK (discipler_reply_delay_min IN (0, 30, 120, 720)),
  ADD COLUMN discipler_react_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN daily_post_on        BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX fellowships_daily_post_idx ON fellowships (daily_post_allowed) WHERE daily_post_allowed;
```

**Admin rules** in `fellowship/index.ts` create and update: the three admin flags require `user_profiles.is_admin`, same check as `max_members = null`. `discipler_allowed` and `daily_post_allowed` require `is_official`.

**Mentor rules**: any mentor of the fellowship may update the five preference columns through the existing PATCH. Non-mentors are rejected.

**Flutter create screen** (`create_fellowship_screen.dart`): the admin section gains Official, Discipler allowed, Daily post allowed. The last two stay disabled until Official is on.

**Fellowship settings screen (new, mentors)**: `updateFellowship` exists in the repository but has no UI. Add `fellowship_settings_screen.dart` reachable from the fellowship home overflow: name, description, posting permission, and a **Discipler** section shown only when the admin has allowed it:
- Answer questions: Off / Answer automatically / Draft for my review
- Which questions: All questions / Lesson discussions only
- Wait for a mentor first: Immediately / 30 min / 2 h / 12 h
- React to posts: on/off
- Post a daily study: on/off
- Notify me about Discipler activity: on/off (per mentor, default on)

Mentions are not a preference: if Discipler is allowed and not off, members can always reach it with `@Discipler`.

**Admin web** — new page `app/(dashboard)/fellowships/page.tsx` and route `app/api/admin/fellowships/route.ts`:
- Table: name, language, members, mentors, official, Discipler allowed, daily post allowed, current mentor settings, replies today, cost today.
- Create dialog: name, description, language, public, unlimited, official, Discipler allowed, daily post allowed, initial mentor (user search).
- Row actions: edit admin flags, add/remove mentor, deactivate.
- Discipler panel: replies and cost per day, queue depth, pending reviews, recent failures (from `discipler_reply_queue` and `discipler_replies`).

## 5. Mentors

**Multiple mentors.** `fellowship_members.role` already supports `mentor`. Add `fellowship-members` routes `POST /promote` and `POST /demote` (mentor or admin only; cannot demote `mentor_user_id`, the owner). `fellowships.mentor_user_id` stays as owner for `transferMentor` and billing. `is_fellowship_mentor()` already checks the role, so posting, deletion, settings, and review permissions extend automatically. `FellowshipEntity.mentorName` becomes `mentors: List<FellowshipMemberEntity>`.

**Ask a mentor.** New column `fellowship_posts.to_mentors BOOLEAN DEFAULT false`. Fellowship home shows a **Mentors** strip (avatars, names, "Ask a mentor" button). The button opens the composer with `post_type = 'question'`, `to_mentors = true`; card shows a "To mentors" chip. Backend sends `fellowship_question` push to every mentor (currently only `mentor_user_id`). Discipler skips `to_mentors` posts.

**Review queue.** When reply mode is `review`, mentors see a "Discipler drafts" badge on the fellowship home and pending comments inline with Approve / Discard.

## 6. Community redesign (screens)

Existing wireframes: `docs/design/community-wireframes.pen` (Pencil). Update in Pencil, then mirror to Figma page "2. UI Design / v1.0.5 Fellowship".

1. **Community tab — My Fellowships.** Cards show name, "Official" badge, mentors avatar stack, unread count, last activity line ("Discipler posted today's verse"). Empty state pushes to Discover.
2. **Discover.** Default filter All; language chips en/hi/ml; "Official" badge; member count shows "Unlimited" when `max_members` is null (fixes the false "Full" state); search unchanged.
3. **Fellowship home header.** Cover gradient, name, description, mentors strip with Ask a mentor, member count, Share fellowship (invite link). Tabs: Feed, Lessons, Members, Meetings.
4. **Feed.** Pinned daily post card (verse block in `brandHighlight`, reflection, question, reply count). Discipler comment styling with AI chip. No system posts. Post card footer: react, comment, **share**. Composer: type chips (General, Prayer, Praise, Question, Ask a mentor).
5. **Lesson discussion** (`fellowship_guide_detail_screen.dart`). Same feed component; Discipler answers appear as comments under the question.
5a. **Composer mentions.** Typing `@` in the post or comment composer opens a mention sheet: Discipler first (when allowed), then mentors. Chips insert `@Discipler` / `@Name`. Mention text renders as a link chip in cards. Discipler replies that carry a guide show an "Open study guide" chip under the text.
6. **Members.** Mentors section first with Promote/Demote for mentors; Discipler listed under "Helpers" with AI chip, not counted.
7. **Notifications.** Group activity: joins (mentors: push; members: in-app activity row, no push in official groups), Discipler replied to your question, new daily post. Mentors additionally: Discipler activity pushes (immediate for replies and drafts, hourly batch for reactions and daily posts) opening the **Discipler activity** screen.
8. **Discipler activity (mentors).** Tabs Needs review / Replies / Reactions / Daily posts; rows with Delete, Approve, Discard.

## 7. Share post

Post card overflow and footer gain **Share**. Payload via `share_plus`:

```
"<first 200 chars of content>"
— <author> in <fellowship name> on Disciplefy
<app public web origin, e.g. https://app.disciplefy.in>/fellowship/<fellowship_id>/post/<post_id>
```

Deep link handler (`deep_link_service.dart`): member → open post detail; non-member and public → Discover detail with Join; else → app home. Daily posts share the verse block as text. Discipler comments are not individually shareable in v1.

## 8. Cleanups shipped with this release

- `fellowship/index.ts:700-706`: remove system post insert. Migration: `DELETE FROM fellowship_posts WHERE post_type = 'system'` and drop `'system'` from the CHECK.
- `fellowship_post_card.dart`: remove reliance on `'system'`; add `'daily'` label config.
- `public_fellowship_model.dart:53` and `PublicFellowshipEntity.maxMembers` → nullable; `community_tab_screen.dart:1460` treats null as unlimited.
- `notification_message_handler_web.dart` gains the fellowship types the mobile handler already routes.
- `fellowship-invites/index.ts:265` token-join path: same push as public join (no post).

## 9. Data model summary

| Table | Change |
|---|---|
| `user_profiles` | `is_system BOOLEAN DEFAULT false` |
| `fellowships` | admin: `is_official`, `discipler_allowed`, `daily_post_allowed`; mentor: `discipler_reply_mode`, `discipler_reply_scope`, `discipler_reply_delay_min`, `daily_post_on` |
| `fellowship_posts` | `to_mentors BOOLEAN DEFAULT false`; `mentions_discipler BOOLEAN DEFAULT false`; `post_type` adds `daily`, removes `system` |
| `fellowship_comments` | `is_pending_review BOOLEAN DEFAULT false`; `mentions_discipler BOOLEAN`; `study_guide_id UUID`, `guide_title`, `guide_input_type`, `guide_input_value`, `guide_language` (guide attachment) |
| `discipler_reply_queue` | id, post_id, comment_id (nullable), fellowship_id, trigger (mention, question), run_after, status (pending, done, failed, skipped_*), attempts, last_error, created_at; index (status, run_after) |
| `discipler_replies` | id, queue_id, post_id, comment_id, fellowship_id, asked_by, trigger, action (reply, react), reaction, guide_attached, language_detected, model, input_tokens, output_tokens, cost_usd, created_at |
| `discipler_activity` | id, fellowship_id, kind (reply, react, draft, daily_post), post_id, comment_id, reaction, language, summary, pushed_at, reviewed_by, reviewed_at, created_at; index (fellowship_id, created_at desc); partial index where pushed_at is null |
| `fellowship_members` | `discipler_activity_push BOOLEAN DEFAULT true` (mentor rows) |
| `discipler_daily_posts` | fellowship_id, post_date, topic_id, study_guide_id, post_id; unique (fellowship_id, post_date); index (fellowship_id, topic_id) |
| `cron_config` | rows `fellowship_daily_post` (`0 0 1 * * *`) and `discipler_reply_worker` (`0 * * * * *`) |
| `study_guides` | GIN FTS index on `input_value + summary` |
| `system_config` | `discipler_user_id`, `discipler_global_enabled`, `latest_app_version = 1.0.5` |
| `notification_logs` CHECK | add `fellowship_daily_post`, `fellowship_discipler_reply`, `fellowship_discipler_activity` |

RLS: new tables are service-role only, consistent with the other fellowship tables.

## 10. API summary

**Constraint: no new Edge Functions.** The project is near the 100-function limit, so every new capability is a route inside an existing function (`fellowship`, `fellowship-posts`, `fellowship-comments`, `fellowship-members`, `fellowship-blocks`). rs-backend jobs and admin-web API routes are not Edge Functions and do not count.

| Function | Change |
|---|---|
| `fellowship` | create/update accept admin flags (admin) and Discipler preferences (mentor); discover returns `is_official`, `max_members` null-safe; list returns `mentors[]` |
| `fellowship-posts` | POST accepts `to_mentors`; detects `@Discipler`; enqueues or reacts; DELETE allows admin; report rejects system author; `POST /notify` (service-role only) fans out pushes for a given post; `POST /discipler-reply` (internal key) runs gates, context, LLM, reply-or-react, guide lookup, insert, log, push for one queue row |
| `fellowship-comments` | POST detects `@Discipler` and enqueues; DELETE allows admin; response includes `author_is_system` and guide fields; hides pending-review comments from non-mentors; `POST /approve`, `POST /discard` (mentor) |
| `fellowship` | `GET /:id/discipler-activity?kind=` (mentor) lists activity rows with the post and comment joined |
| `fellowship-members` | `POST /promote`, `POST /demote` |
| `fellowship-blocks` | reject `is_system` targets |
| rs-backend `fellowship_daily_post` cron (new) | next learning-path topic per fellowship → `study-generate-v2` → post as Discipler → `fellowship-posts/notify` |
| rs-backend `discipler_reply_worker` cron (new) | drains `discipler_reply_queue` every minute honouring delay and mentor-answered skip |
| `admin-fellowships` (new, admin-web route) | list/create/update flags/mentors; Discipler stats |

## 11. Testing

- Backend: unit tests for `isQuestion`, scope gate, language routing in the output schema, budget guard, FTS context selection; integration: a question in an enabled fellowship enqueues one row and, after the worker, yields one Discipler comment and one log row; mentor post yields none; `to_mentors` yields none; review mode hides the comment from members until approved; delay + mentor comment → `skipped_mentor_answered`; every Discipler action writes one `discipler_activity` row and every mentor receives `fellowship_discipler_activity` (reactions batched); `@Discipler` in a comment yields a reply in that thread; a prayer post gets an `amen` reaction and no queue row; a model `react` answer writes a reaction and no comment; `guide_request` with a cached guide attaches its id, without one attaches only input fields; a reply without an explicit guide request never carries guide fields.
- Daily post (Rust): idempotency (second run same day inserts nothing); topic order matches `display_order, position`; wrap-around after exhaustion; language passed equals fellowship language; `studyGuideId` captured from the `complete` event; generation failure leaves no cursor row.
- Theology: run 20 sample questions (en/hi/ml/Hinglish/Manglish) through the `paul-the-apostle` review agent before release.
- Flutter: widget tests for Discipler chip, daily post pin, share action, Discover default All, unlimited badge.
- Drift tests (`push-type-routing-drift.test.ts`, `notification-type-constraint.test.ts`) updated for the two new notification types.

## 12. Rollout

1. Migrations + seed Discipler user (local, then production via the normal release process).
2. Deploy Edge Functions; enable `discipler_global_enabled = false` initially.
3. Admin web: create the official fellowships, turn on Discipler for one group, watch `discipler_replies` for a day.
4. Enable `discipler_reply_worker` and `fellowship_daily_post` in `cron_config`; mentors confirm preferences in the settings screen.
5. Release 1.0.5 clients; bump `latest_app_version`.

## Assumptions (accepted 2026-09-06)

- A1. Join notifications: mentors get push; regular members get an in-app activity row only. Official groups send no member push on joins.
- A2. Auto-reply targets posts only, not questions asked inside comment threads.
- A3. Related-guide context uses Postgres full-text search, not embeddings.
- A4. Discipler replies go to the post author as a push, not to the whole group.
- A5. Share links use the app's public web origin (`app.disciplefy.in`, i.e. `ShareLinks.publicWebUrl`) and require the app link config already used for `/fellowship/join`.
- A6. Design tooling: wireframes updated in Pencil (`community-wireframes.pen`), then rebuilt in Figma.
- A7. Daily post generation uses the learning path's recommended mode (standard when unset), like blog generation. Quick mode would cut cost further if wanted.
- A8. Mentor preference set is: reply mode, scope, delay, reactions, daily post on/off. Tone or persona controls are out of scope for 1.0.5.
- A9. Rule-based reaction map: prayer → amen, praise → hands, study note or shared guide → heart, general → heart. Discipler never uses `i_prayed`.
- A10. Guide links open the generate-or-load page under the tapping user's quota; Discipler never generates a guide itself.
