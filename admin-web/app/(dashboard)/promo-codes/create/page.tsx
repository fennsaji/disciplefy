'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { format } from 'date-fns'
import type { CreatePromoCodeRequest, DiscountType, EligibilityType } from '@/types/admin'

const TIER_OPTIONS = [
  { value: 'free', label: 'Free' },
  { value: 'standard', label: 'Standard' },
  { value: 'plus', label: 'Plus' },
  { value: 'premium', label: 'Premium' },
]

export default function CreatePromoCodePage() {
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [formData, setFormData] = useState<CreatePromoCodeRequest>({
    code: '',
    campaign_name: '',
    description: '',
    discount_type: 'percentage',
    discount_value: 10,
    applies_to_plan: ['standard', 'plus', 'premium'],
    max_total_uses: undefined,
    max_uses_per_user: 1,
    eligible_for: 'all',
    eligible_tiers: [],
    eligible_user_ids: [],
    start_date: format(new Date(), 'yyyy-MM-dd'),
    end_date: format(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), 'yyyy-MM-dd'),
    is_active: true,
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    // Validate
    if (!formData.code || !formData.campaign_name) {
      setError('Please fill in all required fields')
      return
    }

    if (formData.discount_type === 'percentage' && (formData.discount_value <= 0 || formData.discount_value > 100)) {
      setError('Percentage discount must be between 1 and 100')
      return
    }

    if (formData.discount_type === 'fixed_amount' && formData.discount_value <= 0) {
      setError('Fixed amount discount must be greater than 0')
      return
    }

    setIsLoading(true)
    try {
      const response = await fetch('/api/admin/create-promo-code', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to create promo code')
      }

      router.push('/promo-codes')
    } catch (err) {
      console.error('Failed to create promo code:', err)
      setError(err instanceof Error ? err.message : 'Failed to create promo code')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6 dark:bg-gray-900">
      <div className="mx-auto max-w-3xl">
        {/* Header */}
        <div className="mb-6">
          <button
            onClick={() => router.push('/promo-codes')}
            className="mb-4 flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
          >
            <svg
              className="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M15 19l-7-7 7-7"
              />
            </svg>
            Back to Promo Codes
          </button>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
            Create Promo Code
          </h1>
          <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
            Create a new promotional discount code
          </p>
        </div>

        {/* Form */}
        <div className="rounded-lg bg-white shadow dark:bg-gray-800 dark:shadow-gray-900">
          <form onSubmit={handleSubmit} className="p-6">
            {/* Error Message */}
            {error && (
              <div className="mb-6 rounded-lg bg-red-50 p-4 dark:bg-red-900/20">
                <p className="text-sm text-red-800 dark:text-red-300">{error}</p>
              </div>
            )}

            <div className="space-y-8">
              {/* Basic Info */}
              <div className="space-y-4">
                <h3 className="font-medium text-gray-900 dark:text-gray-100">Basic Information</h3>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Promo Code *
                  </label>
                  <input
                    type="text"
                    value={formData.code}
                    onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                    placeholder="e.g., LAUNCH2026"
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 uppercase text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                    disabled={isLoading}
                    required
                  />
                </div>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Campaign Name *
                  </label>
                  <input
                    type="text"
                    value={formData.campaign_name}
                    onChange={(e) => setFormData({ ...formData, campaign_name: e.target.value })}
                    placeholder="e.g., Launch Promotion 2026"
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                    disabled={isLoading}
                    required
                  />
                </div>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Description (Optional)
                  </label>
                  <textarea
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    placeholder="Internal notes about this campaign..."
                    rows={2}
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                    disabled={isLoading}
                  />
                </div>
              </div>

              {/* Discount */}
              <div className="space-y-4">
                <h3 className="font-medium text-gray-900 dark:text-gray-100">Discount Settings</h3>

                <div className="grid gap-4 md:grid-cols-2">
                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                      Discount Type *
                    </label>
                    <select
                      value={formData.discount_type}
                      onChange={(e) => setFormData({ ...formData, discount_type: e.target.value as DiscountType })}
                      className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                      disabled={isLoading}
                    >
                      <option value="percentage">Percentage (%)</option>
                      <option value="fixed_amount">Fixed Amount (₹)</option>
                    </select>
                  </div>

                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                      Discount Value *
                    </label>
                    <input
                      type="number"
                      value={formData.discount_value}
                      onChange={(e) => setFormData({ ...formData, discount_value: parseFloat(e.target.value) })}
                      min="1"
                      max={formData.discount_type === 'percentage' ? '100' : undefined}
                      className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                      disabled={isLoading}
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Applies to Plans *
                  </label>
                  <div className="grid grid-cols-2 gap-2">
                    {TIER_OPTIONS.map((tier) => (
                      <label key={tier.value} className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={formData.applies_to_plan.includes(tier.value)}
                          onChange={(e) => {
                            if (e.target.checked) {
                              setFormData({
                                ...formData,
                                applies_to_plan: [...formData.applies_to_plan, tier.value],
                              })
                            } else {
                              setFormData({
                                ...formData,
                                applies_to_plan: formData.applies_to_plan.filter((p) => p !== tier.value),
                              })
                            }
                          }}
                          className="h-4 w-4 text-primary focus:ring-primary dark:border-gray-600 dark:bg-gray-600"
                          disabled={isLoading}
                        />
                        <span className="text-sm text-gray-700 dark:text-gray-300">{tier.label}</span>
                      </label>
                    ))}
                  </div>
                </div>
              </div>

              {/* Usage Limits */}
              <div className="space-y-4">
                <h3 className="font-medium text-gray-900 dark:text-gray-100">Usage Limits</h3>

                <div className="grid gap-4 md:grid-cols-2">
                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                      Max Total Uses (Optional)
                    </label>
                    <input
                      type="number"
                      value={formData.max_total_uses || ''}
                      onChange={(e) => setFormData({
                        ...formData,
                        max_total_uses: e.target.value ? parseInt(e.target.value) : undefined,
                      })}
                      min="1"
                      placeholder="Unlimited"
                      className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                      disabled={isLoading}
                    />
                  </div>

                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                      Max Uses Per User *
                    </label>
                    <input
                      type="number"
                      value={formData.max_uses_per_user}
                      onChange={(e) => setFormData({ ...formData, max_uses_per_user: parseInt(e.target.value) })}
                      min="1"
                      className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                      disabled={isLoading}
                      required
                    />
                  </div>
                </div>
              </div>

              {/* Eligibility */}
              <div className="space-y-4">
                <h3 className="font-medium text-gray-900 dark:text-gray-100">Eligibility Rules</h3>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Who can use this code? *
                  </label>
                  <select
                    value={formData.eligible_for}
                    onChange={(e) => setFormData({ ...formData, eligible_for: e.target.value as EligibilityType })}
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                    disabled={isLoading}
                  >
                    <option value="all">All Users</option>
                    <option value="new_users_only">New Users Only</option>
                    <option value="specific_tiers">Specific Tiers</option>
                    <option value="specific_users">Specific Users</option>
                  </select>
                </div>
              </div>

              {/* Dates */}
              <div className="space-y-4">
                <h3 className="font-medium text-gray-900 dark:text-gray-100">Campaign Period</h3>

                <div className="grid gap-4 md:grid-cols-2">
                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                      Start Date *
                    </label>
                    <input
                      type="date"
                      value={formData.start_date}
                      onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                      className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                      disabled={isLoading}
                      required
                    />
                  </div>

                  <div>
                    <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                      End Date *
                    </label>
                    <input
                      type="date"
                      value={formData.end_date}
                      onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
                      min={formData.start_date}
                      className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                      disabled={isLoading}
                      required
                    />
                  </div>
                </div>
              </div>

              {/* Status */}
              <div>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                    className="h-4 w-4 text-primary focus:ring-primary dark:border-gray-600 dark:bg-gray-600"
                    disabled={isLoading}
                  />
                  <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Activate immediately</span>
                </label>
              </div>
            </div>

            {/* Actions */}
            <div className="mt-8 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => router.push('/promo-codes')}
                disabled={isLoading}
                className="rounded-lg border border-gray-300 px-4 py-2 font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isLoading}
                className="rounded-lg bg-primary px-4 py-2 font-medium text-white hover:bg-primary-dark disabled:opacity-50"
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
                    Creating...
                  </span>
                ) : (
                  'Create Promo Code'
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
