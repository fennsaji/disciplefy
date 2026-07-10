#!/usr/bin/env node
/**
 * Converts docs/marketing/Blog_SEO/articles/*.md (frontmatter + content)
 * into:
 *   - content/<slug>.md   — plain content only (no frontmatter, no H1, no TOC)
 *   - articles.json       — metadata entries pointing at content_file
 *
 * Safe to re-run: entries already marked "posted" (sent to the API by
 * publish-blogs.js) are left untouched — never rescheduled or reworded.
 * New/unposted entries get sequential daily 8:30 AM IST publish slots.
 *
 * Usage: node convert-md-to-json.js [source-dir] [out.json]
 */

const fs = require('fs')
const path = require('path')

const ARTICLES_DIR = path.resolve(
  __dirname,
  '../../docs/marketing/Blog_SEO/articles'
)
const OUT_PATH = path.resolve(__dirname, 'articles.json')
const CONTENT_DIR = path.resolve(__dirname, 'content')

const IST_OFFSET_MIN = 5 * 60 + 30 // IST = UTC+5:30
const PUBLISH_HOUR_IST = 8
const PUBLISH_MINUTE_IST = 30

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

/** Blog page renders the title itself; drop a leading H1 to avoid duplication. */
function stripLeadingH1(body) {
  return body.replace(/^\s*# .+\r?\n+/, '')
}

/**
 * The marketing site auto-generates an "On this page" TOC from headings,
 * so a "## Table of Contents" section in the source md is redundant.
 */
function stripTocSection(body) {
  return body.replace(/^## Table of Contents\s*\r?\n[\s\S]*?(?=^#{1,6} )/m, '')
}

/** Next 8:30 AM IST instant strictly after `now`, as a UTC Date. */
function nextIstPublishSlot(now) {
  // 8:30 IST == 03:00 UTC same calendar day.
  const istHourUtc = PUBLISH_HOUR_IST - Math.floor(IST_OFFSET_MIN / 60)
  const istMinuteUtc = PUBLISH_MINUTE_IST - (IST_OFFSET_MIN % 60)
  let slot = new Date(Date.UTC(
    now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(),
    istHourUtc, istMinuteUtc, 0, 0
  ))
  if (slot <= now) slot = new Date(slot.getTime() + 24 * 60 * 60 * 1000)
  return slot
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000)
}

function main() {
  const dir = process.argv[2] ? path.resolve(process.argv[2]) : ARTICLES_DIR
  const outPath = process.argv[3] ? path.resolve(process.argv[3]) : OUT_PATH

  const existing = fs.existsSync(outPath)
    ? JSON.parse(fs.readFileSync(outPath, 'utf8'))
    : []
  const existingBySlug = new Map(existing.map(e => [e.slug, e]))

  const files = fs
    .readdirSync(dir)
    .filter(f => f.endsWith('.md'))
    .sort()

  fs.mkdirSync(CONTENT_DIR, { recursive: true })

  // Days already spoken for by posted entries must not be double-booked.
  const reservedSlots = new Set(
    existing.filter(e => e.posted && e.scheduled_for).map(e => e.scheduled_for)
  )
  let cursor = nextIstPublishSlot(new Date())
  function takeNextFreeSlot() {
    while (reservedSlots.has(cursor.toISOString())) cursor = addDays(cursor, 1)
    const slot = cursor
    cursor = addDays(cursor, 1)
    return slot
  }

  let scheduledCount = 0
  const entries = []

  for (const file of files) {
    const raw = fs.readFileSync(path.join(dir, file), 'utf8')
    const { meta, body } = parseFrontmatter(raw)
    const content = stripTocSection(stripLeadingH1(body)).trim()

    if (!meta.title) throw new Error(`${file}: missing title in frontmatter`)
    if (!meta.slug) throw new Error(`${file}: missing slug in frontmatter`)
    if (!content) throw new Error(`${file}: empty content after strip`)

    const contentFileName = `${meta.slug}.md`
    fs.writeFileSync(path.join(CONTENT_DIR, contentFileName), content + '\n')

    const prior = existingBySlug.get(meta.slug)
    if (prior && prior.posted) {
      // Already sent to the API — never touch schedule/status/wording again here.
      entries.push(prior)
      continue
    }

    const scheduledFor = takeNextFreeSlot().toISOString()
    scheduledCount += 1

    entries.push({
      title: meta.title,
      slug: meta.slug,
      excerpt: meta.excerpt || '',
      locale: meta.locale || 'en',
      tags: meta.tags || [],
      featured: meta.featured ?? false,
      status: 'scheduled',
      scheduled_for: scheduledFor,
      source_type: 'manual',
      content_file: `content/${contentFileName}`,
    })
  }

  fs.writeFileSync(outPath, JSON.stringify(entries, null, 2) + '\n')
  console.log(`Wrote ${entries.length} articles → ${path.relative(process.cwd(), outPath)}`)
  console.log(`  (${scheduledCount} newly scheduled, ${entries.length - scheduledCount} already-posted entries preserved)`)
}

main()
