# Blog Preview + Scheduled Auto-Publish — Design Spec

**Date:** 2026-07-05
**Status:** Approved (design shape)

## Goal

Add two capabilities to the admin-web Blog Post editor:

1. **Live preview** — a faithful, side-by-side rendering of how the post will look on the public marketing blog, updating as the author types.
2. **Scheduled publishing** — let an admin pick a future date/time; the post auto-publishes at that time, driven by an rs-backend poll cron.

## Context (current architecture)

- **`blog_posts` table** (Supabase Postgres, migration `20260312100000_blog_posts.sql`): `status TEXT CHECK (status IN ('draft','published'))`, `published_at TIMESTAMPTZ` nullable. RLS public-read policy is gated to `status='published'`. Index `idx_blog_posts_locale_status(locale,status,published_at DESC)`.
- **rs-backend** (Rust/axum) owns the blog API + a `tokio-cron-scheduler` with `cron_config` DB table, per-job `AtomicBool` `CronGuard` concurrency locks, and hot-reloadable schedules. Existing jobs: `blog_generation`, `blog_retry`. `models/post.rs` holds CRUD; `create_post` sets `published_at=now()` only when `status='published'`.
- **admin-web** (Next.js 16) editor: `app/(dashboard)/blogs/new/page.tsx` (raw `<textarea>`, `handleSave('published'|'draft')`) and `app/(dashboard)/blogs/[id]/page.tsx`. Client calls `lib/api/admin.ts` → Next API routes `app/api/admin/blogs/*` which proxy to `${RS_BACKEND_URL}/api/v1/admin/posts` with the admin's Supabase Bearer token. `react-markdown@10` and `date-fns@4` already installed; `@headlessui/react` available. Types in `types/admin.ts` (`BlogPostStatus='draft'|'published'`).
- **marketing** blog article render: `components/blog/BlogPostContent.tsx` uses `next-mdx-remote/rsc` + `rehype-slug` (no remark-gfm, no syntax highlighting) with a hand-written per-element Tailwind map in `components/blog/MDXComponents.tsx`. NOT `prose-disciplefy`. Styling depends on Tailwind tokens `primary`/`primary-hover`, `light.*`/`dark.*` colors, `font-display` (Poppins), `font-sans` (Inter), CSS vars in `globals.css`, `darkMode:'class'`.

## Feature 1 — Live Preview

### Approach
Render the preview **client-side with `react-markdown`** (already a dependency), passing a `components` map ported verbatim from marketing's `MDXComponents.tsx` (same Tailwind class strings per element). Wrap the output in a self-contained `.blog-preview` scope that declares marketing's CSS variables (`--primary`, `--primary-hover`, light/dark `--bg/--surface/--border/--text/--muted`) and applies Poppins (headings) + Inter (body), so it matches the live article regardless of admin-web's own theme tokens.

### Why react-markdown, not next-mdx-remote
The live pane re-renders per keystroke → must be client-side. `next-mdx-remote` client rendering needs a server `serialize()` per change (round-trip per keystroke). `react-markdown` renders client-side with no plugins, which matches marketing's "no GFM" behavior. Visual output is identical for real markdown.

### Known fidelity trade
If an author embeds raw JSX/HTML in content, marketing's MDX executes it while react-markdown escapes it (unless `rehype-raw` is added). This is an edge case; `rehype-raw` may be added to close it. Also: the ported component map is a **second copy** of marketing's styling — it can drift if marketing restyles. Accepted for a preview; documented so it's a known maintenance point.

### UI
- Replace the raw `<textarea>` in `blogs/new/page.tsx` and `blogs/[id]/page.tsx` with a split view: markdown editor left, live `BlogPreview` right. Stacks vertically on narrow widths.
- `BlogPreview` optionally renders the article header chrome (title, tags, published/"draft" label, read-time estimate) above the body so the pane reads like the real article.

### Components / files
- **Create:** `admin-web/components/blog/BlogPreview.tsx` — react-markdown + ported component map, scoped tokens/fonts.
- **Create:** `admin-web/components/blog/mdx-components.tsx` (or inline) — the ported element→className map.
- **Modify:** `blogs/new/page.tsx`, `blogs/[id]/page.tsx` — split layout.
- **Modify:** `admin-web` Tailwind/global CSS — add the scoped `.blog-preview` token/font block (self-contained; no global theme change).
- **Deps:** none required (`react-markdown` present). Optional: `rehype-raw`.
- **No backend change.**

## Feature 2 — Scheduled Auto-Publish

### Data model (new Supabase migration)
- Extend `status` CHECK to `IN ('draft','published','scheduled')`.
- Add `scheduled_for TIMESTAMPTZ NULL`.
- Add CHECK: `status='scheduled'` ⇒ `scheduled_for IS NOT NULL`.
- Add partial index: `CREATE INDEX idx_blog_posts_scheduled ON blog_posts(scheduled_for) WHERE status='scheduled';`
- RLS public-read policy unchanged (`status='published'`) → scheduled posts stay hidden (defense in depth).

### rs-backend
- `models/post.rs`:
  - Add `scheduled_for: Option<DateTime<Utc>>` to `BlogPost`, `CreatePostInput`, `UpdatePostInput`.
  - `validate_create_input`: allow `status='scheduled'`; when scheduled, require `scheduled_for` present and in the future.
  - `create_post` / `create_post_if_not_exists`: for `status='scheduled'`, keep `published_at=NULL`, persist `scheduled_for`; INSERT the new column.
  - `update_post`: allow setting `scheduled_for` and `status='scheduled'`.
  - New `publish_due_scheduled(pool) -> Vec<(Uuid,String)>`: set-based idempotent
    `UPDATE blog_posts SET status='published', published_at=COALESCE(published_at,scheduled_for,now()) WHERE status='scheduled' AND scheduled_for<=now() RETURNING id,slug`.
- `cron/schedules.rs`: add `BLOG_PUBLISH_SCHEDULED = "0 * * * * *"` (every minute).
- `cron/mod.rs`: add `BLOG_PUBLISH_SCHEDULED_RUNNING: AtomicBool`; register a `blog_publish_scheduled` job mirroring existing jobs (per-run enabled check, guard, calls `publish_due_scheduled`); include it in the hardcoded-defaults fallback list.
- `cron_config` seed: add a `blog_publish_scheduled` row (enabled, schedule, label).
- **Altitude fix — `routes/admin.rs` `cron_update_schedule`:** the hot-reload closure (≈lines 222-235) hardcodes `run_blog_generation` for any non-`blog_retry` job and picks the guard flag by name. A third job would hot-reload to the WRONG task. Generalize to a name→(task fn, guard flag) dispatch so every job (incl. `blog_publish_scheduled`) hot-reloads correctly. `cron_status` will list the new job automatically.

### admin-web
- `types/admin.ts`: `BlogPostStatus` += `'scheduled'`; `CreateBlogPostRequest` and `UpdateBlogPostRequest` += `scheduled_for?: string` (ISO 8601 UTC).
- `blogs/new/page.tsx`: add a third action **"Schedule"** revealing `<input type="datetime-local">` (no new lib); on submit call `handleSave('scheduled')` sending `status:'scheduled'`, `scheduled_for:<local→UTC ISO>`. Guard: chosen time must be in the future.
- `blogs/[id]/page.tsx`: allow rescheduling (set/change `scheduled_for`, move to/from `scheduled`).
- `blogs/page.tsx` (list): show a `scheduled` badge and the scheduled time.
- Proxy routes (`app/api/admin/blogs/route.ts`, `[id]/route.ts`) already forward the body unchanged → no change needed.

### Cutover
Additive. Existing `draft`/`published` posts and flows are untouched. New status is opt-in from the editor.

## Out of scope
- Timezone selection UI (use the admin's local time → convert to UTC; display in local).
- Recurring/repeat scheduling.
- Email/notification on auto-publish.
- Extracting marketing's render into a shared package (documented drift risk instead).

## Testing strategy
- **rs-backend:** unit-test `publish_due_scheduled` (due flips, not-yet-due untouched, idempotent re-run) and `validate_create_input` (scheduled requires future `scheduled_for`). Note: repo currently has no Rust tests; add a minimal `#[cfg(test)]` for the pure validation logic; the SQL flip is verified against local Supabase.
- **admin-web:** manual — split preview matches a known marketing article for a sample post; schedule a post 2 min out against local rs-backend + Supabase and confirm auto-flip to published and public visibility.
- **DB:** migration applies clean on local (`supabase migration up`); scheduled rows excluded from public list; CHECK rejects `scheduled` without `scheduled_for`.
