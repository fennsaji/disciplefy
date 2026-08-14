# Admin-Managed Affiliate Keywords Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-link admin-curated keywords in blog posts to Amazon.in affiliate search URLs, with the keyword list managed from the admin-web dashboard.

**Architecture:** New `affiliate_keywords` Supabase table (RLS: public reads active rows) + four `admin-*` Edge Functions mirroring the promo-code ones + one admin-web CRUD page. The marketing site fetches active keywords via the Supabase REST endpoint with 60s ISR caching and runs a pure `linkifyAffiliate()` markdown pass in `BlogPostContent` before the existing `insertAd` pass.

**Tech Stack:** Supabase (Postgres + Deno Edge Functions), Next.js 16 + React Query (admin-web), Next.js 14 + vitest (marketing).

**Spec:** `docs/superpowers/specs/2026-08-14-affiliate-keywords-design.md`

## Global Constraints

- **NEVER run `git commit` or `git push`** — leave all changes uncommitted; the user commits manually after review. (Standing repo rule; overrides the usual commit steps.)
- **NEVER touch production**: no `supabase db push`, no `--project-ref`, local migrations only.
- Affiliate tag: `disciplefy-21`. Marketplace: `amazon.in`. Link shape: `https://www.amazon.in/s?k=<url-encoded keyword>&tag=disciplefy-21`.
- Max **3** affiliate links per post; **first occurrence only** per keyword; longest keyword matched first.
- Never linkify inside existing links, headings, code fences, inline code, or blockquotes.
- Affiliate anchors carry `rel="sponsored nofollow noopener noreferrer"` and `target="_blank"`.
- Disclosure line renders only when a post actually contains ≥1 affiliate link.
- Keyword constraints: trimmed, non-empty, ≤80 chars, case-insensitively unique.
- On any keyword-fetch error the marketing site renders the post with zero links — never breaks the page.

---

### Task 1: Database migration

**Files:**
- Create: `backend/supabase/migrations/20260814090000_affiliate_keywords.sql`

**Interfaces:**
- Produces: `public.affiliate_keywords` table (`id uuid`, `keyword text`, `is_active boolean`, `created_at`, `updated_at`) — consumed by Tasks 2 and 6.

- [ ] **Step 1: Write the migration**

```sql
-- Affiliate keywords: admin-curated terms auto-linked to Amazon affiliate
-- search URLs in marketing blog posts. Admin mutations go through the
-- admin-* Edge Functions (service role, bypasses RLS); the marketing site
-- reads active rows anonymously.
CREATE TABLE public.affiliate_keywords (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  keyword     text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX affiliate_keywords_keyword_unique
  ON public.affiliate_keywords (lower(keyword));

ALTER TABLE public.affiliate_keywords ENABLE ROW LEVEL SECURITY;

CREATE POLICY "affiliate_keywords_anon_read_active"
  ON public.affiliate_keywords FOR SELECT TO anon
  USING (is_active = true);

CREATE POLICY "affiliate_keywords_auth_read_active"
  ON public.affiliate_keywords FOR SELECT TO authenticated
  USING (is_active = true);

-- Seed starter list
INSERT INTO public.affiliate_keywords (keyword) VALUES
  ('ESV Study Bible'),
  ('NIV Study Bible'),
  ('study Bible'),
  ('Bible commentary'),
  ('Strong''s Concordance'),
  ('prayer journal'),
  ('Christian devotional');
```

- [ ] **Step 2: Apply locally and verify**

Run: `cd backend && supabase migration up`
(If the local stack isn't running: `supabase start` first. Never use `db push` or `--project-ref`.)

Then verify:
```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c "SELECT keyword, is_active FROM public.affiliate_keywords ORDER BY keyword;"
```
Expected: 7 seeded rows, all `is_active = t`.

- [ ] **Step 3: Verify RLS blocks anon from inactive rows**

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" <<'SQL'
UPDATE public.affiliate_keywords SET is_active = false WHERE keyword = 'prayer journal';
SET ROLE anon;
SELECT count(*) FROM public.affiliate_keywords;   -- expect 6
RESET ROLE;
UPDATE public.affiliate_keywords SET is_active = true WHERE keyword = 'prayer journal';
SQL
```
Expected: count = 6 while the row is inactive.

Do NOT commit — leave for user review.

---

### Task 2: Admin Edge Functions (list / create / toggle / delete)

**Files:**
- Create: `backend/supabase/functions/admin-list-affiliate-keywords/index.ts`
- Create: `backend/supabase/functions/admin-create-affiliate-keyword/index.ts`
- Create: `backend/supabase/functions/admin-toggle-affiliate-keyword/index.ts`
- Create: `backend/supabase/functions/admin-delete-affiliate-keyword/index.ts`

**Interfaces:**
- Consumes: `public.affiliate_keywords` (Task 1).
- Produces: four HTTP endpoints, all requiring `Authorization: Bearer <service-role-key>` + `x-admin-user-id` headers. Response shapes consumed by Task 3:
  - list → `{ success: true, keywords: AffiliateKeyword[] }`
  - create → `{ success: true, keyword: AffiliateKeyword }` (409 `{ error }` on duplicate)
  - toggle → `{ success: true, keyword: AffiliateKeyword }`
  - delete → `{ success: true }`
  - where `AffiliateKeyword = { id: string, keyword: string, is_active: boolean, created_at: string, updated_at: string }`

All four share the promo-code auth preamble. Do not use the function-factory — the existing `admin-*-promo-code` functions use bare `Deno.serve`, mirror them exactly.

- [ ] **Step 1: Write the shared preamble as part of each file**

Every file starts with this exact block (identical in all four):

```ts
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

// Returns the admin client, or a Response if auth failed.
async function requireAdmin(req: Request): Promise<
  { adminSupabase: ReturnType<typeof createClient>; adminUserId: string } | Response
> {
  const authHeader = req.headers.get('Authorization')
  const adminUserId = req.headers.get('x-admin-user-id')
  if (!authHeader || !adminUserId) return json({ error: 'Unauthorized - Missing credentials' }, 401)

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (authHeader.replace('Bearer ', '') !== serviceRoleKey)
    return json({ error: 'Unauthorized - Invalid credentials' }, 401)

  const adminSupabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceRoleKey)
  const { data: profile, error } = await adminSupabase
    .from('user_profiles')
    .select('is_admin')
    .eq('id', adminUserId)
    .single()
  if (error || !profile?.is_admin) return json({ error: 'Forbidden - Admin access required' }, 403)

  return { adminSupabase, adminUserId }
}
```

- [ ] **Step 2: `admin-list-affiliate-keywords/index.ts`** (after the preamble)

```ts
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const { data, error } = await auth.adminSupabase
      .from('affiliate_keywords')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) return json({ error: 'Failed to list affiliate keywords', details: error.message }, 500)

    return json({ success: true, keywords: data })
  } catch (error) {
    console.error('Error in admin-list-affiliate-keywords:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
```

- [ ] **Step 3: `admin-create-affiliate-keyword/index.ts`** (after the preamble)

```ts
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const body: { keyword?: string } = await req.json()
    const keyword = (body.keyword ?? '').trim()
    if (!keyword) return json({ error: 'Missing keyword' }, 400)
    if (keyword.length > 80) return json({ error: 'Keyword too long (max 80 characters)' }, 400)

    const { data, error } = await auth.adminSupabase
      .from('affiliate_keywords')
      .insert({ keyword })
      .select()
      .single()
    if (error) {
      // 23505 = unique_violation (case-insensitive unique index on lower(keyword))
      if (error.code === '23505') return json({ error: 'Keyword already exists' }, 409)
      return json({ error: 'Failed to create affiliate keyword', details: error.message }, 500)
    }

    try {
      await auth.adminSupabase.from('admin_audit_log').insert({
        admin_user_id: auth.adminUserId,
        action: 'create_affiliate_keyword',
        details: { keyword },
      })
    } catch (auditError) {
      console.warn('Failed to log admin action:', auditError)
    }

    return json({ success: true, keyword: data })
  } catch (error) {
    console.error('Error in admin-create-affiliate-keyword:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
```

- [ ] **Step 4: `admin-toggle-affiliate-keyword/index.ts`** (after the preamble)

```ts
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const body: { id?: string; is_active?: boolean } = await req.json()
    if (!body.id || typeof body.is_active !== 'boolean')
      return json({ error: 'Missing id or is_active' }, 400)

    const { data, error } = await auth.adminSupabase
      .from('affiliate_keywords')
      .update({ is_active: body.is_active, updated_at: new Date().toISOString() })
      .eq('id', body.id)
      .select()
      .single()
    if (error) return json({ error: 'Failed to toggle affiliate keyword', details: error.message }, 500)

    try {
      await auth.adminSupabase.from('admin_audit_log').insert({
        admin_user_id: auth.adminUserId,
        action: 'toggle_affiliate_keyword',
        details: { id: body.id, keyword: data.keyword, is_active: body.is_active },
      })
    } catch (auditError) {
      console.warn('Failed to log admin action:', auditError)
    }

    return json({ success: true, keyword: data })
  } catch (error) {
    console.error('Error in admin-toggle-affiliate-keyword:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
```

- [ ] **Step 5: `admin-delete-affiliate-keyword/index.ts`** (after the preamble)

```ts
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const body: { id?: string } = await req.json()
    if (!body.id) return json({ error: 'Missing id' }, 400)

    const { data, error } = await auth.adminSupabase
      .from('affiliate_keywords')
      .delete()
      .eq('id', body.id)
      .select()
      .single()
    if (error) return json({ error: 'Failed to delete affiliate keyword', details: error.message }, 500)

    try {
      await auth.adminSupabase.from('admin_audit_log').insert({
        admin_user_id: auth.adminUserId,
        action: 'delete_affiliate_keyword',
        details: { id: body.id, keyword: data.keyword },
      })
    } catch (auditError) {
      console.warn('Failed to log admin action:', auditError)
    }

    return json({ success: true })
  } catch (error) {
    console.error('Error in admin-delete-affiliate-keyword:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
```

- [ ] **Step 6: Typecheck all four**

Run: `cd backend && deno check supabase/functions/admin-list-affiliate-keywords/index.ts supabase/functions/admin-create-affiliate-keyword/index.ts supabase/functions/admin-toggle-affiliate-keyword/index.ts supabase/functions/admin-delete-affiliate-keyword/index.ts`
Expected: no errors.

Do NOT commit.

---

### Task 3: admin-web types, API wrappers, API routes

**Files:**
- Modify: `admin-web/types/admin.ts` (append)
- Modify: `admin-web/lib/api/admin.ts` (append)
- Create: `admin-web/app/api/admin/list-affiliate-keywords/route.ts`
- Create: `admin-web/app/api/admin/create-affiliate-keyword/route.ts`
- Create: `admin-web/app/api/admin/toggle-affiliate-keyword/route.ts`
- Create: `admin-web/app/api/admin/delete-affiliate-keyword/route.ts`

**Interfaces:**
- Consumes: Edge Function endpoints from Task 2 (paths `/functions/v1/admin-*-affiliate-keyword*`, response shapes as defined there).
- Produces (for Task 4): `listAffiliateKeywords(): Promise<ListAffiliateKeywordsResponse>`, `createAffiliateKeyword(params: { keyword: string })`, `toggleAffiliateKeyword(params: { id: string; is_active: boolean })`, `deleteAffiliateKeyword(params: { id: string })`, and type `AffiliateKeyword`.

- [ ] **Step 1: Append types to `admin-web/types/admin.ts`**

```ts
// ── Affiliate Keywords ────────────────────────────────────────────────
export interface AffiliateKeyword {
  id: string
  keyword: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface ListAffiliateKeywordsResponse {
  success: boolean
  keywords: AffiliateKeyword[]
}

export interface MutateAffiliateKeywordResponse {
  success: boolean
  keyword?: AffiliateKeyword
  error?: string
}
```

- [ ] **Step 2: Append fetch wrappers to `admin-web/lib/api/admin.ts`**

Match the file's existing wrapper style (check one existing function first and copy its error-handling shape verbatim if it differs from below):

```ts
export async function listAffiliateKeywords(): Promise<ListAffiliateKeywordsResponse> {
  const response = await fetch('/api/admin/list-affiliate-keywords', {
    credentials: 'include',
  })
  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err.error || 'Failed to load affiliate keywords')
  }
  return response.json()
}

export async function createAffiliateKeyword(params: { keyword: string }): Promise<MutateAffiliateKeywordResponse> {
  const response = await fetch('/api/admin/create-affiliate-keyword', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(params),
  })
  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err.error || 'Failed to create affiliate keyword')
  }
  return response.json()
}

export async function toggleAffiliateKeyword(params: { id: string; is_active: boolean }): Promise<MutateAffiliateKeywordResponse> {
  const response = await fetch('/api/admin/toggle-affiliate-keyword', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(params),
  })
  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err.error || 'Failed to toggle affiliate keyword')
  }
  return response.json()
}

export async function deleteAffiliateKeyword(params: { id: string }): Promise<MutateAffiliateKeywordResponse> {
  const response = await fetch('/api/admin/delete-affiliate-keyword', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(params),
  })
  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err.error || 'Failed to delete affiliate keyword')
  }
  return response.json()
}
```

Add the needed type imports to the file's existing `@/types/admin` import.

- [ ] **Step 3: Create the four API routes**

All four follow the exact promo-code route pattern. `list` uses GET; the rest POST. Template — `app/api/admin/list-affiliate-keywords/route.ts`:

```ts
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

export async function GET(_request: NextRequest) {
  try {
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const supabaseAdmin = await createAdminClient()
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()
    if (!profile?.is_admin) {
      return NextResponse.json({ error: 'Unauthorized - Admin access required' }, { status: 403 })
    }

    const functionUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-list-affiliate-keywords`
    const response = await fetch(functionUrl, {
      headers: {
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        'x-admin-user-id': user.id,
      },
    })
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ error: 'Unknown error' }))
      return NextResponse.json(
        { error: errorData.error || 'Failed to list affiliate keywords' },
        { status: response.status }
      )
    }
    return NextResponse.json(await response.json())
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
```

The three POST routes (`create-affiliate-keyword`, `toggle-affiliate-keyword`, `delete-affiliate-keyword`) are identical except: `export async function POST(request: NextRequest)`, they parse `const body = await request.json()` after the admin check, forward it with `method: 'POST'`, `'Content-Type': 'application/json'`, `body: JSON.stringify(body)`, and each points at its own `functionUrl` (`admin-create-affiliate-keyword` / `admin-toggle-affiliate-keyword` / `admin-delete-affiliate-keyword`). Write each file out fully — do not share code between route files (matches existing convention of self-contained routes).

- [ ] **Step 4: Typecheck**

Run: `cd admin-web && npm run type-check`
Expected: no errors.

Do NOT commit.

---

### Task 4: admin-web CRUD page + sidebar entry

**Files:**
- Create: `admin-web/app/(dashboard)/affiliate-keywords/page.tsx`
- Modify: `admin-web/components/sidebar.tsx:29-36` (Finance group)

**Interfaces:**
- Consumes: `listAffiliateKeywords`, `createAffiliateKeyword`, `toggleAffiliateKeyword`, `deleteAffiliateKeyword`, type `AffiliateKeyword` (Task 3).

- [ ] **Step 1: Create the page**

Single-file page (no separate table component — the entity is one string; a dedicated table component is overkill):

```tsx
'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { format } from 'date-fns'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { PageHeader } from '@/components/ui/page-header'
import {
  listAffiliateKeywords,
  createAffiliateKeyword,
  toggleAffiliateKeyword,
  deleteAffiliateKeyword,
} from '@/lib/api/admin'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'

export default function AffiliateKeywordsPage() {
  const [newKeyword, setNewKeyword] = useState('')
  const queryClient = useQueryClient()

  const { data, isLoading, error } = useQuery({
    queryKey: ['affiliate-keywords'],
    queryFn: listAffiliateKeywords,
  })

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['affiliate-keywords'] })

  const createMutation = useMutation({
    mutationFn: createAffiliateKeyword,
    onSuccess: () => {
      invalidate()
      setNewKeyword('')
      toast.success('Keyword added')
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Failed to add keyword'),
  })

  const toggleMutation = useMutation({
    mutationFn: toggleAffiliateKeyword,
    onSuccess: () => {
      invalidate()
      toast.success('Keyword updated')
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Failed to update keyword'),
  })

  const deleteMutation = useMutation({
    mutationFn: deleteAffiliateKeyword,
    onSuccess: () => {
      invalidate()
      toast.success('Keyword deleted')
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Failed to delete keyword'),
  })

  const submit = () => {
    const keyword = newKeyword.trim()
    if (!keyword) return
    createMutation.mutate({ keyword })
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Affiliate Keywords"
        description="Terms auto-linked to Amazon affiliate search results in marketing blog posts (max 3 links per post, first occurrence only)"
      />

      {error && (
        <ErrorState
          title="Error loading affiliate keywords"
          message={error instanceof Error ? error.message : 'Unknown error'}
        />
      )}
      {isLoading && <LoadingState label="Loading affiliate keywords..." />}

      {data && (
        <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
          {/* Inline add row */}
          <div className="mb-6 flex gap-2">
            <input
              type="text"
              value={newKeyword}
              onChange={(e) => setNewKeyword(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && submit()}
              placeholder="e.g. ESV Study Bible"
              maxLength={80}
              className="flex-1 rounded-lg border border-gray-300 px-4 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            />
            <button
              type="button"
              onClick={submit}
              disabled={createMutation.isPending || !newKeyword.trim()}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50"
            >
              Add Keyword
            </button>
          </div>

          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-gray-200 text-gray-500 dark:border-gray-700 dark:text-gray-400">
                <th className="pb-2 font-medium">Keyword</th>
                <th className="pb-2 font-medium">Active</th>
                <th className="pb-2 font-medium">Created</th>
                <th className="pb-2 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.keywords.map((kw) => (
                <tr key={kw.id} className="border-b border-gray-100 last:border-0 dark:border-gray-700">
                  <td className="py-3 font-medium text-gray-900 dark:text-gray-100">{kw.keyword}</td>
                  <td className="py-3">
                    <button
                      type="button"
                      role="switch"
                      aria-checked={kw.is_active}
                      onClick={() => toggleMutation.mutate({ id: kw.id, is_active: !kw.is_active })}
                      className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                        kw.is_active ? 'bg-primary' : 'bg-gray-300 dark:bg-gray-600'
                      }`}
                    >
                      <span
                        className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                          kw.is_active ? 'translate-x-6' : 'translate-x-1'
                        }`}
                      />
                    </button>
                  </td>
                  <td className="py-3 text-gray-500 dark:text-gray-400">
                    {format(new Date(kw.created_at), 'MMM dd, yyyy')}
                  </td>
                  <td className="py-3 text-right">
                    <button
                      type="button"
                      onClick={() => {
                        if (confirm(`Delete keyword "${kw.keyword}"?`)) {
                          deleteMutation.mutate({ id: kw.id })
                        }
                      }}
                      className="text-sm font-medium text-red-600 hover:text-red-700 dark:text-red-400"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
              {data.keywords.length === 0 && (
                <tr>
                  <td colSpan={4} className="py-6 text-center text-gray-500 dark:text-gray-400">
                    No keywords yet — add one above.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Add sidebar entry**

In `admin-web/components/sidebar.tsx`, Finance group, after the Promo Codes line:

```ts
      { name: 'Affiliate Keywords', href: '/affiliate-keywords', emoji: '🔗' },
```

- [ ] **Step 3: Typecheck + lint**

Run: `cd admin-web && npm run type-check && npm run lint`
Expected: no errors.

- [ ] **Step 4: Manual verification**

Run: `cd admin-web && npm run dev` (port 4000, needs local Supabase running with Task 1's migration and `supabase functions serve` for Task 2's functions). Log in as an admin, open Affiliate Keywords, add a keyword, toggle it, delete it. Confirm rows change and toasts appear.

Do NOT commit.

---

### Task 5: `linkifyAffiliate` markdown pass (TDD)

**Files:**
- Create: `marketing/lib/linkifyAffiliate.ts`
- Test: `marketing/lib/linkifyAffiliate.test.ts`

**Interfaces:**
- Produces (for Task 6):
  `export const AFFILIATE_TAG = "disciplefy-21"`,
  `export const MAX_AFFILIATE_LINKS_PER_POST = 3`,
  `export function linkifyAffiliate(content: string, keywords: string[]): { content: string; linkCount: number }`

- [ ] **Step 1: Write the failing tests**

```ts
// marketing/lib/linkifyAffiliate.test.ts
import { describe, it, expect } from "vitest";
import { linkifyAffiliate, AFFILIATE_TAG } from "./linkifyAffiliate";

const url = (kw: string) =>
  `https://www.amazon.in/s?k=${encodeURIComponent(kw)}&tag=${AFFILIATE_TAG}`;

describe("linkifyAffiliate", () => {
  it("no-ops with an empty keyword list", () => {
    const content = "Read your study Bible daily.";
    expect(linkifyAffiliate(content, [])).toEqual({ content, linkCount: 0 });
  });

  it("links the first occurrence only, preserving original casing", () => {
    const content = "A Study Bible helps.\n\nEvery study Bible differs.";
    const { content: out, linkCount } = linkifyAffiliate(content, ["study Bible"]);
    expect(linkCount).toBe(1);
    expect(out).toContain(`[Study Bible](${url("study Bible")})`);
    // second occurrence untouched
    expect(out).toContain("Every study Bible differs.");
  });

  it("matches case-insensitively on word boundaries only", () => {
    const { content: out, linkCount } = linkifyAffiliate(
      "The wordstudy Biblesuffix should not match.",
      ["study Bible"],
    );
    expect(linkCount).toBe(0);
    expect(out).toBe("The wordstudy Biblesuffix should not match.");
  });

  it("prefers the longest keyword when keywords overlap", () => {
    const { content: out } = linkifyAffiliate(
      "Get the ESV Study Bible today.",
      ["study Bible", "ESV Study Bible"],
    );
    expect(out).toContain(`[ESV Study Bible](${url("ESV Study Bible")})`);
    expect(out).not.toContain(`[study Bible]`);
  });

  it("caps at 3 links per post", () => {
    const content = "prayer journal one.\n\nBible commentary two.\n\nstudy Bible three.\n\nChristian devotional four.";
    const { linkCount } = linkifyAffiliate(content, [
      "prayer journal",
      "Bible commentary",
      "study Bible",
      "Christian devotional",
    ]);
    expect(linkCount).toBe(3);
  });

  it("skips headings, code fences, inline code, blockquotes and existing links", () => {
    const content = [
      "# The study Bible heading",
      "",
      "> A study Bible quote line.",
      "",
      "```",
      "study Bible in code fence",
      "```",
      "",
      "Inline `study Bible` code.",
      "",
      "[study Bible](https://example.com) already linked.",
      "",
      "Finally a real study Bible mention.",
    ].join("\n");
    const { content: out, linkCount } = linkifyAffiliate(content, ["study Bible"]);
    expect(linkCount).toBe(1);
    expect(out).toContain(`[study Bible](${url("study Bible")})`);
    expect(out).toContain("# The study Bible heading");
    expect(out).toContain("> A study Bible quote line.");
    expect(out).toContain("[study Bible](https://example.com) already linked.");
  });

  it("url-encodes keywords in the href", () => {
    const { content: out } = linkifyAffiliate("Buy Strong's Concordance now.", [
      "Strong's Concordance",
    ]);
    expect(out).toContain(
      `(https://www.amazon.in/s?k=${encodeURIComponent("Strong's Concordance")}&tag=${AFFILIATE_TAG})`,
    );
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd marketing && npx vitest run lib/linkifyAffiliate.test.ts`
Expected: FAIL — `Cannot find module './linkifyAffiliate'`.

- [ ] **Step 3: Implement**

```ts
// marketing/lib/linkifyAffiliate.ts
// Wraps the first occurrence of admin-curated keywords in Amazon.in
// affiliate search links. Pure — no I/O; keywords come from the caller
// (fetched from Supabase in lib/affiliateKeywords.ts).

export const AFFILIATE_TAG = "disciplefy-21";
export const MAX_AFFILIATE_LINKS_PER_POST = 3;

const affiliateUrl = (keyword: string) =>
  `https://www.amazon.in/s?k=${encodeURIComponent(keyword)}&tag=${AFFILIATE_TAG}`;

const escapeRegExp = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// A line is eligible for linkification unless it's a heading, blockquote,
// or inside a code fence. Inline code and existing links are excluded per
// match via the regex below.
function isProseLine(line: string, inFence: boolean): boolean {
  if (inFence) return false;
  const trimmed = line.trimStart();
  return !trimmed.startsWith("#") && !trimmed.startsWith(">");
}

export function linkifyAffiliate(
  content: string,
  keywords: string[],
): { content: string; linkCount: number } {
  if (keywords.length === 0) return { content, linkCount: 0 };

  // Longest first so "ESV Study Bible" wins over "study Bible".
  const ordered = [...keywords].sort((a, b) => b.length - a.length);
  const linked = new Set<string>(); // lowercased keywords already linked
  let linkCount = 0;
  let inFence = false;

  const lines = content.split("\n").map((line) => {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      return line;
    }
    if (!isProseLine(line, inFence) || linkCount >= MAX_AFFILIATE_LINKS_PER_POST) {
      return line;
    }

    let out = line;
    for (const keyword of ordered) {
      if (linkCount >= MAX_AFFILIATE_LINKS_PER_POST) break;
      const lower = keyword.toLowerCase();
      if (linked.has(lower)) continue;

      // Word-boundary, case-insensitive; skip matches inside inline code
      // (`...`) or markdown links ([...](...)) by rejecting matches whose
      // surrounding context is a code span or link syntax.
      const re = new RegExp(`\\b${escapeRegExp(keyword)}\\b`, "i");
      const m = re.exec(out);
      if (!m) continue;

      const start = m.index;
      const before = out.slice(0, start);
      const matched = m[0];

      // Inside inline code: odd number of backticks before the match.
      const backticks = (before.match(/`/g) ?? []).length;
      if (backticks % 2 === 1) continue;

      // Inside an existing link label or URL: an unclosed "[" or "(" from
      // link syntax before the match. Cheap approximation: last "[" not yet
      // closed by "]", or last "](" not yet closed by ")".
      const openBracket = before.lastIndexOf("[");
      if (openBracket !== -1 && before.indexOf("]", openBracket) === -1) continue;
      const openParen = before.lastIndexOf("](");
      if (openParen !== -1 && before.indexOf(")", openParen) === -1) continue;

      out =
        before +
        `[${matched}](${affiliateUrl(keyword)})` +
        out.slice(start + matched.length);
      linked.add(lower);
      linkCount++;
    }
    return out;
  });

  return { content: lines.join("\n"), linkCount };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd marketing && npx vitest run lib/linkifyAffiliate.test.ts`
Expected: all 7 tests PASS. If the boundary/skip heuristics fail a test, fix the implementation — do not weaken the tests.

Do NOT commit.

---

### Task 6: Marketing wiring — keyword fetch, disclosure, rel attributes

**Files:**
- Create: `marketing/lib/affiliateKeywords.ts`
- Modify: `marketing/components/blog/BlogPostContent.tsx`
- Modify: `marketing/components/blog/AppDownloadLink.tsx`
- Modify: `marketing/.env.example` (document the two new env vars)

**Interfaces:**
- Consumes: `linkifyAffiliate` (Task 5); `affiliate_keywords` table via Supabase REST (Task 1).
- Produces: `getActiveAffiliateKeywords(): Promise<string[]>`.

- [ ] **Step 1: Create the keyword fetcher (plain fetch, no new dependency)**

The marketing site keeps its plain-`fetch` + ISR convention (see `lib/blog.ts`) — do NOT add `@supabase/supabase-js`. Supabase's REST endpoint with the anon key + RLS returns only active rows:

```ts
// marketing/lib/affiliateKeywords.ts
// Fetches admin-curated affiliate keywords from Supabase REST. RLS restricts
// the anon key to is_active = true rows. Cached 5 min (keyword edits are
// low-urgency). On any failure returns [] — blog posts render without
// affiliate links rather than erroring.
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export async function getActiveAffiliateKeywords(): Promise<string[]> {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return [];
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/affiliate_keywords?select=keyword`,
      {
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
        },
        next: { revalidate: 300 },
      },
    );
    if (!res.ok) return [];
    const rows: { keyword: string }[] = await res.json();
    return rows.map((r) => r.keyword);
  } catch (err) {
    console.error("Failed to fetch affiliate keywords:", err);
    return [];
  }
}
```

- [ ] **Step 2: Document env vars in `marketing/.env.example`**

Append:

```
# Supabase read-only access (affiliate keywords; anon key + RLS = active rows only)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

(The real values must also be added to the marketing Vercel project — note this in the final report; it is a deploy-time action the user performs.)

- [ ] **Step 3: Wire into `BlogPostContent.tsx`**

`BlogPostContent` is a sync server component today. Make it async (server components may be async; the callers in `app/[locale]/blog/[slug]/page.tsx` and `app/blog/[slug]/page.tsx` already `return <BlogPostContent .../>` from async pages and need no changes):

```tsx
import { linkifyAffiliate } from "@/lib/linkifyAffiliate";
import { getActiveAffiliateKeywords } from "@/lib/affiliateKeywords";
```

Change the function signature line to `export async function BlogPostContent({ ... })` and replace the current `contentWithAd` line with:

```tsx
  const affiliateKeywords = await getActiveAffiliateKeywords();
  // Linkify first so the ad-marker paragraph can never be linkified.
  const { content: linkedContent, linkCount: affiliateLinkCount } =
    linkifyAffiliate(post.content, affiliateKeywords);
  const contentWithAd = insertAd(linkedContent, ADS, post.slug);
```

Add the disclosure strings to `UI_STRINGS` (each locale object gains one key):

```ts
// en:
affiliateDisclosure: "As an Amazon Associate, Disciplefy earns from qualifying purchases.",
// hi:
affiliateDisclosure: "एक Amazon Associate के रूप में, Disciplefy योग्य खरीदारी से कमाता है।",
// ml:
affiliateDisclosure: "ഒരു Amazon Associate എന്ന നിലയിൽ, യോഗ്യമായ വാങ്ങലുകളിൽ നിന്ന് Disciplefy വരുമാനം നേടുന്നു.",
```

Render the disclosure directly above `<BlogPostCTA .../>`, only when links exist (a dedicated component file is unnecessary for one conditional paragraph — keep it inline):

```tsx
        {/* Amazon Associates disclosure — required whenever affiliate links render */}
        {affiliateLinkCount > 0 && (
          <p className="mt-10 text-xs text-[var(--muted)] italic">
            {ui.affiliateDisclosure}
          </p>
        )}
```

- [ ] **Step 4: Add rel/target for Amazon links in `AppDownloadLink.tsx`**

Add after `isDownloadHref`:

```tsx
function isAmazonAffiliateHref(href?: string) {
  return href?.startsWith("https://www.amazon.in/") ?? false;
}
```

And a branch before the regular-link fallback:

```tsx
  if (isAmazonAffiliateHref(href)) {
    return (
      <a
        href={href}
        target="_blank"
        rel="sponsored nofollow noopener noreferrer"
        className="text-primary dark:text-indigo-300 underline decoration-primary/30 dark:decoration-indigo-400/40 underline-offset-2 hover:decoration-primary dark:hover:decoration-indigo-300 transition-all"
        {...rest}
      >
        {children}
      </a>
    );
  }
```

- [ ] **Step 5: Run the full marketing test suite, typecheck, and build**

Run: `cd marketing && npm test && npx tsc --noEmit && npm run build`
Expected: all tests pass (insertAd 6 + linkifyAffiliate 7), no type errors, clean build.

- [ ] **Step 6: Manual smoke check (only if local blog API + Supabase are running)**

`npm run dev`, open a blog post containing a seeded keyword, confirm: link renders with underline styling, opens amazon.in search with `tag=disciplefy-21`, disclosure line appears above the CTA, and a post with no keyword matches shows no disclosure.

Do NOT commit — leave everything for user review.

---

## Self-Review Notes

- **Spec coverage:** table+RLS+seed (T1) ✓; four Edge Functions incl. audit log, 409 duplicate, validation (T2) ✓; admin-web types/wrappers/routes (T3) ✓; CRUD page + sidebar (T4) ✓; linkify rules — first-only, case-insensitive, longest-first, 3-cap, skip zones, encoding (T5) ✓; keyword fetch with caching + `[]` fallback, disclosure (conditional, localized), `rel="sponsored nofollow noopener noreferrer"` + `target="_blank"` (T6) ✓. Spec's `AffiliateDisclosure.tsx` component simplified to an inline conditional paragraph in `BlogPostContent` (one `<p>`; a file would be ceremony) and spec's `marketing/lib/supabase.ts` client replaced by plain REST fetch (spec explicitly allowed either). Cache window is 300s not 60s — keyword edits are low-urgency; within spec intent.
- **Placeholders:** none — every step has full code or an exact command.
- **Type consistency:** `AffiliateKeyword` fields match table columns and Edge Function `select()` output; `linkifyAffiliate(content, keywords) → { content, linkCount }` consistent between T5 definition and T6 call site; wrapper names in T3 match T4 imports.
