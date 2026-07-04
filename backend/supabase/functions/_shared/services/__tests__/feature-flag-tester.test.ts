import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  normalizeEmail,
  parseTesterEmails,
  applyTesterBypass,
  FeatureFlag,
} from '../feature-flag-service.ts'

function makeFlag(overrides: Partial<FeatureFlag> = {}): FeatureFlag {
  return {
    featureKey: 'enable_new_subscriptions',
    featureName: 'New Subscriptions',
    isEnabled: false,
    enabledForPlans: ['free', 'standard', 'plus', 'premium'],
    rolloutPercentage: 100,
    displayMode: 'hide',
    metadata: {},
    allowTesterBypass: false,
    ...overrides,
  }
}

Deno.test('normalizeEmail lowercases and trims', () => {
  assertEquals(normalizeEmail('  Fenn.Saji@GMAIL.com '), 'fenn.saji@gmail.com')
})

Deno.test('parseTesterEmails splits, normalizes, drops empties', () => {
  assertEquals(
    parseTesterEmails(' A@b.com, ,C@D.com ,'),
    ['a@b.com', 'c@d.com']
  )
  assertEquals(parseTesterEmails(''), [])
  assertEquals(parseTesterEmails(null), [])
  assertEquals(parseTesterEmails(undefined), [])
})

Deno.test('applyTesterBypass: tester + toggle on -> enabled', () => {
  const flags = [makeFlag({ isEnabled: false, allowTesterBypass: true })]
  const result = applyTesterBypass(flags, true)
  assertEquals(result[0].isEnabled, true)
})

Deno.test('applyTesterBypass: tester + toggle off -> unchanged', () => {
  const flags = [makeFlag({ isEnabled: false, allowTesterBypass: false })]
  const result = applyTesterBypass(flags, true)
  assertEquals(result[0].isEnabled, false)
})

Deno.test('applyTesterBypass: non-tester -> unchanged', () => {
  const flags = [makeFlag({ isEnabled: false, allowTesterBypass: true })]
  const result = applyTesterBypass(flags, false)
  assertEquals(result[0].isEnabled, false)
})

Deno.test('applyTesterBypass: does not disable already-enabled flags', () => {
  const flags = [makeFlag({ isEnabled: true, allowTesterBypass: true })]
  const result = applyTesterBypass(flags, true)
  assertEquals(result[0].isEnabled, true)
})

Deno.test('applyTesterBypass: does not mutate input array', () => {
  const flag = makeFlag({ isEnabled: false, allowTesterBypass: true })
  applyTesterBypass([flag], true)
  assertEquals(flag.isEnabled, false)
})

Deno.test('applyTesterBypass: plans and displayMode untouched', () => {
  const flags = [makeFlag({
    isEnabled: false,
    allowTesterBypass: true,
    enabledForPlans: ['premium'],
    displayMode: 'lock',
  })]
  const result = applyTesterBypass(flags, true)
  assertEquals(result[0].enabledForPlans, ['premium'])
  assertEquals(result[0].displayMode, 'lock')
})
