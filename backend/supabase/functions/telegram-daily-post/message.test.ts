// Run with: deno test message.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildTelegramMessage } from './message.ts'

const lesson = {
  topicTitle: "Work, Earning, and God's Provision",
  hook: "Your job isn't punishment for sin—it's older and better than that.",
  body: 'Before anything broke, God gave work as a gift. That shift changes how you show up Monday morning, and it holds when the work is dull.',
  blogSlug: 'work-earning-and-gods-provision-en',
}

Deno.test('the post leads with the topic, then the teaser, then the article', () => {
  assertEquals(buildTelegramMessage(lesson), [
    "📖 Work, Earning, and God's Provision",
    '',
    "✨ Your job isn't punishment for sin—it's older and better than that.",
    '',
    'Before anything broke, God gave work as a gift. That shift changes how you show up Monday morning, and it holds when the work is dull.',
    '',
    'https://www.disciplefy.in/blog/work-earning-and-gods-provision-en',
  ].join('\n'))
})

Deno.test('the body is sent whole, never trimmed', () => {
  const long = 'x'.repeat(220)
  const message = buildTelegramMessage({ ...lesson, body: long })
  assertEquals(message.includes(long), true)
  assertEquals(message.includes('…'), false)
})

Deno.test('no fellowship or attribution line leaks into the channel post', () => {
  const message = buildTelegramMessage(lesson)
  assertEquals(message.includes('— Discipler'), false)
  assertEquals(message.includes('on Disciplefy'), false)
})
