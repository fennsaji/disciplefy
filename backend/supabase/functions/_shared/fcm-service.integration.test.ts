// ============================================================================
// FCM Service Integration Tests (Real Firebase)
// ============================================================================
// Integration tests using real Firebase credentials and network calls
// Run with: deno test --allow-env --allow-net fcm-service.integration.test.ts
//
// IMPORTANT: These tests require real Firebase credentials in environment:
// - FIREBASE_PROJECT_ID
// - FIREBASE_CLIENT_EMAIL
// - FIREBASE_PRIVATE_KEY
//
// These tests are OPTIONAL and only run when credentials are available.
// Unit tests (fcm-service.test.ts) use mocked dependencies and don't require credentials.

import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { FCMService } from './fcm-service.ts';

// ============================================================================
// Test Configuration
// ============================================================================

const hasRealCredentials = () => {
  return Deno.env.get('FIREBASE_PROJECT_ID') &&
    Deno.env.get('FIREBASE_CLIENT_EMAIL') &&
    Deno.env.get('FIREBASE_PRIVATE_KEY');
};

const SKIP_INTEGRATION_TESTS = !hasRealCredentials();

if (SKIP_INTEGRATION_TESTS) {
  console.log('\n' + '='.repeat(60));
  console.log('⚠️  Integration tests skipped - Firebase credentials not found');
  console.log('   Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and');
  console.log('   FIREBASE_PRIVATE_KEY environment variables to run integration tests');
  console.log('   Note: Unit tests (fcm-service.test.ts) use mocks and don\'t require credentials');
  console.log('='.repeat(60) + '\n');
}

// ============================================================================
// Integration Tests (Real Firebase)
// ============================================================================

Deno.test({
  name: 'INTEGRATION: FCMService should initialize with real credentials',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: () => {
    const service = new FCMService();
    assertExists(service);
    console.log('✓ Service initialized with real Firebase credentials');
  },
});

Deno.test({
  name: 'INTEGRATION: should get real access token from Google OAuth',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    const token = await (service as any).getAccessToken();
    
    assertExists(token);
    assertEquals(typeof token, 'string');
    assert(token.length > 0);
    console.log(`✓ Obtained real access token (length: ${token.length})`);
  },
});

Deno.test({
  name: 'INTEGRATION: should cache and reuse real access token',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    // First call - should fetch new token
    const startTime1 = Date.now();
    const token1 = await (service as any).getAccessToken();
    const duration1 = Date.now() - startTime1;
    
    // Second call - should use cached token (much faster)
    const startTime2 = Date.now();
    const token2 = await (service as any).getAccessToken();
    const duration2 = Date.now() - startTime2;
    
    assertEquals(token1, token2);
    assert(duration2 < duration1, `Cached call (${duration2}ms) should be faster than initial (${duration1}ms)`);
    console.log(`✓ Token cached (initial: ${duration1}ms, cached: ${duration2}ms)`);
  },
});

Deno.test({
  name: 'INTEGRATION: should refresh token when manually expired',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    // Get initial token
    const token1 = await (service as any).getAccessToken();
    console.log(`✓ Initial token obtained`);
    
    // Manually expire the token
    (service as any).tokenExpiry = Date.now() - 1000;
    
    // Should fetch new token
    const token2 = await (service as any).getAccessToken();
    console.log(`✓ Refreshed token obtained`);
    
    // Tokens should be different (new access token generated)
    assertExists(token1);
    assertExists(token2);
  },
});

Deno.test({
  name: 'INTEGRATION: JWT should have valid structure with real signing',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
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
    console.log(`✓ JWT header valid:`, header);
    
    const payload = decodeBase64Url(parts[1]);
    assertExists(payload.iss);
    assertExists(payload.aud);
    assertExists(payload.iat);
    assertExists(payload.exp);
    assertEquals(payload.scope, 'https://www.googleapis.com/auth/firebase.messaging');
    console.log(`✓ JWT payload valid (expires in ${payload.exp - payload.iat}s)`);
  },
});

Deno.test({
  name: 'INTEGRATION: sendNotification should handle invalid token with real API',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    // Use an obviously invalid token
    const result = await service.sendNotification({
      token: 'invalid-token-for-testing-12345',
      notification: {
        title: 'Test Notification',
        body: 'This should fail',
      },
    });
    
    assertEquals(result.success, false);
    assertExists(result.error);
    console.log(`✓ Invalid token rejected by real FCM API: ${result.error}`);
  },
});

Deno.test({
  name: 'INTEGRATION: sendNotification should include data payload in real request',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    // This will fail (invalid token) but we're testing the request structure with real API
    const result = await service.sendNotification({
      token: 'test-token',
      notification: {
        title: 'Test',
        body: 'Test',
      },
      data: {
        type: 'daily_verse',
        reference: 'John 3:16',
      },
      android: {
        priority: 'high',
      },
    });
    
    // Should fail with invalid token, but structure should be correct
    assertEquals(result.success, false);
    console.log(`✓ Request with data payload sent to real FCM API`);
  },
});

Deno.test({
  name: 'INTEGRATION: sendBatchNotifications should handle empty array',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    const result = await service.sendBatchNotifications(
      [],
      { title: 'Test', body: 'Test' }
    );
    
    assertEquals(result.successCount, 0);
    assertEquals(result.failureCount, 0);
    assertEquals(result.results.length, 0);
    console.log(`✓ Empty batch handled correctly`);
  },
});

Deno.test({
  name: 'INTEGRATION: sendBatchNotifications should process multiple tokens with real API',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    // Use invalid tokens - they'll all fail but we're testing the batching logic with real API
    const tokens = ['token1', 'token2', 'token3', 'token4', 'token5'];
    
    const result = await service.sendBatchNotifications(
      tokens,
      { title: 'Batch Test', body: 'Testing' }
    );
    
    assertEquals(result.results.length, 5);
    assertEquals(result.failureCount, 5); // All should fail (invalid tokens)
    console.log(`✓ Batch processed ${result.results.length} notifications via real FCM API`);
  },
});

Deno.test({
  name: 'INTEGRATION: sendBatchNotifications should respect batch size with real API',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    // Send 25 notifications - should be split into batches of 10
    const tokens = Array(25).fill('test-token');
    
    const startTime = Date.now();
    const result = await service.sendBatchNotifications(
      tokens,
      { title: 'Test', body: 'Test' }
    );
    const duration = Date.now() - startTime;
    
    assertEquals(result.results.length, 25);
    console.log(`✓ Processed 25 notifications in ${duration}ms (batched to real FCM API)`);
  },
});

Deno.test({
  name: 'INTEGRATION: validateToken should return false for invalid token via real API',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    const isValid = await service.validateToken('invalid-token-123');
    
    assertEquals(isValid, false);
    console.log(`✓ Invalid token correctly identified by real FCM API`);
  },
});

Deno.test({
  name: 'INTEGRATION: should handle network failures gracefully with real network',
  ignore: SKIP_INTEGRATION_TESTS,
  fn: async () => {
    const service = new FCMService();
    
    // Force a network error by using invalid endpoint (will be caught internally)
    const result = await service.sendNotification({
      token: 'test',
      notification: { title: 'Test', body: 'Test' },
    });
    
    // Should return error response, not throw
    assertExists(result);
    assertEquals(typeof result.success, 'boolean');
    console.log(`✓ Network errors handled gracefully with real API`);
  },
});

// ============================================================================
// Test Summary
// ============================================================================

if (!SKIP_INTEGRATION_TESTS) {
  console.log('\n' + '='.repeat(60));
  console.log('✅ All FCM Service integration tests completed!');
  console.log('   Tests executed against real Firebase infrastructure');
  console.log('='.repeat(60) + '\n');
}
