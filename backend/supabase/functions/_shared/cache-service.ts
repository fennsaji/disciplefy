interface CacheEntry {
  value: any;
  expiresAt: number;
}

export class CacheService {
  private cache: Map<string, CacheEntry> = new Map();

  get(key: string): any | null {
    const entry = this.cache.get(key);
    if (entry && entry.expiresAt > Date.now()) {
      return entry.value;
    }
    this.cache.delete(key);
    return null;
  }

  set(key: string, value: any, ttl: number) {
    const expiresAt = Date.now() + ttl;
    this.cache.set(key, { value, expiresAt });
  }
}
