'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface UnlockLimitsEditorProps {
  initialLimits?: {
    free: number
    standard: number
    plus: number
    premium: number
  }
  onSave?: (limits: {
    free: number
    standard: number
    plus: number
    premium: number
  }) => Promise<void>
  isEditing?: boolean
  onEditStart?: () => void
  onCancel?: () => void
}

export default function UnlockLimitsEditor({
  initialLimits = { free: 1, standard: 2, plus: 3, premium: -1 },
  onSave,
  isEditing = false,
  onEditStart,
  onCancel,
}: UnlockLimitsEditorProps) {
  const [limits, setLimits] = useState(initialLimits)
  const [isSaving, setIsSaving] = useState(false)

  const handleSave = async () => {
    try {
      setIsSaving(true)

      // Validation
      if (limits.premium !== -1 && (
        limits.standard < limits.free ||
        limits.plus < limits.standard ||
        limits.premium < limits.plus
      )) {
        toast.error('Limits should increase with tier (Standard ≥ Free, Plus ≥ Standard, Premium ≥ Plus)')
        return
      }

      if (onSave) {
        await onSave(limits)
      } else {
        // Default save to API
        const res = await fetch('/api/admin/system-config/memory-verses/unlock-limits', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(limits),
          credentials: 'include',
        })

        if (!res.ok) {
          const error = await res.json()
          throw new Error(error.error || 'Failed to update unlock limits')
        }

        toast.success('Unlock limits updated successfully')
      }

      // Exit edit mode after successful save
      if (onCancel) onCancel()
    } catch (error) {
      console.error('Error saving unlock limits:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to update unlock limits')
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setLimits(initialLimits)
    if (onCancel) onCancel()
  }

  const handlePreset = (preset: 'conservative' | 'balanced' | 'generous') => {
    const presets = {
      conservative: { free: 1, standard: 1, plus: 2, premium: -1 },
      balanced: { free: 1, standard: 2, plus: 3, premium: -1 },
      generous: { free: 2, standard: 3, plus: 4, premium: -1 },
    }
    setLimits(presets[preset])
  }

  // Read-only view
  if (!isEditing) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
              ℹ️ Practice Mode Unlock Limits
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
              Daily practice mode unlock limits per tier
            </p>
          </div>
          <button
            onClick={onEditStart}
            className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary-600"
          >
            Edit
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { label: 'Free Tier', value: initialLimits.free },
            { label: 'Standard Tier', value: initialLimits.standard },
            { label: 'Plus Tier', value: initialLimits.plus },
            { label: 'Premium Tier', value: initialLimits.premium },
          ].map(({ label, value }) => (
            <div key={label} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                {label}
              </div>
              <div className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                {value === -1 ? '∞' : value}
              </div>
              <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                {value === -1 ? 'Unlimited unlocks' : `${value} unlock${value > 1 ? 's' : ''}/day`}
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  // Edit mode view
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
          ℹ️ Practice Mode Unlock Limits
        </h3>
        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
          Configure how many practice modes users can unlock per verse per day for each tier.
          Set to -1 for unlimited (Premium default).
        </p>
      </div>

      <div className="space-y-6">
        {/* Preset Buttons */}
        <div className="flex gap-2">
          <button
            onClick={() => handlePreset('conservative')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Conservative
          </button>
          <button
            onClick={() => handlePreset('balanced')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Balanced
          </button>
          <button
            onClick={() => handlePreset('generous')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Generous
          </button>
        </div>

        {/* Input Fields */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* Free Tier */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Free Tier
            </label>
            <input
              type="number"
              min={1}
              value={limits.free}
              onChange={(e) => setLimits({ ...limits, free: parseInt(e.target.value) || 1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Free users can unlock {limits.free} mode{limits.free > 1 ? 's' : ''}/day
            </p>
          </div>

          {/* Standard Tier */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Standard Tier
            </label>
            <input
              type="number"
              min={1}
              value={limits.standard}
              onChange={(e) => setLimits({ ...limits, standard: parseInt(e.target.value) || 1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Standard users can unlock {limits.standard} mode{limits.standard > 1 ? 's' : ''}/day
            </p>
          </div>

          {/* Plus Tier */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Plus Tier
            </label>
            <input
              type="number"
              min={1}
              value={limits.plus}
              onChange={(e) => setLimits({ ...limits, plus: parseInt(e.target.value) || 1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Plus users can unlock {limits.plus} mode{limits.plus > 1 ? 's' : ''}/day
            </p>
          </div>

          {/* Premium Tier */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Premium Tier
            </label>
            <input
              type="number"
              min={-1}
              value={limits.premium}
              onChange={(e) => setLimits({ ...limits, premium: parseInt(e.target.value) || -1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {limits.premium === -1 ? 'Unlimited unlocks' : `${limits.premium} mode${limits.premium > 1 ? 's' : ''}/day`}
            </p>
          </div>
        </div>

        {/* Visual Preview */}
        <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
          <h4 className="font-medium mb-3 text-sm text-gray-900 dark:text-gray-100">Preview</h4>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Free users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{limits.free} unlock{limits.free > 1 ? 's' : ''} per verse per day</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Standard users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{limits.standard} unlock{limits.standard > 1 ? 's' : ''} per verse per day</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Plus users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{limits.plus} unlock{limits.plus > 1 ? 's' : ''} per verse per day</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Premium users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{limits.premium === -1 ? 'Unlimited unlocks' : `${limits.premium} unlocks per verse per day`}</span>
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex justify-end gap-2">
          <button
            onClick={handleCancel}
            disabled={isSaving}
            className="px-4 py-2 bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={isSaving}
            className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSaving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  )
}
