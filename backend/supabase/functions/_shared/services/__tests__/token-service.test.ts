/**
 * Token Service Unit Tests
 * 
 * Comprehensive test suite for the TokenService class covering:
 * - Token cost calculations
 * - User plan validations
 * - Token consumption logic
 * - Purchased tokens functionality
 * - Error handling scenarios
 * - Edge cases and boundary conditions
 */

import { assertEquals, assertThrows } from 'https://deno.land/std@0.208.0/testing/asserts.ts'
import { TokenService } from '../token-service.ts'
import { AppError } from '../../utils/error-handler.ts'
import { UserPlan, SupportedLanguage, TOKEN_COST_MAP } from '../../types/token-types.ts'

// Mock Supabase client for testing
class MockSupabaseClient {
  private mockResponses: Map<string, any> = new Map()
  private callHistory: Array<{ method: string; params: any }> = []

  // Set up mock responses for different RPC calls
  setMockResponse(rpcName: string, response: { data?: any; error?: any }) {
    this.mockResponses.set(rpcName, response)
  }

  // Mock the rpc method
  rpc(functionName: string, params?: any) {
    this.callHistory.push({ method: functionName, params })
    
    const mockResponse = this.mockResponses.get(functionName) || {
      data: null,
      error: new Error(`Mock response not configured for ${functionName}`)
    }

    return {
      single: () => Promise.resolve(mockResponse)
    }
  }

  // Helper methods for test verification
  getCallHistory() {
    return this.callHistory
  }

  clearHistory() {
    this.callHistory = []
  }
}

// Test setup helper
function createTokenService(mockClient?: MockSupabaseClient) {
  const client = mockClient || new MockSupabaseClient()
  return new TokenService(client as any)
}

// Test: Token Cost Calculation
// Asserted against TOKEN_COST_MAP rather than inline numbers: Hindi and
// Malayalam stopped costing the same as English when per-language pricing
// landed, and these literals silently went stale (this test was failing with
// "Hindi should cost 20 tokens" against an actual cost of 30).
Deno.test('TokenService: calculateTokenCost - matches the token cost map', () => {
  const tokenService = createTokenService()

  for (const [language, modes] of Object.entries(TOKEN_COST_MAP)) {
    for (const [mode, expected] of Object.entries(modes)) {
      assertEquals(
        tokenService.calculateTokenCost(language, mode as never),
        expected,
        `${language}/${mode} should cost ${expected} tokens`
      )
    }
  }

  // Standard is the default mode when none is given.
  assertEquals(tokenService.calculateTokenCost('en'), TOKEN_COST_MAP.en.standard)
  assertEquals(tokenService.calculateTokenCost('hi'), TOKEN_COST_MAP.hi.standard)
  assertEquals(tokenService.calculateTokenCost('ml'), TOKEN_COST_MAP.ml.standard)
})