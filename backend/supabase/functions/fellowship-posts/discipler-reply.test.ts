// Run with: deno test --allow-env discipler-reply.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildGuideAttachment, claimReplyQueueRow, isInternalCaller } from './discipler-reply.ts'

Deno.test('buildGuideAttachment links a cached guide by id or falls back to inputs', () => {
  assertEquals(buildGuideAttachment({ id: 'g1', title: 'Prayer' }, { input_type: 'topic', input_value: 'prayer' }, 'hi'),
    { study_guide_id: 'g1', guide_title: 'Prayer', guide_input_type: 'topic', guide_input_value: 'prayer', guide_language: 'hi' })
  assertEquals(buildGuideAttachment(null, { input_type: 'scripture', input_value: 'John 15' }, 'en'),
    { study_guide_id: null, guide_title: 'John 15', guide_input_type: 'scripture', guide_input_value: 'John 15', guide_language: 'en' })
})

Deno.test('isInternalCaller accepts the nil system user or the service role bearer', () => {
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'srk')
  assertEquals(isInternalCaller({ userId: '00000000-0000-0000-0000-000000000000' }, 'Bearer nope'), true)
  assertEquals(isInternalCaller({ userId: 'someone' }, 'Bearer srk'), true)
  assertEquals(isInternalCaller({ userId: 'someone' }, 'Bearer nope'), false)
  assertEquals(isInternalCaller(null, 'Bearer srk'), true)
  assertEquals(isInternalCaller(null, null), false)
})

// Fake for the claim update: applies the .or() filter against one stored row.
function claimDb(row: { status: string; updated_at: string }) {
  let filter = ''
  const chain = {
    update(_v: unknown) { return chain },
    eq(_c: string, _v: unknown) { return chain },
    or(f: string) { filter = f; return chain },
    select(_c: string) {
      const staleMatch = filter.match(/updated_at\.lt\.([^)]+)\)/)
      const staleBefore = staleMatch ? staleMatch[1] : ''
      const ok = filter.includes('status.eq.pending') && row.status === 'pending' ||
        (row.status === 'processing' && staleBefore !== '' && row.updated_at < staleBefore)
      return Promise.resolve({ data: ok ? [{ id: 'q1' }] : [], error: null })
    },
  }
  // deno-lint-ignore no-explicit-any
  return { from: (_t: string) => chain } as any
}

/**
 * The handler used to accept a row already in 'processing' unconditionally, so
 * a worker retry while the first run was mid-LLM-call posted the reply and
 * pushed it twice.
 */
Deno.test('a row another run is processing is not claimed again', async () => {
  const now = new Date('2026-10-09T10:00:00Z')
  const fresh = claimDb({ status: 'processing', updated_at: '2026-10-09T09:59:00.000Z' })
  assertEquals(await claimReplyQueueRow(fresh, { id: 'q1', attempts: 1 }, now), false)
})

Deno.test('a pending row, or one abandoned in processing, is claimed', async () => {
  const now = new Date('2026-10-09T10:00:00Z')
  assertEquals(await claimReplyQueueRow(claimDb({ status: 'pending', updated_at: '2026-10-09T09:59:00.000Z' }), { id: 'q1' }, now), true)
  assertEquals(await claimReplyQueueRow(claimDb({ status: 'processing', updated_at: '2026-10-09T09:50:00.000Z' }), { id: 'q1' }, now), true)
})
