/**
 * Unit tests for Bible Book Normalizer
 *
 * Tests validation and auto-correction of Bible book names in LLM responses.
 */

import { assertEquals, assertExists } from 'https://deno.land/std@0.192.0/testing/asserts.ts'
import { BibleBookNormalizer, CANONICAL_BIBLE_BOOKS, INCORRECT_TO_CORRECT } from './bible-book-normalizer.ts'

// ==================== VALIDATION TESTS ====================

Deno.test('BibleBookNormalizer - should validate correct English book names', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'In John 3:16, we see that God loved the world. Also see Romans 8:28.'

  const validation = normalizer.validateBibleBooks(text)

  assertEquals(validation.isValid, true)
  assertEquals(validation.invalidBooks.length, 0)
  assertEquals(validation.correctedBooks.length, 0)
})

Deno.test('BibleBookNormalizer - should detect abbreviated book names', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'Check out Jn 3:16 and Rom 8:28 for encouragement.'

  const validation = normalizer.validateBibleBooks(text)

  // Should detect abbreviations that need correction
  assertEquals(validation.correctedBooks.length >= 2, true)
  assertEquals(validation.warnings.length >= 2, true)
})

Deno.test('BibleBookNormalizer - should detect invalid book names', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'Read Foobar 3:16 for wisdom.' // Invalid book name

  const validation = normalizer.validateBibleBooks(text)

  assertEquals(validation.isValid, false)
  assertEquals(validation.invalidBooks.includes('Foobar'), true)
})

// ==================== NORMALIZATION TESTS ====================

Deno.test('BibleBookNormalizer - should normalize common abbreviations', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'Jn 3:16 says God loves the world. Rom 8:28 is also encouraging.'

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized.includes('John 3:16'), true)
  assertEquals(normalized.includes('Romans 8:28'), true)
  assertEquals(normalized.includes('Jn 3:16'), false) // Should be replaced
  assertEquals(normalized.includes('Rom 8:28'), false) // Should be replaced
})

Deno.test('BibleBookNormalizer - should handle 1st/2nd/3rd format', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = '1st Corinthians 13:4 and 2nd Timothy 3:16 are powerful.'

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized.includes('1 Corinthians 13:4'), true)
  assertEquals(normalized.includes('2 Timothy 3:16'), true)
  assertEquals(normalized.includes('1st Corinthians'), false)
  assertEquals(normalized.includes('2nd Timothy'), false)
})

Deno.test('BibleBookNormalizer - should handle "First/Second" format', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'First Corinthians 13 and Second Peter 1:3 teach us.'

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized.includes('1 Corinthians 13'), true)
  assertEquals(normalized.includes('2 Peter 1:3'), true)
  assertEquals(normalized.includes('First Corinthians'), false)
  assertEquals(normalized.includes('Second Peter'), false)
})

Deno.test('BibleBookNormalizer - should handle Gospel prefixes', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'The Gospel of John 3:16 is the most famous verse.'

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized.includes('John 3:16'), true)
  assertEquals(normalized.includes('The Gospel of John'), false)
})

Deno.test('BibleBookNormalizer - should handle Revelations vs Revelation', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'Revelations 21:4 promises no more tears.'

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized.includes('Revelation 21:4'), true)
  assertEquals(normalized.includes('Revelations'), false)
})

Deno.test('BibleBookNormalizer - should preserve case correctly', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'john 3:16 is a powerful verse.'

  const normalized = normalizer.normalizeBibleBooks(text)

  // Should normalize to proper case
  assertEquals(normalized.includes('John 3:16'), true)
  assertEquals(normalized.includes('john 3:16'), false)
})

Deno.test('BibleBookNormalizer - should handle multiple abbreviations in one text', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'Read Gen 1:1, Ex 20:1-17, Ps 23, and Rev 22:21 for a complete biblical journey.'

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized.includes('Genesis 1:1'), true)
  assertEquals(normalized.includes('Exodus 20:1-17'), true)
  assertEquals(normalized.includes('Psalms 23'), true)
  assertEquals(normalized.includes('Revelation 22:21'), true)
})

Deno.test('BibleBookNormalizer - should not modify correct book names', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'John 3:16 and Romans 8:28 are already correct.'

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized, text) // Should remain unchanged
})

// ==================== MULTI-LANGUAGE TESTS ====================

Deno.test('BibleBookNormalizer - should work with Hindi book names', () => {
  const normalizer = new BibleBookNormalizer('hi-IN')
  const text = 'यूहन्ना 3:16 में परमेश्वर के प्रेम के बारे में बताया गया है।'

  const validation = normalizer.validateBibleBooks(text)

  assertEquals(validation.isValid, true)
  assertEquals(validation.invalidBooks.length, 0)
})

Deno.test('BibleBookNormalizer - should correct Hindi abbreviations', () => {
  const normalizer = new BibleBookNormalizer('hi-IN')
  const text = 'भज 23:1 में लिखा है।' // Abbreviated "भजन संहिता"

  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(normalized.includes('भजन संहिता 23:1'), true)
  assertEquals(normalized.includes('भज 23:1'), false)
})

Deno.test('BibleBookNormalizer - should recognize canonical Malayalam book names', () => {
  const normalizer = new BibleBookNormalizer('ml-IN')
  // Use canonical abbreviated form from CANONICAL_BIBLE_BOOKS['ml-IN']
  const text = 'യോഹ. 3:16 ദൈവത്തിന്റെ സ്നേഹത്തെക്കുറിച്ച് പറയുന്നു.'

  const validation = normalizer.validateBibleBooks(text)

  assertEquals(validation.isValid, true)
  assertEquals(validation.invalidBooks.length, 0)
  // Canonical form should not require correction
  assertEquals(validation.correctedBooks.length, 0)
})

Deno.test('BibleBookNormalizer - should correct non-canonical Malayalam book names', () => {
  const normalizer = new BibleBookNormalizer('ml-IN')
  // Use full form that maps to canonical 'യോഹ.' via INCORRECT_TO_CORRECT['ml-IN']
  const text = 'യോഹന്നാൻ 3:16 ദൈവത്തിന്റെ സ്നേഹത്തെക്കുറിച്ച് പറയുന്നു.'

  const validation = normalizer.validateBibleBooks(text)

  assertEquals(validation.isValid, true)
  assertEquals(validation.invalidBooks.length, 0)
  // Explicitly verify the correction mapping was applied
  assertEquals(validation.correctedBooks.length, 1)
  assertEquals(validation.correctedBooks[0].original, 'യോഹന്നാൻ')
  assertEquals(validation.correctedBooks[0].corrected, 'യോഹ.')
})

// ==================== EDGE CASES ====================

Deno.test('BibleBookNormalizer - should handle empty text', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = ''

  const validation = normalizer.validateBibleBooks(text)
  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(validation.isValid, true)
  assertEquals(normalized, '')
})

Deno.test('BibleBookNormalizer - should handle text without Bible references', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'This is a regular conversation about faith and prayer.'

  const validation = normalizer.validateBibleBooks(text)
  const normalized = normalizer.normalizeBibleBooks(text)

  assertEquals(validation.isValid, true)
  assertEquals(normalized, text)
})

Deno.test('BibleBookNormalizer - should handle mixed correct and incorrect names', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'Read John 3:16 and Jn 14:6 for truth.'

  const normalized = normalizer.normalizeBibleBooks(text)

  // Both should be normalized to "John"
  assertEquals(normalized.includes('John 3:16'), true)
  assertEquals(normalized.includes('John 14:6'), true)
  assertEquals(normalized.includes('Jn 14:6'), false)
})

// ==================== CANONICAL DATA TESTS ====================

Deno.test('CANONICAL_BIBLE_BOOKS - should have 66 books for English', () => {
  const englishBooks = CANONICAL_BIBLE_BOOKS['en-US']
  assertEquals(englishBooks.length, 66) // 39 OT + 27 NT
})

Deno.test('CANONICAL_BIBLE_BOOKS - should have 66 books for Hindi', () => {
  const hindiBooks = CANONICAL_BIBLE_BOOKS['hi-IN']
  assertEquals(hindiBooks.length, 66)
})

Deno.test('CANONICAL_BIBLE_BOOKS - should have 66 books for Malayalam', () => {
  const malayalamBooks = CANONICAL_BIBLE_BOOKS['ml-IN']
  assertEquals(malayalamBooks.length, 66)
})

Deno.test('INCORRECT_TO_CORRECT - should have common abbreviations', () => {
  const englishMappings = INCORRECT_TO_CORRECT['en-US']

  // Check for common abbreviations
  assertEquals(englishMappings['Jn'], 'John')
  assertEquals(englishMappings['Gen'], 'Genesis')
  assertEquals(englishMappings['Rom'], 'Romans')
  assertEquals(englishMappings['Rev'], 'Revelation')
  assertEquals(englishMappings['Ps'], 'Psalms')
})

Deno.test('INCORRECT_TO_CORRECT - should handle alternative forms', () => {
  const englishMappings = INCORRECT_TO_CORRECT['en-US']

  assertEquals(englishMappings['Revelations'], 'Revelation')
  assertEquals(englishMappings['First Corinthians'], '1 Corinthians')
  assertEquals(englishMappings['The Gospel of John'], 'John')
})

// ==================== LOGGING TESTS ====================

Deno.test('BibleBookNormalizer - should log warnings for invalid books', () => {
  const normalizer = new BibleBookNormalizer('en-US')
  const text = 'Jn 3:16 is powerful.'

  const validation = normalizer.validateBibleBooks(text)

  // Should have warnings about "Jn" needing correction
  assertEquals(validation.warnings.length > 0, true)
  assertEquals(validation.warnings[0].includes('Jn'), true)
  assertEquals(validation.warnings[0].includes('John'), true)
})

console.log('✅ All Bible Book Normalizer tests passed!')
