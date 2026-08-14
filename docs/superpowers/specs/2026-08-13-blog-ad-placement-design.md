# Blog Ad Placement — Design

## Context

Marketing site (`marketing/`) wants ads in blog posts: subtle, only Christian-vetted advertisers, blog pages only. No advertisers signed yet. Researched Christian ad networks (ChristianAdNet, Beacon Ad Network) — viable long-term for the "Christian-only" requirement (they pre-vet advertisers), but:
- Their standard formats include a "dockable footer" ad — intrusive, rejected outright.
- Payout/CPM unpublished; site traffic skews non-US (India, Vietnam, Germany, France per Speed Insights), while these networks' advertiser demand skews US — expect thin/inconsistent fill.
- Any 3rd-party ad script risks reintroducing the CLS/TTFB regressions just fixed in the blog performance pass.

Decision: build the placement/UI as a self-contained, host-owned system first. Data source starts as an empty static config (house ads you add by hand) and swaps to a network feed later without touching the rendering/placement code.

## Approach

Chose **Option A: inline card, mid-article** over a text-link line (B, lowest visibility/CTR) and a desktop-only sidebar rail (C, invisible to mobile — the majority of this site's traffic). Validated via visual mockup in the brainstorming companion; user selected A.

## Architecture

```
lib/ads.ts                     — HouseAd type + ADS config array (source of truth, empty by default)
lib/insertAd.ts                — pure function: (markdown, ads, slug) -> markdown with ad marker spliced in
components/blog/AdSlot.tsx     — server component rendering the card (matches mockup option A)
components/blog/BlogPostContent.tsx — calls insertAd() before handing content to MDXRemote
```

## Data flow

1. `BlogPostContent` receives `post.content` (markdown string).
2. `insertAd(content, ADS, post.slug)`:
   - If `ADS.length === 0` → return content unchanged (no-op).
   - Split content on `\n\n` paragraph boundaries.
   - If fewer than 4 paragraphs → return content unchanged (short post, no ad).
   - Compute target index ≈ 40% of paragraph count.
   - Pick an ad deterministically: `ADS[hash(post.slug) % ADS.length]` (stable across ISR revalidations — no flicker between requests).
   - Splice in a raw MDX marker paragraph, e.g. `<AdSlot id="{adId}" />`, at the target index.
   - Return joined markdown.
3. `MDXRemote` renders the marker as `AdSlot` via `mdxComponents` map — same mechanism already used for other custom MDX elements (`components/blog/MDXComponents.tsx`).
4. `AdSlot` looks up the ad by id from `lib/ads.ts` and renders the card markup (image swatch, title, subtitle, "Sponsored" tag, link) — matches the mockup, styled with existing `--text`/`--muted`/`--border` CSS variables for theme consistency.

## Component contracts

- `HouseAd`: `{ id: string; title: string; subtitle: string; href: string; gradient: string }`
- `insertAd(content: string, ads: HouseAd[], slug: string): string` — pure, no I/O, unit-testable in isolation.
- `AdSlot`: server component, zero client JS, fixed-height card (no CLS — dimensions are static CSS, not image-load-dependent).

## Rules / edge cases

- Zero ads configured → feature is fully inert (default state today).
- Post under 4 paragraphs → never gets an ad.
- One ad slot per post, maximum.
- Deterministic per-slug selection — same post always shows the same ad until `ADS` config changes or is rotated manually.
- `AdSlot` only ever imported from `BlogPostContent` — never reachable from any other route.
- Always labeled "Sponsored" — never styled to pass as organic content.

## Non-goals (this iteration)

- No ChristianAdNet/network integration — data source stays a static local array until an advertiser or network is actually signed. Swapping `lib/ads.ts` to fetch from a network later is a separate, later change; `AdSlot`/`insertAd` don't need to know the difference.
- No admin UI for managing `ADS` — hand-edit the array like other config files (`lib/plans.ts` precedent).
- No frequency capping / analytics / click tracking — add only once there's a real advertiser to report to.

## Testing

- Unit tests for `insertAd`: 0 ads (no-op), short post (no-op), normal post (marker present at ~40% index), stable selection across repeated calls with same slug.
- Manual visual check against the approved mockup (dark/light theme, mobile width).
