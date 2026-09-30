/**
 * Small in-memory cache with per-entry expiry, for one worker's lifetime.
 *
 * Only for global data that is the same for every caller (catalogue rows,
 * pricing, config). Never put user-specific data in one of these: a worker
 * serves many users, and nothing here is keyed by who is asking.
 */
export class TtlCache<V> {
  private readonly entries = new Map<string, { value: V; expiresAt: number }>()

  /**
   * @param defaultTtlMs - lifetime of an entry when `set` is given none
   * @param maxEntries - oldest entries are dropped past this size
   * @param now - clock, injectable for tests
   */
  constructor(
    private readonly defaultTtlMs: number,
    private readonly maxEntries = 1000,
    private readonly now: () => number = Date.now,
  ) {}

  get(key: string): V | undefined {
    const entry = this.entries.get(key)
    if (!entry) return undefined
    if (entry.expiresAt <= this.now()) {
      this.entries.delete(key)
      return undefined
    }
    return entry.value
  }

  has(key: string): boolean {
    return this.get(key) !== undefined
  }

  set(key: string, value: V, ttlMs: number = this.defaultTtlMs): void {
    if (ttlMs <= 0) {
      this.entries.delete(key)
      return
    }
    // Re-inserting moves the key to the end, so the first key is the oldest.
    this.entries.delete(key)
    this.entries.set(key, { value, expiresAt: this.now() + ttlMs })
    while (this.entries.size > this.maxEntries) {
      const oldest = this.entries.keys().next().value
      if (oldest === undefined) break
      this.entries.delete(oldest)
    }
  }

  delete(key: string): void {
    this.entries.delete(key)
  }

  clear(): void {
    this.entries.clear()
  }

  get size(): number {
    return this.entries.size
  }
}

/** Milliseconds from `now` until the next 00:00 UTC. */
export function msUntilNextUtcMidnight(now: Date = new Date()): number {
  const next = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1)
  return next - now.getTime()
}

/**
 * Cache-Control for responses that carry only global, non-user data
 * (catalogues, pricing, config): browsers and CDNs may reuse them for five
 * minutes and serve a stale copy for up to an hour while revalidating.
 */
export const PUBLIC_CACHE_CONTROL = 'public, max-age=300, stale-while-revalidate=3600'
