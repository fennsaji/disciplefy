/**
 * Payment Provider Factory
 *
 * Centralized factory for creating payment provider instances.
 * Ensures singleton pattern and proper provider initialization.
 */

import { PaymentProvider, ProviderType, ProviderError } from './base-provider.ts'
import { RazorpayProvider } from './razorpay-provider.ts'
import { GooglePlayProvider } from './google-play-provider.ts'
import { AppleAppStoreProvider } from './apple-appstore-provider.ts'

/**
 * Provider instance cache (singleton pattern)
 */
const providerInstances: Map<ProviderType, PaymentProvider> = new Map()

/**
 * PaymentProviderFactory
 *
 * Factory class for creating and managing payment provider instances.
 */
export class PaymentProviderFactory {
  /**
   * Get a payment provider instance
   *
   * Uses singleton pattern - creates provider on first call, returns cached instance on subsequent calls
   *
   * @param type - Provider type to instantiate
   * @returns Payment provider instance
   * @throws ProviderError if provider type is unknown
   */
  static getProvider(type: ProviderType): PaymentProvider {
    // Return cached instance if exists
    if (providerInstances.has(type)) {
      return providerInstances.get(type)!
    }

    // Create new provider instance
    let provider: PaymentProvider

    switch (type) {
      case 'razorpay':
        provider = new RazorpayProvider()
        break

      case 'google_play':
        provider = new GooglePlayProvider()
        break

      case 'apple_appstore':
        provider = new AppleAppStoreProvider()
        break

      default:
        throw new ProviderError(
          `Unknown provider type: ${type}`,
          type as ProviderType,
          'UNKNOWN_PROVIDER_TYPE',
          400
        )
    }

    // Cache and return
    providerInstances.set(type, provider)
    return provider
  }

  /**
   * Clear provider cache (useful for testing)
   */
  static clearCache(): void {
    providerInstances.clear()
  }

  /**
   * Check if provider type is valid
   *
   * @param type - Provider type to validate
   * @returns true if valid
   */
  static isValidProviderType(type: string): type is ProviderType {
    return type === 'razorpay' || type === 'google_play' || type === 'apple_appstore'
  }

  /**
   * Get all available provider types
   *
   * @returns Array of provider types
   */
  static getAvailableProviders(): ProviderType[] {
    return ['razorpay', 'google_play', 'apple_appstore']
  }
}
