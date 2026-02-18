'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface PlanProvider {
  id: string
  provider: 'razorpay' | 'google_play' | 'apple_appstore'
  planName: string
  planCode: string
  currentPriceMinor: number
  currency: string
  providerPlanId: string
  productId?: string
  region: string
}

interface SubscriptionPriceUpdateModalProps {
  planProvider: PlanProvider
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

export default function SubscriptionPriceUpdateModal({
  planProvider,
  isOpen,
  onClose,
  onSuccess
}: SubscriptionPriceUpdateModalProps) {
  const [newPriceMajor, setNewPriceMajor] = useState<string>(
    (planProvider.currentPriceMinor / 100).toString()
  )
  const [notes, setNotes] = useState<string>('')
  const [externalConsoleUpdated, setExternalConsoleUpdated] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  if (!isOpen) return null

  const currentPriceMajor = planProvider.currentPriceMinor / 100
  const newPriceMinor = Math.round(parseFloat(newPriceMajor || '0') * 100)
  const isRazorpay = planProvider.provider === 'razorpay'
  const isGooglePlay = planProvider.provider === 'google_play'
  const isAppleAppStore = planProvider.provider === 'apple_appstore'

  const getCurrencySymbol = (currency: string): string => {
    const symbols: Record<string, string> = {
      'INR': '₹',
      'USD': '$',
      'EUR': '€',
      'GBP': '£',
    }
    return symbols[currency] || currency
  }

  const getProviderName = (): string => {
    if (isRazorpay) return 'Razorpay'
    if (isGooglePlay) return 'Google Play'
    if (isAppleAppStore) return 'Apple App Store'
    return planProvider.provider
  }

  const getExternalConsoleUrl = (): string => {
    if (isGooglePlay) {
      return 'https://play.google.com/console/developers'
    }
    if (isAppleAppStore) {
      return 'https://appstoreconnect.apple.com/'
    }
    return '#'
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    // Validation
    if (!newPriceMajor || parseFloat(newPriceMajor) <= 0) {
      toast.error('Please enter a valid price')
      return
    }

    if (newPriceMinor === planProvider.currentPriceMinor) {
      toast.error('New price is same as current price - no change needed')
      return
    }

    if (newPriceMinor < 100 || newPriceMinor > 10000000) {
      toast.error('Price must be between ₹1 and ₹100,000')
      return
    }

    // For IAP, require checkbox confirmation
    if ((isGooglePlay || isAppleAppStore) && !externalConsoleUpdated) {
      toast.error(`You must confirm that you've updated the price in ${getProviderName()} Console`)
      return
    }

    setIsSubmitting(true)

    try {
      const response = await fetch('/api/admin/subscription/update-price', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          plan_provider_id: planProvider.id,
          new_price_minor: newPriceMinor,
          notes,
          external_console_updated: externalConsoleUpdated
        })
      })

      const data = await response.json()

      if (!response.ok || !data.success) {
        throw new Error(data.error || 'Failed to update price')
      }

      // Success!
      const priceChange = newPriceMinor - planProvider.currentPriceMinor
      const changeDirection = priceChange > 0 ? 'increased' : 'decreased'
      const changeMajor = Math.abs(priceChange) / 100

      toast.success(
        `Price ${changeDirection} by ${getCurrencySymbol(planProvider.currency)}${changeMajor}`,
        {
          description: isRazorpay
            ? `New Razorpay plan created: ${data.new_provider_plan_id}`
            : data.warning || 'Price updated successfully'
        }
      )

      onSuccess()
      onClose()

    } catch (error) {
      console.error('Error updating price:', error)
      toast.error(
        error instanceof Error ? error.message : 'Failed to update price'
      )
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="p-6">
          {/* Header */}
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
                Update {planProvider.planName} Price
              </h2>
              <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                Provider: {getProviderName()} • Region: {planProvider.region}
              </p>
            </div>
            <button
              onClick={onClose}
              disabled={isSubmitting}
              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <form onSubmit={handleSubmit}>
            {/* Provider-Specific Warning */}
            {isRazorpay && (
              <div className="mb-6 p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
                <div className="flex gap-3">
                  <svg className="w-5 h-5 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                  </svg>
                  <div className="flex-1">
                    <h3 className="text-sm font-medium text-blue-800 dark:text-blue-300">
                      Razorpay Price Update
                    </h3>
                    <p className="text-sm text-blue-700 dark:text-blue-400 mt-1">
                      This will create a <strong>new Razorpay plan</strong> with the new price.
                      The old plan ID will be replaced automatically.
                    </p>
                    <p className="text-xs text-blue-600 dark:text-blue-500 mt-2">
                      Current plan ID: <code className="bg-blue-100 dark:bg-blue-800 px-1 rounded">{planProvider.providerPlanId}</code>
                    </p>
                  </div>
                </div>
              </div>
            )}

            {(isGooglePlay || isAppleAppStore) && (
              <div className="mb-6 p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg">
                <div className="flex gap-3">
                  <svg className="w-5 h-5 text-yellow-600 dark:text-yellow-400 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                  </svg>
                  <div className="flex-1">
                    <h3 className="text-sm font-medium text-yellow-800 dark:text-yellow-300">
                      ⚠️ External Console Update Required
                    </h3>
                    <p className="text-sm text-yellow-700 dark:text-yellow-400 mt-1">
                      You MUST update the price in <strong>{getProviderName()} Console</strong> BEFORE updating here.
                      This only updates the price in our database for display purposes.
                    </p>
                    <div className="mt-3 flex items-center gap-2">
                      <span className="text-xs text-yellow-600 dark:text-yellow-500">
                        Product ID: <code className="bg-yellow-100 dark:bg-yellow-800 px-1 rounded">{planProvider.productId}</code>
                      </span>
                      <a
                        href={getExternalConsoleUrl()}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-xs text-yellow-700 dark:text-yellow-400 hover:text-yellow-900 dark:hover:text-yellow-200 underline"
                      >
                        Open {getProviderName()} Console →
                      </a>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Current Price Display */}
            <div className="mb-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  Current Price:
                </span>
                <span className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                  {getCurrencySymbol(planProvider.currency)}{currentPriceMajor}
                  <span className="text-sm text-gray-500 dark:text-gray-400 ml-1">/month</span>
                </span>
              </div>
            </div>

            {/* New Price Input */}
            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                New Price ({planProvider.currency})
              </label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 dark:text-gray-400 text-lg">
                  {getCurrencySymbol(planProvider.currency)}
                </span>
                <input
                  type="number"
                  step="0.01"
                  min="1"
                  max="100000"
                  value={newPriceMajor}
                  onChange={(e) => setNewPriceMajor(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 text-lg border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary dark:bg-gray-800 dark:text-gray-100"
                  placeholder="0.00"
                  disabled={isSubmitting}
                  required
                />
              </div>
              {newPriceMajor && parseFloat(newPriceMajor) > 0 && newPriceMinor !== planProvider.currentPriceMinor && (
                <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  Change: {newPriceMinor > planProvider.currentPriceMinor ? '+' : ''}
                  {getCurrencySymbol(planProvider.currency)}
                  {((newPriceMinor - planProvider.currentPriceMinor) / 100).toFixed(2)}
                  {' '}({((newPriceMinor / planProvider.currentPriceMinor - 1) * 100).toFixed(1)}%)
                </p>
              )}
            </div>

            {/* Notes Input */}
            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Notes (Optional)
              </label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={3}
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary dark:bg-gray-800 dark:text-gray-100"
                placeholder="Reason for price change (e.g., inflation adjustment, market pricing)"
                disabled={isSubmitting}
              />
            </div>

            {/* IAP Confirmation Checkbox */}
            {(isGooglePlay || isAppleAppStore) && (
              <div className="mb-6">
                <label className="flex items-start gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={externalConsoleUpdated}
                    onChange={(e) => setExternalConsoleUpdated(e.target.checked)}
                    className="w-5 h-5 mt-0.5 text-primary border-gray-300 rounded focus:ring-primary"
                    disabled={isSubmitting}
                    required
                  />
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    <strong>I confirm</strong> that I have updated the price in {getProviderName()} Console to{' '}
                    {getCurrencySymbol(planProvider.currency)}{newPriceMajor || '___'}
                  </span>
                </label>
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex gap-3 justify-end">
              <button
                type="button"
                onClick={onClose}
                disabled={isSubmitting}
                className="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting || (isGooglePlay || isAppleAppStore ? !externalConsoleUpdated : false)}
                className="px-6 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {isSubmitting && (
                  <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                  </svg>
                )}
                {isSubmitting ? 'Updating...' : isRazorpay ? 'Create New Plan & Update Price' : 'Update Price'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
