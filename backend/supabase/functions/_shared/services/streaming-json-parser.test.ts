import { assertEquals, assertAlmostEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { StreamingJsonParser } from './streaming-json-parser.ts'

/** Feeds [text] to [parser] one character at a time, the worst case for the parser. */
function feedByChar(parser: StreamingJsonParser, text: string) {
  const found: Record<string, unknown> = {}
  for (const ch of text) {
    for (const section of parser.addChunk(ch)) found[section.type] = section.content
  }
  return found
}

Deno.test('a string field streamed one character at a time is extracted exactly', () => {
  const parser = new StreamingJsonParser()
  const found = feedByChar(parser, '{"summary": "Grace is God\'s unearned favor.", "context": "Background."}')
  assertEquals(found.summary, "Grace is God's unearned favor.")
  assertEquals(found.context, 'Background.')
})

Deno.test('an unescaped quote inside a string value is kept as literal content', () => {
  const parser = new StreamingJsonParser()
  const found = feedByChar(parser, '{"summary": "The word "faith" means trust.", "context": "x"}')
  assertEquals(found.summary, 'The word "faith" means trust.')
})

Deno.test('escaped characters are unescaped correctly', () => {
  const parser = new StreamingJsonParser()
  const found = feedByChar(parser, '{"summary": "Line one\\nLine two, with a \\"quote\\".", "context": "x"}')
  assertEquals(found.summary, 'Line one\nLine two, with a "quote".')
})

Deno.test('a field is not emitted until its closing quote arrives', () => {
  const parser = new StreamingJsonParser()
  let sections = parser.addChunk('{"summary": "Still writ')
  assertEquals(sections.length, 0)
  sections = parser.addChunk('ing this sentence')
  assertEquals(sections.length, 0)
  sections = parser.addChunk('."}')
  assertEquals(sections[0].content, 'Still writing this sentence.')
})

Deno.test('an array field is extracted once its closing bracket arrives', () => {
  const parser = new StreamingJsonParser()
  const found = feedByChar(
    parser,
    '{"summary": "s", "context": "c", "passage": "John 3:16", "interpretation": "i", ' +
      '"relatedVerses": ["Romans 5:8", "Titus 2:11"], "reflectionQuestions": ["Q1?"], "prayerPoints": ["Thank you."]}',
  )
  assertEquals(found.relatedVerses, ['Romans 5:8', 'Titus 2:11'])
  assertEquals(found.reflectionQuestions, ['Q1?'])
  assertEquals(found.prayerPoints, ['Thank you.'])
})

Deno.test('a comma inside a quoted array element does not split it', () => {
  const parser = new StreamingJsonParser()
  const found = feedByChar(parser, '{"summary":"s","context":"c","relatedVerses": ["Psalm 23:1-6, a psalm", "John 3:16"]}')
  assertEquals(found.relatedVerses, ['Psalm 23:1-6, a psalm', 'John 3:16'])
})

Deno.test('every field arriving in one chunk is still extracted correctly', () => {
  const parser = new StreamingJsonParser()
  const whole =
    '{"summary": "s", "context": "c", "passage": "John 3:16", "interpretation": "i", ' +
    '"relatedVerses": ["Rom 5:8"], "reflectionQuestions": ["Q?"], "prayerPoints": ["P."]}'
  const found: Record<string, unknown> = {}
  for (const section of parser.addChunk(whole)) found[section.type] = section.content
  assertEquals(found.summary, 's')
  assertEquals(found.interpretation, 'i')
  assertEquals(found.prayerPoints, ['P.'])
})

Deno.test('a field is emitted only once even if addChunk is called again after completion', () => {
  const parser = new StreamingJsonParser()
  const first = parser.addChunk('{"summary": "done."}')
  assertEquals(first.length, 1)
  const second = parser.addChunk(', "context": "more"}')
  assertEquals(second.map((s) => s.type), ['context'])
})

Deno.test('a large field streamed in many small chunks does not blow up quadratically', () => {
  // A synthetic proxy for the real symptom: a long field (an interpretation or
  // a Malayalam sermon pass) arriving over many tiny chunks, the way an LLM
  // streams tokens. Rescanning the accumulated value from its start on every
  // chunk is quadratic in the field's length; this asserts it finishes in a
  // time budget that a quadratic implementation would blow past for this size.
  const longValue = 'x'.repeat(60_000)
  const parser = new StreamingJsonParser()
  const chunks: string[] = [`{"summary": "s", "context": "c", "interpretation": "`]
  for (let i = 0; i < longValue.length; i += 20) chunks.push(longValue.slice(i, i + 20))
  chunks.push('"}')

  const start = performance.now()
  let result: unknown
  for (const chunk of chunks) {
    for (const section of parser.addChunk(chunk)) {
      if (section.type === 'interpretation') result = section.content
    }
  }
  const elapsedMs = performance.now() - start

  assertEquals(result, longValue)
  // A quadratic scan of a 60k-character field over ~3,000 chunks does tens of
  // millions of character visits; that takes well over a second even on a
  // fast machine. An incremental scan does ~60k visits total.
  if (elapsedMs > 500) {
    throw new Error(`Expected a linear scan to finish well under 500ms, took ${elapsedMs.toFixed(0)}ms — likely rescanning from the start on every chunk again`)
  }
})
