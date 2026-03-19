# Token Economy Analysis

**Date:** 2026-03-19
**Status:** Finalized — pending code implementation
**Related:** `docs/subscription_plans.md`, `backend/supabase/functions/_shared/types/token-types.ts`

---

## Summary

Every study guide generation was running at a loss under the original token pricing.
This document explains the root cause, the analysis methodology, and the revised token economy.

---

## How the Token Economy Works

The app has two types of "tokens":

1. **App tokens** — internal currency users spend. Earned daily via plan allocation or purchased.
2. **LLM tokens** — actual API tokens consumed by Claude Sonnet when generating a study guide.

These are completely separate. App tokens are an abstraction that converts user spending into LLM cost coverage.

**Exchange rate:** `tokensPerRupee` in `token-types.ts` defines how many app tokens = ₹1.
**Model:** `claude-sonnet-4-5-20250929` — $3.00/MTok input, $15.00/MTok output (USD)
**USD/INR rate used:** ₹84

---

## Original Pricing — Why It Failed

Original rate: **4 tokens = ₹1** (₹0.25/token)
Original base costs: EN=10, HI=15, ML=15 tokens

Every mode, every language was running at a loss:

| Mode | Language | Tokens Charged | Revenue | LLM Cost | Loss |
|------|----------|---------------|---------|----------|------|
| Quick | EN | 5 | ₹1.25 | ₹2.18 | **-₹0.93** |
| Standard | EN | 10 | ₹2.50 | ₹4.96 | **-₹2.46** |
| Standard | HI | 15 | ₹3.75 | ₹8.82 | **-₹5.07** |
| Standard | ML | 15 | ₹3.75 | ₹12.01 | **-₹8.26** |
| Deep | ML | 23 | ₹5.75 | ₹18.90 | **-₹13.15** |
| Lectio | ML | 18 | ₹4.50 | ₹14.95 | **-₹10.45** |

**Root causes:**
1. `tokensPerRupee: 4` underpriced by ~2.5×
2. Hindi/Malayalam base costs treated as 1.5× English — actual LLM cost is 1.8–2.4×
3. Premium plan with "unlimited" tokens had no cost ceiling

---

## Actual LLM Cost Data (from production logs, 2026-03-18)

All measurements from `claude-sonnet-4-5-20250929`. Costs converted at ₹84/USD.

### English
| Mode | Avg Input Tokens | Avg Output Tokens | Avg Cost (USD) | Avg Cost (INR) |
|------|-----------------|------------------|---------------|---------------|
| Quick | ~4,350 | ~860 | $0.026 | ₹2.18 |
| Standard | ~5,400 | ~2,800 | $0.059 | ₹4.96 |
| Deep | ~7,850 | ~3,650 | $0.079 | ₹6.64 |
| Lectio | ~4,650 | ~3,250 | $0.063 | ₹5.29 |
| Sermon* | ~20,000 | ~12,000 | ~$0.148 | ~₹12.43 |

### Hindi
| Mode | Avg Input Tokens | Avg Output Tokens | Avg Cost (USD) | Avg Cost (INR) |
|------|-----------------|------------------|---------------|---------------|
| Quick | ~6,300 | ~1,675 | $0.044 | ₹3.70 |
| Standard | ~11,400 | ~4,800 | $0.105 | ₹8.82 |
| Deep | ~10,600 | ~7,550 | $0.145 | ₹12.18 |
| Lectio | ~12,600 | ~5,250 | $0.126 | ₹10.58 |
| Sermon* | ~28,000 | ~20,000 | ~$0.263 | ~₹22.09 |

### Malayalam (most expensive — script token inefficiency ~7–8×)
| Mode | Avg Input Tokens | Avg Output Tokens | Avg Cost (USD) | Avg Cost (INR) |
|------|-----------------|------------------|---------------|---------------|
| Quick | ~6,950 | ~2,200 | $0.056 | ₹4.70 |
| Standard | ~13,200 | ~6,700 | $0.143 | ₹12.01 |
| Deep | ~11,250 | ~12,900 | $0.225 | ₹18.90 |
| Lectio | ~14,050 | ~8,650 | $0.178 | ₹14.95 |
| Sermon* | ~32,000 | ~24,000 | ~$0.358 | ~₹30.07 |

*\* Sermon uses a 4-pass generation architecture. Costs are extrapolated from Standard costs × 2.5 multipass factor. Validate once real Sermon logs accumulate.*

**Why HI/ML cost so much more:**
- Hindi and Malayalam scripts use significantly more LLM tokens to express equivalent content
- Malayalam specifically has ~7–8× token inefficiency vs English
- Input prompts include Bible text + system instructions translated to the target language, which inflates input tokens

---

## Revised Token Economy

### Exchange Rate
**2 tokens = ₹1** (₹0.50/token) — doubled from original

### Token Cost Per Generation

Designed to satisfy all constraints simultaneously:

| Mode | English | Hindi | Malayalam |
|------|---------|-------|-----------|
| Quick | 10 | 13 | 15 |
| Standard | 20 | 30 | 35 |
| Deep | 30 | 44 | 52 |
| Lectio Divina | 24 | 36 | 42 |
| Sermon Outline | 40 | 60 | 70 |

**Derivation:** `tokens = base_language_cost × mode_multiplier`

Base costs: EN=15, HI=25, ML=30
Mode multipliers: Quick=0.67, Standard=1.33, Deep=2.0, Lectio=1.6, Sermon=2.67
*(rounded to clean integers in practice)*

### Constraint: No Mode Overlap
**"Quick in any language must be cheaper than Standard in any language."**

- Max Quick token cost = ML Quick = **15**
- Min Standard token cost = EN Standard = **20**
- 15 < 20 ✅ — a user on any plan can never spend Quick-level tokens on a Standard guide

### Plan Daily Token Allocations

| Plan | Daily Tokens | Design Rationale |
|------|-------------|-----------------|
| Free | 15 | Exactly 1 Quick in any language (ML Quick = 15 = daily limit) |
| Standard | 40 | Any 1 Standard guide (ML Standard = 35, fits with 5 spare) |
| Plus | 60 | Any 1 Deep guide (HI Deep=44 or ML Deep=52 fit with change) |
| Premium | Unlimited | Avg 1,500 tokens/month fresh; cache hits are free |

---

## Complete Margin Analysis

### Raw margins (no cache)

| Mode | Lang | Tokens | Price | LLM Cost | Margin | Margin % |
|------|------|--------|-------|----------|--------|----------|
| Quick | EN | 10 | ₹5.00 | ₹2.18 | +₹2.82 | 56% |
| Quick | HI | 13 | ₹6.50 | ₹3.70 | +₹2.80 | 43% |
| Quick | ML | 15 | ₹7.50 | ₹4.70 | +₹2.80 | 37% |
| Standard | EN | 20 | ₹10.00 | ₹4.96 | +₹5.04 | 50% |
| Standard | HI | 30 | ₹15.00 | ₹8.82 | +₹6.18 | 41% |
| Standard | ML | 35 | ₹17.50 | ₹12.01 | +₹5.49 | 31% |
| Deep | EN | 30 | ₹15.00 | ₹6.64 | +₹8.36 | 56% |
| Deep | HI | 44 | ₹22.00 | ₹12.18 | +₹9.82 | 45% |
| Deep | ML | 52 | ₹26.00 | ₹18.90 | +₹7.10 | 27% |
| Lectio | EN | 24 | ₹12.00 | ₹5.29 | +₹6.71 | 56% |
| Lectio | HI | 36 | ₹18.00 | ₹10.58 | +₹7.42 | 41% |
| Lectio | ML | 42 | ₹21.00 | ₹14.95 | +₹6.05 | 29% |
| Sermon | EN | 40 | ₹20.00 | ~₹12.43 | +₹7.57 | 38% |
| Sermon | HI | 60 | ₹30.00 | ~₹22.09 | +₹7.91 | 26% |
| Sermon | ML | 70 | ₹35.00 | ~₹30.07 | +₹4.93 | 14% |

All modes positive. ML Sermon is the thinnest — validate with real log data before finalising.

---

## Cache Economics — The Hidden Profit Driver

### How caching works (`study-generate/index.ts`)

| Who accesses | LLM called? | Tokens charged? | Economics |
|-------------|-------------|-----------------|-----------|
| Original creator re-accessing their own guide | No | No | ₹0 cost, ₹0 revenue |
| Premium user accessing any cached guide | No | No | ₹0 cost, ₹0 revenue |
| Free/Standard/Plus user accessing cached guide | **No** | **Yes** | **₹0 cost, full token revenue** ← 100% margin |

### Implication

For every non-premium user who accesses a shared learning path guide:
- We collect full token revenue
- We incur zero LLM cost
- **Margin = 100%**

Learning path adoption directly multiplies profitability:
- If 30% of Standard/Plus generations are cache hits → effective LLM cost drops by 30%
- Revised effective margins with 30% cache: all modes above 40%

### Strategic priority: Promote Learning Paths

Surfacing learning paths to free and standard users is not just good UX — it is the primary lever for improving unit economics. Every user who joins a learning path instead of generating fresh content:
1. Gets a better structured experience
2. Costs less to serve
3. Is more likely to retain (structured progress)

---

## Premium Plan Viability

### Scenario: Average premium user (1,500 tokens/month fresh, 40% EN / 35% HI / 25% ML mix)

| Metric | Calculation | Value |
|--------|-------------|-------|
| Avg tokens/gen | 0.4×20 + 0.35×30 + 0.25×35 | ~27 tokens |
| Fresh gens/month | 1,500 / 27 | ~55 |
| Avg LLM cost/gen | 0.4×₹4.96 + 0.35×₹8.82 + 0.25×₹12.01 | ₹8.07 |
| Total LLM cost | 55 × ₹8.07 | ₹444 |
| Subscription revenue | — | ₹499 |
| Raw profit | ₹499 − ₹444 | +₹55 (11%) |
| With 30% cache lift | ₹499 − ₹311 | **+₹188 (38%)** ✅ |

### Risk: Heavy Malayalam user

A Premium user doing only fresh Malayalam Deep/Lectio daily:
- 1,500 tokens / 52 tokens/gen = ~29 ML Deep gens/month
- LLM cost: 29 × ₹18.90 = ₹548 > ₹499 subscription → **net loss**

**Mitigation options (for future consideration):**
- Monitor via admin dashboard — flag users consuming >1,800 tokens/month
- Consider a soft monthly cap (e.g. 2,500 tokens) with purchase for excess
- Language-specific premium pricing is complex; defer unless outliers become significant

---

## Implementation Checklist

To activate this token economy:

- [ ] `backend/supabase/functions/_shared/types/token-types.ts`
  - `tokensPerRupee: 4` → `2`
  - EN base cost: `10` → `15`
  - HI base cost: `15` → `25`
  - ML base cost: `15` → `30`
  - Mode multipliers: review against new base costs (or switch to hardcoded per-mode costs)
- [ ] Database — `subscription_plans` table
  - Free plan `daily_tokens`: `8` → `15`
  - Standard plan `daily_tokens`: `20` → `40`
  - Plus plan `daily_tokens`: `50` → `60`
- [ ] Frontend — `token_types.dart` or equivalent display strings: update token cost display
- [ ] Admin dashboard — validate new costs appear correctly in cost-by-language and cost-by-study-mode tables
- [ ] After 2 weeks of production data: validate Sermon cost estimates and recalibrate if needed

---

## Open Questions

1. **Sermon costs** — estimated from Standard × 2.5 multipass factor. Need real log data.
2. **ML Sermon margin (14% raw)** — acceptable if cache rate proves to be 30%+. If not, consider raising ML base to 35 (ML Sermon would become 70 tokens → ₹35 → +₹4.93 raw margin retained).
3. **Premium monthly token cap** — currently unlimited. Consider a 2,500 token/month soft cap for outlier protection. Revisit after 60 days of production data.
4. **Token purchase packages** — pricing tiers (e.g. 100 tokens, 500 tokens) need to be validated against the new ₹0.50/token base rate. Check `get_token_price` RPC and token package table in DB.
