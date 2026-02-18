'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { StatsCard } from '@/components/ui/stats-card'
import SubscriptionConfigTable from '@/components/tables/subscription-config-table'
import EditSystemConfigDialog from '@/components/dialogs/edit-system-config-dialog'
import EditSubscriptionConfigDialog from '@/components/dialogs/edit-subscription-config-dialog'
import EditFeatureFlagDialog from '@/components/dialogs/edit-feature-flag-dialog'
import UnlockLimitsEditor from '@/components/system-config/unlock-limits-editor'
import VerseQuotaEditor from '@/components/system-config/verse-quota-editor'
import GamificationEditor from '@/components/system-config/gamification-editor'
import PracticeModesEditor from '@/components/system-config/practice-modes-editor'
import SpacedRepetitionEditor from '@/components/system-config/spaced-repetition-editor'
import PricingEditor from '@/components/system-config/pricing-editor'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'
import { EditIcon, ToggleIcon, actionButtonStyles } from '@/components/ui/action-icons'

type TabType = 'system-config' | 'subscription-config' | 'feature-flags'
type SystemConfigSection = 'token_system' | 'voice_features' | 'maintenance_mode' | 'app_version' | 'trial_config' | 'memory_verses'


const TABS = [
  { value: 'system-config', label: 'System Config', icon: '⚙️' },
  { value: 'subscription-config', label: 'Subscription Config', icon: '💳' },
  { value: 'feature-flags', label: 'Feature Flags', icon: '🚩' },
]

export default function SystemConfigPage() {
  const [activeTab, setActiveTab] = useState<TabType>('system-config')
  const [editSystemConfigOpen, setEditSystemConfigOpen] = useState(false)
  const [editSystemConfigSection, setEditSystemConfigSection] = useState<SystemConfigSection>('token_system')
  const [editSubscriptionConfigOpen, setEditSubscriptionConfigOpen] = useState(false)
  const [selectedSubscriptionConfig, setSelectedSubscriptionConfig] = useState<any>(null)
  const [editFeatureFlagOpen, setEditFeatureFlagOpen] = useState(false)
  const [selectedFeatureFlag, setSelectedFeatureFlag] = useState<any>(null)
  const [isEditingPricing, setIsEditingPricing] = useState(false)
  const queryClient = useQueryClient()

  // Fetch System Config
  const { data: systemConfigData, isLoading: systemConfigLoading } = useQuery({
    queryKey: ['system-config'],
    queryFn: async () => {
      const res = await fetch('/api/admin/system/config', {
        credentials: 'include'
      })
      if (!res.ok) throw new Error('Failed to fetch system config')
      return res.json()
    },
    enabled: activeTab === 'system-config'
  })

  // Fetch Subscription Config
  const { data: subscriptionConfigData, isLoading: subscriptionConfigLoading } = useQuery({
    queryKey: ['subscription-config'],
    queryFn: async () => {
      const res = await fetch('/api/admin/system/subscription-config', {
        credentials: 'include'
      })
      if (!res.ok) throw new Error('Failed to fetch subscription config')
      return res.json()
    },
    enabled: activeTab === 'subscription-config'
  })

  // Fetch Feature Flags
  const { data: featureFlagsData, isLoading: featureFlagsLoading } = useQuery({
    queryKey: ['feature-flags'],
    queryFn: async () => {
      const res = await fetch('/api/admin/system/feature-flags', {
        credentials: 'include'
      })
      if (!res.ok) throw new Error('Failed to fetch feature flags')
      return res.json()
    },
    enabled: activeTab === 'feature-flags'
  })

  // Fetch Memory Verse Config
  const { data: memoryVerseData, isLoading: memoryVerseLoading } = useQuery({
    queryKey: ['memory-verse-config'],
    queryFn: async () => {
      const res = await fetch('/api/admin/system-config/memory-verses', {
        credentials: 'include'
      })
      if (!res.ok) throw new Error('Failed to fetch memory verse config')
      return res.json()
    },
    enabled: activeTab === 'system-config'
  })

  // Fetch Pricing Data
  const { data: pricingData, isLoading: pricingLoading } = useQuery({
    queryKey: ['pricing-data'],
    queryFn: async () => {
      const res = await fetch('/api/admin/system/pricing', {
        credentials: 'include'
      })
      if (!res.ok) throw new Error('Failed to fetch pricing data')
      return res.json()
    },
    enabled: activeTab === 'subscription-config'
  })

  // Update System Config
  const updateSystemConfig = useMutation({
    mutationFn: async (config: any) => {
      const res = await fetch('/api/admin/system/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(config),
      })
      if (!res.ok) throw new Error('Failed to update system config')
      return res.json()
    },
    onSuccess: (data) => {
      const message = data.message || 'Configuration updated successfully'
      toast.success(message)
      queryClient.invalidateQueries({ queryKey: ['system-config'] })
      setEditSystemConfigOpen(false)
    },
    onError: (error) => {
      console.error('Update error:', error)
      toast.error('Failed to update system config')
    }
  })

  // Update Subscription Config
  const updateSubscriptionConfig = useMutation({
    mutationFn: async (config: any) => {
      const res = await fetch('/api/admin/system/subscription-config', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(config),
      })
      if (!res.ok) throw new Error('Failed to update subscription config')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscription-config'] })
      toast.success('Subscription config updated successfully')
    },
    onError: () => {
      toast.error('Failed to update subscription config')
    }
  })

  // Toggle Feature Flag
  const toggleFeatureFlag = useMutation({
    mutationFn: async ({ flag_id, enabled }: { flag_id: string; enabled: boolean }) => {
      const res = await fetch('/api/admin/system/feature-flags', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ flag_id, enabled }),
      })
      if (!res.ok) throw new Error('Failed to toggle feature flag')
      return res.json()
    },
    onSuccess: (data) => {
      toast.success(data.message)
      queryClient.invalidateQueries({ queryKey: ['feature-flags'] })
    },
    onError: () => {
      toast.error('Failed to toggle feature flag')
    }
  })

  // Update Feature Flag
  const updateFeatureFlag = useMutation({
    mutationFn: async (flagData: any) => {
      const res = await fetch('/api/admin/system/feature-flags', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(flagData),
      })
      if (!res.ok) throw new Error('Failed to update feature flag')
      return res.json()
    },
    onSuccess: (data) => {
      toast.success(data.message || 'Feature flag updated successfully')
      queryClient.invalidateQueries({ queryKey: ['feature-flags'] })
      setEditFeatureFlagOpen(false)
      setSelectedFeatureFlag(null)
    },
    onError: () => {
      toast.error('Failed to update feature flag')
    }
  })

  // Render System Config Tab
  const renderSystemConfigTab = () => {
    const config = systemConfigData?.config

    if (!config) return null

    return (
      <div className="space-y-6">
        {/* Token System */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                💰 Token System
              </h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                Values from <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">subscription_plans</code> table
              </p>
            </div>
            <button
              onClick={() => {
                setEditSystemConfigSection('token_system')
                setEditSystemConfigOpen(true)
              }}
              className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary/90"
            >
              Edit
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Free Plan (Daily)</div>
              <div className="text-2xl font-bold text-gray-600">{config.token_system.daily_free_tokens} tokens</div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Standard Plan (Daily)</div>
              <div className="text-2xl font-bold text-blue-600">{config.token_system.standard_daily_tokens} tokens</div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Plus Plan (Daily)</div>
              <div className="text-2xl font-bold text-indigo-600">{config.token_system.plus_daily_tokens} tokens</div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Premium Plan (Daily)</div>
              <div className="text-2xl font-bold text-purple-600">
                {config.token_system.premium_daily_tokens > 1000000 ? '∞ Unlimited' : `${config.token_system.premium_daily_tokens} tokens`}
              </div>
            </div>
          </div>
        </div>

        {/* Voice Features */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                🎙️ Voice Conversations
              </h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                Values from <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">subscription_plans.features.voice_conversations_monthly</code>
              </p>
            </div>
            <button
              onClick={() => {
                setEditSystemConfigSection('voice_features')
                setEditSystemConfigOpen(true)
              }}
              className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary/90"
            >
              Edit
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Free Plan (Monthly)</div>
              <div className="text-2xl font-bold text-gray-600">{config.voice_features.free_monthly_conversations} conversations</div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Standard Plan (Monthly)</div>
              <div className="text-2xl font-bold text-blue-600">{config.voice_features.standard_monthly_conversations} conversations</div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Plus Plan (Monthly)</div>
              <div className="text-2xl font-bold text-indigo-600">{config.voice_features.plus_monthly_conversations} conversations</div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Premium Plan (Monthly)</div>
              <div className="text-2xl font-bold text-purple-600">
                {config.voice_features.premium_monthly_conversations === -1 || config.voice_features.premium_monthly_conversations > 1000000
                  ? '∞ Unlimited'
                  : `${config.voice_features.premium_monthly_conversations} conversations`}
              </div>
            </div>
          </div>
        </div>

        {/* Maintenance Mode */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                🚧 Maintenance Mode
              </h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                Values from <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">system_config</code> table
              </p>
            </div>
            <button
              onClick={() => {
                setEditSystemConfigSection('maintenance_mode')
                setEditSystemConfigOpen(true)
              }}
              className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary/90"
            >
              Edit
            </button>
          </div>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
              <div>
                <div className="text-sm font-medium text-gray-900 dark:text-gray-100">Status</div>
                <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  Emergency app control without deployment
                </div>
              </div>
              <div className={`px-4 py-2 rounded-lg font-semibold ${
                config.maintenance_mode?.enabled
                  ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                  : 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
              }`}>
                {config.maintenance_mode?.enabled ? '🔴 ACTIVE' : '✅ Normal Operation'}
              </div>
            </div>
            {config.maintenance_mode?.message && (
              <div className="p-4 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg">
                <div className="text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">Current Message:</div>
                <div className="text-sm text-gray-600 dark:text-gray-400 italic">
                  "{config.maintenance_mode.message}"
                </div>
              </div>
            )}
          </div>
        </div>

        {/* App Version Control */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                📱 App Version Control
              </h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                Values from <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">system_config</code> table
              </p>
            </div>
            <button
              onClick={() => {
                setEditSystemConfigSection('app_version')
                setEditSystemConfigOpen(true)
              }}
              className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary/90"
            >
              Edit
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm font-medium text-gray-900 dark:text-gray-100 mb-3">
                Minimum Required Versions
              </div>
              <div className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-600 dark:text-gray-400">Android:</span>
                  <span className="text-sm font-mono font-semibold text-gray-900 dark:text-gray-100">
                    {config.app_version?.min_android || '1.0.0'}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-600 dark:text-gray-400">iOS:</span>
                  <span className="text-sm font-mono font-semibold text-gray-900 dark:text-gray-100">
                    {config.app_version?.min_ios || '1.0.0'}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-600 dark:text-gray-400">Web:</span>
                  <span className="text-sm font-mono font-semibold text-gray-900 dark:text-gray-100">
                    {config.app_version?.min_web || '1.0.0'}
                  </span>
                </div>
              </div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm font-medium text-gray-900 dark:text-gray-100 mb-3">
                Update Settings
              </div>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-600 dark:text-gray-400">Latest Version:</span>
                  <span className="text-sm font-mono font-semibold text-gray-900 dark:text-gray-100">
                    {config.app_version?.latest || '1.0.0'}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-600 dark:text-gray-400">Force Update:</span>
                  <span className={`px-3 py-1 rounded-lg font-semibold text-xs ${
                    config.app_version?.force_update
                      ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                      : 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200'
                  }`}>
                    {config.app_version?.force_update ? 'Enabled' : 'Disabled'}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Dynamic Trial Configuration */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                ⏰ Trial Period Configuration
              </h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                Values from <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">system_config</code> table
              </p>
            </div>
            <button
              onClick={() => {
                setEditSystemConfigSection('trial_config')
                setEditSystemConfigOpen(true)
              }}
              className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary/90"
            >
              Edit
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm font-medium text-gray-900 dark:text-gray-100 mb-3">
                Standard Trial
              </div>
              <div className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-600 dark:text-gray-400">End Date:</span>
                  <span className="text-sm font-mono font-semibold text-gray-900 dark:text-gray-100">
                    {config.trial_config?.standard_trial_end_date
                      ? new Date(config.trial_config.standard_trial_end_date).toLocaleDateString()
                      : 'Not set'}
                  </span>
                </div>
              </div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm font-medium text-gray-900 dark:text-gray-100 mb-3">
                Premium Trial
              </div>
              <div className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-600 dark:text-gray-400">Duration:</span>
                  <span className="text-sm font-mono font-semibold text-gray-900 dark:text-gray-100">
                    {config.trial_config?.premium_trial_days || 7} days
                  </span>
                </div>
                <div className="mt-3 pt-3 border-t border-gray-200 dark:border-gray-700">
                  <p className="text-xs text-gray-500 dark:text-gray-400 italic">
                    ✨ On-demand trial: Offered when user clicks "Subscribe to Premium"
                  </p>
                </div>
              </div>
            </div>
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 md:col-span-2">
              <div className="text-sm font-medium text-gray-900 dark:text-gray-100 mb-2">
                Grace Period
              </div>
              <div className="flex justify-between items-center">
                <span className="text-xs text-gray-600 dark:text-gray-400">Duration after trial ends:</span>
                <span className="text-sm font-mono font-semibold text-gray-900 dark:text-gray-100">
                  {config.trial_config?.grace_period_days || 7} days
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Memory Verses Configuration */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                📿 Memory Verses Configuration
              </h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                Configure practice mode unlocks, verse quotas, and gamification for memory verse feature
              </p>
            </div>
          </div>

          {memoryVerseLoading ? (
            <LoadingState label="Loading memory verse configuration..." />
          ) : memoryVerseData?.data ? (
            <div className="space-y-6">
              {/* Practice Mode Unlock Limits */}
              <UnlockLimitsEditor
                initialLimits={{
                  free: parseInt(memoryVerseData.data.unlockLimits['free_practice_unlock_limit']?.value || '1'),
                  standard: parseInt(memoryVerseData.data.unlockLimits['standard_practice_unlock_limit']?.value || '2'),
                  plus: parseInt(memoryVerseData.data.unlockLimits['plus_practice_unlock_limit']?.value || '3'),
                  premium: parseInt(memoryVerseData.data.unlockLimits['premium_practice_unlock_limit']?.value || '-1'),
                }}
                onSave={async (limits) => {
                  queryClient.invalidateQueries({ queryKey: ['memory-verse-config'] })
                }}
              />

              {/* Memory Verse Quotas */}
              <VerseQuotaEditor
                initialQuotas={{
                  free: parseInt(memoryVerseData.data.verseLimits['free_memory_verses_limit']?.value || '3'),
                  standard: parseInt(memoryVerseData.data.verseLimits['standard_memory_verses_limit']?.value || '5'),
                  plus: parseInt(memoryVerseData.data.verseLimits['plus_memory_verses_limit']?.value || '10'),
                  premium: parseInt(memoryVerseData.data.verseLimits['premium_memory_verses_limit']?.value || '-1'),
                }}
                onSave={async (quotas) => {
                  queryClient.invalidateQueries({ queryKey: ['memory-verse-config'] })
                }}
              />

              {/* Gamification Settings */}
              <GamificationEditor
                initialSettings={{
                  masteryThreshold: parseInt(memoryVerseData.data.gamification['memory_verse_mastery_threshold']?.value || '5'),
                  xpPerReview: parseInt(memoryVerseData.data.gamification['memory_verse_xp_per_review']?.value || '10'),
                  xpMasteryBonus: parseInt(memoryVerseData.data.gamification['memory_verse_xp_mastery_bonus']?.value || '50'),
                }}
                onSave={async (settings) => {
                  queryClient.invalidateQueries({ queryKey: ['memory-verse-config'] })
                }}
              />

              {/* Practice Mode Availability */}
              <PracticeModesEditor
                initialModes={{
                  free: memoryVerseData.data.practiceModes['free_available_practice_modes']?.value
                    ? JSON.parse(memoryVerseData.data.practiceModes['free_available_practice_modes'].value)
                    : ['flip_card', 'type_it_out'],
                  paid: memoryVerseData.data.practiceModes['paid_available_practice_modes']?.value
                    ? JSON.parse(memoryVerseData.data.practiceModes['paid_available_practice_modes'].value)
                    : ['flip_card', 'type_it_out', 'cloze_practice', 'first_letter', 'progressive_reveal', 'word_scramble', 'word_bank', 'audio_practice'],
                }}
                onSave={async (modes) => {
                  queryClient.invalidateQueries({ queryKey: ['memory-verse-config'] })
                }}
              />

              {/* Spaced Repetition Settings */}
              <SpacedRepetitionEditor
                initialSettings={{
                  initialEaseFactor: parseFloat(memoryVerseData.data.spacedRepetition['memory_verse_initial_ease_factor']?.value || '2.5'),
                  initialIntervalDays: parseInt(memoryVerseData.data.spacedRepetition['memory_verse_initial_interval_days']?.value || '1'),
                  minEaseFactor: parseFloat(memoryVerseData.data.spacedRepetition['memory_verse_min_ease_factor']?.value || '1.3'),
                  maxIntervalDays: parseInt(memoryVerseData.data.spacedRepetition['memory_verse_max_interval_days']?.value || '365'),
                }}
                onSave={async (settings) => {
                  queryClient.invalidateQueries({ queryKey: ['memory-verse-config'] })
                }}
              />
            </div>
          ) : (
            <ErrorState message="Failed to load memory verse configuration" />
          )}
        </div>

        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4">
          <p className="text-sm text-green-800 dark:text-green-200">
            ✅ <strong>Database-Driven Configuration:</strong> All system configurations are stored in the database and can be edited via the admin panel.
            Changes take effect immediately across both admin and client applications!
          </p>
          <ul className="text-xs text-green-700 dark:text-green-300 mt-2 ml-4 list-disc space-y-1">
            <li><strong>Token System:</strong> <code className="bg-green-100 dark:bg-green-800 px-1 rounded">subscription_plans.features.daily_tokens</code></li>
            <li><strong>Voice Conversations:</strong> <code className="bg-green-100 dark:bg-green-800 px-1 rounded">subscription_plans.features.voice_conversations_monthly</code></li>
            <li><strong>Maintenance, Versions & Trials:</strong> <code className="bg-green-100 dark:bg-green-800 px-1 rounded">system_config</code> table</li>
            <li><strong>Memory Verses:</strong> <code className="bg-green-100 dark:bg-green-800 px-1 rounded">system_config</code> table (practice unlock limits, verse quotas, gamification)</li>
          </ul>
        </div>
      </div>
    )
  }

  // Render Subscription Config Tab
  const renderSubscriptionConfigTab = () => {
    const stats = subscriptionConfigData?.stats

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Plans"
              value={stats.total_plans}
              icon="📋"
              trend={undefined}
            />
            <StatsCard
              title="Active Subscriptions"
              value={stats.total_active_subscriptions}
              icon="✅"
              trend={undefined}
            />
            <StatsCard
              title="Standard Users"
              value={stats.by_plan?.standard || 0}
              icon="🔵"
              trend={undefined}
            />
            <StatsCard
              title="Premium Users"
              value={stats.by_plan?.premium || 0}
              icon="💎"
              trend={undefined}
            />
          </div>
        )}

        {/* Table */}
        <div className="rounded-lg border border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-800">
          {subscriptionConfigLoading ? (
            <LoadingState label="Loading subscription plans..." />
          ) : (
            <SubscriptionConfigTable
              configs={subscriptionConfigData?.subscription_config || []}
              onEdit={(config) => {
                setSelectedSubscriptionConfig(config)
                setEditSubscriptionConfigOpen(true)
              }}
            />
          )}
        </div>

        {/* Subscription Pricing Configuration */}
        <div>
          {pricingData?.data ? (
            <PricingEditor
              initialPricing={pricingData.data}
              isEditing={isEditingPricing}
              onEditStart={() => setIsEditingPricing(true)}
              onCancel={() => setIsEditingPricing(false)}
              onSaveComplete={() => {
                queryClient.invalidateQueries({ queryKey: ['pricing-data'] })
              }}
            />
          ) : pricingLoading ? (
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
              <LoadingState label="Loading pricing data..." />
            </div>
          ) : (
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
              <ErrorState message="Failed to load pricing data" />
            </div>
          )}
        </div>

        <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <p className="text-sm text-blue-800 dark:text-blue-200">
            ℹ️ <strong>Info:</strong> Subscription configuration is stored in the database.
            Changes take effect immediately but won't affect existing subscriptions until renewal.
          </p>
        </div>
      </div>
    )
  }

  // Render Feature Flags Tab
  const renderFeatureFlagsTab = () => {
    const stats = featureFlagsData?.stats
    const flags = featureFlagsData?.feature_flags || []

    const flagsByCategory = flags.reduce((acc: any, flag: any) => {
      if (!acc[flag.category]) acc[flag.category] = []
      acc[flag.category].push(flag)
      return acc
    }, {})

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Flags"
              value={stats.total_flags}
              icon="🚩"
              trend={undefined}
            />
            <StatsCard
              title="Enabled"
              value={stats.enabled_flags}
              icon="✅"
              trend={undefined}
            />
            <StatsCard
              title="Disabled"
              value={stats.disabled_flags}
              icon="🔴"
              trend={undefined}
            />
            <StatsCard
              title="Categories"
              value={Object.keys(stats.by_category).length}
              icon="📁"
              trend={undefined}
            />
          </div>
        )}

        {/* Flags by Category */}
        <div className="space-y-6">
          {Object.entries(flagsByCategory).map(([category, categoryFlags]: [string, any]) => (
            <div key={category} className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4 capitalize">
                {category.replace('_', ' ')}
              </h3>
              <div className="space-y-3">
                {categoryFlags.map((flag: any) => (
                  <div
                    key={flag.id}
                    className="flex items-center justify-between p-4 border border-gray-200 dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
                  >
                    <div className="flex-1">
                      <div className="flex items-center gap-3">
                        <h4 className="text-sm font-semibold text-gray-900 dark:text-gray-100">
                          {flag.name}
                        </h4>
                        <span className={`px-2 py-0.5 text-xs rounded-full ${
                          flag.enabled
                            ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                            : 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                        }`}>
                          {flag.enabled ? 'Enabled' : 'Disabled'}
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                        {flag.description}
                      </p>
                      <div className="flex items-center gap-4 text-xs text-gray-500 dark:text-gray-500 mt-2">
                        <span>Rollout: {flag.rollout_percentage}%</span>
                        {flag.enabled_for_plans && flag.enabled_for_plans.length > 0 && (
                          <span>Plans: {flag.enabled_for_plans.join(', ')}</span>
                        )}
                      </div>
                    </div>
                    <div className="ml-4 flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => {
                          setSelectedFeatureFlag(flag)
                          setEditFeatureFlagOpen(true)
                        }}
                        className={actionButtonStyles.edit}
                        title="Edit"
                      >
                        <EditIcon />
                      </button>
                      <button
                        type="button"
                        onClick={() => toggleFeatureFlag.mutate({ flag_id: flag.id, enabled: !flag.enabled })}
                        className={flag.enabled ? actionButtonStyles.toggleActive : actionButtonStyles.toggleInactive}
                        title={flag.enabled ? 'Disable' : 'Enable'}
                      >
                        <ToggleIcon />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4">
          <p className="text-sm text-green-800 dark:text-green-200">
            ✅ <strong>Database-Driven Feature Flags:</strong> All feature flags are stored in the <code className="bg-green-100 dark:bg-green-800 px-1 rounded">feature_flags</code> table.
            Toggle changes take effect immediately for both backend and frontend applications!
          </p>
          <ul className="text-xs text-green-700 dark:text-green-300 mt-2 ml-4 list-disc space-y-1">
            <li><strong>Plan-Based Access:</strong> Feature availability controlled via <code className="bg-green-100 dark:bg-green-800 px-1 rounded">enabled_for_plans</code> array</li>
            <li><strong>Rollout Control:</strong> Gradual feature rollout using <code className="bg-green-100 dark:bg-green-800 px-1 rounded">rollout_percentage</code></li>
            <li><strong>Instant Updates:</strong> Backend caches for 5 minutes, frontend checks on navigation</li>
          </ul>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="System Configuration"
        description="Manage system settings, subscription plans, and feature flags"
      />

      <TabNav
        tabs={TABS}
        activeTab={activeTab}
        onChange={(v) => setActiveTab(v as TabType)}
      />

      {/* Tab Content */}
      {systemConfigLoading && activeTab === 'system-config' && <LoadingState label="Loading system configuration..." />}
      {!systemConfigLoading && activeTab === 'system-config' && renderSystemConfigTab()}
      {activeTab === 'subscription-config' && renderSubscriptionConfigTab()}
      {featureFlagsLoading && activeTab === 'feature-flags' && <LoadingState label="Loading feature flags..." />}
      {!featureFlagsLoading && activeTab === 'feature-flags' && renderFeatureFlagsTab()}

      {/* Edit Dialogs */}
      <EditSystemConfigDialog
        isOpen={editSystemConfigOpen}
        onClose={() => setEditSystemConfigOpen(false)}
        onSave={(config) => updateSystemConfig.mutate({ [editSystemConfigSection]: config })}
        config={systemConfigData?.config?.[editSystemConfigSection]}
        section={editSystemConfigSection}
      />

      <EditSubscriptionConfigDialog
        isOpen={editSubscriptionConfigOpen}
        onClose={() => {
          setEditSubscriptionConfigOpen(false)
          setSelectedSubscriptionConfig(null)
        }}
        onSave={(config) => updateSubscriptionConfig.mutate(config)}
        config={selectedSubscriptionConfig}
      />

      <EditFeatureFlagDialog
        isOpen={editFeatureFlagOpen}
        onClose={() => {
          setEditFeatureFlagOpen(false)
          setSelectedFeatureFlag(null)
        }}
        onSave={(flagData) => updateFeatureFlag.mutate(flagData)}
        flag={selectedFeatureFlag}
      />
    </div>
  )
}
