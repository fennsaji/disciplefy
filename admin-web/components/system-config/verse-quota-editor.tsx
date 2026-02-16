'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface VerseQuotaEditorProps {
  initialQuotas?: {
    free: number
    standard: number
    plus: number
    premium: number
  }
  onSave?: (quotas: {
    free: number
    standard: number
    plus: number
    premium: number
  }) => Promise<void>
  isEditing?: boolean
  onEditStart?: () => void
  onCancel?: () => void
}

export default function VerseQuotaEditor({
  initialQuotas = { free: 3, standard: 5, plus: 10, premium: -1 },
  onSave,
  isEditing = false,
  onEditStart,
  onCancel,
}: VerseQuotaEditorProps) {
  const [quotas, setQuotas] = useState(initialQuotas)
  const [isSaving, setIsSaving] = useState(false)

  const handleSave = async () => {
    try {
      setIsSaving(true)

      // Validation
      if (quotas.premium !== -1 && (
        quotas.standard < quotas.free ||
        quotas.plus < quotas.standard ||
        quotas.premium < quotas.plus
      )) {
        toast.error('Quotas should increase with tier (Standard ≥ Free, Plus ≥ Standard, Premium ≥ Plus)')
        return
      }

      if (onSave) {
        await onSave(quotas)
      } else {
        // Default save to API
        const res = await fetch('/api/admin/system-config/memory-verses/verse-quotas', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(quotas),
          credentials: 'include',
        })

        if (!res.ok) {
          const error = await res.json()
          throw new Error(error.error || 'Failed to update verse quotas')
        }

        toast.success('Verse quotas updated successfully')
      }

      // Exit edit mode after successful save
      if (onCancel) onCancel()
    } catch (error) {
      console.error('Error saving verse quotas:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to update verse quotas')
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setQuotas(initialQuotas)
    if (onCancel) onCancel()
  }

  const handlePreset = (preset: 'strict' | 'moderate' | 'generous') => {
    const presets = {
      strict: { free: 2, standard: 3, plus: 5, premium: -1 },
      moderate: { free: 3, standard: 5, plus: 10, premium: -1 },
      generous: { free: 5, standard: 10, plus: 20, premium: -1 },
    }
    setQuotas(presets[preset])
  }

  // Read-only view
  if (!isEditing) {
    return (
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
              📖 Memory Verse Quotas
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
              Maximum number of active memory verses per tier
            </p>
          </div>
          <button
            onClick={onEditStart}
            className="px-4 py-2 bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            ✏️ Edit
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { label: 'Free Tier', value: initialQuotas.free },
            { label: 'Standard Tier', value: initialQuotas.standard },
            { label: 'Plus Tier', value: initialQuotas.plus },
            { label: 'Premium Tier', value: initialQuotas.premium },
          ].map(({ label, value }) => (
            <div key={label} className="p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
              <div className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                {label}
              </div>
              <div className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                {value === -1 ? '∞' : value}
              </div>
              <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                {value === -1 ? 'Unlimited verses' : `${value} active verse${value > 1 ? 's' : ''}`}
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  // Edit mode view
  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
          📖 Memory Verse Quotas
        </h3>
        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
          Configure maximum number of active memory verses users can have for each tier.
          Set to -1 for unlimited (Premium default).
        </p>
      </div>

      <div className="space-y-6">
        {/* Preset Buttons */}
        <div className="flex gap-2">
          <button
            onClick={() => handlePreset('strict')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Strict
          </button>
          <button
            onClick={() => handlePreset('moderate')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Moderate
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
              value={quotas.free}
              onChange={(e) => setQuotas({ ...quotas, free: parseInt(e.target.value) || 1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {quotas.free} active verse{quotas.free > 1 ? 's' : ''}
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
              value={quotas.standard}
              onChange={(e) => setQuotas({ ...quotas, standard: parseInt(e.target.value) || 1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {quotas.standard} active verse{quotas.standard > 1 ? 's' : ''}
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
              value={quotas.plus}
              onChange={(e) => setQuotas({ ...quotas, plus: parseInt(e.target.value) || 1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {quotas.plus} active verse{quotas.plus > 1 ? 's' : ''}
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
              value={quotas.premium}
              onChange={(e) => setQuotas({ ...quotas, premium: parseInt(e.target.value) || -1 })}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
            />
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {quotas.premium === -1 ? 'Unlimited verses' : `${quotas.premium} active verses`}
            </p>
          </div>
        </div>

        {/* Visual Preview */}
        <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
          <h4 className="font-medium mb-3 text-sm text-gray-900 dark:text-gray-100">Preview</h4>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Free users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">Can have {quotas.free} active verse{quotas.free > 1 ? 's' : ''}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Standard users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">Can have {quotas.standard} active verse{quotas.standard > 1 ? 's' : ''}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Plus users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">Can have {quotas.plus} active verse{quotas.plus > 1 ? 's' : ''}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Premium users:</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">{quotas.premium === -1 ? 'Unlimited active verses' : `Can have ${quotas.premium} active verses`}</span>
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
