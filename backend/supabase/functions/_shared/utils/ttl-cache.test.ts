// Run with: deno test ttl-cache.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { TtlCache, msUntilNextUtcMidnight } from './ttl-cache.ts'

/** A clock the test moves by hand. */
function fakeClock(start = 1_000_000) {
  let now = start
  return { now: () => now, advance: (ms: number) => { now += ms } }
}

Deno.test('TtlCache serves a value until its TTL passes, then forgets it', () => {
  const clock = fakeClock()
  const cache = new TtlCache<number>(1000, 10, clock.now)
  cache.set('a', 1)

  clock.advance(999)
  assertEquals(cache.get('a'), 1)

  clock.advance(1)
  assertEquals(cache.get('a'), undefined)
  assertEquals(cache.size, 0)
})

Deno.test('TtlCache honours a per-entry TTL over the default', () => {
  const clock = fakeClock()
  const cache = new TtlCache<string>(10_000, 10, clock.now)
  cache.set('short', 'x', 100)
  cache.set('long', 'y')

  clock.advance(100)
  assertEquals(cache.get('short'), undefined)
  assertEquals(cache.get('long'), 'y')
})

Deno.test('TtlCache keeps falsy values such as 0 and null', () => {
  const cache = new TtlCache<number | null>(1000)
  cache.set('zero', 0)
  cache.set('none', null)
  assertEquals(cache.get('zero'), 0)
  assertEquals(cache.get('none'), null)
  assertEquals(cache.has('zero'), true)
  assertEquals(cache.has('none'), true)
})

Deno.test('TtlCache does not store an entry with a TTL of zero or less', () => {
  const cache = new TtlCache<number>(1000)
  cache.set('a', 1)
  cache.set('a', 2, 0)
  assertEquals(cache.get('a'), undefined)
  cache.set('b', 3, -5)
  assertEquals(cache.has('b'), false)
})

Deno.test('TtlCache drops the oldest entry past its size limit', () => {
  const cache = new TtlCache<number>(1000, 2)
  cache.set('a', 1)
  cache.set('b', 2)
  cache.set('a', 11) // refreshed: now newer than b
  cache.set('c', 3)
  assertEquals(cache.get('b'), undefined)
  assertEquals(cache.get('a'), 11)
  assertEquals(cache.get('c'), 3)
})

Deno.test('TtlCache delete and clear remove entries', () => {
  const cache = new TtlCache<number>(1000)
  cache.set('a', 1)
  cache.set('b', 2)
  cache.delete('a')
  assertEquals(cache.get('a'), undefined)
  cache.clear()
  assertEquals(cache.size, 0)
})

Deno.test('msUntilNextUtcMidnight counts to the next 00:00 UTC', () => {
  assertEquals(msUntilNextUtcMidnight(new Date('2026-09-30T23:59:00Z')), 60_000)
  assertEquals(msUntilNextUtcMidnight(new Date('2026-09-30T00:00:00Z')), 24 * 3600_000)
  // Month and year roll over.
  assertEquals(msUntilNextUtcMidnight(new Date('2026-12-31T12:00:00Z')), 12 * 3600_000)
})
