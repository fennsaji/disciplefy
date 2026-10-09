// Run: deno test --sloppy-imports lib/utils/plan-marketing-features.test.ts
// (admin-web has no test framework; this uses only node:test.)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { buildMarketingFeatures, planMarketingUpdate } from './plan-marketing-features'

const standardFeatures = { daily_tokens: 40, voice_conversations_monthly: 3 }

test('Standard copy quotes credits, enforced limits and Discipler count', () => {
  const copy = buildMarketingFeatures('standard', standardFeatures, {
    memoryVersesLimit: 5,
    practiceModes: 8,
  })
  assert.deepEqual(copy.en, [
    'Daily Bible verse',
    '40 credits a day',
    'Quick Read, Standard, Deep Dive and Lectio Divina',
    'Guided learning paths',
    'Review 5 memory verses a day · all 8 practice modes',
    '10 follow-ups per study',
    'Discipler · 3 conversations a month',
    'Join fellowships',
  ])
})

test('no token wording and no "Not Included" lines', () => {
  for (const plan of ['free', 'standard', 'plus', 'premium'] as const) {
    const copy = buildMarketingFeatures(plan, { daily_tokens: 15, voice_conversations_monthly: 0 })
    const text = copy.en.join(' | ')
    assert.doesNotMatch(text, /token/i)
    assert.doesNotMatch(text, /Not Included/)
    assert.doesNotMatch(text, /Memorize up to 0/)
  }
})

test('Plus and Premium follow-ups match the backend limits', () => {
  const plus = buildMarketingFeatures('plus', { daily_tokens: 60, voice_conversations_monthly: 10 })
  const premium = buildMarketingFeatures('premium', { daily_tokens: -1, voice_conversations_monthly: -1 })
  assert.ok(plus.en.includes('15 follow-ups per study'))
  assert.ok(premium.en.includes('20 follow-ups per study'))
  assert.ok(premium.en.includes('Unlimited credits'))
  assert.ok(premium.en.includes('Unlimited Discipler conversations'))
  assert.ok(premium.en.includes('Unlimited memory reviews'))
})

test('Free shows no follow-up or Discipler line', () => {
  const free = buildMarketingFeatures('free', { daily_tokens: 15, voice_conversations_monthly: 0 })
  assert.deepEqual(free.en, [
    'Daily Bible verse',
    '15 credits a day',
    'Quick Read and Standard studies',
    'Guided learning paths',
    'Review 3 memory verses a day',
    '2 practice modes',
    'Join fellowships',
  ])
})

test('every locale gets the same number of items', () => {
  for (const plan of ['free', 'standard', 'plus', 'premium'] as const) {
    const copy = buildMarketingFeatures(plan, standardFeatures)
    assert.equal(copy.hi.length, copy.en.length)
    assert.equal(copy.ml.length, copy.en.length)
  }
  const hi = buildMarketingFeatures('standard', standardFeatures).hi
  assert.ok(hi.includes('40 क्रेडिट/दिन'))
})

test('planMarketingUpdate reads system_config and keeps other locales', async () => {
  const client = {
    from: () => ({
      select: () => ({
        in: async () => ({
          data: [
            { key: 'plus_memory_verses_limit', value: '12' },
            { key: 'paid_available_practice_modes', value: JSON.stringify(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) },
          ],
        }),
      }),
    }),
  }
  const update = await planMarketingUpdate(
    client,
    'plus',
    { daily_tokens: 60, voice_conversations_monthly: 10 },
    { ta: ['kept'], hi: ['old'] }
  )
  assert.ok(update)
  assert.ok(update.marketing_features.includes('Review 12 memory verses a day · all 8 practice modes'))
  assert.deepEqual(update.marketing_features_i18n.ta, ['kept'])
  assert.notDeepEqual(update.marketing_features_i18n.hi, ['old'])
})

test('unknown plan codes are left alone', async () => {
  const client = { from: () => assert.fail('should not query') }
  assert.equal(await planMarketingUpdate(client, 'gold', {}, null), null)
})
