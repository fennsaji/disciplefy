// ============================================================================
// Rate Limiter Utility
// ============================================================================
// Simple in-memory rate limiter for Edge Functions
// Prevents abuse of service role endpoints if credentials are compromised
//
// NOTE: This is an in-memory implementation that resets on function cold starts.
// For production with multiple instances, consider using Redis or Supabase.

/**
 * Rate limiter configuration
 */
export interface RateLimiterConfig {
  /** Time window in milliseconds */
  readonly windowMs: number;
  /** Maximum requests allowed per window */
  readonly maxRequests: number;
}

/**
 * Request tracking data
 */
interface RequestTracker {
  count: number;
  windowStart: number;
}

/**
 * Simple in-memory rate limiter using sliding window
 */
export class RateLimiter {
  private readonly config: Required<RateLimiterConfig>;
  private readonly requests: Map<string, RequestTracker>;
  private cleanupInterval?: number;

  constructor(config: RateLimiterConfig) {
    this.config = config;
    this.requests = new Map();

    // Clean up old entries every 5 minutes (optional in tests)
    if (typeof Deno !== 'undefined' && Deno.env.get('DENO_TESTING') !== 'true') {
      this.cleanupInterval = setInterval(() => this.cleanup(), 5 * 60 * 1000);
    }
  }

  /**
   * Stop cleanup interval (for testing and cleanup)
   */
  destroy(): void {
    if (this.cleanupInterval !== undefined) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = undefined;
    }
  }

  /**
   * Check if a request should be allowed
   *
   * @param identifier - Unique identifier (IP address, user ID, etc.)
   * @returns true if request is allowed, false if rate limit exceeded
   */
  allow(identifier: string | null): boolean {
    // Allow if no identifier (fail open for better UX)
    if (!identifier) {
      console.warn('[RateLimiter] No identifier provided, allowing request');
      return true;
    }

    const now = Date.now();
    const tracker = this.requests.get(identifier);

    // First request or window expired
    if (!tracker || now - tracker.windowStart >= this.config.windowMs) {
      this.requests.set(identifier, {
        count: 1,
        windowStart: now,
      });
      return true;
    }

    // Within window, check count
    if (tracker.count < this.config.maxRequests) {
      tracker.count++;
      return true;
    }

    // Rate limit exceeded
    console.warn(
      `[RateLimiter] Rate limit exceeded for ${identifier}: ` +
      `${tracker.count} requests in ${Math.round((now - tracker.windowStart) / 1000)}s`
    );
    return false;
  }

  /**
   * Get remaining requests for an identifier
   *
   * @param identifier - Unique identifier
   * @returns Number of remaining requests in current window
   */
  getRemaining(identifier: string): number {
    const tracker = this.requests.get(identifier);
    if (!tracker) return this.config.maxRequests;

    const now = Date.now();
    if (now - tracker.windowStart >= this.config.windowMs) {
      return this.config.maxRequests;
    }

    return Math.max(0, this.config.maxRequests - tracker.count);
  }

  /**
   * Get reset time for an identifier
   *
   * @param identifier - Unique identifier
   * @returns Timestamp when the rate limit window resets
   */
  getResetTime(identifier: string): number {
    const tracker = this.requests.get(identifier);
    if (!tracker) return Date.now();

    return tracker.windowStart + this.config.windowMs;
  }

  /**
   * Clean up expired entries
   */
  private cleanup(): void {
    const now = Date.now();
    let cleaned = 0;

    for (const [identifier, tracker] of this.requests.entries()) {
      if (now - tracker.windowStart >= this.config.windowMs) {
        this.requests.delete(identifier);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      console.log(`[RateLimiter] Cleaned up ${cleaned} expired entries`);
    }
  }

  /**
   * Reset rate limit for a specific identifier
   * Useful for testing or manual intervention
   *
   * @param identifier - Unique identifier to reset
   */
  reset(identifier: string): void {
    this.requests.delete(identifier);
    console.log(`[RateLimiter] Reset rate limit for ${identifier}`);
  }

  /**
   * Get current stats for monitoring
   */
  getStats(): {
    totalTracked: number;
    activeWindows: number;
  } {
    const now = Date.now();
    let activeWindows = 0;

    for (const tracker of this.requests.values()) {
      if (now - tracker.windowStart < this.config.windowMs) {
        activeWindows++;
      }
    }

    return {
      totalTracked: this.requests.size,
      activeWindows,
    };
  }
}

/**
 * Default rate limiter for service role endpoints
 * 10 requests per minute per IP address
 */
export const defaultServiceRoleLimiter = new RateLimiter({
  windowMs: 60 * 1000, // 1 minute
  maxRequests: 10,
});

/**
 * Extract identifier from request (IP address)
 *
 * @param req - Incoming request
 * @returns IP address or null
 */
export function getRequestIdentifier(req: Request): string | null {
  // Try multiple headers (in order of preference)
  const headers = [
    'x-forwarded-for',
    'x-real-ip',
    'cf-connecting-ip', // Cloudflare
    'x-client-ip',
  ];

  for (const header of headers) {
    const value = req.headers.get(header);
    if (value) {
      // x-forwarded-for can be a comma-separated list, take the first
      return value.split(',')[0].trim();
    }
  }

  return null;
}
