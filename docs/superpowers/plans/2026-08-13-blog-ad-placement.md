# Blog Ad Placement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a subtle, host-owned "Sponsored" card that can appear mid-article in blog posts, with zero ads shown until an entry is hand-added to config.

**Architecture:** A pure function (`insertAd`) splices an `<AdSlot id="..." />` marker into the raw markdown at ~40% paragraph depth, deterministically per post slug. `AdSlot` is registered as an MDX component so `MDXRemote` renders it as a styled card looking up its data from a static `ADS` config array. No client JS, no network calls, no CLS (fixed-height card).

**Tech Stack:** Next.js 14 App Router, `next-mdx-remote/rsc`, TypeScript, Vitest (new — no test framework existed in this project before).

**Spec:** `docs/superpowers/specs/2026-08-13-blog-ad-placement-design.md`

## Global Constraints

- `ADS` array starts empty — feature must be a no-op with zero entries.
- Posts under 4 paragraphs never get an ad.
- Maximum one ad slot per post.
- Ad selection is deterministic per `post.slug` (no `Math.random()`/`Date.now()` — stable across ISR revalidations).
- `AdSlot` ships zero client JS (server component, no `"use client"`).
- Always labeled "Sponsored" — never styled to look like organic content.
- `AdSlot`/`insertAd` reachable only from the blog post route — not imported elsewhere.

---

### Task 1: Add Vitest test runner

No test framework exists in `marketing/` yet. This task adds the minimum needed to unit-test `insertAd` in Task 3.

**Files:**
- Modify: `marketing/package.json`

**Interfaces:**
- Produces: `npm test` script that later tasks' test files run under.

- [ ] **Step 1: Install vitest as a dev dependency**

Run: `cd marketing && npm install --save-dev vitest`

- [ ] **Step 2: Add the test script**

Edit `marketing/package.json` `scripts` block to add:

```json
"test": "vitest run"
```

(Keep existing `dev`, `build`, `start`, `lint` scripts unchanged.)

- [ ] **Step 3: Verify the runner works with a throwaway test**

Create a temporary file `marketing/lib/__smoke.test.ts`:

```ts
import { describe, it, expect } from "vitest";

describe("smoke", () => {
  it("runs", () => {
    expect(1 + 1).toBe(2);
  });
});
```

Run: `cd marketing && npm test`
Expected: 1 test passes.

Delete `marketing/lib/__smoke.test.ts` after confirming — it was only to verify the runner.

- [ ] **Step 4: Commit**

```bash
git add marketing/package.json marketing/package-lock.json
git commit -m "chore(marketing): add vitest test runner"
```

---

### Task 2: `HouseAd` type and empty `ADS` config

**Files:**
- Create: `marketing/lib/ads.ts`

**Interfaces:**
- Produces: `interface HouseAd { id: string; title: string; subtitle: string; href: string; gradient: string }` and `export const ADS: HouseAd[]`. Task 3 (`insertAd`) and Task 4 (`AdSlot`) both import from here.

- [ ] **Step 1: Write the file**

```ts
// marketing/lib/ads.ts
// House ad config. Empty by default — the blog ad feature is a no-op until
// an entry is added here by hand. `gradient` follows the same Tailwind
// "from-x to-y" pattern used for post tag accents in BlogPostContent.tsx.
export interface HouseAd {
  id: string;
  title: string;
  subtitle: string;
  href: string;
  gradient: string;
}

export const ADS: HouseAd[] = [];
```

- [ ] **Step 2: Typecheck**

Run: `cd marketing && npx tsc --noEmit`
Expected: no new errors from `lib/ads.ts`.

- [ ] **Step 3: Commit**

```bash
git add marketing/lib/ads.ts
git commit -m "feat(marketing): add HouseAd config (empty by default)"
```

---

### Task 3: `insertAd` placement function (TDD)

**Files:**
- Create: `marketing/lib/insertAd.ts`
- Test: `marketing/lib/insertAd.test.ts`

**Interfaces:**
- Consumes: `HouseAd` type and `ADS` array shape from Task 2 (`lib/ads.ts`) — test file constructs its own fixture array, doesn't need `ADS` to be non-empty.
- Produces: `export function insertAd(content: string, ads: HouseAd[], slug: string): string`. Task 5 (`BlogPostContent.tsx`) calls this directly.

- [ ] **Step 1: Write the failing tests**

```ts
// marketing/lib/insertAd.test.ts
import { describe, it, expect } from "vitest";
import { insertAd } from "./insertAd";
import type { HouseAd } from "./ads";

const AD_A: HouseAd = {
  id: "ad-a",
  title: "Daily Prayer Journal",
  subtitle: "90-day guided devotional",
  href: "https://example.com/a",
  gradient: "from-indigo-500 to-violet-500",
};
const AD_B: HouseAd = {
  id: "ad-b",
  title: "Study Bible Study Companion",
  subtitle: "Notes for every book",
  href: "https://example.com/b",
  gradient: "from-teal-500 to-indigo-500",
};

const LONG_POST = [
  "Intro paragraph one.",
  "Paragraph two with more detail.",
  "Paragraph three continues the thought.",
  "Paragraph four wraps up the first half.",
  "Paragraph five starts the second half.",
  "Paragraph six.",
  "Paragraph seven.",
  "Paragraph eight, the conclusion.",
].join("\n\n");

const SHORT_POST = ["Only paragraph one.", "Only paragraph two."].join("\n\n");

describe("insertAd", () => {
  it("returns content unchanged when no ads are configured", () => {
    expect(insertAd(LONG_POST, [], "some-slug")).toBe(LONG_POST);
  });

  it("returns content unchanged for posts under 4 paragraphs", () => {
    expect(insertAd(SHORT_POST, [AD_A], "some-slug")).toBe(SHORT_POST);
  });

  it("inserts an AdSlot marker into a long post", () => {
    const result = insertAd(LONG_POST, [AD_A], "some-slug");
    expect(result).toContain('<AdSlot id="ad-a" />');
    // Original paragraphs must still all be present, untouched.
    for (const para of LONG_POST.split("\n\n")) {
      expect(result).toContain(para);
    }
  });

  it("places the marker near 40% paragraph depth", () => {
    const result = insertAd(LONG_POST, [AD_A], "some-slug");
    const paragraphs = result.split("\n\n");
    const markerIndex = paragraphs.findIndex((p) => p.includes("<AdSlot"));
    // 8 source paragraphs, target = floor(8 * 0.4) = 3 (0-indexed insert position)
    expect(markerIndex).toBe(3);
  });

  it("is deterministic: same slug always yields the same ad", () => {
    const first = insertAd(LONG_POST, [AD_A, AD_B], "stable-slug");
    const second = insertAd(LONG_POST, [AD_A, AD_B], "stable-slug");
    expect(first).toBe(second);
  });

  it("can select different ads for different slugs", () => {
    // With two very different slugs and two ads, at least verify each
    // result contains exactly one of the two configured ad ids.
    const result = insertAd(LONG_POST, [AD_A, AD_B], "slug-one");
    const hasA = result.includes('<AdSlot id="ad-a" />');
    const hasB = result.includes('<AdSlot id="ad-b" />');
    expect(hasA !== hasB).toBe(true); // exactly one, never both, never neither
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd marketing && npx vitest run lib/insertAd.test.ts`
Expected: FAIL — `Cannot find module './insertAd'`.

- [ ] **Step 3: Implement `insertAd`**

```ts
// marketing/lib/insertAd.ts
import type { HouseAd } from "./ads";

// Deterministic string hash (djb2) — used only to pick a stable ad per
// slug, not for any security purpose.
function hashSlug(slug: string): number {
  let hash = 5381;
  for (let i = 0; i < slug.length; i++) {
    hash = (hash * 33) ^ slug.charCodeAt(i);
  }
  return Math.abs(hash);
}

// Splices an `<AdSlot id="..." />` marker into markdown at ~40% paragraph
// depth. No-op when there are no ads configured or the post is too short
// to interrupt. Selection is deterministic per slug so ISR revalidations
// never flicker between different ads on the same post.
export function insertAd(content: string, ads: HouseAd[], slug: string): string {
  if (ads.length === 0) return content;

  const paragraphs = content.split("\n\n");
  if (paragraphs.length < 4) return content;

  const targetIndex = Math.floor(paragraphs.length * 0.4);
  const ad = ads[hashSlug(slug) % ads.length];
  const marker = `<AdSlot id="${ad.id}" />`;

  return [
    ...paragraphs.slice(0, targetIndex),
    marker,
    ...paragraphs.slice(targetIndex),
  ].join("\n\n");
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd marketing && npx vitest run lib/insertAd.test.ts`
Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add marketing/lib/insertAd.ts marketing/lib/insertAd.test.ts
git commit -m "feat(marketing): add insertAd markdown placement function"
```

---

### Task 4: `AdSlot` component

**Files:**
- Create: `marketing/components/blog/AdSlot.tsx`

**Interfaces:**
- Consumes: `ADS` array and `HouseAd` type from `lib/ads.ts` (Task 2).
- Produces: `export function AdSlot({ id }: { id: string })` — a server component. Task 5 registers this in `mdxComponents`.

- [ ] **Step 1: Write the component**

```tsx
// marketing/components/blog/AdSlot.tsx
// Renders the card inserted by insertAd() (lib/insertAd.ts). Server
// component — no client JS, fixed height, no CLS. Looks up id in ADS;
// silently renders nothing if the id no longer exists (e.g. config edited
// after a page was cached under ISR) rather than showing a broken ad.
import { ADS } from "@/lib/ads";

export function AdSlot({ id }: { id: string }) {
  const ad = ADS.find((a) => a.id === id);
  if (!ad) return null;

  return (
    <div className="not-prose flex items-center gap-3 rounded-xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3 my-6">
      <div
        aria-hidden="true"
        className={`h-9 w-9 flex-shrink-0 rounded-lg bg-gradient-to-br ${ad.gradient}`}
      />
      <div className="min-w-0 flex-1">
        <a
          href={ad.href}
          rel="sponsored noopener noreferrer"
          target="_blank"
          className="block text-sm font-semibold text-[var(--text)] hover:text-primary dark:hover:text-indigo-300 transition-colors truncate"
        >
          {ad.title}
        </a>
        <p className="text-xs text-[var(--muted)] truncate">{ad.subtitle}</p>
      </div>
      <span className="flex-shrink-0 text-[10px] uppercase tracking-wide text-[var(--muted)] border border-[var(--border)] px-2 py-0.5 rounded-full">
        Sponsored
      </span>
    </div>
  );
}
```

- [ ] **Step 2: Typecheck**

Run: `cd marketing && npx tsc --noEmit`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add marketing/components/blog/AdSlot.tsx
git commit -m "feat(marketing): add AdSlot card component"
```

---

### Task 5: Wire into the blog post render path

**Files:**
- Modify: `marketing/components/blog/MDXComponents.tsx`
- Modify: `marketing/components/blog/BlogPostContent.tsx`

**Interfaces:**
- Consumes: `insertAd` (Task 3), `AdSlot` (Task 4), `ADS` (Task 2).
- Produces: nothing further downstream — this is the integration point.

- [ ] **Step 1: Register `AdSlot` as an MDX component**

In `marketing/components/blog/MDXComponents.tsx`, add the import and map entry:

```tsx
import { AppDownloadLink } from "@/components/blog/AppDownloadLink";
import { AdSlot } from "@/components/blog/AdSlot";
```

Add to the `mdxComponents` object (anywhere in the object literal, e.g. after `a`):

```tsx
  AdSlot,
```

- [ ] **Step 2: Call `insertAd` before rendering in `BlogPostContent.tsx`**

In `marketing/components/blog/BlogPostContent.tsx`, add the import:

```tsx
import { insertAd } from "@/lib/insertAd";
import { ADS } from "@/lib/ads";
```

Change the body to compute the content once, before the `return`:

```tsx
export function BlogPostContent({
  post,
  locale = "en",
  adjacent,
  related,
}: {
  post: Post;
  locale?: string;
  adjacent?: AdjacentPosts;
  related?: PostMeta[];
}) {
  const gradient = getGradient(post.tags);
  const ui = UI_STRINGS[(locale as UILocale) in UI_STRINGS ? (locale as UILocale) : "en"];
  const toc = extractToc(post.content);
  const contentWithAd = insertAd(post.content, ADS, post.slug);
  // Always share the post's own canonical (single-locale) URL, not the page-chrome locale.
  const postLocale = post.locale ?? locale;
  const shareUrl = `https://www.disciplefy.in${postLocale === "en" ? "" : `/${postLocale}`}/blog/${post.slug}`;
```

Then change the `MDXRemote` call to use `contentWithAd` instead of `post.content`:

```tsx
              <MDXRemote
                source={contentWithAd}
                components={mdxComponents}
                options={{ mdxOptions: { rehypePlugins: [rehypeSlug] } }}
              />
```

(`extractToc(post.content)` for the table of contents stays on the *original* `post.content` — the ad marker isn't a heading, so it wouldn't change the TOC, but using the pre-ad content keeps the two clearly independent.)

- [ ] **Step 3: Typecheck**

Run: `cd marketing && npx tsc --noEmit`
Expected: no new errors.

- [ ] **Step 4: Manual verification with a real ad entry**

Temporarily add a fixture entry to `marketing/lib/ads.ts` (do not commit this change):

```ts
export const ADS: HouseAd[] = [
  {
    id: "test-ad",
    title: "Test Sponsor",
    subtitle: "Manual verification only",
    href: "https://example.com",
    gradient: "from-indigo-500 to-violet-500",
  },
];
```

Run: `cd marketing && npm run dev`, open a blog post with 4+ paragraphs (e.g. `/blog/<any-existing-slug>`), confirm:
- Card renders once, roughly 40% down the post, styled like the approved mockup (swatch, title, subtitle, "Sponsored" tag).
- Light and dark theme both look correct.
- Mobile width (resize browser) — card doesn't overflow or shift layout on load.

Then revert `marketing/lib/ads.ts` back to the empty array (Task 2's version) — the feature must ship inert.

- [ ] **Step 5: Run full test suite**

Run: `cd marketing && npm test`
Expected: all tests (Task 3's `insertAd.test.ts`) still pass.

- [ ] **Step 6: Commit**

```bash
git add marketing/components/blog/MDXComponents.tsx marketing/components/blog/BlogPostContent.tsx
git commit -m "feat(marketing): render house ad card mid-article on blog posts"
```

---

## Self-Review Notes

- **Spec coverage:** `lib/ads.ts` (Task 2) ✓, `insertAd` splice-at-40%/no-op rules (Task 3) ✓, `AdSlot` card matching mockup A + "Sponsored" label + theme tokens (Task 4) ✓, wiring + blog-only reachability (Task 5) ✓, unit tests for 0-ads/short-post/normal-post/stable-selection (Task 3) ✓. Non-goals (network integration, admin UI, analytics) intentionally have no task — correct per spec.
- **No placeholders:** all steps contain full runnable code; no "TBD"/"similar to Task N".
- **Type consistency:** `HouseAd` (Task 2) fields — `id, title, subtitle, href, gradient` — used identically in `insertAd.test.ts` fixtures (Task 3), `insertAd.ts` (Task 3), and `AdSlot.tsx` (Task 4). `insertAd(content: string, ads: HouseAd[], slug: string): string` signature matches its Task 3 definition and its Task 5 call site (`insertAd(post.content, ADS, post.slug)`). `AdSlot({ id }: { id: string })` matches the marker string emitted by `insertAd` (`<AdSlot id="${ad.id}" />`) and its registration in `mdxComponents`.
