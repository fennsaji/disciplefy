# Blog Preview + Scheduled Auto-Publish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live faithful preview and scheduled auto-publish to the admin-web blog editor.

**Architecture:** DB gains a `scheduled` status + `scheduled_for` column. rs-backend gains a 1-minute poll cron that flips due scheduled posts to published. admin-web gets a side-by-side react-markdown preview (marketing styling ported) and a datetime schedule action.

**Tech Stack:** Supabase Postgres migration; Rust/axum + `tokio-cron-scheduler` (rs-backend); Next.js 16 + `react-markdown@10` + `date-fns` (admin-web).

## Global Constraints

- Never commit docs (specs/plans/marketing) — code changes only.
- Commit messages: one-liner `type(scope): description`, no `Co-Authored-By`.
- `blog_posts` public RLS read stays `status='published'` — scheduled posts must never be publicly visible.
- Fail closed: `status='scheduled'` requires a future `scheduled_for`; reject otherwise.
- Preview must not restyle admin-web globally — all marketing tokens/fonts live in a scoped `.blog-preview` container.
- Additive cutover: existing `draft`/`published` posts and flows unchanged.
- Product IDs / status strings are exact: statuses are exactly `'draft'`, `'published'`, `'scheduled'`.
- rs-backend uses raw SQLx queries (no compile-time checking); statement cache disabled — keep queries plain.

---

### Task 1: DB migration — scheduled status + scheduled_for

**Files:**
- Create: `backend/supabase/migrations/20260705000002_blog_scheduled_publishing.sql`

**Interfaces:**
- Produces: `blog_posts.scheduled_for TIMESTAMPTZ`, `status` accepts `'scheduled'`, `cron_config` row `blog_publish_scheduled`.

- [ ] **Step 1: Write the migration**

```sql
-- Scheduled publishing for blog posts.
-- Adds a 'scheduled' status + scheduled_for timestamp. A rs-backend poll cron
-- flips due rows to 'published'. Public RLS read stays 'published' only, so
-- scheduled rows are never publicly visible.

BEGIN;

ALTER TABLE blog_posts DROP CONSTRAINT IF EXISTS blog_posts_status_check;
ALTER TABLE blog_posts
  ADD CONSTRAINT blog_posts_status_check
  CHECK (status IN ('draft', 'published', 'scheduled'));

ALTER TABLE blog_posts ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ;

-- A scheduled post must carry a target time.
ALTER TABLE blog_posts DROP CONSTRAINT IF EXISTS blog_posts_scheduled_requires_time;
ALTER TABLE blog_posts
  ADD CONSTRAINT blog_posts_scheduled_requires_time
  CHECK (status <> 'scheduled' OR scheduled_for IS NOT NULL);

-- Poll index: only scheduled rows.
CREATE INDEX IF NOT EXISTS idx_blog_posts_scheduled
  ON blog_posts(scheduled_for) WHERE status = 'scheduled';

-- Seed cron_config row so the new job persists + is listed by admin cron status.
INSERT INTO cron_config (name, enabled, schedule, label)
VALUES ('blog_publish_scheduled', true, '0 * * * * *', 'Every minute — publish due scheduled posts')
ON CONFLICT (name) DO NOTHING;

COMMIT;
```

- [ ] **Step 2: Apply + verify locally**

Run: `cd backend && supabase migration up`
Then verify:
```bash
psql "$LOCAL_DB_URL" -c "\d blog_posts" | grep scheduled_for
psql "$LOCAL_DB_URL" -c "INSERT INTO blog_posts (slug,title,content,locale,status) VALUES ('x-en','x','x','en','scheduled');"
# Expected: ERROR — violates blog_posts_scheduled_requires_time
psql "$LOCAL_DB_URL" -c "SELECT name FROM cron_config WHERE name='blog_publish_scheduled';"
# Expected: one row
```

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260705000002_blog_scheduled_publishing.sql
git commit -m "feat(blog): add scheduled status and scheduled_for to blog_posts"
```

Note: confirm `cron_config` has a UNIQUE constraint on `name` before relying on `ON CONFLICT (name)`; if not, the seed uses `WHERE NOT EXISTS` instead. Check `cron_config` migration first.

---

### Task 2: rs-backend — scheduled_for model, validation, publish query

**Files:**
- Modify: `rs-backend/src/models/post.rs`

**Interfaces:**
- Consumes: `blog_posts.scheduled_for` (Task 1).
- Produces:
  - `BlogPost.scheduled_for: Option<DateTime<Utc>>`
  - `CreatePostInput.scheduled_for: Option<DateTime<Utc>>`, `UpdatePostInput.scheduled_for: Option<DateTime<Utc>>`
  - `pub async fn publish_due_scheduled(pool: &PgPool) -> Result<Vec<(Uuid, String)>, AppError>`

- [ ] **Step 1: Add fields**

In `BlogPost` struct add after `published_at`:
```rust
    pub scheduled_for: Option<DateTime<Utc>>,
```
In `CreatePostInput` add:
```rust
    #[serde(default)]
    pub scheduled_for: Option<DateTime<Utc>>,
```
In `UpdatePostInput` add:
```rust
    pub scheduled_for: Option<DateTime<Utc>>,
```

- [ ] **Step 2: Extend validation**

In `validate_create_input`, replace the status check block:
```rust
    let valid_statuses = ["draft", "published", "scheduled"];
    if !valid_statuses.contains(&input.status.as_str()) {
        return Err(AppError::BadRequest(
            "status must be 'draft', 'published', or 'scheduled'".to_string(),
        ));
    }
    if input.status == "scheduled" {
        match input.scheduled_for {
            None => {
                return Err(AppError::BadRequest(
                    "scheduled_for is required when status is 'scheduled'".to_string(),
                ))
            }
            Some(t) if t <= Utc::now() => {
                return Err(AppError::BadRequest(
                    "scheduled_for must be in the future".to_string(),
                ))
            }
            _ => {}
        }
    }
```

- [ ] **Step 3: Add unit test for validation**

Append to `post.rs`:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn base_input(status: &str, scheduled_for: Option<DateTime<Utc>>) -> CreatePostInput {
        CreatePostInput {
            title: "Title".into(),
            content: "Body".into(),
            excerpt: String::new(),
            locale: "en".into(),
            tags: vec![],
            featured: false,
            status: status.into(),
            slug: None,
            source_type: None,
            source_topic_id: None,
            source_learning_path_id: None,
            source_guide_id: None,
            scheduled_for,
        }
    }

    #[test]
    fn scheduled_requires_future_time() {
        assert!(validate_create_input(&base_input("scheduled", None)).is_err());
        let past = Utc::now() - chrono::Duration::hours(1);
        assert!(validate_create_input(&base_input("scheduled", Some(past))).is_err());
        let future = Utc::now() + chrono::Duration::hours(1);
        assert!(validate_create_input(&base_input("scheduled", Some(future))).is_ok());
    }

    #[test]
    fn draft_and_published_still_valid() {
        assert!(validate_create_input(&base_input("draft", None)).is_ok());
        assert!(validate_create_input(&base_input("published", None)).is_ok());
    }
}
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `cd rs-backend && cargo test scheduled_requires_future_time draft_and_published_still_valid`
Expected: 2 passed.

- [ ] **Step 5: Update published_at logic + INSERTs**

In `create_post` and `create_post_if_not_exists`, replace the `published_at` computation:
```rust
    let published_at = if input.status == "published" {
        Some(Utc::now())
    } else {
        None // draft or scheduled
    };
```
Add `scheduled_for` to both INSERT column lists and VALUES (new `$14`), binding `input.scheduled_for` after the `published_at` bind. Update the column list to include `scheduled_for` and the placeholder count. Example for `create_post`:
```rust
    let post = sqlx::query_as::<_, BlogPost>(
        "INSERT INTO blog_posts (slug, title, excerpt, content, locale, tags, featured, status,
                                 source_type, source_topic_id, source_learning_path_id,
                                 source_guide_id, published_at, scheduled_for)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
         RETURNING *",
    )
    // ...existing binds through published_at...
    .bind(published_at)
    .bind(input.scheduled_for)
    .fetch_one(pool)
    .await?;
```
Apply the same to `create_post_if_not_exists` (keep its `ON CONFLICT (slug) DO NOTHING`).

- [ ] **Step 6: Extend update_post**

Add `scheduled_for` to the UPDATE SET list and bind:
```rust
        "UPDATE blog_posts SET
           title = COALESCE($2, title),
           content = COALESCE($3, content),
           excerpt = COALESCE($4, excerpt),
           tags = COALESCE($5, tags),
           featured = COALESCE($6, featured),
           status = COALESCE($7, status),
           scheduled_for = COALESCE($8, scheduled_for)
         WHERE id = $1
         RETURNING *",
```
Add `.bind(input.scheduled_for)` after the existing binds.

- [ ] **Step 7: Add publish_due_scheduled**

```rust
/// Flip all scheduled posts whose time has arrived to published. Set-based and
/// idempotent: a re-run selects nothing because rows are no longer 'scheduled'.
pub async fn publish_due_scheduled(pool: &PgPool) -> Result<Vec<(Uuid, String)>, AppError> {
    let rows: Vec<(Uuid, String)> = sqlx::query_as(
        "UPDATE blog_posts
         SET status = 'published',
             published_at = COALESCE(published_at, scheduled_for, now())
         WHERE status = 'scheduled' AND scheduled_for <= now()
         RETURNING id, slug",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows)
}
```

- [ ] **Step 8: Compile**

Run: `cd rs-backend && cargo check`
Expected: no errors. (`generate_blog_from_study_guide` in admin.rs constructs `CreatePostInput` — Step 1's `#[serde(default)]` does not apply to struct literals, so that literal must add `scheduled_for: None`. Fix it in Task 4; for now `cargo check` will flag it — that is expected and resolved in Task 4. If you want a clean check here, add `scheduled_for: None` to that literal now.)

- [ ] **Step 9: Commit**

```bash
git add rs-backend/src/models/post.rs
git commit -m "feat(blog): support scheduled status in post model and add publish_due_scheduled"
```

---

### Task 3: rs-backend — register the blog_publish_scheduled cron

**Files:**
- Modify: `rs-backend/src/cron/schedules.rs`
- Modify: `rs-backend/src/cron/mod.rs`

**Interfaces:**
- Consumes: `post::publish_due_scheduled` (Task 2), `cron_config` row `blog_publish_scheduled` (Task 1).
- Produces: a running 1-minute cron; `BLOG_PUBLISH_SCHEDULED_RUNNING` guard exported for reuse in Task 4.

- [ ] **Step 1: Add the schedule constant**

`schedules.rs`, append:
```rust
/// Publish scheduled posts — every minute, flips due scheduled posts to published.
pub const BLOG_PUBLISH_SCHEDULED: &str = "0 * * * * *";
```

- [ ] **Step 2: Add the guard flag**

`cron/mod.rs`, near the other `AtomicBool`s:
```rust
pub static BLOG_PUBLISH_SCHEDULED_RUNNING: AtomicBool = AtomicBool::new(false);
```

- [ ] **Step 3: Add to the hardcoded-defaults fallback list**

In `start_scheduler`, add to the fallback `vec![...]`:
```rust
            CronConfig {
                name: "blog_publish_scheduled".into(),
                enabled: true,
                schedule: schedules::BLOG_PUBLISH_SCHEDULED.into(),
                label: "Every minute — publish due scheduled posts".into(),
                updated_at: chrono::Utc::now(),
            },
```

- [ ] **Step 4: Register the job**

In `start_scheduler`, after the blog_retry job registration and before `sched.start()`, add:
```rust
    // Scheduled-post publisher CRON
    let sched_cfg = configs.iter().find(|c| c.name == "blog_publish_scheduled");
    let sched_schedule = sched_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::BLOG_PUBLISH_SCHEDULED.into());
    let sched_pool = pool.clone();

    let publish_job = Job::new_async(sched_schedule.as_str(), move |_uuid, _lock| {
        let p = sched_pool.clone();
        Box::pin(async move {
            match cron_config::get(&p, "blog_publish_scheduled").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::info!("blog_publish_scheduled cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
            let _guard = match CronGuard::try_acquire(&BLOG_PUBLISH_SCHEDULED_RUNNING) {
                Some(g) => g,
                None => {
                    tracing::warn!("Scheduled-publish CRON skipped: previous run still in progress");
                    return;
                }
            };
            match crate::models::post::publish_due_scheduled(&p).await {
                Ok(published) if !published.is_empty() => {
                    tracing::info!(count = published.len(), "Auto-published scheduled posts");
                }
                Ok(_) => {}
                Err(e) => tracing::error!("Scheduled-publish CRON failed: {}", e),
            }
        })
    })
    .expect("Failed to create scheduled-publish CRON job");

    let publish_uuid = sched
        .add(publish_job)
        .await
        .expect("Failed to add scheduled-publish CRON job");
    job_ids.insert("blog_publish_scheduled".into(), publish_uuid);
```

- [ ] **Step 5: Compile + run**

Run: `cd rs-backend && cargo check`
Expected: no errors.
Run locally: `cargo run` — expect log line listing the scheduler start; no panic.

- [ ] **Step 6: Commit**

```bash
git add rs-backend/src/cron/schedules.rs rs-backend/src/cron/mod.rs
git commit -m "feat(blog): add every-minute cron to auto-publish scheduled posts"
```

---

### Task 4: rs-backend — generalize cron hot-reload dispatch (altitude fix)

**Files:**
- Modify: `rs-backend/src/routes/admin.rs`

**Interfaces:**
- Consumes: `BLOG_PUBLISH_SCHEDULED_RUNNING` (Task 3), `post::publish_due_scheduled` (Task 2).

**Why:** `cron_update_schedule`'s hot-reload closure currently hardcodes `run_blog_generation` for any non-`blog_retry` job and picks the guard by name. With a third job, editing `blog_publish_scheduled`'s schedule would hot-reload it to run blog GENERATION. Generalize so each job re-registers with its own task + guard.

- [ ] **Step 1: Add scheduled_for to the study-guide CreatePostInput literal**

In `generate_blog_from_study_guide`, the `post::CreatePostInput { ... }` literal: add `scheduled_for: None,`. (Resolves the expected `cargo check` gap from Task 2 Step 8.)

- [ ] **Step 2: Refactor the hot-reload job body to dispatch by name**

Replace the inner `Box::pin(async move { ... })` body in `cron_update_schedule`'s `Job::new_async` closure so it dispatches on `n`:
```rust
                    Box::pin(async move {
                        match cron_config::get(&p, &n).await {
                            Ok(cfg) if !cfg.enabled => {
                                tracing::info!("{} cron disabled — skipping", n);
                                return;
                            }
                            Err(e) => tracing::warn!(
                                "Could not read cron_config: {} — proceeding anyway",
                                e
                            ),
                            _ => {}
                        }
                        match n.as_str() {
                            "blog_publish_scheduled" => {
                                let _guard = match crate::cron::CronGuard::try_acquire(
                                    &crate::cron::BLOG_PUBLISH_SCHEDULED_RUNNING,
                                ) {
                                    Some(g) => g,
                                    None => {
                                        tracing::warn!("CRON skipped: previous run still in progress");
                                        return;
                                    }
                                };
                                match crate::models::post::publish_due_scheduled(&p).await {
                                    Ok(published) if !published.is_empty() => tracing::info!(
                                        count = published.len(),
                                        "Auto-published scheduled posts"
                                    ),
                                    Ok(_) => {}
                                    Err(e) => tracing::error!("Scheduled-publish CRON failed: {}", e),
                                }
                            }
                            other => {
                                // blog_generation or blog_retry — both run generation
                                let flag = if other == "blog_retry" {
                                    &crate::cron::BLOG_RETRY_RUNNING
                                } else {
                                    &crate::cron::BLOG_GENERATION_RUNNING
                                };
                                let _guard = match crate::cron::CronGuard::try_acquire(flag) {
                                    Some(g) => g,
                                    None => {
                                        tracing::warn!("CRON skipped: previous run still in progress");
                                        return;
                                    }
                                };
                                if let Err(e) =
                                    crate::cron::blog_generator::run_blog_generation(&p, &c, &h).await
                                {
                                    tracing::error!("CRON failed: {}", e);
                                }
                            }
                        }
                    })
```
Note: `c` (config Arc) and `h` (http) are still captured for the generation branch — keep their clones in the closure. The scheduled branch ignores them.

- [ ] **Step 3: Compile**

Run: `cd rs-backend && cargo check`
Expected: no errors.

- [ ] **Step 4: Manual end-to-end DB flip test**

With local rs-backend running against local Supabase:
```bash
# Insert a post scheduled 60s out (service-role):
psql "$LOCAL_DB_URL" -c "INSERT INTO blog_posts (slug,title,content,locale,status,scheduled_for)
  VALUES ('sched-test-en','Sched Test','Body','en','scheduled', now() + interval '60 seconds');"
# Wait ~90s, then:
psql "$LOCAL_DB_URL" -c "SELECT status, published_at FROM blog_posts WHERE slug='sched-test-en';"
# Expected: status=published, published_at set (~scheduled_for).
```

- [ ] **Step 5: Commit**

```bash
git add rs-backend/src/routes/admin.rs
git commit -m "fix(blog): dispatch cron hot-reload by job name to support scheduled-publish"
```

---

### Task 5: admin-web — schedule action + types + list badge

**Files:**
- Modify: `admin-web/types/admin.ts`
- Modify: `admin-web/app/(dashboard)/blogs/new/page.tsx`
- Modify: `admin-web/app/(dashboard)/blogs/[id]/page.tsx`
- Modify: `admin-web/app/(dashboard)/blogs/page.tsx`

**Interfaces:**
- Consumes: rs-backend accepts `status:'scheduled'` + `scheduled_for` (Tasks 1-2).
- Produces: editor sends `{ status:'scheduled', scheduled_for: <ISO UTC> }`.

- [ ] **Step 1: Extend types**

`types/admin.ts`:
```ts
export type BlogPostStatus = 'draft' | 'published' | 'scheduled';
```
Add to `CreateBlogPostRequest` and `UpdateBlogPostRequest`:
```ts
  scheduled_for?: string; // ISO 8601 UTC; required when status === 'scheduled'
```
Add `scheduled_for?: string | null;` to the `BlogPost` response type if present.

- [ ] **Step 2: Add schedule UI to the create page**

In `blogs/new/page.tsx`:
- Add state: `const [scheduledFor, setScheduledFor] = useState('');` and `const [showSchedule, setShowSchedule] = useState(false);`
- Extend `handleSave` signature to accept `'scheduled'` and include `scheduled_for` when scheduling:
```tsx
const handleSave = async (saveStatus: BlogPostStatus) => {
  // ...existing validation...
  let scheduledIso: string | undefined;
  if (saveStatus === 'scheduled') {
    if (!scheduledFor) { toast.error('Pick a date & time to schedule'); return; }
    const when = new Date(scheduledFor); // datetime-local is local time
    if (when.getTime() <= Date.now()) { toast.error('Scheduled time must be in the future'); return; }
    scheduledIso = when.toISOString(); // → UTC
  }
  const post = await createBlogPost({
    // ...existing fields...
    status: saveStatus,
    scheduled_for: scheduledIso,
  });
  // ...existing routing...
};
```
- In the PUBLISH card, add below "Save as Draft":
```tsx
<button
  type="button"
  onClick={() => setShowSchedule((s) => !s)}
  className="/* match existing secondary button classes */"
>
  🗓️ Schedule
</button>
{showSchedule && (
  <div className="mt-3 space-y-2">
    <input
      type="datetime-local"
      value={scheduledFor}
      onChange={(e) => setScheduledFor(e.target.value)}
      className="/* match existing input classes */"
    />
    <button
      type="button"
      disabled={saving || !scheduledFor}
      onClick={() => handleSave('scheduled')}
      className="/* match existing primary button classes */"
    >
      Schedule Post
    </button>
  </div>
)}
```

- [ ] **Step 3: Add rescheduling to the edit page**

In `blogs/[id]/page.tsx`: load `scheduled_for` into state; when the post `status==='scheduled'`, show the `datetime-local` populated (convert stored UTC → local for the input via `date-fns` `format(new Date(iso), "yyyy-MM-dd'T'HH:mm")`). Add a "Reschedule"/"Schedule" action calling `updateBlogPost(id, { status:'scheduled', scheduled_for: new Date(local).toISOString() })`. Reuse the same future-time guard.

- [ ] **Step 4: List badge**

In `blogs/page.tsx`: render a `scheduled` badge (distinct color) and, when scheduled, show the local time via `date-fns format`. Add `scheduled` to any status filter control.

- [ ] **Step 5: Typecheck + manual**

Run: `cd admin-web && npx tsc --noEmit`
Expected: clean.
Manual: create a post scheduled 2 min out → confirm it appears with a scheduled badge, is absent from the public marketing list, and flips to published after the rs-backend cron runs.

- [ ] **Step 6: Commit**

```bash
git add admin-web/types/admin.ts "admin-web/app/(dashboard)/blogs/new/page.tsx" "admin-web/app/(dashboard)/blogs/[id]/page.tsx" "admin-web/app/(dashboard)/blogs/page.tsx"
git commit -m "feat(blog): add schedule action and scheduled status to admin blog editor"
```

---

### Task 6: admin-web — live faithful preview (side-by-side)

**Files:**
- Create: `admin-web/components/blog/BlogPreview.tsx`
- Create: `admin-web/components/blog/blog-mdx-components.tsx`
- Modify: `admin-web/app/globals.css` (add scoped `.blog-preview` tokens/fonts)
- Modify: `admin-web/app/(dashboard)/blogs/new/page.tsx`
- Modify: `admin-web/app/(dashboard)/blogs/[id]/page.tsx`

**Interfaces:**
- Consumes: `content` markdown string + `title`/`tags`/`status` from the editor pages.
- Produces: `<BlogPreview content title tags status />`.

- [ ] **Step 1: Port the component map**

Create `admin-web/components/blog/blog-mdx-components.tsx` exporting a `react-markdown` `components` object using the EXACT Tailwind class strings from `marketing/components/blog/MDXComponents.tsx` (h1-h4, p, ul, ol, li, blockquote, strong, em, hr, code, pre). For the anchor, use a plain `<a>` with marketing's inline-link classes (no app-download CTA logic — preview only):
```tsx
import type { Components } from 'react-markdown';

export const blogPreviewComponents: Components = {
  h1: ({node, ...p}) => <h1 className="scroll-mt-24 font-display font-extrabold text-3xl mt-12 mb-5 text-gray-900 dark:text-white leading-tight" {...p} />,
  h2: ({node, ...p}) => <h2 className="scroll-mt-24 font-display font-bold text-2xl mt-12 mb-4 leading-snug text-primary dark:text-indigo-300 border-l-[3px] border-primary dark:border-indigo-400 pl-4" {...p} />,
  h3: ({node, ...p}) => <h3 className="scroll-mt-24 font-display font-semibold text-xl mt-8 mb-3 leading-snug text-gray-800 dark:text-slate-100" {...p} />,
  h4: ({node, ...p}) => <h4 className="scroll-mt-24 font-display font-semibold text-lg mt-6 mb-2 text-gray-700 dark:text-slate-300" {...p} />,
  p:  ({node, ...p}) => <p className="text-gray-700 dark:text-slate-300 leading-[2.0] mb-5 text-[18px]" {...p} />,
  ul: ({node, ...p}) => <ul className="list-disc pl-6 space-y-2.5 mb-5 text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]" {...p} />,
  ol: ({node, ...p}) => <ol className="list-decimal pl-6 space-y-2.5 mb-5 text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]" {...p} />,
  li: ({node, ...p}) => <li className="leading-[1.9]" {...p} />,
  a:  ({node, ...p}) => <a className="text-primary dark:text-indigo-300 underline decoration-primary/30 underline-offset-2 hover:decoration-primary transition-all" {...p} />,
  blockquote: ({node, ...p}) => <blockquote className="relative border-l-4 border-amber-400 dark:border-amber-500 pl-5 pr-4 py-3 my-7 rounded-r-lg bg-amber-50/60 dark:bg-amber-500/8 italic text-gray-700 dark:text-slate-300 text-[18px] leading-[2.0]" {...p} />,
  strong: ({node, ...p}) => <strong className="font-semibold text-gray-900 dark:text-slate-100" {...p} />,
  em: ({node, ...p}) => <em className="italic text-gray-600 dark:text-slate-400" {...p} />,
  hr: () => <hr className="my-10 border-none h-px bg-gradient-to-r from-transparent via-gray-300 dark:via-slate-600 to-transparent" />,
  code: ({node, ...p}) => <code className="text-sm font-mono bg-primary/10 dark:bg-indigo-500/15 text-primary dark:text-indigo-300 px-1.5 py-0.5 rounded" {...p} />,
  pre: ({node, ...p}) => <pre className="overflow-x-auto rounded-xl bg-gray-100 dark:bg-slate-800/60 border border-gray-200 dark:border-slate-700 p-5 my-6 text-sm font-mono text-gray-800 dark:text-slate-200" {...p} />,
};
```

- [ ] **Step 2: Build BlogPreview**

Create `admin-web/components/blog/BlogPreview.tsx`:
```tsx
'use client';
import ReactMarkdown from 'react-markdown';
import { blogPreviewComponents } from './blog-mdx-components';

export function BlogPreview({
  content, title, tags, status,
}: { content: string; title: string; tags: string[]; status: string }) {
  return (
    <div className="blog-preview">
      <header className="mb-8">
        {tags.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-4">
            {tags.map((t) => (
              <span key={t} className="text-xs font-semibold text-primary dark:text-indigo-300 bg-primary/10 px-2.5 py-1 rounded-full">{t}</span>
            ))}
          </div>
        )}
        <h1 className="font-display font-extrabold text-3xl sm:text-4xl leading-tight text-gray-900 dark:text-white mb-3">
          {title || 'Untitled post'}
        </h1>
        <p className="text-sm text-gray-500">Preview · status: {status}</p>
      </header>
      <article className="min-w-0 max-w-[68ch]">
        <ReactMarkdown components={blogPreviewComponents}>{content}</ReactMarkdown>
      </article>
    </div>
  );
}
```

- [ ] **Step 3: Add the scoped token/font block**

In `admin-web/app/globals.css`, add a `.blog-preview` scope that pins marketing's tokens + fonts locally so the preview matches the live site regardless of admin-web's theme. Use marketing's values from its `globals.css`/`tailwind.config.ts`:
```css
.blog-preview {
  --primary: #4F46E5;
  --primary-hover: #4338CA;
  font-family: var(--font-inter, ui-sans-serif, system-ui, sans-serif);
}
.dark .blog-preview { --primary: #818CF8; --primary-hover: #A5B4FC; }
.blog-preview .font-display { font-family: var(--font-poppins, var(--font-inter), sans-serif); }
```
If admin-web does not already load Inter/Poppins, add them via `next/font` in the dashboard layout and expose `--font-inter`/`--font-poppins`, OR accept system fonts (spacing/weights still match; only the typeface differs). Confirm admin-web's Tailwind config maps `primary` → `var(--primary)`; if it uses a static `primary`, the `.blog-preview` var override still applies to the `text-primary`/`bg-primary` utilities only if they reference the CSS var — otherwise add a `.blog-preview` color override or a local `primary` mapping. Verify against admin-web `tailwind.config` before finalizing.

- [ ] **Step 4: Wire split layout into the create page**

In `blogs/new/page.tsx`, wrap the content editor + preview in a responsive two-column grid; keep the `<textarea>` as the left editor, `<BlogPreview>` on the right, fed by live `content`/`title`/`tags`/status state:
```tsx
<div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
  <textarea /* existing content textarea */ />
  <div className="border rounded-lg p-6 overflow-auto max-h-[70vh]">
    <BlogPreview content={content} title={title} tags={tagsInput.split(',').map(s=>s.trim()).filter(Boolean)} status={/* current intended status */ 'draft'} />
  </div>
</div>
```

- [ ] **Step 5: Wire into the edit page**

Same split treatment in `blogs/[id]/page.tsx` around its content textarea.

- [ ] **Step 6: Typecheck + visual verify**

Run: `cd admin-web && npx tsc --noEmit`
Expected: clean.
Visual: paste a real marketing article's markdown; compare the preview side-by-side with the live article — headings (Poppins, indigo h2 with left border), 18px body, amber blockquote, indigo inline code should match. Note any divergence for the reviewer.

- [ ] **Step 7: Commit**

```bash
git add admin-web/components/blog/BlogPreview.tsx admin-web/components/blog/blog-mdx-components.tsx admin-web/app/globals.css "admin-web/app/(dashboard)/blogs/new/page.tsx" "admin-web/app/(dashboard)/blogs/[id]/page.tsx"
git commit -m "feat(blog): add live faithful side-by-side preview to admin blog editor"
```

---

## Self-review notes
- Task 2 Step 8 intentionally leaves one compile gap (study-guide `CreatePostInput` literal) resolved in Task 4 Step 1 — if running tasks out of order or wanting a clean check per task, add `scheduled_for: None` to that literal in Task 2.
- Preview fidelity caveat (raw JSX/HTML, and ported-map drift) is documented in the spec; add `rehype-raw` to `BlogPreview` only if raw HTML in content must render.
- Verify `cron_config` has a UNIQUE(name) before relying on `ON CONFLICT (name)` (Task 1).
- Confirm admin-web Tailwind `primary` resolves from a CSS var before relying on the `.blog-preview` override (Task 6 Step 3).
