'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface PricingData {
  id: string
  provider: string
  planCode: string
  planName: string
  basePriceMinor: number // paise/cents
  currency: string
  region: string
  isActive: boolean
  formattedPrice: string
}

interface PricingEditorProps {
  initialPricing?: PricingData[]
  isEditing?: boolean
  onEditStart?: () => void
  onCancel?: () => void
  onSaveComplete?: () => void
}

export default function PricingEditor({
  initialPricing = [],
  isEditing = false,
  onEditStart,
  onCancel,
  onSaveComplete,
}: PricingEditorProps) {
  const [pricing, setPricing] = useState<PricingData[]>(initialPricing)
  const [isSaving, setIsSaving] = useState(false)

  // Group pricing by provider
  const groupedPricing = pricing.reduce((acc, p) => {
    if (!acc[p.provider]) {
      acc[p.provider] = []
    }
    acc[p.provider].push(p)
    return acc
  }, {} as Record<string, PricingData[]>)

  const handlePriceChange = (id: string, newPriceMinor: number) => {
    setPricing(prev => prev.map(p =>
      p.id === id ? { ...p, basePriceMinor: newPriceMinor } : p
    ))
  }

  const handleActiveToggle = (id: string) => {
    setPricing(prev => prev.map(p =>
      p.id === id ? { ...p, isActive: !p.isActive } : p
    ))
  }

  const handleSave = async () => {
    try {
      setIsSaving(true)

      // Find modified pricing entries
      const modified = pricing.filter(p => {
        const original = initialPricing.find(o => o.id === p.id)
        return original &&
          (original.basePriceMinor !== p.basePriceMinor || original.isActive !== p.isActive)
      })

      if (modified.length === 0) {
        toast.info('No changes to save')
        if (onCancel) onCancel()
        return
      }

      // Update each modified entry
      const updatePromises = modified.map(p =>
        fetch('/api/admin/system/pricing', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: p.id,
            basePriceMinor: p.basePriceMinor,
            isActive: p.isActive,
          }),
          credentials: 'include',
        }).then(res => {
          if (!res.ok) throw new Error(`Failed to update ${p.planName} for ${p.provider}`)
          return res.json()
        })
      )

      await Promise.all(updatePromises)

      toast.success(`Updated ${modified.length} pricing ${modified.length === 1 ? 'entry' : 'entries'}`)

      // Exit edit mode and refresh data
      if (onSaveComplete) onSaveComplete()
      if (onCancel) onCancel()
    } catch (error) {
      console.error('Error saving pricing:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to update pricing')
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setPricing(initialPricing)
    if (onCancel) onCancel()
  }

  const formatPriceInput = (priceMinor: number, currency: string): string => {
    const major = priceMinor / 100
    return currency === 'INR' ? Math.floor(major).toString() : major.toFixed(2)
  }

  const parsePriceInput = (input: string, currency: string): number => {
    const value = parseFloat(input) || 0
    return Math.round(value * 100)
  }

  const getCurrencySymbol = (currency: string): string => {
    const symbols: Record<string, string> = {
      'INR': '₹',
      'USD': '$',
      'EUR': '€',
      'GBP': '£',
    }
    return symbols[currency] || currency
  }

  const getProviderName = (provider: string): string => {
    const names: Record<string, string> = {
      'razorpay': 'Razorpay (Web)',
      'google_play': 'Google Play (Android)',
      'apple_appstore': 'Apple App Store (iOS)',
    }
    return names[provider] || provider
  }

  const getPlanColor = (planCode: string): string => {
    const colors: Record<string, string> = {
      'free': 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200',
      'standard': 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
      'plus': 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200',
      'premium': 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
    }
    return colors[planCode] || 'bg-gray-100 text-gray-800'
  }

  // Read-only view
  if (!isEditing) {
    return (
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
              💰 Subscription Pricing
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
              Values from <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">subscription_plan_providers</code> table
            </p>
          </div>
          {onEditStart && (
            <button
              onClick={onEditStart}
              className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary/90"
            >
              Edit Pricing
            </button>
          )}
        </div>

        <div className="space-y-6">
          {Object.entries(groupedPricing).map(([provider, plans]) => (
            <div key={provider} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <h4 className="text-md font-semibold text-gray-800 dark:text-gray-200 mb-3">
                {getProviderName(provider)}
              </h4>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
                {plans.map(p => (
                  <div
                    key={p.id}
                    className={`border rounded-lg p-3 ${
                      p.isActive
                        ? 'border-gray-200 dark:border-gray-700'
                        : 'border-gray-300 dark:border-gray-600 opacity-50'
                    }`}
                  >
                    <div className={`inline-block px-2 py-1 rounded text-xs font-semibold mb-2 ${getPlanColor(p.planCode)}`}>
                      {p.planName}
                    </div>
                    <div className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                      {p.formattedPrice}
                      <span className="text-sm text-gray-500 dark:text-gray-400">/month</span>
                    </div>
                    <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                      {p.isActive ? '✓ Active' : '✗ Inactive'}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  // Edit mode
  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
          💰 Edit Subscription Pricing
        </h3>
        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
          Update pricing for each plan and provider combination. Prices are in {pricing[0]?.currency || 'INR'}.
        </p>
      </div>

      <div className="space-y-6 mb-6">
        {Object.entries(groupedPricing).map(([provider, plans]) => (
          <div key={provider} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
            <h4 className="text-md font-semibold text-gray-800 dark:text-gray-200 mb-3">
              {getProviderName(provider)}
            </h4>
            <div className="space-y-3">
              {plans.map(p => (
                <div
                  key={p.id}
                  className="flex items-center gap-4 p-3 border border-gray-200 dark:border-gray-700 rounded-lg"
                >
                  <div className="flex-1">
                    <div className={`inline-block px-2 py-1 rounded text-xs font-semibold ${getPlanColor(p.planCode)}`}>
                      {p.planName}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-lg font-semibold text-gray-700 dark:text-gray-300">
                      {getCurrencySymbol(p.currency)}
                    </span>
                    <input
                      type="number"
                      value={formatPriceInput(p.basePriceMinor, p.currency)}
                      onChange={(e) => handlePriceChange(p.id, parsePriceInput(e.target.value, p.currency))}
                      step={p.currency === 'INR' ? '1' : '0.01'}
                      min="0"
                      className="w-24 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                    />
                    <span className="text-sm text-gray-500 dark:text-gray-400">/month</span>
                  </div>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={p.isActive}
                      onChange={() => handleActiveToggle(p.id)}
                      className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">Active</span>
                  </label>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="flex gap-3">
        <button
          onClick={handleSave}
          disabled={isSaving}
          className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isSaving ? 'Saving...' : 'Save Changes'}
        </button>
        <button
          onClick={handleCancel}
          disabled={isSaving}
          className="px-4 py-2 bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200 rounded-lg hover:bg-gray-300 dark:hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Cancel
        </button>
      </div>
    </div>
  )
}
