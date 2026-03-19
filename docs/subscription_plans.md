# Subscription Plans (4-Tier Model)

**Last Updated:** 2026-03-19
**Status:** Revised — see `docs/analysis/token_economy_analysis.md` for full rationale

---

## Exchange Rate

**2 tokens = ₹1 (₹0.50 per token)**
Previously: 4 tokens = ₹1 — was running every single mode at a loss.

---

## Plans Overview

### Free — ₹0/month
- **Daily Tokens:** 15 (enough for 1 Quick in any language)
- **Study Modes:** Quick only
- **Token Purchases:** Enabled (2 tokens/₹1)
- **Follow-ups:** None
- **AI Discipler:** 1/month
- **Memory Verses:** 3 active
- **Practice Modes:** 2 (Flip Card, Type It Out)
- **Practice Limit:** 1/verse/day

### Standard — ₹79/month
- **Daily Tokens:** 40 (enough for 1 Standard in any language)
- **Study Modes:** Quick, Standard, Deep
- **Token Purchases:** Enabled (2 tokens/₹1)
- **Follow-ups:** 5/guide (Haiku)
- **AI Discipler:** 3/month
- **Memory Verses:** 5 active
- **Practice Modes:** All 8 modes
- **Practice Limit:** 2/verse/day

### Plus — ₹149/month
- **Daily Tokens:** 60 (enough for 1 Deep in any language)
- **Study Modes:** Quick, Standard, Deep, Lectio Divina
- **Token Purchases:** Enabled (2 tokens/₹1)
- **Follow-ups:** 10/guide (Haiku)
- **AI Discipler:** 10/month
- **Memory Verses:** 10 active
- **Practice Modes:** All 8 modes
- **Practice Limit:** 3/verse/day

### Premium — ₹499/month
- **Daily Tokens:** Unlimited (avg ~1,500 tokens/month per user)
- **Study Modes:** All (Quick, Standard, Deep, Lectio, Sermon Outline)
- **Token Purchases:** Not needed
- **Follow-ups:** Unlimited (Haiku)
- **AI Discipler:** Unlimited
- **Memory Verses:** Unlimited
- **Practice Modes:** All 8 modes
- **Practice Limit:** Unlimited

---

## Token Cost Per Generation (tokens charged to user)

| Mode | English | Hindi | Malayalam |
|------|---------|-------|-----------|
| Quick | 10 | 13 | 15 |
| Standard | 20 | 30 | 35 |
| Deep | 30 | 44 | 52 |
| Lectio Divina | 24 | 36 | 42 |
| Sermon Outline | 40 | 60 | 70 |

**No-overlap rule:** Max Quick (ML=15) < Min Standard (EN=20) ✅
No user can spend Quick-tier tokens on a Standard-tier guide in any language.

---

## Daily Token Allocation vs What It Buys

| Plan | Daily Tokens | Can generate (examples) |
|------|-------------|------------------------|
| Free | 15 | 1× Quick in any language (ML Quick = 15 exactly) |
| Standard | 40 | 1× Standard any language (ML Standard=35 fits), or 4× EN Quick |
| Plus | 60 | 1× Deep HI (44) or 1× Deep ML (52), or 3× EN Standard (60) |
| Premium | Unlimited | Avg 1,500 tokens/month = ~50 fresh generations |

---

## Margin Per Generation (at ₹0.50/token)

### 🇺🇸 English
| Mode | Tokens | User Pays | LLM Cost | Raw Margin | w/ 30% Cache |
|------|--------|-----------|----------|-----------|-------------|
| Quick | 10 | ₹5.00 | ₹2.18 | +₹2.82 (56%) | **63%** |
| Standard | 20 | ₹10.00 | ₹4.96 | +₹5.04 (50%) | **65%** |
| Deep | 30 | ₹15.00 | ₹6.64 | +₹8.36 (56%) | **69%** |
| Lectio | 24 | ₹12.00 | ₹5.29 | +₹6.71 (56%) | **69%** |
| Sermon* | 40 | ₹20.00 | ~₹12.43 | +₹7.57 (38%) | **57%** |

### 🇮🇳 Hindi
| Mode | Tokens | User Pays | LLM Cost | Raw Margin | w/ 30% Cache |
|------|--------|-----------|----------|-----------|-------------|
| Quick | 13 | ₹6.50 | ₹3.70 | +₹2.80 (43%) | **60%** |
| Standard | 30 | ₹15.00 | ₹8.82 | +₹6.18 (41%) | **59%** |
| Deep | 44 | ₹22.00 | ₹12.18 | +₹9.82 (45%) | **61%** |
| Lectio | 36 | ₹18.00 | ₹10.58 | +₹7.42 (41%) | **59%** |
| Sermon* | 60 | ₹30.00 | ~₹22.09 | +₹7.91 (26%) | **48%** |

### 🇮🇳 Malayalam
| Mode | Tokens | User Pays | LLM Cost | Raw Margin | w/ 30% Cache |
|------|--------|-----------|----------|-----------|-------------|
| Quick | 15 | ₹7.50 | ₹4.70 | +₹2.80 (37%) | **56%** |
| Standard | 35 | ₹17.50 | ₹12.01 | +₹5.49 (31%) | **52%** |
| Deep | 52 | ₹26.00 | ₹18.90 | +₹7.10 (27%) | **49%** |
| Lectio | 42 | ₹21.00 | ₹14.95 | +₹6.05 (29%) | **50%** |
| Sermon* | 70 | ₹35.00 | ~₹30.07 | +₹4.93 (14%) | **43%** |

*\* Sermon costs are estimated (4-pass generation, no sufficient log data yet). Recalibrate once real data available.*

**Cache column assumes 30% of generations hit learning path cache → LLM cost = ₹0 on those.**

---

## Cache Economics (Key Profit Driver)

Learning path cache behaviour:
- **Original creator** revisits own guide → 0 tokens charged, ₹0 LLM cost
- **Premium user** accesses any cached guide → 0 tokens charged, ₹0 LLM cost
- **Free/Standard/Plus user** accesses cached guide → **full tokens charged, ₹0 LLM cost** ← 100% margin

**Strategic implication:** Every user who joins a learning path instead of generating fresh is more profitable than one doing fresh generation. Promoting learning paths aggressively is both better UX and better unit economics.

---

## Premium Plan Viability (₹499/month)

Modelled at avg 1,500 tokens/month, language mix 40% EN / 35% HI / 25% ML:

| Metric | Value |
|--------|-------|
| Avg tokens/generation | ~27 |
| Fresh generations/month | ~55 |
| Avg LLM cost/generation | ₹8.07 |
| Total LLM cost (raw) | ₹444 |
| Revenue | ₹499 |
| Raw profit | ₹55 (11%) |
| Profit with 30% cache benefit | **₹188 (38%)** ✅ |

Premium profitability is healthy as long as learning path adoption drives ~30%+ cache hit rate.
**Risk:** Heavy Malayalam users doing only fresh Deep/Lectio/Sermon daily can exceed ₹499 LLM cost. Monitor via admin dashboard.

---

## Practice Modes

**Easy:** Flip Card, Progressive Reveal, First Letter Hints
**Medium:** Word Bank, Word Scramble, Cloze (Fill in Blanks)
**Hard:** Audio Practice, Type It Out

---

## Feature Comparison

| Feature | Free | Standard | Plus | Premium |
|---------|------|----------|------|---------|
| **Price** | ₹0 | ₹79 | ₹149 | ₹499 |
| **Daily Tokens** | 15 | 40 | 60 | Unlimited |
| **Token Rate** | 2/₹1 | 2/₹1 | 2/₹1 | — |
| **Study Modes** | Quick | Standard, Deep | + Lectio | All incl. Sermon |
| **Follow-ups** | None | 5 | 10 | Unlimited |
| **Token Purchases** | ✅ | ✅ | ✅ | — |
| **AI Discipler** | 1/mo | 3/mo | 10/mo | Unlimited |
| **Memory Verses** | 3 | 5 | 10 | Unlimited |
| **Practice Modes** | 2 | 8 | 8 | All |
| **Practice Limit** | 1/day | 2/day | 3/day | Unlimited |

---

## What Changed From Previous Version

| Parameter | Old | New | Reason |
|-----------|-----|-----|--------|
| Token rate | 4/₹1 | 2/₹1 | Every mode was running at a loss |
| Free daily tokens | 8 | 15 | 8 was below even 1 Quick EN (old cost=5 tokens) |
| Standard daily tokens | 20 | 40 | 20 couldn't afford even 1 Standard guide |
| Plus daily tokens | 50 | 60 | Extra headroom for HI/ML Deep |
| EN base cost | 10 | 15 | Closer to actual LLM cost recovery |
| HI base cost | 15 | 25 | HI is 1.8× EN in LLM cost, not 1.5× |
| ML base cost | 15 | 30 | ML is 2.4× EN in LLM cost, not 1.5× |

> See `docs/analysis/token_economy_analysis.md` for complete cost analysis and strategic rationale.
