/**
 * Guards the section total every stream path sends.
 *
 * index.ts serves on import, so its multi-pass paths cannot run here without
 * a live LLM. Instead this reads the source and checks that no section event
 * or pass helper is given a numeric literal total: they must use
 * `sectionTotal` (= expectedSectionTotal(study_mode)) or a value derived
 * from it, so the client sees one total for the whole stream.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'

const source = await Deno.readTextFile(new URL('./index.ts', import.meta.url))

/** Argument list (top-level commas split) of each call to [fn] in [src]. */
function callArgs(src: string, fn: string): string[][] {
  const calls: string[][] = []
  let from = 0
  while (true) {
    const start = src.indexOf(`${fn}(`, from)
    if (start === -1) break
    let i = start + fn.length + 1
    let depth = 1
    let arg = ''
    const args: string[] = []
    let quote: string | null = null
    for (; i < src.length && depth > 0; i++) {
      const ch = src[i]
      if (quote) {
        if (ch === '\\') { arg += ch + src[++i]; continue }
        if (ch === quote) quote = null
        arg += ch
        continue
      }
      if (ch === '"' || ch === "'" || ch === '`') quote = ch
      if ('([{'.includes(ch)) depth++
      if (')]}'.includes(ch)) depth--
      if (depth === 1 && ch === ',') { args.push(arg.trim()); arg = ''; continue }
      if (depth > 0) arg += ch
    }
    if (arg.trim()) args.push(arg.trim())
    calls.push(args)
    from = i
  }
  return calls
}

const NUMERIC = /^\d+$/

Deno.test('every section event uses a computed total, never a literal', () => {
  const calls = callArgs(source, 'createSectionEvent').filter((args) => args.length > 0)
  assert(calls.length >= 20, `expected the section events to be found, got ${calls.length}`)
  for (const args of calls) {
    assertEquals(args.length, 2, `createSectionEvent(${args.join(', ')})`)
    assert(!NUMERIC.test(args[1]), `literal total in createSectionEvent(${args.join(', ')})`)
  }
})

Deno.test('every multi-pass helper call gets the mode total', () => {
  for (const fn of ['streamAndParsePass', 'streamAndParsePass2WithEmission', 'streamAndParseSermonPass4WithEmission']) {
    // Skip the declaration (its 4th parameter is `totalSections: number`).
    const calls = callArgs(source, `await ${fn}`)
    assert(calls.length > 0, `no calls to ${fn} found`)
    for (const args of calls) {
      assertEquals(args[3], 'sectionTotal', `${fn} total`)
    }
  }
})

Deno.test('the multi-pass total and the poll total come from the mode', () => {
  assert(source.includes('const sectionTotal = expectedSectionTotal(study_mode)'))
  const polls = callArgs(source, 'await pollForInProgressCompletion')
  assertEquals(polls.length, 1)
  assertEquals(polls[0].at(-1), 'expectedSectionTotal(study_mode)')
})
