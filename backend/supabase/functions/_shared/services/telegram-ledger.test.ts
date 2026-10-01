import { assertEquals, assertRejects } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { claimDailySlot, parseJobRequest, settleDailySlot, STALE_CLAIM_MS } from './telegram-ledger.ts'
import { AppError } from '../utils/error-handler.ts'

type Row = { post_date: string; language: string; status: string; claimed_at: string | null; [k: string]: unknown }

/** In-memory ledger honouring the unique (post_date, language) key and the reclaim filter. */
function ledgerFake(initial: Row[] = [], opts: { failUpdates?: boolean } = {}) {
  const rows = [...initial]
  const find = (d: string, l: string) => rows.find((r) => r.post_date === d && r.language === l)
  const supabase = {
    from: () => ({
      upsert: (row: Row) => ({
        select: () => {
          if (find(row.post_date, row.language)) return Promise.resolve({ data: [], error: null })
          rows.push({ ...row })
          return Promise.resolve({ data: [{ id: 'x' }], error: null })
        },
      }),
      update: (patch: Partial<Row>) => {
        const f: Record<string, string> = {}
        let orFilter: string | null = null
        const apply = () => {
          if (opts.failUpdates) return { data: null, error: { message: 'db down' } }
          const r = find(f.post_date, f.language)
          if (!r) return { data: [], error: null }
          if (orFilter) {
            const stale = orFilter.match(/claimed_at\.lt\.([^)]+)\)/)![1]
            const ok = r.status === 'failed' || (r.status === 'pending' && (!r.claimed_at || r.claimed_at < stale))
            if (!ok) return { data: [], error: null }
          }
          Object.assign(r, patch)
          return { data: [{ id: 'x' }], error: null }
        }
        const c = {
          eq: (k: string, v: string) => { f[k] = v; return c },
          or: (s: string) => { orFilter = s; return c },
          select: () => Promise.resolve(apply()),
          then: (res: (v: unknown) => unknown) => Promise.resolve(apply()).then(res),
        }
        return c
      },
      select: () => {
        const f: Record<string, string> = {}
        const c = {
          eq: (k: string, v: string) => { f[k] = v; return c },
          maybeSingle: () => Promise.resolve({ data: find(f.post_date, f.language) ?? null, error: null }),
        }
        return c
      },
    }),
  }
  return { supabase, rows }
}

const T = 'telegram_daily_verse_posts' as const
const D = '2026-10-01'

Deno.test('first run claims; second run skips while pending and after sent (no double post)', async () => {
  const { supabase, rows } = ledgerFake()
  assertEquals(await claimDailySlot(supabase, T, D, 'en', { reference: 'John 3:16' }), { claimed: true })
  assertEquals(await claimDailySlot(supabase, T, D, 'en', { reference: 'John 3:16' }), { claimed: false, status: 'pending' })
  await settleDailySlot(supabase, T, D, 'en', { ok: true, messageId: 5, error: null })
  assertEquals(rows[0].status, 'sent')
  assertEquals(await claimDailySlot(supabase, T, D, 'en', { reference: 'John 3:16' }), { claimed: false, status: 'sent' })
})

Deno.test('send succeeded but settle failed: the pending claim still blocks a manual re-run', async () => {
  const { supabase } = ledgerFake()
  await claimDailySlot(supabase, T, D, 'en', {})
  const broken = ledgerFake([], { failUpdates: true })
  assertEquals(await settleDailySlot(broken.supabase, T, D, 'en', { ok: true, messageId: 1, error: null }), false)
  assertEquals((await claimDailySlot(supabase, T, D, 'en', {})).claimed, false)
})

Deno.test('failed slot and stale pending slot can be reclaimed', async () => {
  const now = new Date('2026-10-01T01:00:00Z')
  const stale = new Date(now.getTime() - STALE_CLAIM_MS - 1000).toISOString()
  const { supabase } = ledgerFake([
    { post_date: D, language: 'en', status: 'failed', claimed_at: now.toISOString() },
    { post_date: D, language: 'hi', status: 'pending', claimed_at: stale },
  ])
  assertEquals(await claimDailySlot(supabase, T, D, 'en', {}, now), { claimed: true })
  assertEquals(await claimDailySlot(supabase, T, D, 'hi', {}, now), { claimed: true })
})

const req = (body: unknown) => new Request('http://x', { method: 'POST', body: body === undefined ? undefined : JSON.stringify(body) })

Deno.test('job request: missing or unsupported language is rejected with 400', async () => {
  for (const body of [undefined, {}, { language: 'fr' }, { language: 1 }]) {
    const err = await assertRejects(() => parseJobRequest(req(body)), AppError)
    assertEquals(err.statusCode, 400)
  }
  assertEquals(await parseJobRequest(req({ language: 'ml', dry_run: true })), { language: 'ml', dryRun: true })
})
