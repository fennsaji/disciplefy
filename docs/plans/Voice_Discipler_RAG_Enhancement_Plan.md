# Voice Discipler — RAG Enhancement Plan

**Status:** Proposed
**Owner:** TBD
**Last updated:** 2026-06-17
**Related:** `docs/specs/AI_Study_Buddy_Voice_Specification.md`, `docs/internal/LLM_Development_Guide.md`

---

## 1. Purpose

Voice Discipler is a voice-based conversational Bible-discipleship feature (STT → LLM → TTS, streamed over SSE, EN/HI/ML, 5-Solas-constrained). This document specifies how Retrieval-Augmented Generation (RAG) can improve answer accuracy, theological grounding, and personalization — **and where it is *not* worth it.**

This is a phased plan. Each phase is independently shippable and gated by evidence. Do **not** treat "add RAG" as one project; the value is highly uneven across phases.

---

## 2. Current state (baseline)

Today the feature does **context injection, not retrieval**. It stuffs fixed context into the system prompt with no semantic search:

| Context source | Where | Notes |
|---|---|---|
| Linked study guide | `voice-conversation-repository.ts` → `getStudyContext()` | Only when `related_study_guide_id` is set |
| User profile (interests, maturity) | `getUserContext()` | Static, coarse |
| Last ~10 messages of *current* conversation | `getConversationHistory()` | No cross-session recall |
| `related_scripture` | conversation row | Reference string, not verse text |

Key gaps:

- **Scripture references are extracted but verse text is never fed back to the model** (`BibleBookNormalizer.extractScriptureReferences()` in `voice-conversation/index.ts`). The model quotes from memory → misquote risk.
- **No retrieval over the user's own past studies/conversations** — data is stored but never semantically recalled.
- **No vetted theological corpus** — orthodoxy relies entirely on the system prompt holding.

### Relevant files

**Backend**
- `backend/supabase/functions/voice-conversation/index.ts` — SSE handler, quota, normalization
- `backend/supabase/functions/_shared/services/voice-streaming-service.ts` — LLM streaming (OpenAI primary `gpt-4.1-mini` / `gpt-4o-mini`; Anthropic fallback `claude-haiku-4-5`)
- `backend/supabase/functions/_shared/repositories/voice-conversation-repository.ts` — context assembly + persistence
- `backend/supabase/functions/_shared/prompts/voice-conversation-prompts.ts` — multi-language system prompts with `{{maturity_level}}`, `{{current_study}}`, `{{recent_topics}}` slots
- `backend/supabase/functions/_shared/utils/bible-book-normalizer.ts` — reference extraction/normalization
- `backend/supabase/migrations/20260119000500_voice_system.sql` — voice schema

**Frontend** (no changes required for any phase — retrieval is server-side)
- `frontend/lib/features/voice_buddy/`

---

## 3. Goals / Non-goals

### Goals
- Eliminate scripture misquotes by grounding in real verse text.
- Strengthen doctrinal safety with retrievable, vetted grounding (defense-in-depth over the prompt).
- Enable cross-session personalized discipleship ("last week you studied grace…").
- Preserve voice latency and the 2–4 sentence / 50–80 word response shape.

### Non-goals
- Replacing the system-prompt theological framework (RAG augments, never overrides the 5-Solas constraints).
- Long, essay-style answers. Retrieved context informs short spoken replies; it is not read aloud verbatim.
- Frontend/UX changes. STT/TTS, BLoC, and pages are unaffected.

---

## 4. Shared architecture

All phases reuse one retrieval substrate. Infra already exists — **Supabase ships `pgvector`**.

### 4.1 Components

1. **Embedding provider.** OpenAI `text-embedding-3-small` (1536-dim) — cheap, fast, already an OpenAI shop.
   - ⚠️ **Provider coupling:** Anthropic has no embeddings API, so the Claude fallback path cannot embed. Retrieval depends on OpenAI being reachable. Mitigation: cache all corpus embeddings; only the live query embeds per turn; on OpenAI embedding failure, **degrade gracefully to no-retrieval** (today's behavior) rather than erroring.
   - Alternative if provider parity matters later: Voyage AI (`voyage-3`).

2. **Vector store.** `pgvector` tables in Supabase with HNSW or IVFFlat indexes. One logical store, multiple source types (verses, KB chunks, study guides, conversation messages).

3. **Retrieval hook.** A single `RetrievalService` invoked in `voice-streaming-service.ts` **before** the LLM call. It embeds the user's transcribed message, runs per-source ANN search, assembles a compact `{{retrieved_context}}` block, and injects it into the existing prompt template.

4. **Ingestion pipelines.** Offline/background jobs (service-role Edge Functions or scripts) that chunk + embed source content and upsert vectors. Re-embed on content change.

### 4.2 Prompt integration

Add one new slot to each language template in `voice-conversation-prompts.ts`:

```
RETRIEVED GROUNDING (use only if relevant; never read verbatim; cite full canonical book names):
{{retrieved_context}}
```

Rules baked into the prompt:
- Retrieved text is **grounding, not script** — synthesize, stay at 50–80 words.
- If retrieved grounding conflicts with the 5-Solas framework, the framework wins (the KB is curated to align, so this is a backstop).
- Never expose raw chunks, sources, or that retrieval happened.

### 4.3 Latency budget

Voice is latency-sensitive (streamed, turn-taking). Target retrieval overhead **< 150 ms p95**.

- Run query-embed + ANN search **in parallel** with existing per-turn work (quota check, normalization setup).
- `top_k` small: **3–5 chunks total** across sources. Answers are 50–80 words; more context just adds latency and dilution.
- Cache corpus embeddings; never re-embed static content per turn.
- **Gate retrieval**: skip for chit-chat/greetings (cheap heuristic or classifier) so only substantive turns pay the cost.
- Fail open: retrieval error/timeout → proceed with no retrieval (never block the response).

### 4.4 Security & LLM rules (per `LLM_Development_Guide.md`)

- Sanitize the query before embedding (reuse `security-validator.ts`).
- Never log raw user input, raw chunks, or embeddings — metadata only.
- Curated KB content must be theologically reviewed before ingestion (see Phase 2).
- Retrieval must not leak another user's data — per-user sources filter by `user_id` in SQL, enforced by RLS.

---

## 5. Phases

> Phases are ordered by ROI. Each has an explicit **decision gate** — do not start a phase until its gate passes.

### Phase 1 — Verse-text grounding (ship first, unconditionally)

**Problem:** A *Bible* app whose voice mentor misquotes the Bible. The model cites references from memory.

**This is barely RAG** — no vector store, no embeddings. It's deterministic lookup. Listed as Phase 1 because it delivers most of the trust win for the least cost and de-risks the prompt-integration plumbing the later phases reuse.

**Approach:**
1. After the user message arrives (and/or after the model drafts a reply), extract candidate references with the existing `BibleBookNormalizer.extractScriptureReferences()`.
2. For passages in play, fetch **actual verse text** in the user's translation (ESV `en`, IRV `hi`, POC `ml`) via the existing verse-fetch path (`fetch-verse` / bible-api service).
3. Optionally add a small static **cross-reference table** (e.g., Treasury of Scripture Knowledge subset) to pull 1–2 related passages.
4. Inject verse text into `{{retrieved_context}}`.

**Effort:** Low (days). Reuses extraction + verse fetch already in the codebase.

**Risks:** Reference extraction recall; verse-fetch latency (cache hot verses). Both bounded.

**Decision gate:** None — ship it. The failure mode it fixes (misquoting scripture) is unacceptable for this product regardless of metrics.

**Success metric:** Misquote rate (sampled transcripts) drops to ~0 for cited passages; added latency < 80 ms p95.

---

### Phase 2 — Curated theological KB + per-user memory (gated)

Two retrieval sources that *are* real RAG. Bundled because they share ingestion + retrieval plumbing, but each is independently gated.

#### 2a. Curated theological knowledge base

**Problem it solves:** Doctrinal drift. The product's moat is "theologically safe." A vetted, retrievable corpus is the most durable guardrail — defense-in-depth beyond the prompt.

**Corpus (must be theologically reviewed before ingestion):**
- Reformed/evangelical confessions & catechisms (e.g., Westminster, Heidelberg) — public domain.
- Trusted public-domain commentaries, filtered for orthodoxy.
- Your own approved study material.

**Pipeline:**
1. Curate + **human theological review** of every source (use the `paul-the-apostle` doctrinal-review agent / human reviewer). This is the expensive, non-skippable step.
2. Chunk (~200–400 tokens, semantic boundaries), embed, upsert to `kb_chunks` vector table with `source`, `tradition`, `tags`.
3. At query time, retrieve top 2–3 KB chunks; inject as grounding.

#### 2b. Per-user past studies & conversations

**Problem it solves:** Real personalized discipleship — the feature's premise. Recall the user's own `study_guides` and past `voice_conversation_messages` semantically, beyond the current conversation's last 10 turns.

**Pipeline:**
1. Backfill-embed existing `study_guides` (summary/context/interpretation) and assistant/user messages per user.
2. On new study-guide creation and conversation message save, embed + upsert (hook into existing save paths).
3. At query time, ANN search filtered by `user_id` (RLS-enforced); retrieve top 1–2.

**Effort:** Medium–High. Ingestion pipelines, re-embedding, eval harness, corpus maintenance. **Not a weekend.**

**Risks:**
- KB orthodoxy review is ongoing labor.
- Per-user value scales with how much history a user has — thin for new/low-engagement users.
- Vector store becomes permanent operational surface (re-embedding, index tuning, cost).

**Decision gate (both must be measured first):**
- **KB (2a):** Pull ≥ 50 real transcripts; count actual doctrinal/accuracy errors the prompt failed to prevent. If the rate is materially non-zero → build. If the prompt already holds → **defer**; you'd be insuring against a problem you don't have.
- **Memory (2b):** Measure median studies-per-user and conversation length. If most users have little history, recall retrieves thin gruel → **defer to retention stage.**

**Success metrics:** Doctrinal-error rate ↓ (2a); user-reported "it remembered / felt personal" + retention lift (2b); latency budget still met.

---

### Phase 3 — Topical semantic Bible search (lowest ROI, gated)

**Problem it solves:** Open-ended spoken questions ("what does the Bible say about anxiety?") where wording ≠ verse wording, so keyword/reference matching fails.

**Approach:**
1. Embed the whole Bible (per translation) into `verse_embeddings`.
2. At query time, detect topical/open questions; semantic-search verses; retrieve top 3–5; inject text (overlaps Phase 1 injection).

**Effort:** Medium (embed full Bible × 3 translations; tune retrieval quality; detect when to trigger).

**Why last:** A large share of the value is already reachable by letting the LLM name passages + Phase 1 fetching their text. The marginal lift over Phases 1–2 is small relative to cost.

**Decision gate:** Only after Phases 1–2 are live and transcripts show a meaningful volume of open-ended topical questions that current handling answers poorly.

**Success metric:** Improved answer relevance on a labeled set of topical questions vs. the Phase 1 baseline.

---

## 6. Cross-cutting concerns

### 6.1 Cost
- Query embeddings: one small embedding per substantive turn — negligible.
- Corpus embeddings: one-time + on-change. Bible ×3 + KB is bounded; per-user grows with usage.
- Track under existing cost-tracking service; respect the $15/day, $100/month ceilings.

### 6.2 Evaluation (build before Phase 2)
- A **golden transcript set** with labeled expected behavior (correct citation, orthodox answer, relevant recall).
- Offline retrieval eval: recall@k, citation accuracy.
- Online: doctrinal-error rate (sampled), misquote rate, latency p50/p95, helpfulness rating (already captured in `voice_conversations.was_helpful`/`rating`).

### 6.3 Failure modes / graceful degradation
- Embedding API down → no-retrieval fallback (today's behavior).
- Retrieval timeout (> budget) → proceed without it.
- Empty/low-similarity results → inject nothing; never force irrelevant context.

### 6.4 Multi-language
- Embed and retrieve per language where possible (EN/HI/ML). KB may be English-primary initially; verses use the per-language translation. Avoid cross-language retrieval that injects English chunks into a Malayalam reply unless translated.

---

## 7. Recommendation summary

| Phase | What | Worth it? | Gate |
|---|---|---|---|
| 1 | Verse-text grounding | **Yes — ship now** | None |
| 2a | Curated theological KB | **Only if** transcripts show real doctrinal errors | Measure error rate on ≥50 transcripts |
| 2b | Per-user studies/convo recall | **Only if** users have enough history | Measure studies-per-user, convo length |
| 3 | Topical semantic Bible search | Lowest ROI; defer | After 1–2 + evidence of topical-question gaps |

**Bottom line:** RAG is worth it in slices, not as a monolith. Phase 1 is unconditional. Phases 2–3 are evidence-gated — without the transcript and engagement data, full RAG risks being a solution waiting for a problem. The current ceiling on Voice Discipler's value may be STT/TTS quality, latency, and the free-tier offering 0 conversations more than retrieval grounding; weigh RAG against those.

---

## 8. Open questions

- Which translations/editions are licensing-clear for storing full verse text at rest (vs. fetch-on-demand)?
- Who owns ongoing theological review of the KB corpus?
- Do we embed per-language separately or use a multilingual embedding model?
- What's the actual measured doctrinal-error rate today? (Blocks the Phase 2a decision.)
