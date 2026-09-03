import { assertEquals, assertThrows } from 'jsr:@std/assert'
import { joinInterpretationParts } from './join-passes.ts'

// A Malayalam study guide was persisted with interpretation
// "undefined\n\nundefined" because the combiners built this field with a
// template string over pass fields that were absent.

Deno.test('joins the parts that are present', () => {
  assertEquals(joinInterpretationParts(['one', 'two'], 'test'), 'one\n\ntwo')
})

Deno.test('drops missing parts instead of stringifying undefined', () => {
  assertEquals(joinInterpretationParts(['one', undefined], 'test'), 'one')
  assertEquals(joinInterpretationParts([undefined, 'two'], 'test'), 'two')
  assertEquals(joinInterpretationParts(['one', '   '], 'test'), 'one')
})

Deno.test('never emits the literal text "undefined"', () => {
  const joined = joinInterpretationParts([undefined, 'real content', null], 'test')
  assertEquals(joined.includes('undefined'), false)
  assertEquals(joined.includes('null'), false)
})

Deno.test('throws rather than storing an empty interpretation', () => {
  assertThrows(() => joinInterpretationParts([undefined, undefined], 'test'))
  assertThrows(() => joinInterpretationParts([], 'test'))
})
