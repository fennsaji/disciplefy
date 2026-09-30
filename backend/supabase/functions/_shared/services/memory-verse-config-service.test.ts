// Run with: deno test memory-verse-config-service.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { MemoryVerseConfigService } from './memory-verse-config-service.ts'

/**
 * system-config now keeps one service per worker and feeds it the shared,
 * cached get_system_configs rows. Pinned here: the loader replaces the RPC,
 * the service's own cache hits between calls, the cache age runs from when
 * the rows were read, and a failing loader still yields the defaults.
 */

/** A client whose RPC must not be called when a loader is given. */
const noRpcClient = {
  rpc() {
    throw new Error('rpc must not be called when a rows loader is provided')
  },
}

Deno.test('uses the rows loader instead of the RPC and caches the result', async () => {
  let loads = 0
  const service = new MemoryVerseConfigService(noRpcClient, () => {
    loads++
    return Promise.resolve({
      rows: [{ key: 'free_memory_verses_limit', value: '7' }],
      fetchedAt: Date.now(),
    })
  })

  const first = await service.getMemoryVerseConfig()
  const second = await service.getMemoryVerseConfig()

  assertEquals(first.verseLimits.free, 7)
  assertEquals(second.verseLimits.free, 7)
  assertEquals(loads, 1)
})

Deno.test('cache age runs from when the shared rows were read', async () => {
  let loads = 0
  const service = new MemoryVerseConfigService(noRpcClient, () => {
    loads++
    // Rows read six minutes ago: already past the 5-minute TTL.
    return Promise.resolve({ rows: [], fetchedAt: Date.now() - 6 * 60 * 1000 })
  })

  await service.getMemoryVerseConfig()
  await service.getMemoryVerseConfig()
  assertEquals(loads, 2)
})

Deno.test('a failing loader falls back to the default config', async () => {
  const originalError = console.error
  console.error = () => {}
  try {
    const service = new MemoryVerseConfigService(noRpcClient, () =>
      Promise.reject(new Error('rpc down'))
    )
    const config = await service.getMemoryVerseConfig()
    assertEquals(typeof config.verseLimits.free, 'number')
  } finally {
    console.error = originalError
  }
})

Deno.test('without a loader it still reads get_system_configs', async () => {
  let calls = 0
  const client = {
    rpc(name: string) {
      calls++
      assertEquals(name, 'get_system_configs')
      return Promise.resolve({ data: [{ key: 'plus_memory_verses_limit', value: '12' }], error: null })
    },
  }
  const service = new MemoryVerseConfigService(client)
  const config = await service.getMemoryVerseConfig()
  assertEquals(config.verseLimits.plus, 12)
  assertEquals(calls, 1)
})
