// Run with: deno test admin-learning-paths/short-title.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { normalizeShortTitle, SHORT_TITLE_MAX, shortTitleErrors } from './short-title.ts'

Deno.test('normalizeShortTitle trims, maps blank to null, keeps undefined', () => {
  assertEquals(normalizeShortTitle('  Romans  '), 'Romans')
  assertEquals(normalizeShortTitle('   '), null)
  assertEquals(normalizeShortTitle(null), null)
  assertEquals(normalizeShortTitle(undefined), undefined)
})

Deno.test('shortTitleErrors accepts 28 characters, counting code points', () => {
  assertEquals(SHORT_TITLE_MAX, 28)
  assertEquals(shortTitleErrors({ short_title: 'Singleness, Dating, Marriage' }), [])
  // 26 code points of Devanagari, as Postgres char_length counts them.
  assertEquals(shortTitleErrors({ translations: { hi: { short_title: 'कुलुस्सियों: सर्वोच्च मसीह' } } }), [])
})

Deno.test('shortTitleErrors names every field over the limit, per language', () => {
  const long = 'x'.repeat(29)
  assertEquals(shortTitleErrors({
    short_title: long,
    translations: { en: { short_title: 'ok' }, ml: { short_title: long }, hi: { short_title: null } },
  }), ['short_title', 'translations.ml.short_title'])
})

Deno.test('shortTitleErrors rejects a non-string value', () => {
  assertEquals(shortTitleErrors({ short_title: 42 as unknown as string }), ['short_title'])
})
