'use client'

import { useState, useEffect } from 'react'

interface EditSubscriptionConfigDialogProps {
  isOpen: boolean
  onClose: () => void
  onSave: (config: any) => void
  config: any
}

export default function EditSubscriptionConfigDialog({
  isOpen,
  onClose,
  onSave,
  config
}: EditSubscriptionConfigDialogProps) {
  const [formData, setFormData] = useState(config || {})

  // Update formData whenever config changes or dialog opens
  useEffect(() => {
    if (isOpen && config) {
      setFormData(config)
    }
  }, [isOpen, config])

  if (!isOpen) return null

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    // Ensure proper data structure with features object
    const updatedConfig = {
      id: config?.id,
      plan_code: config?.plan_code,
      plan_name: config?.plan_name,
      razorpay_plan_id: formData.razorpay_plan_id,
      price_inr: formData.price_inr,
      billing_period: formData.billing_period,
      daily_tokens: formData.features?.daily_tokens || 0, // Top-level for backward compatibility
      features: {
        daily_tokens: formData.features?.daily_tokens || 0,
        voice_conversations_monthly: formData.features?.voice_conversations_monthly ?? 0,
        practice_modes: formData.features?.practice_modes ?? 0,
        study_modes: formData.features?.study_modes || ['standard']
      }
    }

    onSave(updatedConfig)
    onClose()
  }

  const studyModes = ['standard', 'deep', 'lectio', 'sermon', 'recommended']

  const toggleStudyMode = (mode: string) => {
    const currentModes = formData.features?.study_modes || []
    const newModes = currentModes.includes(mode)
      ? currentModes.filter((m: string) => m !== mode)
      : [...currentModes, mode]
    setFormData({
      ...formData,
      features: {
        ...formData.features,
        study_modes: newModes
      }
    })
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700 sticky top-0 bg-white dark:bg-gray-900">
          <h2 className="text-xl font-bold text-gray-900 dark:text-gray-100">
            Edit Subscription Plan: {config?.plan_name || config?.plan_code?.toUpperCase()}
          </h2>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Pricing Section */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              💰 Pricing
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Razorpay Plan ID
                </label>
                <input
                  type="text"
                  value={formData.razorpay_plan_id || ''}
                  onChange={(e) => setFormData({ ...formData, razorpay_plan_id: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Price (INR)
                </label>
                <input
                  type="number"
                  value={formData.price_inr || 0}
                  onChange={(e) => setFormData({ ...formData, price_inr: parseInt(e.target.value) })}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                  min="0"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Billing Period
                </label>
                <select
                  value={formData.billing_period || 'monthly'}
                  onChange={(e) => setFormData({ ...formData, billing_period: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                >
                  <option value="monthly">Monthly</option>
                  <option value="yearly">Yearly</option>
                  <option value="lifetime">Lifetime</option>
                </select>
              </div>
            </div>
          </div>

          {/* Token Allocation */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              🪙 Token Allocation
            </h3>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Daily Tokens (Use 999999999 for unlimited)
              </label>
              <input
                type="number"
                value={formData.features?.daily_tokens || 0}
                onChange={(e) => setFormData({
                  ...formData,
                  features: {
                    ...formData.features,
                    daily_tokens: parseInt(e.target.value)
                  }
                })}
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                min="0"
              />
            </div>
          </div>

          {/* Voice Conversations */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              🎙️ Voice Features
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Voice Conversations/Month (Use -1 for unlimited)
                </label>
                <input
                  type="number"
                  value={formData.features?.voice_conversations_monthly ?? 0}
                  onChange={(e) => setFormData({
                    ...formData,
                    features: {
                      ...formData.features,
                      voice_conversations_monthly: parseInt(e.target.value)
                    }
                  })}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                  min="-1"
                />
              </div>
            </div>
          </div>

          {/* Study Modes */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              📚 Unlocked Study Modes
            </h3>
            <div className="flex flex-wrap gap-3">
              {studyModes.map(mode => {
                const currentModes = formData.features?.study_modes || []
                const isSelected = currentModes.includes(mode) || currentModes.includes('all')
                return (
                  <button
                    key={mode}
                    type="button"
                    onClick={() => toggleStudyMode(mode)}
                    className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                      isSelected
                        ? 'bg-primary text-white'
                        : 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
                    }`}
                  >
                    {mode}
                  </button>
                )
              })}
            </div>
            <div className="mt-2">
              <button
                type="button"
                onClick={() => setFormData({
                  ...formData,
                  features: {
                    ...formData.features,
                    study_modes: ['all']
                  }
                })}
                className="text-sm text-primary hover:underline"
              >
                Select All Modes
              </button>
            </div>
          </div>

          {/* Practice Modes Configuration */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              🎯 Practice Configuration
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Available Practice Modes
                </label>
                <input
                  type="number"
                  value={formData.features?.practice_modes ?? 0}
                  onChange={(e) => setFormData({
                    ...formData,
                    features: {
                      ...formData.features,
                      practice_modes: parseInt(e.target.value)
                    }
                  })}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                  min="0"
                  max="8"
                />
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Maximum 8 modes available</p>
              </div>
            </div>
          </div>

          <div className="space-y-3">
            <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-3">
              <p className="text-xs text-blue-800 dark:text-blue-200">
                ℹ️ <strong>Quotas Only:</strong> This dialog configures usage limits (quotas). Feature access control is managed via the Feature Flags tab.
              </p>
            </div>
            <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-3">
              <p className="text-xs text-green-800 dark:text-green-200">
                ✅ Changes apply to new subscriptions immediately. Existing subscriptions update on renewal.
              </p>
            </div>
            <div className="bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800 rounded-lg p-3">
              <p className="text-xs text-purple-800 dark:text-purple-200">
                📿 <strong>Memory Verses Config:</strong> Memory verse limits and practice unlock limits are configured in the <strong>Memory Verses Configuration</strong> section of System Config tab (single source of truth).
              </p>
            </div>
          </div>

          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary/90"
            >
              Save Changes
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
