'use client'

import { useState } from 'react'
import { format } from 'date-fns'
import type { DateRange, DateRangePreset } from '@/lib/utils/date'
import { getDateRangePreset } from '@/lib/utils/date'

interface DateRangePickerProps {
  value: DateRange
  onChange: (range: DateRange) => void
}

const presets: { label: string; value: DateRangePreset }[] = [
  { label: 'Today', value: 'today' },
  { label: 'Last 7 Days', value: '7days' },
  { label: 'Last 30 Days', value: '30days' },
  { label: 'Custom', value: 'custom' },
]

export function DateRangePicker({ value, onChange }: DateRangePickerProps) {
  const [selectedPreset, setSelectedPreset] = useState<DateRangePreset>('7days')
  const [showCustom, setShowCustom] = useState(false)

  const handlePresetChange = (preset: DateRangePreset) => {
    setSelectedPreset(preset)

    if (preset === 'custom') {
      setShowCustom(true)
    } else {
      setShowCustom(false)
      const range = getDateRangePreset(preset)
      onChange(range)
    }
  }

  const handleCustomDateChange = (type: 'from' | 'to', dateString: string) => {
    const date = new Date(dateString)
    if (type === 'from') {
      onChange({ from: date, to: value.to })
    } else {
      onChange({ from: value.from, to: date })
    }
  }

  return (
    <div className="flex flex-col gap-4 rounded-lg bg-white p-4 shadow-sm dark:bg-gray-800">
      <div className="flex gap-2">
        {presets.map((preset) => (
          <button
            key={preset.value}
            onClick={() => handlePresetChange(preset.value)}
            className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
              selectedPreset === preset.value
                ? 'bg-primary text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
            }`}
          >
            {preset.label}
          </button>
        ))}
      </div>

      {showCustom && (
        <div className="flex gap-4">
          <div className="flex-1">
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              From
            </label>
            <input
              type="date"
              value={format(value.from, 'yyyy-MM-dd')}
              onChange={(e) => handleCustomDateChange('from', e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            />
          </div>
          <div className="flex-1">
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              To
            </label>
            <input
              type="date"
              value={format(value.to, 'yyyy-MM-dd')}
              onChange={(e) => handleCustomDateChange('to', e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            />
          </div>
        </div>
      )}

      <div className="text-sm text-gray-600 dark:text-gray-400">
        Showing data from {format(value.from, 'MMM dd, yyyy')} to{' '}
        {format(value.to, 'MMM dd, yyyy')}
      </div>
    </div>
  )
}
