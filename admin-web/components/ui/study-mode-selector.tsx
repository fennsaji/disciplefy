'use client'

import type { StudyMode } from '@/types/admin'

interface StudyModeSelectorProps {
  selectedMode: StudyMode
  onChange: (mode: StudyMode) => void
  disabled?: boolean
}

const STUDY_MODES = [
  {
    mode: 'quick' as StudyMode,
    label: 'Quick',
    duration: '3 min',
    description: 'Brief overview for quick insights',
  },
  {
    mode: 'standard' as StudyMode,
    label: 'Standard',
    duration: '10 min',
    description: 'Balanced depth for daily study',
  },
  {
    mode: 'deep' as StudyMode,
    label: 'Deep',
    duration: '25 min',
    description: 'Comprehensive theological exploration',
  },
  {
    mode: 'lectio' as StudyMode,
    label: 'Lectio Divina',
    duration: '15 min',
    description: 'Contemplative scripture meditation',
  },
  {
    mode: 'sermon' as StudyMode,
    label: 'Sermon',
    duration: '50-60 min',
    description: 'Full expository sermon preparation',
  },
]

export function StudyModeSelector({
  selectedMode,
  onChange,
  disabled = false,
}: StudyModeSelectorProps) {
  return (
    <div className="space-y-3">
      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
        Study Mode
      </label>

      <div className="space-y-2">
        {STUDY_MODES.map((modeOption) => (
          <label
            key={modeOption.mode}
            className={`flex cursor-pointer items-start gap-3 rounded-lg border-2 p-4 transition-all ${
              selectedMode === modeOption.mode
                ? 'border-primary bg-primary-50 dark:bg-primary-900/20'
                : 'border-gray-200 hover:border-gray-300 dark:border-gray-600 dark:hover:border-gray-500'
            } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
          >
            <input
              type="radio"
              name="study-mode"
              value={modeOption.mode}
              checked={selectedMode === modeOption.mode}
              onChange={(e) => onChange(e.target.value as StudyMode)}
              disabled={disabled}
              className="mt-1 h-4 w-4 text-primary focus:ring-primary"
            />
            <div className="flex-1">
              <div className="flex items-center justify-between">
                <span className="font-medium text-gray-900 dark:text-gray-100">
                  {modeOption.label}
                </span>
                <span className="text-sm text-gray-500 dark:text-gray-400">
                  {modeOption.duration}
                </span>
              </div>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                {modeOption.description}
              </p>
            </div>
          </label>
        ))}
      </div>

      {/* Info Note */}
      <div className="rounded-lg bg-blue-50 p-3 dark:bg-blue-900/20">
        <p className="text-sm text-blue-800 dark:text-blue-300">
          💡 <strong className="text-blue-900 dark:text-blue-200">Tip:</strong> The selected mode determines the depth of
          theological analysis and study duration.
        </p>
      </div>
    </div>
  )
}
