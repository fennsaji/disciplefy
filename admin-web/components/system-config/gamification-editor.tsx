'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface GamificationEditorProps {
  initialSettings?: {
    masteryThreshold: number
    xpPerReview: number
    xpMasteryBonus: number
  }
  onSave?: (settings: {
    masteryThreshold: number
    xpPerReview: number
    xpMasteryBonus: number
  }) => Promise<void>
  isEditing?: boolean
  onEditStart?: () => void
  onCancel?: () => void
}

export default function GamificationEditor({
  initialSettings = { masteryThreshold: 5, xpPerReview: 10, xpMasteryBonus: 50 },
  onSave,
  isEditing = false,
  onEditStart,
  onCancel,
}: GamificationEditorProps) {
  const [settings, setSettings] = useState(initialSettings)
  const [isSaving, setIsSaving] = useState(false)

  const handleSave = async () => {
    try {
      setIsSaving(true)

      // Validation
      if (settings.masteryThreshold < 3 || settings.masteryThreshold > 10) {
        toast.error('Mastery threshold must be between 3 and 10')
        return
      }

      if (settings.xpPerReview < 5 || settings.xpPerReview > 50) {
        toast.error('XP per review must be between 5 and 50')
        return
      }

      if (settings.xpMasteryBonus < 25 || settings.xpMasteryBonus > 200) {
        toast.error('Mastery bonus must be between 25 and 200')
        return
      }

      if (onSave) {
        await onSave(settings)
      } else {
        // Default save to API
        const res = await fetch('/api/admin/system-config/memory-verses/gamification', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(settings),
          credentials: 'include',
        })

        if (!res.ok) {
          const error = await res.json()
          throw new Error(error.error || 'Failed to update gamification settings')
        }

        toast.success('Gamification settings updated successfully')
      }

      // Exit edit mode after successful save
      if (onCancel) onCancel()
    } catch (error) {
      console.error('Error saving gamification settings:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to update gamification settings')
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setSettings(initialSettings)
    if (onCancel) onCancel()
  }

  const handlePreset = (preset: 'low' | 'balanced' | 'high') => {
    const presets = {
      low: { masteryThreshold: 7, xpPerReview: 5, xpMasteryBonus: 25 },
      balanced: { masteryThreshold: 5, xpPerReview: 10, xpMasteryBonus: 50 },
      high: { masteryThreshold: 3, xpPerReview: 20, xpMasteryBonus: 100 },
    }
    setSettings(presets[preset])
  }

  const calculateTotalMasteryXP = () => {
    return (settings.masteryThreshold * settings.xpPerReview) + settings.xpMasteryBonus
  }

  // Read-only view
  if (!isEditing) {
    const totalXP = (initialSettings.masteryThreshold * initialSettings.xpPerReview) + initialSettings.xpMasteryBonus

    return (
      <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
              🏆 Gamification Settings
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
              XP rewards and mastery thresholds
            </p>
          </div>
          <button
            onClick={onEditStart}
            className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary-600"
          >
            Edit
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[
            { label: 'Mastery Threshold', value: `${initialSettings.masteryThreshold} reviews`, description: 'Consecutive correct reviews needed' },
            { label: 'XP Per Review', value: `${initialSettings.xpPerReview} XP`, description: 'Earned per successful review' },
            { label: 'Mastery Bonus', value: `${initialSettings.xpMasteryBonus} XP`, description: 'Bonus when verse is mastered' },
          ].map(({ label, value, description }) => (
            <div key={label} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <div className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                {label}
              </div>
              <div className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                {value}
              </div>
              <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                {description}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-4 p-4 bg-primary/10 rounded-lg">
          <div className="flex items-center justify-between">
            <span className="font-medium text-sm text-gray-900 dark:text-gray-100">Total XP for mastering a verse:</span>
            <span className="text-lg font-bold text-primary">
              {totalXP} XP
            </span>
          </div>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            ({initialSettings.masteryThreshold} reviews × {initialSettings.xpPerReview} XP) + {initialSettings.xpMasteryBonus} XP bonus
          </p>
        </div>
      </div>
    )
  }

  // Edit mode view
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
          🏆 Gamification Settings
        </h3>
        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
          Configure XP rewards and mastery thresholds for memory verse practice.
        </p>
      </div>

      <div className="space-y-6">
        {/* Preset Buttons */}
        <div className="flex gap-2">
          <button
            onClick={() => handlePreset('low')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Low Rewards
          </button>
          <button
            onClick={() => handlePreset('balanced')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Balanced
          </button>
          <button
            onClick={() => handlePreset('high')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            High Rewards
          </button>
        </div>

        {/* Input Fields */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Mastery Threshold */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Mastery Threshold
            </label>
            <input
              type="number"
              min={3}
              max={10}
              value={settings.masteryThreshold}
              onChange={(e) => setSettings({ ...settings, masteryThreshold: parseInt(e.target.value) || 5 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Consecutive correct reviews needed (3-10)
            </p>
          </div>

          {/* XP Per Review */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              XP Per Review
            </label>
            <input
              type="number"
              min={5}
              max={50}
              value={settings.xpPerReview}
              onChange={(e) => setSettings({ ...settings, xpPerReview: parseInt(e.target.value) || 10 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              XP earned per successful review (5-50)
            </p>
          </div>

          {/* Mastery Bonus */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Mastery Bonus XP
            </label>
            <input
              type="number"
              min={25}
              max={200}
              value={settings.xpMasteryBonus}
              onChange={(e) => setSettings({ ...settings, xpMasteryBonus: parseInt(e.target.value) || 50 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Bonus XP when verse is mastered (25-200)
            </p>
          </div>
        </div>

        {/* Visual Preview */}
        <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg space-y-4">
          <h4 className="font-medium mb-3 text-sm text-gray-900 dark:text-gray-100">Preview</h4>

          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">User needs to review correctly:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{settings.masteryThreshold} times consecutively</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">XP per successful review:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{settings.xpPerReview} XP</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Bonus when mastered:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{settings.xpMasteryBonus} XP</span>
            </div>
          </div>

          <div className="border-t border-gray-300 dark:border-gray-700 pt-3 mt-3">
            <div className="flex justify-between items-center">
              <span className="font-medium text-sm text-gray-900 dark:text-gray-100">Total XP for mastering a verse:</span>
              <span className="text-lg font-bold text-primary">
                {calculateTotalMasteryXP()} XP
              </span>
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
              ({settings.masteryThreshold} reviews × {settings.xpPerReview} XP) + {settings.xpMasteryBonus} XP bonus
            </p>
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
