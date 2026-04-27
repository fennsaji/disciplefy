# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Disciplefy Admin Panel — a Next.js 16 dashboard for managing the Disciplefy Bible Study app. Manages learning paths, study topics, AI study guide generation, LLM cost analytics, subscriptions, promo codes, blogs, gamification, security logs, cron jobs, and admin users.

## Commands

```bash
npm run dev          # Dev server on port 4000
npm run build        # Production build
npm run start        # Production server on port 4000
npm run lint         # ESLint (.ts, .tsx)
npm run type-check   # TypeScript noEmit check
```

No test framework is configured.

## Tech Stack

- **Next.js 16** (App Router, Turbopack, Server/Client Components)
- **React 19**, **TypeScript 5.9**
- **Tailwind CSS 3** (class-based dark mode)
- **React Query 5** (TanStack) for server state
- **Supabase** (`@supabase/supabase-js` + `@supabase/ssr`) for auth and database
- **@dnd-kit** for drag-and-drop, **Recharts** for charts, **sonner** for toasts, **papaparse** for CSV import

## Architecture

### Route Structure

```
app/
├── (auth)/login/          # Google OAuth login
├── (dashboard)/           # Protected admin routes (15+ sections)
│   ├── layout.tsx         # Auth gate: checks user + is_admin flag
│   ├── learning-paths/    # CRUD + reorder + import/export
│   ├── topics/            # CRUD + bulk CSV import
│   ├── study-generator/   # AI study guide generation (SSE streaming)
│   ├── llm-costs/         # Cost analytics with charts
│   └── ...                # subscriptions, promo-codes, blogs, analytics, etc.
└── api/admin/             # ~28 API route files (server-side)
```

### Data Flow Pattern

```
Page (useQuery) → lib/api/admin.ts (fetch wrapper) → /api/admin/* (API route)
  → Auth check (createClient + createAdminClient) → Supabase Edge Function or direct DB query
```

1. **Client pages** call typed fetch functions from `lib/api/admin.ts`
2. **API routes** (`app/api/admin/*/route.ts`) verify auth + admin status, then call Supabase Edge Functions using the service role key, or query the database directly
3. **React Query** caches responses (staleTime: 1 min, refetchOnWindowFocus: false)

### Three Supabase Clients

- `lib/supabase/client.ts` — Browser client (createBrowserClient, uses anon key)
- `lib/supabase/server.ts` — Server client (createServerClient, reads cookies for user session)
- `lib/supabase/admin.ts` — Admin client (createClient with service role key, bypasses RLS). **Only used in API routes, never in client components.**

### Auth Flow

Dashboard layout (`app/(dashboard)/layout.tsx`) is the auth gate:
1. Get user via server Supabase client (cookie session)
2. Check `user_profiles.is_admin` via admin client (service role)
3. Redirect to `/login` if no user, `/unauthorized` if not admin

API routes repeat this check: every route verifies user auth + admin flag before processing.

### Component Organization

```
components/
├── dialogs/          # Modal forms (create/edit learning paths, topics, bulk import)
├── tables/           # Data display tables (15+ tables)
├── ui/               # Reusable: translation-editor, icon-color-picker, tags-input, markdown-editor, etc.
├── charts/           # Recharts wrappers (cost trends, pie charts)
├── study-generator/  # Source selector, streaming preview, content editor
├── sidebar.tsx       # Left nav (gradient background, 4 groups, emoji icons)
├── dashboard-shell.tsx  # Main layout wrapper
└── header.tsx        # Top bar
```

### Type System

All types are centralized in `types/admin.ts` (~865 lines). Every API operation has typed request/response pairs. Import types from `@/types/admin`.

### API Client Functions

`lib/api/admin.ts` exports 40+ async functions (one per API operation). All use `credentials: 'include'` and return typed responses. When adding a new API endpoint:
1. Add types to `types/admin.ts`
2. Add fetch function to `lib/api/admin.ts`
3. Create API route in `app/api/admin/`

### Adding a New API Route

Follow the established pattern in `app/api/admin/*/route.ts`:
```typescript
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

export async function GET(request: NextRequest) {
  // 1. Verify user auth
  const supabaseUser = await createClient()
  const { data: { user } } = await supabaseUser.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // 2. Verify admin
  const supabaseAdmin = await createAdminClient()
  const { data: profile } = await supabaseAdmin.from('user_profiles').select('is_admin').eq('id', user.id).single()
  if (!profile?.is_admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 })

  // 3. Call Edge Function or query DB
  const functionUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/your-function`
  const response = await fetch(functionUrl, {
    headers: {
      'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
      'x-admin-user-id': user.id,
    },
  })
  // ...
}
```

## Design System

Tailwind custom colors defined in `tailwind.config.ts`:
- **primary**: `#4F46E5` (indigo, 10-shade palette)
- **highlight**: `#FFEEC0` (light gold, 6-shade palette)
- **surface**: `#FFFFFF`
- **background**: `#F8F9FA`

Path alias: `@/*` maps to project root.

## Environment Variables

- `NEXT_PUBLIC_SUPABASE_URL` — Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — Public anon key
- `SUPABASE_SERVICE_ROLE_KEY` — Server-only, never exposed to client

## Relation to Main Project

This admin panel lives alongside the Flutter frontend (`../frontend/`) and Supabase backend (`../backend/`). It calls the same Supabase Edge Functions that the Flutter app uses (prefixed with `admin-`). See the root `CLAUDE.md` for the full project context.
