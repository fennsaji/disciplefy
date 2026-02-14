'use client'

import { useState, useEffect } from 'react'

interface EditFeatureFlagDialogProps {
  isOpen: boolean
  onClose: () => void
  onSave: (flagData: any) => void
  flag: any
}

const AVAILABLE_PLANS = ['free', 'standard', 'plus', 'premium']

export default function EditFeatureFlagDialog({
  isOpen,
  onClose,
  onSave,
  flag
}: EditFeatureFlagDialogProps) {
  const [formData, setFormData] = useState({
    feature_name: '',
    description: '',
    is_enabled: true,
    enabled_for_plans: [] as string[],
    rollout_percentage: 100
  })

  useEffect(() => {
    if (flag) {
      setFormData({
        feature_name: flag.name || '',
        description: flag.description || '',
        is_enabled: flag.enabled ?? true,
        enabled_for_plans: flag.enabled_for_plans || [],
        rollout_percentage: flag.rollout_percentage ?? 100
      })
    }
  }, [flag])

  if (!isOpen || !flag) return null

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSave({
      flag_id: flag.id,
      ...formData
    })
  }

  const togglePlan = (plan: string) => {
    setFormData(prev => ({
      ...prev,
      enabled_for_plans: prev.enabled_for_plans.includes(plan)
        ? prev.enabled_for_plans.filter(p => p !== plan)
        : [...prev.enabled_for_plans, plan]
    }))
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-xl font-bold text-gray-900 dark:text-gray-100">
            Edit Feature Flag
          </h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
            Feature Key: <code className="bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded">{flag.feature_key}</code>
          </p>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Feature Name */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Feature Name
            </label>
            <input
              type="text"
              value={formData.feature_name}
              onChange={(e) => setFormData({ ...formData, feature_name: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
              placeholder="e.g., Voice Buddy"
              required
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Description
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
              rows={3}
              placeholder="Brief description of what this feature does..."
              required
            />
          </div>

          {/* Enabled Status */}
          <div>
            <label className="flex items-center gap-3">
              <input
                type="checkbox"
                checked={formData.is_enabled}
                onChange={(e) => setFormData({ ...formData, is_enabled: e.target.checked })}
                className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary"
              />
              <div>
                <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  Feature Enabled
                </span>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                  When disabled, feature is hidden from all users regardless of plan
                </p>
              </div>
            </label>
          </div>

          {/* Enabled for Plans */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
              Available for Plans
            </label>
            <div className="grid grid-cols-2 gap-3">
              {AVAILABLE_PLANS.map(plan => (
                <label
                  key={plan}
                  className={`flex items-center gap-3 p-3 border rounded-lg cursor-pointer transition-colors ${
                    formData.enabled_for_plans.includes(plan)
                      ? 'border-primary bg-primary/5 dark:bg-primary/10'
                      : 'border-gray-300 dark:border-gray-600'
                  }`}
                >
                  <input
                    type="checkbox"
                    checked={formData.enabled_for_plans.includes(plan)}
                    onChange={() => togglePlan(plan)}
                    className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
                  />
                  <div className="flex-1">
                    <span className="text-sm font-medium text-gray-900 dark:text-gray-100 capitalize">
                      {plan}
                    </span>
                    {plan === 'free' && (
                      <span className="text-xs text-gray-500 ml-2">8 tokens/day</span>
                    )}
                    {plan === 'standard' && (
                      <span className="text-xs text-blue-600 ml-2">20 tokens/day</span>
                    )}
                    {plan === 'plus' && (
                      <span className="text-xs text-indigo-600 ml-2">50 tokens/day</span>
                    )}
                    {plan === 'premium' && (
                      <span className="text-xs text-purple-600 ml-2">∞ Unlimited</span>
                    )}
                  </div>
                </label>
              ))}
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">
              Select which subscription plans have access to this feature
            </p>
          </div>

          {/* Rollout Percentage */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Rollout Percentage: {formData.rollout_percentage}%
            </label>
            <input
              type="range"
              min="0"
              max="100"
              step="5"
              value={formData.rollout_percentage}
              onChange={(e) => setFormData({ ...formData, rollout_percentage: parseInt(e.target.value) })}
              className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer dark:bg-gray-700"
            />
            <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-1">
              <span>0% (No users)</span>
              <span>50% (Half of eligible users)</span>
              <span>100% (All eligible users)</span>
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">
              Gradual rollout: randomly show feature to this percentage of eligible users
            </p>
          </div>

          {/* Category Badge */}
          {flag.category && (
            <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-3">
              <p className="text-xs text-blue-800 dark:text-blue-200">
                📁 <strong>Category:</strong> <code className="bg-blue-100 dark:bg-blue-800 px-2 py-0.5 rounded">{flag.category}</code>
              </p>
            </div>
          )}

          {/* Database Update Notice */}
          <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-3">
            <p className="text-xs text-green-800 dark:text-green-200">
              ✅ <strong>Database Update:</strong> Changes will be saved to the <code className="bg-green-100 dark:bg-green-800 px-1 rounded">feature_flags</code> table and take effect immediately across all systems (5-minute cache).
            </p>
          </div>

          {/* Action Buttons */}
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
