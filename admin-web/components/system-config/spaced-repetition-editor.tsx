'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface SpacedRepetitionEditorProps {
  initialSettings?: {
    initialEaseFactor: number
    initialIntervalDays: number
    minEaseFactor: number
    maxIntervalDays: number
  }
  onSave?: (settings: {
    initialEaseFactor: number
    initialIntervalDays: number
    minEaseFactor: number
    maxIntervalDays: number
  }) => Promise<void>
  isEditing?: boolean
  onEditStart?: () => void
  onCancel?: () => void
}

const DEFAULT_SETTINGS = {
  initialEaseFactor: 2.5,
  initialIntervalDays: 1,
  minEaseFactor: 1.3,
  maxIntervalDays: 365,
}

export default function SpacedRepetitionEditor({
  initialSettings = DEFAULT_SETTINGS,
  onSave,
  isEditing = false,
  onEditStart,
  onCancel,
}: SpacedRepetitionEditorProps) {
  const [settings, setSettings] = useState(initialSettings)
  const [isSaving, setIsSaving] = useState(false)

  const handleSave = async () => {
    try {
      setIsSaving(true)

      // Validation
      if (settings.initialEaseFactor < 1.3 || settings.initialEaseFactor > 3.0) {
        toast.error('Initial ease factor must be between 1.3 and 3.0')
        return
      }

      if (settings.initialIntervalDays < 1 || settings.initialIntervalDays > 7) {
        toast.error('Initial interval must be between 1 and 7 days')
        return
      }

      if (settings.minEaseFactor < 1.0 || settings.minEaseFactor > 2.0) {
        toast.error('Min ease factor must be between 1.0 and 2.0')
        return
      }

      if (settings.maxIntervalDays < 30 || settings.maxIntervalDays > 730) {
        toast.error('Max interval must be between 30 and 730 days')
        return
      }

      if (onSave) {
        await onSave(settings)
      } else {
        // Default save to API
        const res = await fetch('/api/admin/system-config/memory-verses/spaced-repetition', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(settings),
          credentials: 'include',
        })

        if (!res.ok) {
          const error = await res.json()
          throw new Error(error.error || 'Failed to update spaced repetition settings')
        }

        toast.success('Spaced repetition settings updated successfully')
      }

      // Exit edit mode after successful save
      if (onCancel) onCancel()
    } catch (error) {
      console.error('Error saving spaced repetition settings:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to update spaced repetition settings')
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setSettings(initialSettings)
    if (onCancel) onCancel()
  }

  const handleReset = () => {
    setSettings(DEFAULT_SETTINGS)
    toast.info('Settings reset to defaults')
  }

  // Calculate sample review schedule
  const calculateSampleSchedule = (useSettings = settings) => {
    const schedule = []
    let interval = useSettings.initialIntervalDays
    let easeFactor = useSettings.initialEaseFactor
    let day = 0

    for (let i = 0; i < 6; i++) {
      day += interval
      if (day > useSettings.maxIntervalDays * 3) break // Stop after reasonable time

      schedule.push({ review: i + 1, day, interval })

      // Simulate successful review (quality: 4)
      easeFactor = Math.max(useSettings.minEaseFactor, easeFactor + (0.1 - (5 - 4) * (0.08 + (5 - 4) * 0.02)))
      interval = Math.min(Math.round(interval * easeFactor), useSettings.maxIntervalDays)
    }

    return schedule
  }

  const sampleSchedule = calculateSampleSchedule()

  // Read-only view
  if (!isEditing) {
    const readOnlySchedule = calculateSampleSchedule(initialSettings)

    return (
      <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
              🧠 Spaced Repetition Algorithm (SM-2)
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
              SuperMemo 2 algorithm parameters
            </p>
          </div>
          <button
            onClick={onEditStart}
            className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary-600"
          >
            Edit
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {[
            { label: 'Initial Ease Factor', value: initialSettings.initialEaseFactor.toFixed(1), description: 'Starting difficulty multiplier' },
            { label: 'Initial Interval', value: `${initialSettings.initialIntervalDays} day${initialSettings.initialIntervalDays > 1 ? 's' : ''}`, description: 'Days until first review' },
            { label: 'Min Ease Factor', value: initialSettings.minEaseFactor.toFixed(1), description: 'Minimum difficulty floor' },
            { label: 'Max Interval', value: `${initialSettings.maxIntervalDays} days`, description: 'Maximum days between reviews' },
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

        <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
          <h4 className="font-medium mb-3 text-sm text-gray-900 dark:text-gray-100 flex items-center gap-2">
            Sample Review Schedule
            <span className="text-xs text-gray-500 dark:text-gray-400 font-normal">(assuming all correct recalls)</span>
          </h4>
          <div className="space-y-2">
            {readOnlySchedule.slice(0, 4).map((item) => (
              <div key={item.review} className="flex items-center justify-between p-2 bg-white dark:bg-gray-900 rounded text-sm">
                <div className="font-medium text-gray-900 dark:text-gray-100">Review #{item.review}</div>
                <div className="text-gray-500 dark:text-gray-400 text-xs">
                  After <strong className="text-gray-900 dark:text-gray-100">{item.interval}</strong> days • Day <strong className="text-gray-900 dark:text-gray-100">{item.day}</strong>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  // Edit mode view
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
          🧠 Spaced Repetition Algorithm (SM-2)
        </h3>
        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
          Configure the SuperMemo 2 algorithm parameters for optimal memory verse retention.
        </p>
      </div>

      <div className="space-y-6">
        {/* Reset Button */}
        <div className="flex justify-end">
          <button
            onClick={handleReset}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            🔄 Reset to Defaults
          </button>
        </div>

        {/* Parameter Inputs */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Initial Ease Factor */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Initial Ease Factor
              </label>
              <span className="text-sm font-mono font-semibold text-primary">
                {settings.initialEaseFactor.toFixed(1)}
              </span>
            </div>
            <input
              type="range"
              min={1.3}
              max={3.0}
              step={0.1}
              value={settings.initialEaseFactor}
              onChange={(e) => setSettings({ ...settings, initialEaseFactor: parseFloat(e.target.value) })}
              className="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-primary"
            />
            <input
              type="number"
              min={1.3}
              max={3.0}
              step={0.1}
              value={settings.initialEaseFactor}
              onChange={(e) => setSettings({ ...settings, initialEaseFactor: parseFloat(e.target.value) || 2.5 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Starting difficulty multiplier (1.3-3.0). Higher = longer intervals.
            </p>
          </div>

          {/* Initial Interval Days */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Initial Interval (Days)
              </label>
              <span className="text-sm font-mono font-semibold text-primary">
                {settings.initialIntervalDays}
              </span>
            </div>
            <input
              type="range"
              min={1}
              max={7}
              step={1}
              value={settings.initialIntervalDays}
              onChange={(e) => setSettings({ ...settings, initialIntervalDays: parseInt(e.target.value) })}
              className="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-primary"
            />
            <input
              type="number"
              min={1}
              max={7}
              step={1}
              value={settings.initialIntervalDays}
              onChange={(e) => setSettings({ ...settings, initialIntervalDays: parseInt(e.target.value) || 1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Days until first review (1-7). Shorter = more frequent early reviews.
            </p>
          </div>

          {/* Min Ease Factor */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Min Ease Factor
              </label>
              <span className="text-sm font-mono font-semibold text-primary">
                {settings.minEaseFactor.toFixed(1)}
              </span>
            </div>
            <input
              type="range"
              min={1.0}
              max={2.0}
              step={0.1}
              value={settings.minEaseFactor}
              onChange={(e) => setSettings({ ...settings, minEaseFactor: parseFloat(e.target.value) })}
              className="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-primary"
            />
            <input
              type="number"
              min={1.0}
              max={2.0}
              step={0.1}
              value={settings.minEaseFactor}
              onChange={(e) => setSettings({ ...settings, minEaseFactor: parseFloat(e.target.value) || 1.3 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Minimum difficulty floor (1.0-2.0). Prevents intervals from becoming too short.
            </p>
          </div>

          {/* Max Interval Days */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Max Interval (Days)
              </label>
              <span className="text-sm font-mono font-semibold text-primary">
                {settings.maxIntervalDays}
              </span>
            </div>
            <input
              type="range"
              min={30}
              max={730}
              step={30}
              value={settings.maxIntervalDays}
              onChange={(e) => setSettings({ ...settings, maxIntervalDays: parseInt(e.target.value) })}
              className="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-primary"
            />
            <input
              type="number"
              min={30}
              max={730}
              step={30}
              value={settings.maxIntervalDays}
              onChange={(e) => setSettings({ ...settings, maxIntervalDays: parseInt(e.target.value) || 365 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Maximum days between reviews (30-730). Caps interval growth.
            </p>
          </div>
        </div>

        {/* Algorithm Explanation */}
        <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <div className="flex items-start gap-2">
            <span className="text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0">ℹ️</span>
            <div className="space-y-2 text-sm text-blue-800 dark:text-blue-200">
              <p className="font-medium">SuperMemo 2 (SM-2) Algorithm</p>
              <p className="text-xs leading-relaxed">
                The SM-2 algorithm optimizes review timing based on user performance. When a verse is recalled correctly,
                the interval increases exponentially (multiplied by ease factor). Incorrect recalls decrease the ease factor,
                making reviews more frequent. This ensures optimal retention with minimal reviews.
              </p>
            </div>
          </div>
        </div>

        {/* Sample Review Schedule */}
        <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg space-y-4">
          <h4 className="font-medium mb-3 text-sm text-gray-900 dark:text-gray-100 flex items-center gap-2">
            Sample Review Schedule
            <span className="text-xs text-gray-500 dark:text-gray-400 font-normal">(assuming all correct recalls)</span>
          </h4>

          <div className="space-y-2">
            {sampleSchedule.map((item) => (
              <div key={item.review} className="flex items-center justify-between p-3 bg-white dark:bg-gray-900 rounded border border-gray-300 dark:border-gray-600 text-sm">
                <div className="font-medium text-gray-900 dark:text-gray-100">Review #{item.review}</div>
                <div className="flex items-center gap-4 text-gray-500 dark:text-gray-400 text-xs">
                  <span>After <strong className="text-gray-900 dark:text-gray-100">{item.interval}</strong> days</span>
                  <span className="text-gray-400 dark:text-gray-600">•</span>
                  <span>Day <strong className="text-gray-900 dark:text-gray-100">{item.day}</strong></span>
                </div>
              </div>
            ))}
            {sampleSchedule.length === 0 && (
              <p className="text-xs text-gray-500 dark:text-gray-400 italic text-center py-4">
                No schedule generated. Check parameter values.
              </p>
            )}
          </div>

          <p className="text-xs text-gray-500 dark:text-gray-400 italic">
            💡 Actual schedule varies based on user performance. This preview assumes perfect recall (quality: 4/5).
          </p>
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
