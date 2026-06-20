# App-Wide RAG Strategy

**Status:** Proposed
**Owner:** TBD
**Last updated:** 2026-06-17
**Companion to:** `docs/plans/Voice_Discipler_RAG_Enhancement_Plan.md`
**Related:** `docs/internal/LLM_Development_Guide.md`, `docs/architecture/Data Model.md`

---

## 1. Purpose

This document looks beyond Voice Discipler and asks: **where else in Disciplefy is Retrieval-Augmented Generation (RAG) worth it?** It inventories every LLM/content surface, identifies a **shared retrieval substrate** that amortizes across multiple features, and ranks each surface as a RAG candidate with explicit decision gates.

Voice Discipler has its own detailed phase plan (companion doc). This doc is the umbrella: it shows that the substrate built for Voice should be reused, not rebuilt, for the other strong candidates.

---

## 2. Key finding

**Disciplefy is generation-heavy and retrieval-light.** Multiple features call the LLM but inject almost no grounding, and several let the model **invent scripture from memory** — a direct credibility risk for a Bible app.

Two facts reframe the whole question:

1. **No retrieval infra exists yet.** No `pgvector`, no embeddings; search is hash-based cache lookup only. Building the substrate is a one-time cost.
2. **The substrate is a shared asset.** The two expensive pieces — a **curated theological KB** and a **verse-text retrieval/validation layer** — are reusable across at least 3–4 surfaces. This changes the ROI: a KB that's marginal for Voice *alone* clears the bar once Voice + Study Followup + Deep/Sermon generation all use it.

> **Reframe:** The question isn't "where else do we add RAG?" It's "build the retrieval substrate once, then light up each surface."

---

## 3. LLM / content surface inventory

| Feature | LLM-driven? | Current grounding | RAG candidate | Notes |
|---|---|---|---|---|
| **Study Followup** (`study-followup`) | ✅ | Study guide + last 10 msgs; no external retrieval | **STRONG** | Text twin of Voice Discipler |
| **Study Generation — Deep/Sermon** (`study-generate-v2`) | ✅ | User input + mode only; invents related verses | **STRONG** | Long-form, scholarly; latency-tolerant |
| **Study Generation — Standard/Lectio/Quick** | ✅ | Same | Weak | Don't need scholarly depth |
| **Admin Study Generator** (`admin-study-generator`) | ✅ | Same as v2 | **STRONG** | Library seeding; quality matters most |
| **Daily Verse** (`daily-verse`) | ✅ | Recent-30-day DB exclusion; LLM *selects* verse | **Not RAG** | Fix selection with curated pool, not embeddings |
| **Voice Discipler** (`voice-conversation`) | ✅ | Study guide + profile + last 10 msgs | **STRONG** | See companion doc |
| Memory Verses (`*-memory-*`) | ❌ | SM-2 algorithm | Weak/future | Optional struggle hints only |
| Fellowship posts/comments | ❌ | User content | Weak/future | Thread summarization someday |
| Learning Paths / Continue Learning | ❌ | Curated DB | N/A | Recommender, not RAG |
| Recommended Topics / Suggested Verses | ❌ | Curated DB | N/A | Pure serving |
| Fetch Verse | ❌ | API.Bible direct | N/A | Already retrieval |

**Corpora that exist to retrieve against:** `study_guides`, `recommended_topics` (+ translations), `suggested_verses` (+ translations), `learning_paths`, `conversation_messages`, `memory_verses`, fellowship content. **Missing:** any commentary/confession corpus, and full Bible verse text at rest.

**Vector status:** ❌ no `pgvector`, ❌ no embeddings anywhere. Text search = GIN indexes (some commented out) + hash cache.

---

## 4. The shared retrieval substrate

Build these **once**; every strong candidate consumes them. Mirrors the architecture in the Voice plan §4.

### 4.1 Verse-text retrieval & validation
- Deterministic lookup of real verse text in the user's translation (ESV `en` / IRV `hi` / POC `ml`) via the existing `fetch-verse` path + `bible-book-normalizer.ts`.
- Two jobs: (a) **inject** verse text where the model should quote; (b) **validate** LLM-emitted references (`passage`, `related_verses`) against the real Bible and drop/flag invented ones.
- **Not really RAG** — no embeddings. Highest trust-per-effort. Reuses code that already exists.

### 4.2 Curated theological KB (the real RAG part)
- `pgvector` store of **theologically reviewed** chunks: confessions/catechisms (public domain), filtered public-domain commentaries, your own approved material.
- Embeddings: see §4.5 for the encoder decision. ⚠️ Whatever the provider, embeddings depend on an external API → cache corpus embeddings, embed only the live query, **fail open** to no-retrieval on embedding error.
- Every source **human/doctrinally reviewed before ingestion** (use the `paul-the-apostle` agent + reviewer). This is the non-skippable cost.

### 4.3 Per-user memory (narrower reuse)
- Semantic recall of a user's own `study_guides` + past `conversation_messages` / voice messages, filtered by `user_id` (RLS-enforced).
- Reused only by Voice + Study Followup. Retention-gated.

### 4.4 Cross-cutting rules (per `LLM_Development_Guide.md`)
- Sanitize queries before embedding (`security-validator.ts`).
- Never log raw input, chunks, or embeddings — metadata only.
- Retrieved grounding never overrides the 5-Solas system-prompt framework; the KB is curated to align, the prompt is the backstop.
- Respect cost ceilings ($15/day, $100/month) via existing cost-tracking.

### 4.5 Encoder & vector store decision (docs-backed)

**Vector store — settled: Supabase `pgvector` + HNSW index, cosine distance.**
- Supabase explicitly recommends HNSW as the default (built on empty tables, recall stays stable as data grows; IVFFlat degrades on distribution shift and needs rebuilds). [[Supabase HNSW](https://supabase.com/docs/guides/ai/vector-indexes/hnsw-indexes)]
- Use `vector_cosine_ops` (`<=>`) — candidate encoders output unit-normalized vectors.
- **Hard limit:** the `vector` index caps at 2,000 dims (`halfvec` → 4,000). Keep embeddings ≤1,536. (Rules out OpenAI `3-large` at its 3,072 default unless down-projected.)
- No new infra — it's already the database. Optionally use Supabase "automatic embeddings" (triggers + pgmq + pg_cron + pg_net) to keep vectors fresh on content change.

**Encoder — recommended: Cohere `embed-v4.0`; self-host `bge-m3` as the no-API-cost alternative.**

The deciding factor is **Malayalam** (low-resource Indic). Only two candidates confirm it in official docs:

| Model | Malayalam | Max tok | Dims | Hosting | Text price |
|---|---|---|---|---|---|
| **Cohere `embed-v4.0`** (recommended) | "100+ langs" (v3.0 lists `ml` explicitly) | 128k | 256/512/1024/1536 | Managed API | **$0.12 / 1M** |
| Cohere `embed-multilingual-v3.0` | ✅ `ml` listed explicitly | 512 | 1024 | Managed API | ~$0.10 / 1M |
| **BAAI `bge-m3`** (self-host alt) | ✅ maintainer-confirmed | 8,192 | 1024 | Self-host (GPU) | $0 / token |
| OpenAI `3-small` | ❌ unconfirmed | 8,192 | 1536 | Managed | $0.02 / 1M |

- **Do not default to OpenAI** despite it being our LLM provider: its docs publish no language list and never name Malayalam/Hindi/Indic. For a Malayalam-core Bible app that's an unverified quality bet. Only use it if a Malayalam eval proves acceptable recall.
- `bge-m3` is the strongest technical fit (8k tokens, hybrid dense+sparse+ColBERT, free) but **cannot run in Supabase Edge Functions** (Deno, no GPU) — it needs a separate GPU inference service. Choose only if willing to run inference.
- Sources: [Cohere supported-languages (`ml`)](https://github.com/cohere-ai/cohere-developer-experience/blob/main/fern/pages/text-embeddings/multilingual-language-models/supported-languages.mdx), [Embed v4.0 specs/price](https://vercel.com/ai-gateway/models/embed-v4.0), [bge-m3 maintainer confirmation](https://huggingface.co/BAAI/bge-m3/discussions/29), [OpenAI embeddings](https://developers.openai.com/api/docs/guides/embeddings).

**Non-negotiables:**
1. **Run a Malayalam retrieval eval before locking in.** Stated coverage ≠ proven quality. Embed ~30 Malayalam query/passage pairs, measure recall@5 across the top 2 candidates, decide on evidence.
2. **Keep the encoder swappable.** Store `model_name` + `dimensions` with every vector (dims differ 1024 vs 1536 → a switch means re-embedding). Hide it behind the `RetrievalService`.

### 4.6 Cost model (Cohere `embed-v4.0`, $0.12 / 1M text tokens)

The encoder bill is **negligible** — a quality decision, not a cost one. Image/output tokens are unused.

**One-time ingestion:**

| Corpus | ~Tokens | Cost |
|---|---|---|
| Curated KB (confessions + commentaries) | ~5M | ~$0.60 |
| All study guides (~10k × ~1.5k tok) | ~15M | ~$1.80 |
| Full Bible × 3 translations (Phase D only) | ~2–3M | ~$0.30 |
| Re-embed everything once | ~25M | ~$3 |

**Ongoing query embedding** (~50–100 tok/query):

| Queries/mo | Tokens | Cost/mo |
|---|---|---|
| 10k | ~1M | $0.12 |
| 100k | ~10M | $1.20 |
| 1M | ~100M | $12 |

**Bottom line:** realistically **< $5/mo** + a few dollars one-time until ~1M queries/mo — well inside the $15/day / $100/month ceilings. The real costs are human KB review and ingestion ops, not embeddings. (Cohere also offers dedicated instances at ~$2,500–3,250/mo — ignore unless very high sustained throughput or data-residency SLAs are needed. The $0.12/1M serverless rate differs if routed via Bedrock/Azure — re-verify there.)

---

## 5. Per-surface phases

Ordered by ROI. Each phase is independently shippable and evidence-gated.

### Phase A — Verse grounding & validation (cross-cutting, ship first)
**Substrate:** §4.1 only. No vector store.
- **A1.** Voice Discipler verse-text injection (= Voice plan Phase 1).
- **A2.** Study-generation **reference validation**: verify LLM-emitted `passage`/`related_verses` against real verse text; drop or correct invented references before saving to `study_guides`.
- **A3.** Study Followup verse-text injection.

**Why first:** Kills the single worst failure mode app-wide — a Bible app citing scripture that doesn't say what the model claims. Low effort, reuses `fetch-verse` + normalizer. **No decision gate — ship it.**

**Metric:** sampled misquote / invented-reference rate → ~0; added latency < 80 ms p95 on live paths.

---

### Phase B — Curated KB grounding (gated, high reuse)
**Substrate:** §4.2.
- **B1.** Stand up `pgvector` + KB ingestion + reviewed corpus.
- **B2.** Wire KB retrieval into **Study Followup** (closest twin to Voice; highest reuse).
- **B3.** Wire KB retrieval into **Study Generation Deep + Sermon** (and **Admin generator**) — inject commentary / historical background / real cross-references; latency-tolerant since cache-backed.
- **B4.** Wire KB retrieval into **Voice Discipler** (= Voice plan Phase 2a).

**Effort:** Medium–High (ingestion, ongoing doctrinal review, eval harness). The KB is permanent operational surface.

**Decision gate (measure before building):**
- Pull ≥ 50 real transcripts/guides across Study Followup + Deep/Sermon output. Count actual doctrinal/accuracy errors and weak/invented content the prompt failed to prevent.
- If the rate is materially non-zero across surfaces → build (cost amortizes over 3–4 surfaces, so the bar is lower than for Voice alone).
- If the prompt already holds everywhere → defer.

**Metric:** doctrinal-error + invented-content rate ↓; sermon-application quality ↑ (human-rated); latency budget held on live paths.

---

### Phase C — Per-user memory (gated, narrow reuse)
**Substrate:** §4.3. Applies to Voice (Voice plan Phase 2b) + Study Followup only.

**Decision gate:** median studies-per-user and conversation length high enough that semantic recall has real content. If users have little history → defer to retention stage.

---

### Phase D — Topical semantic Bible search (lowest ROI, gated)
Embed the Bible per translation; semantic verse search for open-ended questions. Benefits Voice + Study Followup + topical study generation. Most of the value is already reachable via Phase A (LLM names passages → fetch text). **Defer** until transcripts show meaningful volume of poorly-handled topical questions. (= Voice plan Phase 3.)

---

## 6. Explicitly NOT RAG (fix differently or skip)

- **Daily Verse** — the bug is "LLM *selects* a verse and can hallucinate." Fix = retrieve from a **curated, themed verse pool with rotation** (deterministic). No embeddings. Treat as a correctness fix, not a RAG project. Can reuse `suggested_verses` with seasonal/thematic tags.
- **Learning-path / topic recommendations** — embeddings could power "similar topic" suggestions, but that's a **recommender**, premature; out of scope here.
- **Memory-verse hints / fellowship thread summarization** — speculative future LLM features, not retrieval problems.
- **Topics, Suggested Verses, Fetch Verse, Learning Paths, Fellowship serving** — no LLM; pure curated-DB/API. N/A.

---

## 7. Recommendation summary

| Phase | Scope | Worth it? | Gate |
|---|---|---|---|
| **A** Verse grounding/validation | Voice, Study Followup, Study Gen | **Yes — ship now** | None |
| **B** Curated KB | Study Followup, Deep/Sermon, Admin, Voice | **Likely yes** (amortized over 3–4 surfaces) | Measure error rate on ≥50 samples |
| **C** Per-user memory | Voice, Study Followup | Retention-gated | Measure history-per-user |
| **D** Topical Bible search | Voice, Study Followup, Study Gen | Lowest ROI; defer | Evidence of topical-question gaps |
| — Daily Verse fix | Daily Verse | Yes, but **not RAG** | None |

**Bottom line:** Build the substrate once; reuse everywhere. Phase A is unconditional and app-wide. Phase B's economics are *better* than the Voice-only doc implies because the KB serves Study Followup + Deep/Sermon generation too — but it's still gated on measuring the real error rate. Everything else is either narrow (C), low-ROI (D), or not actually a RAG problem (Daily Verse, recommendations).

---

## 8. Open questions

- What is the measured doctrinal-error / invented-reference rate **today** across study generation + followup? (Blocks Phase B.)
- Licensing: which translations can we store full verse text at rest vs. fetch-on-demand?
- Who owns ongoing theological review of the KB corpus?
- Do we embed per-language separately or adopt a multilingual embedding model?
- Should reference *validation* (Phase A2) hard-block saving an invented reference, or flag-and-correct?
