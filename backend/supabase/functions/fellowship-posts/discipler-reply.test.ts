// Run with: deno test --allow-env discipler-reply.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildGuideAttachment, isInternalCaller } from './discipler-reply.ts'

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
