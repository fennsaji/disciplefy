# Fellowship 1.0.5 — Plan 05: Admin Web Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give admins a Fellowships page: list every fellowship with its admin flags and mentor settings, create official fellowships with Discipler enabled, edit flags, manage mentors, and see Discipler activity and cost.

**Architecture:** One Next.js API route (`app/api/admin/fellowships/route.ts`) using the repo's `requireAdmin()` + service-role client pattern from `moderation/route.ts`, and one dashboard page (`app/(dashboard)/fellowships/page.tsx`) using React Query + `sonner` + the existing `PageHeader`/`TabNav` components and plain Tailwind tables. No test framework exists in admin-web; verification is `npm run lint`, `npm run type-check`, and a manual pass against local Supabase.

**Tech Stack:** Next.js 16 (App Router), React 19, @tanstack/react-query 5, @supabase/supabase-js 2, Tailwind 3.

**Spec:** `docs/superpowers/specs/2026-09-06-fellowship-discipler-redesign-design.md` §4 (Admin web). Index: `2026-09-06-fellowship-discipler-00-index.md`. Requires Plan 01 (and 02 for live data).

## Global Constraints

See index. Relevant here:
- Admin flags are written directly with the service-role client (admin-web bypasses Edge Functions), with the same validation as the Edge Function: `discipler_allowed`/`daily_post_allowed` require `is_official`.
- Creating a fellowship from admin-web requires an initial mentor (auth user id); the API inserts the `fellowship_members` mentor row and rolls back on failure, as `fellowship/index.ts` does.
- Local admin-web env: `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321`, `SUPABASE_SERVICE_ROLE_KEY=<local service role>`; sign in as `anna@test.local`.

---

### Task 1: API route

**Files:**
- Create: `admin-web/app/api/admin/fellowships/route.ts`

**Interfaces:**
- `GET /api/admin/fellowships?limit&offset&search` → `{ data: FellowshipRow[], total, limit, offset }` where
  `FellowshipRow = { id, name, language, is_public, is_official, discipler_allowed, daily_post_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_on, max_members, member_count, mentors: { user_id, email }[], replies_today, cost_today_usd, created_at }`.
- `POST /api/admin/fellowships` body `{ name, description?, language, is_public, unlimited_members, is_official, discipler_allowed, daily_post_allowed, mentor_email }` → `{ data: { id } }`.
- `PATCH /api/admin/fellowships` body `{ fellowship_id, is_official?, discipler_allowed?, daily_post_allowed?, is_public?, is_active? }` → `{ success: true }`.
- `PUT /api/admin/fellowships` body `{ fellowship_id, action: 'add_mentor' | 'remove_mentor', user_id }` → `{ success: true }`.

- [ ] **Step 1: Write the route**

```ts
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 200
const LANGUAGES = ['en', 'hi', 'ml']

async function requireAdmin() {
  const supabaseUser = await createClient()
  const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
  if (userError || !user) return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  const supabaseAdmin = createAdminClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!)
  const { data: profile } = await supabaseAdmin.from('user_profiles').select('is_admin').eq('id', user.id).single()
  if (!profile?.is_admin) return { error: NextResponse.json({ error: 'Unauthorized - Admin access required' }, { status: 403 }) }
  return { supabaseAdmin, userId: user.id }
}

export async function GET(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const p = request.nextUrl.searchParams
  const limit = Math.min(Math.max(parseInt(p.get('limit') || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT, 1), MAX_LIMIT)
  const offset = Math.max(parseInt(p.get('offset') || '0', 10) || 0, 0)
  const search = p.get('search')?.trim()

  let q = supabaseAdmin.from('fellowships')
    .select('id, name, language, is_public, is_active, is_official, discipler_allowed, daily_post_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_on, max_members, created_at', { count: 'exact' })
    .order('created_at', { ascending: false }).order('id', { ascending: true }).range(offset, offset + limit - 1)
  if (search) q = q.ilike('name', `%${search}%`)
  const { data: rows, count, error } = await q
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  const ids = (rows ?? []).map((r) => r.id)
  if (ids.length === 0) return NextResponse.json({ data: [], total: count ?? 0, limit, offset })

  const dayStart = new Date(); dayStart.setUTCHours(0, 0, 0, 0)
  const [members, mentors, replies] = await Promise.all([
    supabaseAdmin.from('fellowship_members').select('fellowship_id').in('fellowship_id', ids).eq('is_active', true),
    supabaseAdmin.from('fellowship_members').select('fellowship_id, user_id').in('fellowship_id', ids).eq('is_active', true).eq('role', 'mentor'),
    supabaseAdmin.from('discipler_replies').select('fellowship_id, cost_usd').in('fellowship_id', ids).gte('created_at', dayStart.toISOString()),
  ])
  const memberCount = new Map<string, number>()
  for (const m of members.data ?? []) memberCount.set(m.fellowship_id, (memberCount.get(m.fellowship_id) ?? 0) + 1)
  const mentorIds = [...new Set((mentors.data ?? []).map((m) => m.user_id))]
  let emails: Record<string, string> = {}
  try { emails = await getAuthEmailMap(supabaseAdmin, mentorIds) } catch (e) { console.error('Failed to fetch mentor emails:', e) }
  const mentorsBy = new Map<string, { user_id: string; email: string }[]>()
  for (const m of mentors.data ?? []) {
    const list = mentorsBy.get(m.fellowship_id) ?? []
    list.push({ user_id: m.user_id, email: emails[m.user_id] ?? m.user_id })
    mentorsBy.set(m.fellowship_id, list)
  }
  const repliesBy = new Map<string, { n: number; cost: number }>()
  for (const r of replies.data ?? []) {
    const cur = repliesBy.get(r.fellowship_id) ?? { n: 0, cost: 0 }
    cur.n += 1; cur.cost += Number(r.cost_usd ?? 0)
    repliesBy.set(r.fellowship_id, cur)
  }
  const data = (rows ?? []).map((r) => ({
    ...r,
    member_count: memberCount.get(r.id) ?? 0,
    mentors: mentorsBy.get(r.id) ?? [],
    replies_today: repliesBy.get(r.id)?.n ?? 0,
    cost_today_usd: Number((repliesBy.get(r.id)?.cost ?? 0).toFixed(4)),
  }))
  return NextResponse.json({ data, total: count ?? 0, limit, offset })
}

export async function POST(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const body = await request.json().catch(() => null)
  if (!body) return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
  const name = String(body.name ?? '').trim()
  if (name.length < 3 || name.length > 60) return NextResponse.json({ error: 'name must be 3–60 characters' }, { status: 400 })
  if (!LANGUAGES.includes(body.language)) return NextResponse.json({ error: 'language must be en, hi or ml' }, { status: 400 })
  const isOfficial = body.is_official === true
  const disciplerAllowed = body.discipler_allowed === true
  const dailyAllowed = body.daily_post_allowed === true
  if ((disciplerAllowed || dailyAllowed) && !isOfficial) return NextResponse.json({ error: 'Discipler and daily post require an official fellowship' }, { status: 400 })
  const mentorEmail = String(body.mentor_email ?? '').trim().toLowerCase()
  if (!mentorEmail) return NextResponse.json({ error: 'mentor_email is required' }, { status: 400 })

  const { data: users } = await supabaseAdmin.auth.admin.listUsers({ page: 1, perPage: 1000 })
  const mentor = users?.users.find((u) => u.email?.toLowerCase() === mentorEmail)
  if (!mentor) return NextResponse.json({ error: 'No user with that email' }, { status: 404 })

  const { data: f, error } = await supabaseAdmin.from('fellowships').insert({
    name, description: body.description?.trim() || null, mentor_user_id: mentor.id,
    max_members: body.unlimited_members ? null : 12, is_public: body.is_public === true, language: body.language,
    posting_permission: 'all_members', is_official: isOfficial, discipler_allowed: disciplerAllowed, daily_post_allowed: dailyAllowed,
  }).select('id').single()
  if (error || !f) return NextResponse.json({ error: error?.message ?? 'Insert failed' }, { status: 500 })
  const { error: mErr } = await supabaseAdmin.from('fellowship_members').insert({ fellowship_id: f.id, user_id: mentor.id, role: 'mentor' })
  if (mErr) {
    await supabaseAdmin.from('fellowships').delete().eq('id', f.id)
    return NextResponse.json({ error: 'Failed to add mentor' }, { status: 500 })
  }
  return NextResponse.json({ data: { id: f.id } }, { status: 201 })
}

export async function PATCH(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const body = await request.json().catch(() => null)
  if (!body?.fellowship_id) return NextResponse.json({ error: 'fellowship_id is required' }, { status: 400 })
  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() }
  for (const k of ['is_official', 'discipler_allowed', 'daily_post_allowed', 'is_public', 'is_active'] as const) {
    if (typeof body[k] === 'boolean') updates[k] = body[k]
  }
  const { data: current } = await supabaseAdmin.from('fellowships').select('is_official, discipler_allowed, daily_post_allowed').eq('id', body.fellowship_id).single()
  if (!current) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  const next = { ...current, ...updates }
  if ((next.discipler_allowed || next.daily_post_allowed) && !next.is_official) {
    return NextResponse.json({ error: 'Discipler and daily post require an official fellowship' }, { status: 400 })
  }
  const { error } = await supabaseAdmin.from('fellowships').update(updates).eq('id', body.fellowship_id)
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ success: true })
}

export async function PUT(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const body = await request.json().catch(() => null)
  if (!body?.fellowship_id || !body?.user_id || !['add_mentor', 'remove_mentor'].includes(body.action)) {
    return NextResponse.json({ error: 'fellowship_id, user_id and action are required' }, { status: 400 })
  }
  const { data: f } = await supabaseAdmin.from('fellowships').select('mentor_user_id').eq('id', body.fellowship_id).single()
  if (!f) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  if (body.action === 'remove_mentor' && f.mentor_user_id === body.user_id) return NextResponse.json({ error: 'The owner cannot be demoted' }, { status: 400 })
  const role = body.action === 'add_mentor' ? 'mentor' : 'member'
  const { error } = await supabaseAdmin.from('fellowship_members')
    .upsert({ fellowship_id: body.fellowship_id, user_id: body.user_id, role, is_active: true }, { onConflict: 'fellowship_id,user_id' })
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ success: true })
}
```

- [ ] **Step 2: Verify** — `npm run type-check && npm run lint`. With the dev server on port 4000 and a signed-in admin browser session: `GET /api/admin/fellowships` returns the three seeded fellowships with `mentors` emails; `PATCH { fellowship_id, discipler_allowed: true }` on a non-official one → 400; after `is_official: true` → 200.

- [ ] **Step 3: Commit**

```bash
git add admin-web/app/api/admin/fellowships/route.ts
git commit -m "feat(admin-web): fellowships API with Discipler flags, mentors and daily stats"
```

---

### Task 2: Fellowships page and sidebar entry

**Files:**
- Create: `admin-web/app/(dashboard)/fellowships/page.tsx`
- Create: `admin-web/components/dialogs/create-fellowship-dialog.tsx`
- Modify: `admin-web/components/sidebar.tsx` (add `{ name: 'Fellowships', href: '/fellowships', emoji: '🤝' }` to the Core group after Moderation-adjacent items)

**Interfaces:**
- Page reads `GET /api/admin/fellowships`, mutates with PATCH/PUT, opens `CreateFellowshipDialog({ isOpen, onClose, onCreated })`.

- [ ] **Step 1: Page**

Structure mirrors `moderation/page.tsx`: `PageHeader` title "Fellowships", a search input (debounced 300 ms into the query key), a `Create fellowship` button, and a table with columns: Name (+ `OFFICIAL` amber pill), Language, Members (`Unlimited` when `max_members` is null), Mentors (emails, comma-joined, with an `×` per mentor calling PUT `remove_mentor` after `window.confirm`), Official (checkbox → PATCH), Discipler (checkbox, disabled unless official → PATCH), Daily post (checkbox, disabled unless official → PATCH), Mentor settings (`reply_mode / scope / delay min / react on-off / daily on-off` as small grey text), Today (`replies_today · $cost_today_usd`), Public (checkbox → PATCH). Pagination component copied from the moderation page (`PAGE_SIZE = 50`). Mutations: `useMutation` with `fetch('/api/admin/fellowships', { method, headers: {'Content-Type':'application/json'}, credentials: 'include', body })`, `onSuccess: () => { toast.success('Saved'); queryClient.invalidateQueries({ queryKey: ['admin', 'fellowships'] }) }`, `onError: (e) => toast.error(e.message)`.
An "Add mentor" inline form per row: text input for a user id or email; if it contains `@`, resolve through `GET /api/admin/users?search=` if that route exists, otherwise require the user id (the existing Admin Management page lists users with ids). Keep it simple: accept a user id.

- [ ] **Step 2: Create dialog** — copy the overlay markup pattern from `edit-system-config-dialog.tsx` (`if (!isOpen) return null`, fixed inset overlay, `max-w-md` card). Fields: name, description (textarea), language (`select` en/hi/ml), Public (checkbox), Unlimited members (checkbox), Official (checkbox), Allow Discipler replies (checkbox, disabled until Official), Allow daily study post (checkbox, disabled until Official), Mentor email (input, required). Submit POSTs and calls `onCreated()`.

- [ ] **Step 3: Verify** — `npm run type-check && npm run lint`; open `/fellowships`, create "Disciplefy हिन्दी" official with Discipler on and `meera@test.local` as mentor; the row appears with Official/Discipler checked; toggling Discipler off and on works; Today shows the replies produced during Plan 02/03 testing.

- [ ] **Step 4: Commit**

```bash
git add "admin-web/app/(dashboard)/fellowships/page.tsx" admin-web/components/dialogs/create-fellowship-dialog.tsx admin-web/components/sidebar.tsx
git commit -m "feat(admin-web): Fellowships page with Discipler flags, mentors and creation dialog"
```

---

### Task 3: Discipler activity panel

**Files:**
- Modify: `admin-web/app/api/admin/fellowships/route.ts` (add `GET ?view=activity`)
- Modify: `admin-web/app/(dashboard)/fellowships/page.tsx` (second `TabNav` tab "Discipler activity")

**Interfaces:**
- `GET /api/admin/fellowships?view=activity&limit&offset&kind` → `{ data: ActivityRow[], total }` where `ActivityRow = { id, fellowship_id, fellowship_name, kind, reaction, language, summary, reviewed_at, created_at, comment_content, comment_pending, comment_deleted, post_content }`.
- `DELETE /api/admin/fellowships` body `{ comment_id }` → soft-deletes a Discipler comment and stamps `discipler_activity.reviewed_*`.

- [ ] **Step 1: Extend the route**

In `GET`, when `view === 'activity'`:
```ts
  let aq = supabaseAdmin.from('discipler_activity')
    .select('id, fellowship_id, kind, reaction, language, summary, reviewed_at, created_at, fellowships(name), fellowship_posts(content), fellowship_comments(content, is_pending_review, is_deleted)', { count: 'exact' })
    .order('created_at', { ascending: false }).range(offset, offset + limit - 1)
  const kind = p.get('kind')
  if (kind && ['reply', 'react', 'draft', 'daily_post'].includes(kind)) aq = aq.eq('kind', kind)
  const { data, count, error } = await aq
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({
    data: (data ?? []).map((r: any) => ({
      id: r.id, fellowship_id: r.fellowship_id, fellowship_name: r.fellowships?.name ?? '', kind: r.kind, reaction: r.reaction,
      language: r.language, summary: r.summary, reviewed_at: r.reviewed_at, created_at: r.created_at,
      comment_content: r.fellowship_comments?.content ?? null, comment_pending: r.fellowship_comments?.is_pending_review ?? false,
      comment_deleted: r.fellowship_comments?.is_deleted ?? false, post_content: r.fellowship_posts?.content ?? null,
    })), total: count ?? 0, limit, offset,
  })
```
Add `export async function DELETE(request)`: `requireAdmin`, body `{ comment_id }`, `update fellowship_comments set is_deleted=true where id`, then `update discipler_activity set reviewed_by=userId, reviewed_at=now() where comment_id`.

- [ ] **Step 2: Page tab** — `TABS = [{ value: 'fellowships', label: 'Fellowships', icon: '🤝' }, { value: 'activity', label: 'Discipler activity', icon: '✨' }]`; the activity tab has a kind filter `select` (All/Drafts/Replies/Reactions/Daily) and a table: When, Fellowship, Kind (badge), Language, Summary, Reply (comment content, greyed when deleted, amber "pending" pill), Actions (`Delete` when a live comment exists → DELETE with `window.confirm`).

- [ ] **Step 3: Verify** — type-check, lint; the tab lists rows produced during Plans 02/03 testing; Delete soft-deletes and the row shows greyed.

- [ ] **Step 4: Commit**

```bash
git add admin-web/app/api/admin/fellowships/route.ts "admin-web/app/(dashboard)/fellowships/page.tsx"
git commit -m "feat(admin-web): Discipler activity panel with delete"
```

---

## Self-Review Notes

- Spec §4 "Admin web" bullets: table (T2), create dialog (T2), row actions flags/mentors/deactivate (T1 PATCH `is_active`, PUT mentors), Discipler panel replies/cost per day (T1 GET aggregates) and recent activity with failures (T3 shows activity; queue failures are visible in the rs-backend logs and the `discipler_reply_queue` table — an explicit "failures" column can be added later without schema changes).
- Admin-web writes bypass the Edge Function validation, so the same official→Discipler rule is re-implemented in PATCH/POST.
- No tests: verification is type-check + lint + manual, matching the existing admin-web convention.
