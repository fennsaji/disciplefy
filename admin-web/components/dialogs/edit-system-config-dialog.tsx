'use client'

import { useState, useEffect } from 'react'

interface EditSystemConfigDialogProps {
  isOpen: boolean
  onClose: () => void
  onSave: (config: any) => void
  config: any
  section: 'token_system' | 'voice_features' | 'maintenance_mode' | 'app_version' | 'trial_config' | 'memory_verses'
}

export default function EditSystemConfigDialog({
  isOpen,
  onClose,
  onSave,
  config,
  section
}: EditSystemConfigDialogProps) {
  const [formData, setFormData] = useState(config || {})

  // Update formData when config changes
  useEffect(() => {
    if (config) {
      setFormData(config)
    }
  }, [config])

  if (!isOpen) return null

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSave(formData)
    onClose()
  }

  const renderTokenSystemFields = () => (
    <>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Free Plan Daily Tokens
        </label>
        <input
          type="number"
          value={formData.daily_free_tokens || 8}
          onChange={(e) => setFormData({ ...formData, daily_free_tokens: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Standard Plan Daily Tokens
        </label>
        <input
          type="number"
          value={formData.standard_daily_tokens || 20}
          onChange={(e) => setFormData({ ...formData, standard_daily_tokens: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Plus Plan Daily Tokens
        </label>
        <input
          type="number"
          value={formData.plus_daily_tokens || 50}
          onChange={(e) => setFormData({ ...formData, plus_daily_tokens: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Premium Plan Daily Tokens
        </label>
        <input
          type="number"
          value={formData.premium_daily_tokens || 999999999}
          onChange={(e) => setFormData({ ...formData, premium_daily_tokens: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
          placeholder="999999999 for unlimited"
        />
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
          Use 999999999 for unlimited access
        </p>
      </div>
    </>
  )

  const renderVoiceFeaturesFields = () => (
    <>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Free Plan Monthly Conversations
        </label>
        <input
          type="number"
          value={formData.free_monthly_conversations || 0}
          onChange={(e) => setFormData({ ...formData, free_monthly_conversations: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Standard Plan Monthly Conversations
        </label>
        <input
          type="number"
          value={formData.standard_monthly_conversations || 0}
          onChange={(e) => setFormData({ ...formData, standard_monthly_conversations: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Plus Plan Monthly Conversations
        </label>
        <input
          type="number"
          value={formData.plus_monthly_conversations || 0}
          onChange={(e) => setFormData({ ...formData, plus_monthly_conversations: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Premium Plan Monthly Conversations
        </label>
        <input
          type="number"
          value={formData.premium_monthly_conversations || -1}
          onChange={(e) => setFormData({ ...formData, premium_monthly_conversations: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="-1"
          placeholder="-1 for unlimited"
        />
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
          Use -1 for unlimited conversations
        </p>
      </div>
    </>
  )

  const renderMaintenanceModeFields = () => (
    <>
      <div>
        <label className="flex items-center gap-3">
          <input
            type="checkbox"
            checked={formData.enabled || false}
            onChange={(e) => setFormData({ ...formData, enabled: e.target.checked })}
            className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary"
          />
          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Enable Maintenance Mode
          </span>
        </label>
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-2 ml-8">
          When enabled, only admin users can access the app
        </p>
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Maintenance Message
        </label>
        <textarea
          value={formData.message || ''}
          onChange={(e) => setFormData({ ...formData, message: e.target.value })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          rows={4}
          placeholder="We are currently performing maintenance. Please check back soon."
        />
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
          This message will be displayed to users when maintenance mode is active
        </p>
      </div>
    </>
  )

  const renderAppVersionFields = () => (
    <>
      <div className="grid grid-cols-3 gap-3">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Min Android
          </label>
          <input
            type="text"
            value={formData.min_android || '1.0.0'}
            onChange={(e) => setFormData({ ...formData, min_android: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm"
            placeholder="1.0.0"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Min iOS
          </label>
          <input
            type="text"
            value={formData.min_ios || '1.0.0'}
            onChange={(e) => setFormData({ ...formData, min_ios: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm"
            placeholder="1.0.0"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Min Web
          </label>
          <input
            type="text"
            value={formData.min_web || '1.0.0'}
            onChange={(e) => setFormData({ ...formData, min_web: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 text-sm"
            placeholder="1.0.0"
          />
        </div>
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Latest Version
        </label>
        <input
          type="text"
          value={formData.latest || '1.0.0'}
          onChange={(e) => setFormData({ ...formData, latest: e.target.value })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          placeholder="1.0.0"
        />
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
          Use semantic versioning (e.g., 1.2.3)
        </p>
      </div>
      <div>
        <label className="flex items-center gap-3">
          <input
            type="checkbox"
            checked={formData.force_update || false}
            onChange={(e) => setFormData({ ...formData, force_update: e.target.checked })}
            className="w-5 h-5 text-primary border-gray-300 rounded focus:ring-primary"
          />
          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Force Update
          </span>
        </label>
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-2 ml-8">
          When enabled, users below minimum version cannot access the app
        </p>
      </div>
    </>
  )

  const renderTrialConfigFields = () => (
    <>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Standard Trial End Date
        </label>
        <input
          type="datetime-local"
          value={formData.standard_trial_end_date ? new Date(formData.standard_trial_end_date).toISOString().slice(0, 16) : ''}
          onChange={(e) => setFormData({ ...formData, standard_trial_end_date: e.target.value })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Premium Trial Duration (days)
        </label>
        <input
          type="number"
          value={formData.premium_trial_days || 7}
          onChange={(e) => setFormData({ ...formData, premium_trial_days: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="1"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Premium Trial Start Date
        </label>
        <input
          type="datetime-local"
          value={formData.premium_trial_start_date ? new Date(formData.premium_trial_start_date).toISOString().slice(0, 16) : ''}
          onChange={(e) => setFormData({ ...formData, premium_trial_start_date: e.target.value })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Grace Period (days)
        </label>
        <input
          type="number"
          value={formData.grace_period_days || 7}
          onChange={(e) => setFormData({ ...formData, grace_period_days: parseInt(e.target.value) })}
          className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          min="0"
        />
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
          Number of days users can access features after trial ends
        </p>
      </div>
    </>
  )

  const getSectionTitle = () => {
    switch (section) {
      case 'token_system': return 'Edit Token System'
      case 'voice_features': return 'Edit Voice Conversations'
      case 'maintenance_mode': return 'Edit Maintenance Mode'
      case 'app_version': return 'Edit App Version Control'
      case 'trial_config': return 'Edit Trial Configuration'
      default: return 'Edit Configuration'
    }
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-xl font-bold text-gray-900 dark:text-gray-100">
            {getSectionTitle()}
          </h2>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {section === 'token_system' && renderTokenSystemFields()}
          {section === 'voice_features' && renderVoiceFeaturesFields()}
          {section === 'maintenance_mode' && renderMaintenanceModeFields()}
          {section === 'app_version' && renderAppVersionFields()}
          {section === 'trial_config' && renderTrialConfigFields()}

          <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-3">
            <p className="text-xs text-green-800 dark:text-green-200">
              ✅ <strong>Database Update:</strong> {
                section === 'token_system'
                  ? 'Token limits will be saved to subscription_plans.features.daily_tokens'
                  : section === 'voice_features'
                  ? 'Voice conversation limits will be saved to subscription_plans.features.voice_conversations_monthly'
                  : section === 'maintenance_mode'
                  ? 'Maintenance settings will be saved to system_config table'
                  : section === 'app_version'
                  ? 'Version control settings will be saved to system_config table'
                  : section === 'trial_config'
                  ? 'Trial configuration will be saved to system_config table'
                  : 'Configuration will be saved to database'
              }
              {' '}Changes take effect immediately across all systems.
            </p>
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
