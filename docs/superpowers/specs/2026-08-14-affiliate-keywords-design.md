# Admin-Managed Affiliate Keywords — Design

## Context

Blog monetization step 2 (after the house-ad slot): auto-link curated product-shaped
keywords in blog posts to Amazon.in affiliate search URLs. The keyword list must be
editable from the admin-web dashboard (add / remove / enable-disable), not a static
file — so marketing copy changes never require a deploy.

Amazon Associates account exists; marketplace is **amazon.in**, tracking ID
**disciplefy-21**. Link target choice (already decided): auto-generated *search*
links (`https://www.amazon.in/s?k=<term>&tag=disciplefy-21`), not per-ASIN product
links — zero product-list curation at the cost of lower conversion.

## Architecture

Mirrors the existing promo-codes feature end to end. One new table, four small admin
Edge Functions, one admin-web CRUD page, and a keyword-linkify pass in the marketing
blog renderer alongside the existing `insertAd` pass.

```
backend/supabase/migrations/<ts>_affiliate_keywords.sql   — table + RLS
backend/supabase/functions/admin-list-affiliate-keywords/
backend/supabase/functions/admin-create-affiliate-keyword/
backend/supabase/functions/admin-toggle-affiliate-keyword/
backend/supabase/functions/admin-delete-affiliate-keyword/
admin-web/app/(dashboard)/affiliate-keywords/page.tsx     — CRUD screen
admin-web/app/api/admin/*-affiliate-keyword*/route.ts     — API routes (auth + forward)
admin-web/lib/api/admin.ts                                — fetch wrappers (extend)
marketing/lib/supabase.ts                                 — NEW anon-key read-only client
marketing/lib/affiliateKeywords.ts                        — fetch active keywords (cached)
marketing/lib/linkifyAffiliate.ts                         — pure markdown transform
marketing/components/blog/BlogPostContent.tsx             — wire the pass in
marketing/components/blog/AffiliateDisclosure.tsx         — required disclosure line
```

## Database

```sql
CREATE TABLE public.affiliate_keywords (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  keyword     text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX affiliate_keywords_keyword_unique
  ON public.affiliate_keywords (lower(keyword));
```

RLS: enabled. `SELECT` for `anon` and `authenticated` restricted to
`is_active = true` (marketing site reads with the anon key). No INSERT/UPDATE/DELETE
policies — admin mutations go through Edge Functions with the service-role key,
which bypasses RLS (same as `promotional_campaigns`).

Keyword constraints (enforced in the create Edge Function): trimmed, non-empty,
max 80 chars, case-insensitively unique.

## Admin Edge Functions

Copy the `admin-*-promo-code` handlers' shape exactly: verify
`Authorization: Bearer <service-role-key>` + `x-admin-user-id` header → re-check
`user_profiles.is_admin` → perform op → write `admin_audit_log` row (create /
toggle / delete) → return JSON.

- `admin-list-affiliate-keywords` — GET all rows (active and inactive), newest first.
- `admin-create-affiliate-keyword` — POST `{ keyword }`; validates constraints;
  409 on duplicate.
- `admin-toggle-affiliate-keyword` — POST `{ id, is_active }`.
- `admin-delete-affiliate-keyword` — POST `{ id }`; hard delete (the toggle covers
  soft-off; delete is for typos/junk).

## Admin-web CRUD page

Copy `promo-codes/page.tsx` structure: React Query list + mutations via
`lib/api/admin.ts` wrappers → `app/api/admin/*` routes (cookie-session auth,
`is_admin` check, forward to Edge Function). UI: single table (keyword, active
toggle, created date, delete button) + one inline "add keyword" input. No separate
create page — the entity is one string, a full page is overkill.

## Marketing consumption

- `marketing/lib/supabase.ts`: new `@supabase/supabase-js` dependency, anon-key
  client. New env vars `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  in marketing's Vercel project. Read-only by construction (RLS).
- `marketing/lib/affiliateKeywords.ts`: `getActiveAffiliateKeywords()` — selects
  `keyword` where RLS already filters to active; wrapped in the same 60s
  `revalidate`-style caching as blog fetches (fetch via Supabase REST URL with
  `next: { revalidate: 60 }` rather than the JS client if simpler — implementation
  detail, either is acceptable so long as it's cached and never per-request).
  On any error: return `[]` (feature degrades to no links, never breaks the page).

## Linkify pass

`linkifyAffiliate(content: string, keywords: string[]): string` — pure, unit-tested:

- Wraps the **first occurrence only** of each matched keyword in
  `[<matched text>](https://www.amazon.in/s?k=<url-encoded keyword>&tag=disciplefy-21)`.
- Match is case-insensitive on word boundaries; preserves the original casing of the
  matched text in the link label.
- Skips matches inside: existing links, headings, code fences, inline code, and
  blockquotes (scripture callouts must never get an affiliate link).
- Global cap: max **3** affiliate links per post (constant in the module). Longer
  keywords are matched first so "ESV Study Bible" wins over "study Bible".
- Runs in `BlogPostContent` on `post.content` before `insertAd` (linkify first so
  the ad-marker paragraph can never be linkified).

Link attributes: the MDX `a` renderer must emit
`rel="sponsored nofollow noopener noreferrer"` for amazon.in hrefs (extend the
existing `a` component in `MDXComponents.tsx`, which currently routes through
`AppDownloadLink`).

## Disclosure (required, non-negotiable)

Amazon operating agreement requires a visible disclosure on pages carrying
affiliate links. `AffiliateDisclosure` renders one muted line — "As an Amazon
Associate, Disciplefy earns from qualifying purchases." — above `BlogPostCTA`,
**only when the rendered post actually contains at least one affiliate link**
(linkify returns both the content and a `linkCount` so the caller knows).
Localized en/hi/ml via the existing `UI_STRINGS` map in `BlogPostContent`.

## Config

`AFFILIATE_TAG = "disciplefy-21"` and `MAX_LINKS_PER_POST = 3` live as constants in
`marketing/lib/linkifyAffiliate.ts` (or a tiny `affiliateConfig.ts`). The tag is
public information (visible in every URL) — not a secret, no env var needed.

## Seed keywords

Migration seeds the starter list (all active): "ESV Study Bible",
"NIV Study Bible", "study Bible", "Bible commentary", "Strong's Concordance",
"prayer journal", "Christian devotional". Editable from admin thereafter.

## Non-goals

- Per-ASIN product links, image cards, or price display — search links only.
- Click analytics on affiliate links (Amazon's own dashboard reports clicks/earnings;
  revisit only if attribution per post is ever needed).
- Localized keyword lists per language — one global list; Hindi/Malayalam posts
  simply won't match English keywords, which is acceptable at this stage.
- Any caching/invalidations fancier than the 60s revalidate window.

## Testing

- `linkifyAffiliate` unit tests (vitest, alongside `insertAd.test.ts`): first-match
  only, case-insensitivity, longest-keyword-first, skip links/headings/code/quotes,
  3-link cap, empty-keyword-list no-op, link URL shape (tag + encoding).
- Edge Functions: mirror whatever test coverage the promo-code functions have (if
  none, manual verification via local supabase serve is acceptable — consistent
  with existing admin functions).
- Admin page: manual verification locally (no test framework in admin-web today).
- Marketing fetch failure path: unit-test that `getActiveAffiliateKeywords()`
  returns `[]` on error.
