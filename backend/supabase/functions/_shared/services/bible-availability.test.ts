import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { featureFlagEnabled, flagEnabled } from './bible-availability.ts'

Deno.test('flagEnabled: undefined flag -> enabled (fail-open)', () => {
  assertEquals(flagEnabled(undefined), true)
})

Deno.test('flagEnabled: null flag -> enabled', () => {
  assertEquals(flagEnabled(null), true)
})

Deno.test('flagEnabled: is_enabled true -> enabled', () => {
  assertEquals(flagEnabled({ is_enabled: true }), true)
})

Deno.test('flagEnabled: is_enabled false -> disabled', () => {
  assertEquals(flagEnabled({ is_enabled: false }), false)
})

Deno.test('flagEnabled: missing is_enabled -> enabled', () => {
  assertEquals(flagEnabled({}), true)
})

// featureFlagEnabled maps the FeatureFlag camelCase `isEnabled` field. These
// guard the snake_case conversion — a regression (e.g. passing the flag
// straight to flagEnabled) would read `is_enabled` as undefined and wrongly
// report a disabled flag as enabled.
Deno.test('featureFlagEnabled: undefined flag -> enabled (fail-open)', () => {
  assertEquals(featureFlagEnabled(undefined), true)
})

Deno.test('featureFlagEnabled: null flag -> enabled', () => {
  assertEquals(featureFlagEnabled(null), true)
})

Deno.test('featureFlagEnabled: isEnabled true -> enabled', () => {
  assertEquals(featureFlagEnabled({ isEnabled: true }), true)
})

Deno.test('featureFlagEnabled: isEnabled false -> disabled', () => {
  assertEquals(featureFlagEnabled({ isEnabled: false }), false)
})

Deno.test('featureFlagEnabled: missing isEnabled -> enabled', () => {
  assertEquals(featureFlagEnabled({}), true)
})
