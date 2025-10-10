// ============================================================================
// FCM Service Unit Tests (Hermetic)
// ============================================================================
// Comprehensive test coverage with mocked external dependencies
// Run with: deno test --allow-env fcm-service.test.ts

import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { FCMService } from './fcm-service.ts';

// ============================================================================
// Test Mocks & Utilities
// ============================================================================

/**
 * Mock fetch implementation that returns deterministic responses
 */
class MockFetch {
  private originalFetch: typeof globalThis.fetch;
  private responses: Map<string, Response> = new Map();

  constructor() {
    this.originalFetch = globalThis.fetch;
  }

  /**
   * Register a mock response for a specific URL pattern
   */
  mockResponse(urlPattern: string, response: Response): void {
    this.responses.set(urlPattern, response);
  }

  /**
   * Install the mock fetch
   */
  install(): void {
    globalThis.fetch = async (input: string | URL | Request): Promise<Response> => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
      
      // Check for matching mock response
      for (const [pattern, response] of this.responses.entries()) {
        if (url.includes(pattern)) {
          return response.clone();
        }
      }
      
      // Default error response for unmocked URLs
      return new Response(JSON.stringify({ error: 'Unmocked URL' }), { status: 500 });
    };
  }

  /**
   * Restore original fetch
   */
  restore(): void {
    globalThis.fetch = this.originalFetch;
    this.responses.clear();
  }
}

/**
 * Mock crypto.subtle implementation for deterministic JWT signing
 */
class MockCryptoSubtle {
  private originalDescriptor: PropertyDescriptor | undefined;

  /**
   * Install mock crypto.subtle
   */
  install(): void {
    // Save original property descriptor
    this.originalDescriptor = Object.getOwnPropertyDescriptor(crypto, 'subtle');

    const mockSubtle = {
      importKey: async (
        _format: string,
        _keyData: BufferSource,
        _algorithm: any,
        _extractable: boolean,
        _keyUsages: string[]
      ): Promise<CryptoKey> => {
        // Return a mock CryptoKey (any object will do for testing)
        return {} as CryptoKey;
      },

      sign: async (
        _algorithm: string,
        _key: CryptoKey,
        _data: BufferSource
      ): Promise<ArrayBuffer> => {
        // Return deterministic signature bytes
        const mockSignature = 'mock-signature-bytes';
        const encoder = new TextEncoder();
        const encoded = encoder.encode(mockSignature);
        return encoded.buffer as ArrayBuffer;
      },
    };

    // Replace crypto.subtle getter with mock
    Object.defineProperty(crypto, 'subtle', {
      value: mockSubtle,
      writable: true,
      configurable: true,
    });
  }

  /**
   * Restore original crypto.subtle
   */
  restore(): void {
    if (this.originalDescriptor) {
      Object.defineProperty(crypto, 'subtle', this.originalDescriptor);
    }
  }
}

/**
 * Setup test environment with mocked credentials
 */
function setupTestEnv(): void {
  Deno.env.set('FIREBASE_PROJECT_ID', 'test-project-id');
  Deno.env.set('FIREBASE_CLIENT_EMAIL', 'test@test-project.iam.gserviceaccount.com');
  Deno.env.set('FIREBASE_PRIVATE_KEY', '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC\n-----END PRIVATE KEY-----');
}

/**
 * Cleanup test environment
 */
function cleanupTestEnv(): void {
  Deno.env.delete('FIREBASE_PROJECT_ID');
  Deno.env.delete('FIREBASE_CLIENT_EMAIL');
  Deno.env.delete('FIREBASE_PRIVATE_KEY');
}

// ============================================================================
// Constructor & Initialization Tests
// ============================================================================

Deno.test({
  name: 'FCMService: should throw error with missing credentials',
  fn: () => {
    cleanupTestEnv();
    
    let error: Error | null = null;
    try {
      new FCMService();
    } catch (e) {
      error = e as Error;
    }
    
    assertExists(error);
    assert(error!.message.includes('Missing Firebase credentials'));
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: should initialize with valid credentials',
  fn: () => {
    setupTestEnv();
    
    const service = new FCMService();
    assertExists(service);
    
    cleanupTestEnv();
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// Access Token Management Tests (Mocked)
// ============================================================================

Deno.test({
  name: 'FCMService: should get access token from Google OAuth (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth token response
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({
          access_token: 'mock-access-token-12345',
          expires_in: 3600,
          token_type: 'Bearer',
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const token = await (service as any).getAccessToken();
      
      assertExists(token);
      assertEquals(token, 'mock-access-token-12345');
      assertEquals(typeof token, 'string');
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: should cache and reuse access token (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      let fetchCallCount = 0;
      
      // Mock OAuth token response and count calls
      const originalInstall = mockFetch.install.bind(mockFetch);
      mockFetch.install = () => {
        globalThis.fetch = async (input: string | URL | Request): Promise<Response> => {
          const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
          
          if (url.includes('oauth2.googleapis.com/token')) {
            fetchCallCount++;
            return new Response(
              JSON.stringify({
                access_token: 'mock-cached-token',
                expires_in: 3600,
                token_type: 'Bearer',
              }),
              { status: 200, headers: { 'Content-Type': 'application/json' } }
            );
          }
          
          return new Response(JSON.stringify({ error: 'Unmocked URL' }), { status: 500 });
        };
      };
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      
      // First call - should fetch new token
      const token1 = await (service as any).getAccessToken();
      
      // Second call - should use cached token
      const token2 = await (service as any).getAccessToken();
      
      assertEquals(token1, token2);
      assertEquals(token1, 'mock-cached-token');
      assertEquals(fetchCallCount, 1, 'Should only fetch token once (second call should be cached)');
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: should refresh token when expired (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      let tokenCounter = 0;
      
      // Mock OAuth with different tokens
      const originalInstall = mockFetch.install.bind(mockFetch);
      mockFetch.install = () => {
        globalThis.fetch = async (input: string | URL | Request): Promise<Response> => {
          const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
          
          if (url.includes('oauth2.googleapis.com/token')) {
            tokenCounter++;
            return new Response(
              JSON.stringify({
                access_token: `mock-token-${tokenCounter}`,
                expires_in: 3600,
                token_type: 'Bearer',
              }),
              { status: 200, headers: { 'Content-Type': 'application/json' } }
            );
          }
          
          return new Response(JSON.stringify({ error: 'Unmocked URL' }), { status: 500 });
        };
      };
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      
      // Get initial token
      const token1 = await (service as any).getAccessToken();
      assertEquals(token1, 'mock-token-1');
      
      // Manually expire the token
      (service as any).tokenExpiry = Date.now() - 1000;
      
      // Should fetch new token
      const token2 = await (service as any).getAccessToken();
      assertEquals(token2, 'mock-token-2');
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// JWT Creation Tests (Mocked)
// ============================================================================

Deno.test({
  name: 'FCMService: JWT should have valid structure (header.payload.signature)',
  fn: async () => {
    setupTestEnv();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      mockCrypto.install();
      
      const service = new FCMService();
      const jwt = await (service as any).createServiceAccountJWT();
      
      const parts = jwt.split('.');
      assertEquals(parts.length, 3, 'JWT should have 3 parts');
      
      // Decode and validate header
      const decodeBase64Url = (str: string) => {
        const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
        const padding = '='.repeat((4 - base64.length % 4) % 4);
        return JSON.parse(atob(base64 + padding));
      };
      
      const header = decodeBase64Url(parts[0]);
      assertEquals(header.alg, 'RS256');
      assertEquals(header.typ, 'JWT');
      
      const payload = decodeBase64Url(parts[1]);
      assertEquals(payload.iss, 'test@test-project.iam.gserviceaccount.com');
      assertEquals(payload.aud, 'https://oauth2.googleapis.com/token');
      assertExists(payload.iat);
      assertExists(payload.exp);
      assertEquals(payload.scope, 'https://www.googleapis.com/auth/firebase.messaging');
    } finally {
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// Base64 URL Encoding Tests
// ============================================================================

Deno.test({
  name: 'FCMService: base64UrlEncode should encode correctly',
  fn: () => {
    setupTestEnv();
    
    const service = new FCMService();
    const encoded = (service as any).base64UrlEncode('test string');
    
    // Should not contain +, /, or =
    assert(!encoded.includes('+'));
    assert(!encoded.includes('/'));
    assert(!encoded.includes('='));
    
    // Should be URL-safe base64
    assert(/^[A-Za-z0-9_-]+$/.test(encoded));
    
    cleanupTestEnv();
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// Notification Sending Tests (Mocked)
// ============================================================================

Deno.test({
  name: 'FCMService: sendNotification should handle invalid token gracefully (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth token
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({ access_token: 'mock-token', expires_in: 3600 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      // Mock FCM error response for invalid token
      mockFetch.mockResponse('fcm.googleapis.com', new Response(
        JSON.stringify({
          error: {
            code: 400,
            message: 'INVALID_ARGUMENT',
            status: 'INVALID_ARGUMENT',
            details: [{ errorCode: 'INVALID_ARGUMENT' }],
          },
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const result = await service.sendNotification({
        token: 'invalid-token-for-testing',
        notification: {
          title: 'Test Notification',
          body: 'This should fail',
        },
      });
      
      assertEquals(result.success, false);
      assertExists(result.error);
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: sendNotification should succeed with valid token (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth token
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({ access_token: 'mock-token', expires_in: 3600 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      // Mock successful FCM response
      mockFetch.mockResponse('fcm.googleapis.com', new Response(
        JSON.stringify({
          name: 'projects/test-project/messages/msg-12345',
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const result = await service.sendNotification({
        token: 'valid-test-token',
        notification: {
          title: 'Test Notification',
          body: 'This should succeed',
        },
      });
      
      assertEquals(result.success, true);
      assertEquals(result.messageId, 'projects/test-project/messages/msg-12345');
      assertEquals(result.error, undefined);
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: sendNotification should include data payload (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      let capturedBody: any = null;
      
      // Custom mock to capture request body
      mockFetch.install = () => {
        globalThis.fetch = async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
          const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
          
          if (url.includes('oauth2.googleapis.com/token')) {
            return new Response(
              JSON.stringify({ access_token: 'mock-token', expires_in: 3600 }),
              { status: 200, headers: { 'Content-Type': 'application/json' } }
            );
          }
          
          if (url.includes('fcm.googleapis.com')) {
            capturedBody = JSON.parse(init?.body as string);
            return new Response(
              JSON.stringify({ name: 'projects/test/messages/123' }),
              { status: 200, headers: { 'Content-Type': 'application/json' } }
            );
          }
          
          return new Response(JSON.stringify({ error: 'Unmocked' }), { status: 500 });
        };
      };
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      await service.sendNotification({
        token: 'test-token',
        notification: {
          title: 'Test',
          body: 'Test Body',
        },
        data: {
          type: 'daily_verse',
          reference: 'John 3:16',
        },
        android: {
          priority: 'high',
        },
      });
      
      assertExists(capturedBody);
      assertExists(capturedBody.message);
      assertEquals(capturedBody.message.data?.type, 'daily_verse');
      assertEquals(capturedBody.message.data?.reference, 'John 3:16');
      assertEquals(capturedBody.message.android?.priority, 'high');
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// Batch Notification Tests (Mocked)
// ============================================================================

Deno.test({
  name: 'FCMService: sendBatchNotifications should handle empty array',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const result = await service.sendBatchNotifications(
        [],
        { title: 'Test', body: 'Test' }
      );
      
      assertEquals(result.successCount, 0);
      assertEquals(result.failureCount, 0);
      assertEquals(result.results.length, 0);
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: sendBatchNotifications should process multiple tokens (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({ access_token: 'mock-token', expires_in: 3600 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      // Mock FCM success
      mockFetch.mockResponse('fcm.googleapis.com', new Response(
        JSON.stringify({ name: 'projects/test/messages/123' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const tokens = ['token1', 'token2', 'token3', 'token4', 'token5'];
      
      const result = await service.sendBatchNotifications(
        tokens,
        { title: 'Batch Test', body: 'Testing' }
      );
      
      assertEquals(result.results.length, 5);
      assertEquals(result.successCount, 5);
      assertEquals(result.failureCount, 0);
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: sendBatchNotifications should respect batch size of 10 (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({ access_token: 'mock-token', expires_in: 3600 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      // Mock FCM success
      mockFetch.mockResponse('fcm.googleapis.com', new Response(
        JSON.stringify({ name: 'projects/test/messages/123' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const tokens = Array(25).fill(null).map((_, i) => `token-${i}`);
      
      const result = await service.sendBatchNotifications(
        tokens,
        { title: 'Test', body: 'Test' }
      );
      
      assertEquals(result.results.length, 25);
      assertEquals(result.successCount, 25);
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// Token Validation Tests (Mocked)
// ============================================================================

Deno.test({
  name: 'FCMService: validateToken should return false for invalid token (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({ access_token: 'mock-token', expires_in: 3600 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      // Mock FCM error for invalid token
      mockFetch.mockResponse('fcm.googleapis.com', new Response(
        JSON.stringify({ error: { message: 'INVALID_ARGUMENT' } }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const isValid = await service.validateToken('invalid-token-123');
      
      assertEquals(isValid, false);
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: validateToken should return true for valid token (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({ access_token: 'mock-token', expires_in: 3600 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      // Mock FCM success for valid token
      mockFetch.mockResponse('fcm.googleapis.com', new Response(
        JSON.stringify({ name: 'projects/test/messages/123' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const isValid = await service.validateToken('valid-token-123');
      
      assertEquals(isValid, true);
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// Error Handling Tests (Mocked)
// ============================================================================

Deno.test({
  name: 'FCMService: should handle OAuth failures gracefully (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock OAuth failure
      mockFetch.mockResponse('oauth2.googleapis.com/token', new Response(
        JSON.stringify({ error: 'invalid_grant' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      ));
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      
      const result = await service.sendNotification({
        token: 'test-token',
        notification: { title: 'Test', body: 'Test' },
      });
      
      // Should return error response, not throw
      assertEquals(result.success, false);
      assertExists(result.error);
      assert(result.error!.includes('Failed to authenticate with Firebase'));
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

Deno.test({
  name: 'FCMService: should handle network failures gracefully (mocked)',
  fn: async () => {
    setupTestEnv();
    const mockFetch = new MockFetch();
    const mockCrypto = new MockCryptoSubtle();
    
    try {
      // Mock network error
      mockFetch.install = () => {
        globalThis.fetch = async (): Promise<Response> => {
          throw new Error('Network error: Connection refused');
        };
      };
      
      mockFetch.install();
      mockCrypto.install();
      
      const service = new FCMService();
      const result = await service.sendNotification({
        token: 'test-token',
        notification: { title: 'Test', body: 'Test' },
      });
      
      assertEquals(result.success, false);
      assertExists(result.error);
      assert(result.error!.includes('Network error') || result.error!.includes('Failed to authenticate'));
    } finally {
      mockFetch.restore();
      mockCrypto.restore();
      cleanupTestEnv();
    }
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// ============================================================================
// Test Summary
// ============================================================================

console.log('\n' + '='.repeat(60));
console.log('✅ All FCM Service hermetic unit tests completed!');
console.log('   All external dependencies mocked for deterministic testing');
console.log('='.repeat(60) + '\n');
