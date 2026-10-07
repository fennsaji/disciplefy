import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { isFreeCatalogueLesson } from './lesson-pricing.ts'

Deno.test('path lessons are free in quick and in the recommended mode', () => {
  assertEquals(isFreeCatalogueLesson('standard', 'quick'), true)
  assertEquals(isFreeCatalogueLesson('standard', 'standard'), true)
  assertEquals(isFreeCatalogueLesson('standard', 'deep'), false)
  assertEquals(isFreeCatalogueLesson(null, 'quick'), false)
})

Deno.test('a topic outside every path is never free, in any mode', () => {
  for (const mode of ['quick', 'standard', 'deep', 'lectio', 'sermon']) {
    assertEquals(isFreeCatalogueLesson(null, mode), false)
  }
})

Deno.test('a path lesson is free in its own recommended mode, whatever that mode is', () => {
  for (const mode of ['quick', 'standard', 'deep', 'lectio', 'sermon']) {
    assertEquals(isFreeCatalogueLesson(mode, mode), true)
  }
})

Deno.test('a path lesson in another paid mode still costs', () => {
  assertEquals(isFreeCatalogueLesson('deep', 'standard'), false)
  assertEquals(isFreeCatalogueLesson('standard', 'lectio'), false)
  assertEquals(isFreeCatalogueLesson('standard', 'sermon'), false)
  assertEquals(isFreeCatalogueLesson('quick', 'standard'), false)
})

Deno.test('quick is free for a path lesson whose path recommends a deeper mode', () => {
  assertEquals(isFreeCatalogueLesson('deep', 'quick'), true)
  assertEquals(isFreeCatalogueLesson('sermon', 'quick'), true)
})
