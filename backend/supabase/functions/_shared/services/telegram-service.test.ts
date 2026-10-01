// Run with: deno test telegram-service.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildSendMessageBody, pickThreadId } from './telegram-service.ts'

const rows = [
  { kind: 'study_post', language: 'en', thread_id: 74 },
  { kind: 'study_post', language: 'hi', thread_id: 72 },
  { kind: 'study_post', language: 'ml', thread_id: 73 },
  { kind: 'daily_verse', language: 'en', thread_id: 79 },
  { kind: 'daily_verse', language: 'hi', thread_id: '80' },
  { kind: 'daily_verse', language: 'ml', thread_id: 81 },
]

Deno.test('resolves the topic per kind and language', () => {
  assertEquals(pickThreadId(rows, 'study_post', 'en'), 74)
  assertEquals(pickThreadId(rows, 'study_post', 'ml'), 73)
  assertEquals(pickThreadId(rows, 'daily_verse', 'hi'), 80) // bigint arrives as string
  assertEquals(pickThreadId(rows, 'daily_verse', 'ml'), 81)
})

Deno.test('missing or invalid mapping resolves to null', () => {
  assertEquals(pickThreadId(rows.slice(0, 1), 'daily_verse', 'en'), null)
  assertEquals(pickThreadId(null, 'study_post', 'en'), null)
  assertEquals(pickThreadId([{ kind: 'study_post', language: 'en', thread_id: null }], 'study_post', 'en'), null)
})

Deno.test('send body carries message_thread_id only when a topic is mapped', () => {
  assertEquals(buildSendMessageBody('@g', 'hi', 79), {
    chat_id: '@g', text: 'hi', disable_web_page_preview: false, message_thread_id: 79,
  })
  assertEquals('message_thread_id' in buildSendMessageBody('@g', 'hi', null), false)
})
