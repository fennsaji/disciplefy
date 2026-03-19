# Breakeven Analysis

**Date:** 2026-03-19
**Related:** `docs/analysis/token_economy_analysis.md`, `docs/subscription_plans.md`

---

## Assumptions

| Parameter | Value |
|-----------|-------|
| Monthly fixed costs | ₹10,000 (infra + ops) |
| User distribution — Free | 70% |
| User distribution — Standard | 15% (₹79/month) |
| User distribution — Plus | 10% (₹149/month) |
| User distribution — Premium | 5% (₹499/month) |
| Token rate | 2 tokens = ₹1 |
| LLM model | claude-sonnet-4-5-20250929 |

---

## Unit Economics

### Average Revenue Per User (ARPU)

| Plan | Price | Share | Contribution |
|------|-------|-------|-------------|
| Free | ₹0 | 70% | ₹0.00 |
| Standard | ₹79 | 15% | ₹11.85 |
| Plus | ₹149 | 10% | ₹14.90 |
| Premium | ₹499 | 5% | ₹24.95 |
| **Total ARPU** | | | **₹51.70/user** |

### LLM Cost Per User

LLM costs average **~42% of ARPU** across the user base (consistent with raw per-generation margins of 37–56% from the token economy analysis). This accounts for:
- Free users consuming daily token allocations (₹0 revenue, nonzero LLM cost)
- Paid users generating at various modes and languages
- Premium users averaging ~55 fresh generations/month

**Average LLM cost: ₹21.85/user/month**

### Contribution Margin

```
Net contribution per user = ARPU − LLM cost
                          = ₹51.70 − ₹21.85
                          = ₹29.85/user/month
```

### Breakeven Formula

```
Breakeven users = Fixed costs ÷ Net contribution per user
               = ₹10,000 ÷ ₹29.85
               = 335 users
```

---

## Scenarios at Different User Counts

| Users | Monthly Revenue | LLM Cost | Fixed Cost | Net P&L | Status |
|------:|----------------:|---------:|-----------:|--------:|--------|
| 50 | ₹2,585 | ₹1,093 | ₹10,000 | **−₹8,508** | Loss |
| 100 | ₹5,170 | ₹2,185 | ₹10,000 | **−₹7,015** | Loss |
| 150 | ₹7,755 | ₹3,278 | ₹10,000 | **−₹5,523** | Loss |
| 200 | ₹10,340 | ₹4,370 | ₹10,000 | **−₹4,030** | Loss |
| 250 | ₹12,925 | ₹5,463 | ₹10,000 | **−₹2,538** | Loss |
| 300 | ₹15,510 | ₹6,555 | ₹10,000 | **−₹1,045** | Loss |
| **335** | **₹17,320** | **₹7,320** | **₹10,000** | **₹0** | **⬛ BREAKEVEN** |
| 400 | ₹20,680 | ₹8,740 | ₹10,000 | **+₹1,940** | Profit |
| 500 | ₹25,850 | ₹10,925 | ₹10,000 | **+₹4,925** | Profit |
| 750 | ₹38,775 | ₹16,388 | ₹10,000 | **+₹12,387** | Profit |
| 1,000 | ₹51,700 | ₹21,850 | ₹10,000 | **+₹19,850** | Profit |
| 2,000 | ₹1,03,400 | ₹43,700 | ₹10,000 | **+₹49,700** | Profit |

*Revenue = users × ₹51.70 ARPU | LLM cost = users × ₹21.85 | Fixed = ₹10,000 flat*

---

## Key Milestones

| Milestone | Users Needed |
|-----------|-------------|
| Cover infrastructure alone | ~194 users |
| Breakeven (zero profit/loss) | **335 users** |
| ₹5,000/month profit | ~502 users |
| ₹10,000/month profit | ~669 users |
| ₹25,000/month profit | ~1,170 users |
| ₹50,000/month profit | ~2,005 users |

*Milestone formula: users = (fixed + target\_profit) ÷ ₹29.85*

---

## Sensitivity: What If the Mix Shifts?

The breakeven point is sensitive to the paid-to-free ratio. If more users upgrade:

| Scenario | Paid % | ARPU | Breakeven |
|----------|--------|------|-----------|
| Current (base) | 30% | ₹51.70 | 335 users |
| More upgrades | 40% | ₹68.93 | ~206 users |
| Heavy free skew | 20% | ₹34.47 | ~520 users |
| Premium-heavy | 10% premium | ₹61.35 | ~235 users |

Converting just 10% more free users to Standard cuts the breakeven by ~130 users.

---

## Multi-Tier P&L by User Mix

P&L across user counts for realistic distributions. Premium varies from 0–5% (increases as free% rises to compensate); Standard:Plus held at **3:2** among remaining paid users. Row 5 (70% free) = current base mix.

### Per-Tier Unit Economics

| Plan | Revenue | Est. LLM Cost | Net/user |
|------|---------|---------------|----------|
| Free | ₹0 | ₹3 | **−₹3** |
| Standard | ₹79 | ₹25 | **+₹54** |
| Plus | ₹149 | ₹55 | **+₹94** |
| Premium | ₹499 | ₹200 | **+₹299** |

*LLM costs back-calculated from the ₹21.85/user average at the 70/15/10/5 base mix.*

---

### P&L at Different User Counts

| Free % | Std % | Plus % | Premium % |  100 users |  500 users | 1,000 users | 10,000 users |
|:------:|:-----:|:------:|:---------:|-----------:|-----------:|------------:|-------------:|
|   0%   |  60%  |  40%   |    0%     |   −₹3,000  |  +₹25,000  |   +₹60,000  |  +₹6,90,000  |
|  20%   |  47%  |  32%   |    1%     |   −₹4,230  |  +₹18,845  |   +₹47,690  |  +₹5,66,900  |
|  40%   |  35%  |  23%   |    2%     |   −₹5,460  |  +₹12,690  |   +₹35,380  |  +₹4,43,800  |
|  60%   |  22%  |  15%   |    3%     |   −₹6,690  |   +₹6,535  |   +₹23,070  |  +₹3,20,700  |
|  70%   |  15%  |  10%   |    5%     |   −₹6,965  |   +₹5,175  |   +₹20,350  |  +₹2,93,500  |
|  80%   |   9%  |   6%   |    5%     |   −₹7,695  |   +₹1,525  |   +₹13,050  |  +₹2,20,500  |

*Net/user = −3f + 54s + 94p + 299r (fractions). Row 5 = current base mix (70/15/10/5).*

---

### Scale Effect: Max Sustainable Free %

| Users | With 0% Premium | With 5% Premium |
|------:|----------------:|----------------:|
| 100 | Not achievable | Not achievable |
| 335 (base breakeven) | 55% | 71% |
| 500 | 68% | 84% |
| 1,000 | 82% | ~95%+ |
| 10,000 | 95% | Any mix |

Adding even 5% Premium users raises the max sustainable free % by ~12–15 percentage points at every scale.

---

## Notes

- **Cache effect not included** — if 30% of paid generations hit learning path cache (₹0 LLM cost), effective LLM cost drops ~30%, improving the breakeven to ~260 users.
- **Token purchase revenue not included** — free and paid users buying extra tokens is upside not captured here.
- **Premium risk** — a heavy Malayalam-only Premium user can cost ₹548/month in LLM vs ₹499 subscription. Monitor users consuming >1,800 tokens/month via admin dashboard.
- **Fixed costs assumed flat** — infra scales negligibly up to ~5,000 users on current Supabase plan.
