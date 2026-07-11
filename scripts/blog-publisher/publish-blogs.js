#!/usr/bin/env node
/**
 * Publishes blog articles to the Disciplefy blog API (rs-backend).
 *
 * Usage:
 *   node publish-blogs.js [articles.json] [--dry-run] [--force]
 *
 * Env (.env in this directory or exported):
 *   BLOG_API_URL     API base URL (default https://api.disciplefy.in)
 *   BLOG_ADMIN_TOKEN Supabase admin JWT (required unless --dry-run)
 *
 * JSON entry shape — content lives in a separate plain-content .md file
 * (see convert-md-to-json.js to regenerate from
 * docs/marketing/Blog_SEO/articles/*.md):
 *   {
 *     "title": "...", "slug": "...", "excerpt": "...",
 *     "locale": "en", "tags": [...], "featured": false,
 *     "status": "scheduled",                     // draft | published | scheduled
 *     "scheduled_for": "2026-07-15T03:00:00Z",    // required when scheduled
 *     "content_file": "content/how-to-study-the-bible.md"
 *   }
 *
 * Idempotency: after a successful POST, the entry is stamped with
 * `posted: true` (+ remote_id/remote_status/posted_at) and articles.json
 * is rewritten. Re-running the script skips already-posted entries, so a
 * scheduled article is never scheduled twice. Pass --force to resend anyway.
 *
 * Legacy: an entry may instead carry inline "content", or a "file" pointing
 * at a full md with frontmatter (content/meta parsed from it).
 */

const fs = require('fs')
const path = require('path')

// ── Env ────────────────────────────────────────────────────

function loadDotEnv(dir) {
  const envPath = path.join(dir, '.env')
  if (!fs.existsSync(envPath)) return
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const eq = trimmed.indexOf('=')
    if (eq === -1) continue
    const key = trimmed.slice(0, eq).trim()
    let value = trimmed.slice(eq + 1).trim()
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }
    if (!(key in process.env)) process.env[key] = value
  }
}

// ── Frontmatter (legacy "file" entries only) ────────────────

function parseFrontmatter(raw) {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/)
  if (!match) return { meta: {}, body: raw }

  const meta = {}
  for (const line of match[1].split('\n')) {
    const m = line.match(/^(\w[\w-]*):\s*(.*)$/)
    if (!m) continue
    const key = m[1]
    let value = m[2].trim()
    if (value.startsWith('[') && value.endsWith(']')) {
      meta[key] = value
        .slice(1, -1)
        .split(',')
        .map(s => s.trim().replace(/^["']|["']$/g, ''))
        .filter(Boolean)
    } else if (value === 'true' || value === 'false') {
      meta[key] = value === 'true'
    } else {
      meta[key] = value.replace(/^["']|["']$/g, '')
    }
  }
  return { meta, body: raw.slice(match[0].length) }
}

function stripLeadingH1(body) {
  return body.replace(/^\s*# .+\r?\n+/, '')
}

function stripTocSection(body) {
  return body.replace(/^## Table of Contents\s*\r?\n[\s\S]*?(?=^#{1,6} )/m, '')
}

// ── Main ───────────────────────────────────────────────────

async function main() {
  const scriptDir = __dirname
  loadDotEnv(scriptDir)

  const args = process.argv.slice(2)
  const dryRun = args.includes('--dry-run')
  const force = args.includes('--force')
  const jsonArg = args.find(a => !a.startsWith('--')) || 'articles.json'
  const jsonPath = path.resolve(scriptDir, jsonArg)

  const apiUrl = (process.env.BLOG_API_URL || 'https://api.disciplefy.in').replace(/\/$/, '')
  const token = process.env.BLOG_ADMIN_TOKEN

  if (!dryRun && !token) {
    console.error('Error: BLOG_ADMIN_TOKEN is not set. Add it to .env or export it.')
    process.exit(1)
  }

  const entries = JSON.parse(fs.readFileSync(jsonPath, 'utf8'))
  if (!Array.isArray(entries)) {
    console.error('Error: JSON root must be an array of article entries.')
    process.exit(1)
  }

  const jsonDir = path.dirname(jsonPath)
  const results = { created: [], failed: [], skipped: [] }
  let stateChanged = false

  for (const entry of entries) {
    const label = entry.slug || entry.title || entry.file || entry.content_file || 'entry'

    if (entry.skip) {
      console.log(`⏭  ${label} — skipped (skip: true)`)
      results.skipped.push(label)
      continue
    }

    if (entry.posted && !force) {
      console.log(`⏭  ${label} — already posted (id=${entry.remote_id}, status=${entry.remote_status}) on ${entry.posted_at}`)
      results.skipped.push(label)
      continue
    }

    try {
      let meta = {}
      let body

      if (entry.content_file) {
        body = fs.readFileSync(path.resolve(jsonDir, entry.content_file), 'utf8').trim()
      } else if (entry.content) {
        body = entry.content
      } else if (entry.file) {
        // Legacy: full md with frontmatter.
        const raw = fs.readFileSync(path.resolve(jsonDir, entry.file), 'utf8')
        const parsed = parseFrontmatter(raw)
        meta = parsed.meta
        body = stripTocSection(stripLeadingH1(parsed.body)).trim()
      } else {
        throw new Error('entry has no "content_file", "content", or "file"')
      }

      const payload = {
        title: entry.title ?? meta.title,
        content: body,
        excerpt: entry.excerpt ?? meta.excerpt ?? '',
        locale: entry.locale ?? meta.locale ?? 'en',
        tags: entry.tags ?? meta.tags ?? [],
        featured: entry.featured ?? meta.featured ?? false,
        status: entry.status ?? meta.status ?? 'draft',
        slug: entry.slug ?? meta.slug ?? null,
        source_type: entry.source_type ?? 'manual',
        scheduled_for: entry.scheduled_for ?? null,
      }

      if (!payload.title) throw new Error('no title in frontmatter or JSON')
      if (!payload.content) throw new Error('article body is empty')
      if (payload.status === 'scheduled' && !payload.scheduled_for) {
        throw new Error('status "scheduled" requires "scheduled_for"')
      }

      if (dryRun) {
        console.log(`✓ [dry-run] ${label}`)
        console.log(`    slug=${payload.slug} locale=${payload.locale} status=${payload.status}` +
          (payload.scheduled_for ? ` scheduled_for=${payload.scheduled_for}` : '') +
          ` tags=${payload.tags.length} content=${payload.content.length} chars`)
        results.created.push(payload.slug || label)
        continue
      }

      const res = await fetch(`${apiUrl}/api/v1/admin/posts`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      })

      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        const msg = data?.error?.message || data?.message || `HTTP ${res.status}`
        throw new Error(msg)
      }

      const post = data.data ?? data
      console.log(`✓ ${label} → id=${post.id} slug=${post.slug} status=${post.status}`)
      results.created.push(post.slug)

      entry.posted = true
      entry.posted_at = new Date().toISOString()
      entry.remote_id = post.id
      entry.remote_status = post.status
      stateChanged = true
    } catch (err) {
      console.error(`✗ ${label} — ${err.message}`)
      results.failed.push({ label, error: err.message })
    }
  }

  if (stateChanged) {
    fs.writeFileSync(jsonPath, JSON.stringify(entries, null, 2) + '\n')
    console.log(`\nUpdated ${path.relative(process.cwd(), jsonPath)} with posted state.`)
  }

  console.log(`\nDone. created=${results.created.length} failed=${results.failed.length} skipped=${results.skipped.length}`)
  if (results.failed.length > 0) process.exit(1)
}

main().catch(err => {
  console.error('Fatal:', err.message)
  process.exit(1)
})
