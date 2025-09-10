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
import { UserPlan, SupportedLanguage } from '../../types/token-types.ts'

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
Deno.test('TokenService: calculateTokenCost - returns correct costs for supported languages', () => {
  const tokenService = createTokenService()

  // Test supported languages
  assertEquals(tokenService.calculateTokenCost('en'), 10, 'English should cost 10 tokens')
  assertEquals(tokenService.calculateTokenCost('hi'), 20, 'Hindi should cost 20 tokens')
  assertEquals(tokenService.calculateTokenCost('ml'), 20, 'Malayalam should cost 20 tokens')
})