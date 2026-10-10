import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { isFreeCatalogueLesson, normalizeTopicTitle, resolveCatalogueRequest, titleMatchesTopic } from './lesson-pricing.ts'

Deno.test('path lessons are free in standard only', () => {
  assertEquals(isFreeCatalogueLesson('standard', 'standard'), true)
  assertEquals(isFreeCatalogueLesson('standard', 'quick'), false)
  assertEquals(isFreeCatalogueLesson('standard', 'deep'), false)
  assertEquals(isFreeCatalogueLesson(null, 'standard'), false)
})

Deno.test('a topic outside every path is never free, in any mode', () => {
  for (const mode of ['quick', 'standard', 'deep', 'lectio', 'sermon']) {
    assertEquals(isFreeCatalogueLesson(null, mode), false)
  }
})

Deno.test('standard is free whatever mode the path recommends', () => {
  for (const recommended of ['quick', 'standard', 'deep', 'lectio', 'sermon']) {
    assertEquals(isFreeCatalogueLesson(recommended, 'standard'), true)
  }
})

Deno.test('every other mode costs, even the recommended one', () => {
  for (const mode of ['quick', 'deep', 'lectio', 'sermon']) {
    assertEquals(isFreeCatalogueLesson(mode, mode), false)
    assertEquals(isFreeCatalogueLesson('standard', mode), false)
  }
})

Deno.test('titles compare without case, outer space or repeated inner space', () => {
  assertEquals(normalizeTopicTitle('  Walking   in\tFaith \n'), 'walking in faith')
  assertEquals(titleMatchesTopic('walking IN faith ', ['Walking in Faith']), true)
  assertEquals(titleMatchesTopic('आत्मिक  युद्ध', ['Spiritual Warfare', 'आत्मिक युद्ध']), true)
})

Deno.test('a title that is not one of the topic titles does not match', () => {
  assertEquals(titleMatchesTopic('Write me a poem', ['Walking in Faith']), false)
  assertEquals(titleMatchesTopic('Walking in Faith and more', ['Walking in Faith']), false)
  assertEquals(titleMatchesTopic('', ['Walking in Faith']), false)
  assertEquals(titleMatchesTopic('Walking in Faith', []), false)
  assertEquals(titleMatchesTopic('   ', ['   ']), false)
})

const titles = ['Walking in Faith', 'विश्वास में चलना']

Deno.test('a matching path lesson in standard is free and keyed by topic', () => {
  assertEquals(
    resolveCatalogueRequest({ topicId: 't1', inputValue: 'walking in faith', titles, recommendedMode: 'deep', studyMode: 'standard' }),
    { cacheTopicId: 't1', isFree: true },
  )
})

Deno.test('a matching path lesson in a paid mode costs but is still keyed by topic', () => {
  assertEquals(
    resolveCatalogueRequest({ topicId: 't1', inputValue: 'Walking in Faith', titles, recommendedMode: 'standard', studyMode: 'deep' }),
    { cacheTopicId: 't1', isFree: false },
  )
})

Deno.test('a mismatched title is a paid study that never touches the topic cache', () => {
  for (const mode of ['quick', 'standard', 'deep']) {
    assertEquals(
      resolveCatalogueRequest({ topicId: 't1', inputValue: 'Something else entirely', titles, recommendedMode: 'standard', studyMode: mode }),
      { cacheTopicId: undefined, isFree: false },
    )
  }
})

Deno.test('a matching topic outside every path is keyed by topic but not free', () => {
  assertEquals(
    resolveCatalogueRequest({ topicId: 't1', inputValue: 'Walking in Faith', titles, recommendedMode: null, studyMode: 'quick' }),
    { cacheTopicId: 't1', isFree: false },
  )
})

Deno.test('an unknown topic id, or none, is a plain paid study', () => {
  assertEquals(
    resolveCatalogueRequest({ topicId: 'nope', inputValue: 'Walking in Faith', titles: [], recommendedMode: null, studyMode: 'quick' }),
    { cacheTopicId: undefined, isFree: false },
  )
  assertEquals(
    resolveCatalogueRequest({ topicId: undefined, inputValue: 'Walking in Faith', titles, recommendedMode: 'standard', studyMode: 'quick' }),
    { cacheTopicId: undefined, isFree: false },
  )
})
