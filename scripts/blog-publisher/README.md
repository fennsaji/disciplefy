# Blog Publisher

Local-only scripts that turn `docs/marketing/Blog_SEO/articles/*.md` into blog posts on the API (`rs-backend`, `POST /api/v1/admin/posts`).

## Setup

```bash
cp .env.example .env   # then fill BLOG_ADMIN_TOKEN
```

- `BLOG_API_URL` — defaults to `https://api.disciplefy.in`. Use `http://localhost:8080` for local rs-backend.
- `BLOG_ADMIN_TOKEN` — the raw Supabase `access_token` JWT of an admin user (`user_profiles.is_admin = true`). **Not** the whole session/cookie blob — just the JWT (starts `eyJ...`, three dot-separated segments). Expires in ~1h; re-extract when publish fails with `Invalid or expired token`.

### Getting the token

Log into admin-web as an admin, open DevTools console on that tab, and run:

```js
(() => {
  const parts = document.cookie.split('; ')
    .filter(c => /^sb-.*-auth-token(\.\d+)?=/.test(c))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
  if (!parts.length) { console.log('no sb-*-auth-token cookie found — are you logged in on this tab?'); return; }
  let raw = parts.map(p => decodeURIComponent(p.slice(p.indexOf('=') + 1))).join('');
  if (raw.startsWith('base64-')) raw = raw.slice(7);
  const session = JSON.parse(atob(raw));
  console.log(session.access_token);
})();
```

(admin-web uses `@supabase/ssr`, which stores the session as a — possibly chunked — `sb-*-auth-token` cookie, base64-encoded JSON. The script reassembles chunks, strips the `base64-` prefix, decodes, and prints just `access_token`.)

If no cookie is found, the session may be in `localStorage` instead:

```js
Object.keys(localStorage).filter(k => k.includes('auth-token')).forEach(k => console.log(k, '=>', JSON.parse(localStorage.getItem(k))?.access_token))
```

Copy the printed JWT into `.env` as `BLOG_ADMIN_TOKEN=<jwt>`.

## 1. Convert markdown → content files + metadata

```bash
node convert-md-to-json.js
```

For every `docs/marketing/Blog_SEO/articles/*.md` (frontmatter: `title`, `slug`, `excerpt`, `tags`, `locale`, `featured`, `status`), this writes:

- `content/<slug>.md` — plain content only (frontmatter, leading `# H1`, and the `## Table of Contents` section stripped — the blog page renders the title from the DB and auto-builds its own "On this page" nav from headings). Gitignored — fully derived, regenerate any time with `convert-md-to-json.js`.
- `articles.json` — one metadata entry per article, e.g.:

```json
{
  "title": "How to Study the Bible: A Complete Beginner's Guide (2026)",
  "slug": "how-to-study-the-bible",
  "excerpt": "...",
  "locale": "en",
  "tags": ["bible study for beginners", "..."],
  "featured": false,
  "status": "scheduled",
  "scheduled_for": "2026-07-11T03:00:00.000Z",
  "source_type": "manual",
  "content_file": "content/how-to-study-the-bible.md"
}
```

New/unposted articles are auto-scheduled **one per day at 8:30 AM IST** (03:00 UTC), starting from the next 8:30 IST slot after the script runs. Safe to re-run any time a new `.md` is added — already-`posted` entries (see below) are left completely untouched, and new schedule slots skip any day already claimed by a posted entry.

## 2. Publish

```bash
node publish-blogs.js --dry-run        # validate without calling the API
node publish-blogs.js                  # publish articles.json
node publish-blogs.js --force          # resend entries already marked posted
node publish-blogs.js my-batch.json    # custom JSON list
```

Requires Node ≥ 18 (built-in fetch). No dependencies.

**Idempotent:** after a successful POST, the entry is stamped `posted: true` (+ `remote_id`, `remote_status`, `posted_at`) and `articles.json` is rewritten. Re-running the script skips already-posted entries — a scheduled article is never scheduled twice. Use `--force` to intentionally resend one.

## Editing an article

Edit the source `.md` in `docs/marketing/Blog_SEO/articles/`, then re-run `convert-md-to-json.js` to refresh its `content/<slug>.md`. If the article was already posted, this only refreshes the local content file — it does **not** re-send anything (use the admin panel's edit/update flow for already-published posts).

You can also hand-edit `content/<slug>.md` or `articles.json` directly (e.g. to tweak `scheduled_for` or `tags`) without touching the source `.md`.

## Notes

- Slugs are unique per API; a genuinely new slug that collides with an existing remote post fails for that entry only — the rest continue. Exit code 1 if any entry failed.
- Legacy support: an entry with inline `"content"`, or a `"file"` field pointing at a full md-with-frontmatter, still works.
