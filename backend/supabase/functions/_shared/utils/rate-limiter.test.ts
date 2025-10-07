// ============================================================================
// Rate Limiter Unit Tests
// ============================================================================
// Tests for the in-memory rate limiter used to protect service role endpoints
// Run with: deno test --allow-env rate-limiter.test.ts

import { assertEquals, assert } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { RateLimiter, getRequestIdentifier } from './rate-limiter.ts';

// ============================================================================
// Rate Limiter Tests
// ============================================================================

Deno.test({
  name: 'RateLimiter: should allow requests within limit',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 5,
    });

    const identifier = '192.168.1.1';

    // All 5 requests should be allowed
    for (let i = 0; i < 5; i++) {
      const allowed = limiter.allow(identifier);
      assertEquals(allowed, true, `Request ${i + 1} should be allowed`);
    }

    // 6th request should be blocked
    const blocked = limiter.allow(identifier);
    assertEquals(blocked, false, '6th request should be blocked');
  },
});

Deno.test({
  name: 'RateLimiter: should track separate identifiers independently',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 3,
    });

    const ip1 = '192.168.1.1';
    const ip2 = '192.168.1.2';

    // Use up ip1's limit
    for (let i = 0; i < 3; i++) {
      assertEquals(limiter.allow(ip1), true);
    }
    assertEquals(limiter.allow(ip1), false, 'ip1 should be rate limited');

    // ip2 should still have full quota
    for (let i = 0; i < 3; i++) {
      assertEquals(limiter.allow(ip2), true);
    }
    assertEquals(limiter.allow(ip2), false, 'ip2 should be rate limited');
  },
});

Deno.test({
  name: 'RateLimiter: should reset after window expires',
  fn: async () => {
    const limiter = new RateLimiter({
      windowMs: 100, // 100ms window for fast testing
      maxRequests: 2,
    });

    const identifier = '192.168.1.1';

    // Use up quota
    assertEquals(limiter.allow(identifier), true);
    assertEquals(limiter.allow(identifier), true);
    assertEquals(limiter.allow(identifier), false, 'Should be rate limited');

    // Wait for window to expire
    await new Promise(resolve => setTimeout(resolve, 150));

    // Should be allowed again
    assertEquals(limiter.allow(identifier), true, 'Should allow after window reset');
  },
});

Deno.test({
  name: 'RateLimiter: should return correct remaining count',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 5,
    });

    const identifier = '192.168.1.1';

    assertEquals(limiter.getRemaining(identifier), 5, 'Should start with 5');

    limiter.allow(identifier);
    assertEquals(limiter.getRemaining(identifier), 4, 'Should have 4 remaining');

    limiter.allow(identifier);
    limiter.allow(identifier);
    assertEquals(limiter.getRemaining(identifier), 2, 'Should have 2 remaining');

    limiter.allow(identifier);
    limiter.allow(identifier);
    assertEquals(limiter.getRemaining(identifier), 0, 'Should have 0 remaining');
  },
});

Deno.test({
  name: 'RateLimiter: should return correct reset time',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 5,
    });

    const identifier = '192.168.1.1';
    const before = Date.now();

    limiter.allow(identifier);

    const resetTime = limiter.getResetTime(identifier);
    const after = Date.now();

    // Reset time should be roughly 60 seconds from now
    assert(resetTime >= before + 60 * 1000, 'Reset time should be at least 60s in future');
    assert(resetTime <= after + 60 * 1000 + 100, 'Reset time should not be too far in future');
  },
});

Deno.test({
  name: 'RateLimiter: reset() should clear rate limit for identifier',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 2,
    });

    const identifier = '192.168.1.1';

    // Use up quota
    limiter.allow(identifier);
    limiter.allow(identifier);
    assertEquals(limiter.allow(identifier), false, 'Should be rate limited');

    // Reset
    limiter.reset(identifier);

    // Should be allowed again immediately
    assertEquals(limiter.allow(identifier), true, 'Should allow after reset');
    assertEquals(limiter.getRemaining(identifier), 1, 'Should have correct remaining count');
  },
});

Deno.test({
  name: 'RateLimiter: should handle null identifier gracefully',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 2,
    });

    // Null identifier should always be allowed (fail open)
    assertEquals(limiter.allow(null), true);
    assertEquals(limiter.allow(null), true);
    assertEquals(limiter.allow(null), true);
  },
});

Deno.test({
  name: 'RateLimiter: getStats() should return correct statistics',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 5,
    });

    // Initially empty
    let stats = limiter.getStats();
    assertEquals(stats.totalTracked, 0);
    assertEquals(stats.activeWindows, 0);

    // Add some identifiers
    limiter.allow('192.168.1.1');
    limiter.allow('192.168.1.2');
    limiter.allow('192.168.1.3');

    stats = limiter.getStats();
    assertEquals(stats.totalTracked, 3);
    assertEquals(stats.activeWindows, 3);
  },
});

// ============================================================================
// Request Identifier Extraction Tests
// ============================================================================

Deno.test({
  name: 'getRequestIdentifier: should extract x-forwarded-for',
  fn: () => {
    const req = new Request('http://localhost', {
      headers: { 'x-forwarded-for': '192.168.1.1' }
    });

    const identifier = getRequestIdentifier(req);
    assertEquals(identifier, '192.168.1.1');
  },
});

Deno.test({
  name: 'getRequestIdentifier: should extract first IP from comma-separated list',
  fn: () => {
    const req = new Request('http://localhost', {
      headers: { 'x-forwarded-for': '192.168.1.1, 10.0.0.1, 172.16.0.1' }
    });

    const identifier = getRequestIdentifier(req);
    assertEquals(identifier, '192.168.1.1');
  },
});

Deno.test({
  name: 'getRequestIdentifier: should try x-real-ip as fallback',
  fn: () => {
    const req = new Request('http://localhost', {
      headers: { 'x-real-ip': '10.0.0.1' }
    });

    const identifier = getRequestIdentifier(req);
    assertEquals(identifier, '10.0.0.1');
  },
});

Deno.test({
  name: 'getRequestIdentifier: should prioritize x-forwarded-for over x-real-ip',
  fn: () => {
    const req = new Request('http://localhost', {
      headers: {
        'x-forwarded-for': '192.168.1.1',
        'x-real-ip': '10.0.0.1'
      }
    });

    const identifier = getRequestIdentifier(req);
    assertEquals(identifier, '192.168.1.1');
  },
});

Deno.test({
  name: 'getRequestIdentifier: should return null when no IP headers present',
  fn: () => {
    const req = new Request('http://localhost');

    const identifier = getRequestIdentifier(req);
    assertEquals(identifier, null);
  },
});

Deno.test({
  name: 'getRequestIdentifier: should handle Cloudflare header',
  fn: () => {
    const req = new Request('http://localhost', {
      headers: { 'cf-connecting-ip': '1.2.3.4' }
    });

    const identifier = getRequestIdentifier(req);
    assertEquals(identifier, '1.2.3.4');
  },
});

// ============================================================================
// Integration Test
// ============================================================================

Deno.test({
  name: 'Integration: rate limiter with request identifier extraction',
  fn: () => {
    const limiter = new RateLimiter({
      windowMs: 60 * 1000,
      maxRequests: 3,
    });

    // Simulate multiple requests from same IP
    const req1 = new Request('http://localhost', {
      headers: { 'x-forwarded-for': '192.168.1.100' }
    });
    const req2 = new Request('http://localhost', {
      headers: { 'x-forwarded-for': '192.168.1.100' }
    });
    const req3 = new Request('http://localhost', {
      headers: { 'x-forwarded-for': '192.168.1.100' }
    });
    const req4 = new Request('http://localhost', {
      headers: { 'x-forwarded-for': '192.168.1.100' }
    });

    const ip1 = getRequestIdentifier(req1);
    const ip2 = getRequestIdentifier(req2);
    const ip3 = getRequestIdentifier(req3);
    const ip4 = getRequestIdentifier(req4);

    assertEquals(limiter.allow(ip1), true, 'Request 1 should be allowed');
    assertEquals(limiter.allow(ip2), true, 'Request 2 should be allowed');
    assertEquals(limiter.allow(ip3), true, 'Request 3 should be allowed');
    assertEquals(limiter.allow(ip4), false, 'Request 4 should be blocked');

    // Different IP should have separate quota
    const req5 = new Request('http://localhost', {
      headers: { 'x-forwarded-for': '10.0.0.1' }
    });
    const ip5 = getRequestIdentifier(req5);
    assertEquals(limiter.allow(ip5), true, 'Different IP should be allowed');
  },
});

// ============================================================================
// Test Summary
// ============================================================================

console.log('\n' + '='.repeat(60));
console.log('✅ All Rate Limiter tests completed successfully!');
console.log('='.repeat(60) + '\n');
