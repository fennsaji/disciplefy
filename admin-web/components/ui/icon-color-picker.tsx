'use client'

import { useState } from 'react'

interface IconColorPickerProps {
  selectedIcon: string
  selectedColor: string
  onIconChange: (icon: string) => void
  onColorChange: (color: string) => void
  disabled?: boolean
}

const ICONS = [
  { name: 'book', emoji: '📖', label: 'Book' },
  { name: 'school', emoji: '🎓', label: 'School' },
  { name: 'cross', emoji: '✝️', label: 'Cross' },
  { name: 'heart', emoji: '❤️', label: 'Heart' },
  { name: 'star', emoji: '⭐', label: 'Star' },
  { name: 'pray', emoji: '🙏', label: 'Pray' },
  { name: 'dove', emoji: '🕊️', label: 'Dove' },
  { name: 'light', emoji: '💡', label: 'Light' },
  { name: 'path', emoji: '🛤️', label: 'Path' },
  { name: 'compass', emoji: '🧭', label: 'Compass' },
  { name: 'crown', emoji: '👑', label: 'Crown' },
  { name: 'mountain', emoji: '⛰️', label: 'Mountain' },
]

const COLORS = [
  { name: 'Purple', value: '#6A4FB6', label: 'Primary Purple' },
  { name: 'Blue', value: '#3B82F6', label: 'Blue' },
  { name: 'Green', value: '#10B981', label: 'Green' },
  { name: 'Red', value: '#EF4444', label: 'Red' },
  { name: 'Orange', value: '#F59E0B', label: 'Orange' },
  { name: 'Pink', value: '#EC4899', label: 'Pink' },
  { name: 'Indigo', value: '#6366F1', label: 'Indigo' },
  { name: 'Teal', value: '#14B8A6', label: 'Teal' },
]

export function IconColorPicker({
  selectedIcon,
  selectedColor,
  onIconChange,
  onColorChange,
  disabled = false,
}: IconColorPickerProps) {
  const [showIconPicker, setShowIconPicker] = useState(false)
  const [showColorPicker, setShowColorPicker] = useState(false)

  const selectedIconData = ICONS.find((i) => i.name === selectedIcon)

  return (
    <div className="space-y-4">
      {/* Icon Picker */}
      <div>
        <label className="mb-2 block text-sm font-medium text-gray-700">
          Icon
        </label>
        <div className="relative">
          <button
            type="button"
            onClick={() => !disabled && setShowIconPicker(!showIconPicker)}
            disabled={disabled}
            className="flex w-full items-center justify-between rounded-lg border border-gray-300 px-4 py-2 hover:bg-gray-50 disabled:cursor-not-allowed disabled:bg-gray-50 disabled:opacity-50"
          >
            <div className="flex items-center gap-2">
              <span className="text-2xl">{selectedIconData?.emoji}</span>
              <span className="text-gray-700">
                {selectedIconData?.label || 'Select icon'}
              </span>
            </div>
            <svg
              className="h-5 w-5 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M19 9l-7 7-7-7"
              />
            </svg>
          </button>

          {showIconPicker && !disabled && (
            <div className="absolute z-10 mt-2 w-full rounded-lg border border-gray-200 bg-white p-4 shadow-lg">
              <div className="grid grid-cols-4 gap-2">
                {ICONS.map((icon) => (
                  <button
                    key={icon.name}
                    type="button"
                    onClick={() => {
                      onIconChange(icon.name)
                      setShowIconPicker(false)
                    }}
                    className={`flex flex-col items-center gap-1 rounded-lg p-3 hover:bg-gray-100 ${
                      selectedIcon === icon.name ? 'bg-primary-50 ring-2 ring-primary' : ''
                    }`}
                  >
                    <span className="text-2xl">{icon.emoji}</span>
                    <span className="text-xs text-gray-600">{icon.label}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Color Picker */}
      <div>
        <label className="mb-2 block text-sm font-medium text-gray-700">
          Color
        </label>
        <div className="relative">
          <button
            type="button"
            onClick={() => !disabled && setShowColorPicker(!showColorPicker)}
            disabled={disabled}
            className="flex w-full items-center justify-between rounded-lg border border-gray-300 px-4 py-2 hover:bg-gray-50 disabled:cursor-not-allowed disabled:bg-gray-50 disabled:opacity-50"
          >
            <div className="flex items-center gap-3">
              <div
                className="h-6 w-6 rounded border border-gray-300"
                style={{ backgroundColor: selectedColor }}
              />
              <span className="text-gray-700">{selectedColor}</span>
            </div>
            <svg
              className="h-5 w-5 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M19 9l-7 7-7-7"
              />
            </svg>
          </button>

          {showColorPicker && !disabled && (
            <div className="absolute z-10 mt-2 w-full rounded-lg border border-gray-200 bg-white p-4 shadow-lg">
              <div className="grid grid-cols-4 gap-2">
                {COLORS.map((color) => (
                  <button
                    key={color.value}
                    type="button"
                    onClick={() => {
                      onColorChange(color.value)
                      setShowColorPicker(false)
                    }}
                    className={`flex flex-col items-center gap-2 rounded-lg p-3 hover:bg-gray-100 ${
                      selectedColor === color.value ? 'ring-2 ring-primary' : ''
                    }`}
                  >
                    <div
                      className="h-8 w-8 rounded-full border border-gray-300"
                      style={{ backgroundColor: color.value }}
                    />
                    <span className="text-xs text-gray-600">{color.name}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Preview */}
      <div className="rounded-lg border border-gray-200 p-4">
        <p className="mb-2 text-sm font-medium text-gray-700">Preview</p>
        <div
          className="flex items-center gap-3 rounded-lg p-4"
          style={{ backgroundColor: `${selectedColor}20` }}
        >
          <span className="text-3xl">{selectedIconData?.emoji}</span>
          <div>
            <p className="font-medium" style={{ color: selectedColor }}>
              Sample Title
            </p>
            <p className="text-sm text-gray-600">This is how it will look</p>
          </div>
        </div>
      </div>
    </div>
  )
}
