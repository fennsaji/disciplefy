'use client'

import { useState } from 'react'
import { toast } from 'sonner'

interface PracticeModesEditorProps {
  initialModes?: {
    free: string[]
    paid: string[]
  }
  onSave?: (modes: {
    free: string[]
    paid: string[]
  }) => Promise<void>
  isEditing?: boolean
  onEditStart?: () => void
  onCancel?: () => void
}

const ALL_PRACTICE_MODES = [
  { value: 'flip_card', label: 'Flip Card', description: 'Classic flashcard experience' },
  { value: 'type_it_out', label: 'Type It Out', description: 'Type the complete verse' },
  { value: 'cloze_practice', label: 'Cloze Practice', description: 'Fill in missing words' },
  { value: 'first_letter', label: 'First Letter', description: 'First letter hints' },
  { value: 'progressive_reveal', label: 'Progressive Reveal', description: 'Reveal one word at a time' },
  { value: 'word_scramble', label: 'Word Scramble', description: 'Unscramble the words' },
  { value: 'word_bank', label: 'Word Bank', description: 'Select words in order' },
  { value: 'audio_practice', label: 'Audio Practice', description: 'Listen and recite' },
]

export default function PracticeModesEditor({
  initialModes = {
    free: ['flip_card', 'type_it_out'],
    paid: ALL_PRACTICE_MODES.map(m => m.value)
  },
  onSave,
  isEditing = false,
  onEditStart,
  onCancel,
}: PracticeModesEditorProps) {
  const [freeModes, setFreeModes] = useState<string[]>(initialModes.free)
  const [paidModes, setPaidModes] = useState<string[]>(initialModes.paid)
  const [isSaving, setIsSaving] = useState(false)

  const handleSave = async () => {
    try {
      setIsSaving(true)

      // Validation
      if (freeModes.length < 2) {
        toast.error('Free tier should have at least 2 practice modes')
        return
      }

      // Check that free modes are a subset of paid modes
      const invalidFreeModes = freeModes.filter(mode => !paidModes.includes(mode))
      if (invalidFreeModes.length > 0) {
        toast.error('Free tier modes must be a subset of paid tier modes')
        return
      }

      if (onSave) {
        await onSave({ free: freeModes, paid: paidModes })
      } else {
        // Default save to API
        const res = await fetch('/api/admin/system-config/memory-verses/practice-modes', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ free: freeModes, paid: paidModes }),
          credentials: 'include',
        })

        if (!res.ok) {
          const error = await res.json()
          throw new Error(error.error || 'Failed to update practice modes')
        }

        toast.success('Practice modes updated successfully')
      }

      // Exit edit mode after successful save
      if (onCancel) onCancel()
    } catch (error) {
      console.error('Error saving practice modes:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to update practice modes')
    } finally {
      setIsSaving(false)
    }
  }

  const handleCancel = () => {
    setFreeModes(initialModes.free)
    setPaidModes(initialModes.paid)
    if (onCancel) onCancel()
  }

  const handlePreset = (preset: 'minimal' | 'balanced' | 'all') => {
    const presets = {
      minimal: {
        free: ['flip_card', 'type_it_out'],
        paid: ['flip_card', 'type_it_out', 'cloze_practice', 'first_letter', 'progressive_reveal', 'word_scramble'],
      },
      balanced: {
        free: ['flip_card', 'type_it_out', 'cloze_practice'],
        paid: ALL_PRACTICE_MODES.map(m => m.value),
      },
      all: {
        free: ALL_PRACTICE_MODES.map(m => m.value),
        paid: ALL_PRACTICE_MODES.map(m => m.value),
      },
    }
    setFreeModes(presets[preset].free)
    setPaidModes(presets[preset].paid)
  }

  const toggleFreeMode = (modeValue: string, checked: boolean) => {
    if (checked) {
      setFreeModes([...freeModes, modeValue])
    } else {
      setFreeModes(freeModes.filter(m => m !== modeValue))
    }
  }

  const togglePaidMode = (modeValue: string, checked: boolean) => {
    if (checked) {
      setPaidModes([...paidModes, modeValue])
    } else {
      setPaidModes(paidModes.filter(m => m !== modeValue))
      // If removing from paid, also remove from free
      if (freeModes.includes(modeValue)) {
        setFreeModes(freeModes.filter(m => m !== modeValue))
      }
    }
  }

  // Read-only view
  if (!isEditing) {
    return (
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
              📖 Practice Mode Availability
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
              Available practice modes per tier
            </p>
          </div>
          <button
            onClick={onEditStart}
            className="px-4 py-2 bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            ✏️ Edit
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Free Tier */}
          <div className="p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="flex items-center justify-between mb-4">
              <h4 className="text-base font-semibold text-gray-900 dark:text-gray-100">Free Tier</h4>
              <span className="text-sm text-gray-500 dark:text-gray-400">
                {initialModes.free.length} / {ALL_PRACTICE_MODES.length} modes
              </span>
            </div>
            <ul className="space-y-2">
              {initialModes.free.map(mode => {
                const modeInfo = ALL_PRACTICE_MODES.find(m => m.value === mode)
                return (
                  <li key={mode} className="flex items-center gap-2 text-sm">
                    <span className="text-green-600 dark:text-green-400">✓</span>
                    <div>
                      <div className="font-medium text-gray-900 dark:text-gray-100">{modeInfo?.label}</div>
                      <div className="text-xs text-gray-500 dark:text-gray-400">{modeInfo?.description}</div>
                    </div>
                  </li>
                )
              })}
            </ul>
          </div>

          {/* Paid Tier */}
          <div className="p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="flex items-center justify-between mb-4">
              <h4 className="text-base font-semibold text-gray-900 dark:text-gray-100">Paid Tier</h4>
              <span className="text-sm text-gray-500 dark:text-gray-400">
                {initialModes.paid.length} / {ALL_PRACTICE_MODES.length} modes
              </span>
            </div>
            <ul className="space-y-2">
              {initialModes.paid.map(mode => {
                const modeInfo = ALL_PRACTICE_MODES.find(m => m.value === mode)
                return (
                  <li key={mode} className="flex items-center gap-2 text-sm">
                    <span className="text-green-600 dark:text-green-400">✓</span>
                    <div>
                      <div className="font-medium text-gray-900 dark:text-gray-100">{modeInfo?.label}</div>
                      <div className="text-xs text-gray-500 dark:text-gray-400">{modeInfo?.description}</div>
                    </div>
                  </li>
                )
              })}
            </ul>
          </div>
        </div>
      </div>
    )
  }

  // Edit mode view
  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
          📖 Practice Mode Availability
        </h3>
        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
          Configure which practice modes are available for Free and Paid (Standard/Plus/Premium) users.
        </p>
      </div>

      <div className="space-y-6">
        {/* Preset Buttons */}
        <div className="flex gap-2">
          <button
            onClick={() => handlePreset('minimal')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Minimal (2 Free, 6 Paid)
          </button>
          <button
            onClick={() => handlePreset('balanced')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            Balanced (3 Free, All Paid)
          </button>
          <button
            onClick={() => handlePreset('all')}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            All Modes (8 Free, 8 Paid)
          </button>
        </div>

        {/* Practice Modes Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Free Tier */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h4 className="text-base font-semibold text-gray-900 dark:text-gray-100">Free Tier Modes</h4>
              <span className="text-sm text-gray-500 dark:text-gray-400">
                {freeModes.length} / {ALL_PRACTICE_MODES.length} selected
              </span>
            </div>
            <div className="space-y-3 border border-gray-300 dark:border-gray-600 rounded-lg p-4 bg-gray-50 dark:bg-gray-800">
              {ALL_PRACTICE_MODES.map((mode) => (
                <div key={mode.value} className="flex items-start space-x-3">
                  <input
                    type="checkbox"
                    id={`free-${mode.value}`}
                    checked={freeModes.includes(mode.value)}
                    onChange={(e) => toggleFreeMode(mode.value, e.target.checked)}
                    disabled={!paidModes.includes(mode.value)}
                    className="mt-1 h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary disabled:opacity-50 disabled:cursor-not-allowed"
                  />
                  <div className="flex-1">
                    <label
                      htmlFor={`free-${mode.value}`}
                      className={`text-sm font-medium block mb-1 cursor-pointer ${
                        !paidModes.includes(mode.value) ? 'text-gray-400 dark:text-gray-600' : 'text-gray-900 dark:text-gray-100'
                      }`}
                    >
                      {mode.label}
                    </label>
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      {mode.description}
                    </p>
                  </div>
                </div>
              ))}
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 italic">
              ℹ️ Free modes must be a subset of paid modes. At least 2 modes recommended.
            </p>
          </div>

          {/* Paid Tier */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h4 className="text-base font-semibold text-gray-900 dark:text-gray-100">Paid Tier Modes</h4>
              <span className="text-sm text-gray-500 dark:text-gray-400">
                {paidModes.length} / {ALL_PRACTICE_MODES.length} selected
              </span>
            </div>
            <div className="space-y-3 border border-gray-300 dark:border-gray-600 rounded-lg p-4 bg-gray-50 dark:bg-gray-800">
              {ALL_PRACTICE_MODES.map((mode) => (
                <div key={mode.value} className="flex items-start space-x-3">
                  <input
                    type="checkbox"
                    id={`paid-${mode.value}`}
                    checked={paidModes.includes(mode.value)}
                    onChange={(e) => togglePaidMode(mode.value, e.target.checked)}
                    className="mt-1 h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                  />
                  <div className="flex-1">
                    <label
                      htmlFor={`paid-${mode.value}`}
                      className="text-sm font-medium text-gray-900 dark:text-gray-100 block mb-1 cursor-pointer"
                    >
                      {mode.label}
                    </label>
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      {mode.description}
                    </p>
                  </div>
                </div>
              ))}
            </div>
            <p className="text-xs text-gray-500 dark:text-gray-400 italic">
              ℹ️ All 8 modes recommended for optimal experience.
            </p>
          </div>
        </div>

        {/* Visual Preview */}
        <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg space-y-4">
          <h4 className="font-medium mb-3 text-sm text-gray-900 dark:text-gray-100">Preview</h4>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 text-sm">
            <div>
              <div className="font-medium mb-2 text-gray-900 dark:text-gray-100">Free Tier ({freeModes.length} modes):</div>
              <div className="bg-white dark:bg-gray-900 p-3 rounded border border-gray-300 dark:border-gray-600">
                {freeModes.length > 0 ? (
                  <ul className="list-disc list-inside space-y-1">
                    {freeModes.map(mode => (
                      <li key={mode} className="text-xs text-gray-900 dark:text-gray-100">
                        {ALL_PRACTICE_MODES.find(m => m.value === mode)?.label}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-xs text-gray-500 dark:text-gray-400 italic">No modes selected</p>
                )}
              </div>
            </div>

            <div>
              <div className="font-medium mb-2 text-gray-900 dark:text-gray-100">Paid Tier ({paidModes.length} modes):</div>
              <div className="bg-white dark:bg-gray-900 p-3 rounded border border-gray-300 dark:border-gray-600">
                {paidModes.length > 0 ? (
                  <ul className="list-disc list-inside space-y-1">
                    {paidModes.map(mode => (
                      <li key={mode} className="text-xs text-gray-900 dark:text-gray-100">
                        {ALL_PRACTICE_MODES.find(m => m.value === mode)?.label}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-xs text-gray-500 dark:text-gray-400 italic">No modes selected</p>
                )}
              </div>
            </div>
          </div>

          <div className="border-t border-gray-300 dark:border-gray-700 pt-3 mt-3">
            <div className="text-xs text-gray-500 dark:text-gray-400">
              <strong>JSON Arrays (database format):</strong>
            </div>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-2 mt-2">
              <code className="text-xs bg-white dark:bg-gray-900 p-2 rounded block overflow-auto border border-gray-300 dark:border-gray-600 text-gray-900 dark:text-gray-100">
                free: {JSON.stringify(freeModes)}
              </code>
              <code className="text-xs bg-white dark:bg-gray-900 p-2 rounded block overflow-auto border border-gray-300 dark:border-gray-600 text-gray-900 dark:text-gray-100">
                paid: {JSON.stringify(paidModes)}
              </code>
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
