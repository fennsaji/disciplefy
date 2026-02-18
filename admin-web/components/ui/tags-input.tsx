'use client'

import { useState, KeyboardEvent } from 'react'

interface TagsInputProps {
  tags: string[]
  onChange: (tags: string[]) => void
  placeholder?: string
  disabled?: boolean
  suggestions?: string[]
}

export function TagsInput({
  tags,
  onChange,
  placeholder = 'Add tags...',
  disabled = false,
  suggestions = [],
}: TagsInputProps) {
  const [inputValue, setInputValue] = useState('')
  const [showSuggestions, setShowSuggestions] = useState(false)

  // Filter suggestions based on input and exclude already added tags
  const filteredSuggestions = suggestions
    .filter(
      (s) =>
        s.toLowerCase().includes(inputValue.toLowerCase()) &&
        !tags.includes(s)
    )
    .slice(0, 5)

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault()
      addTag()
    } else if (e.key === 'Backspace' && inputValue === '' && tags.length > 0) {
      // Remove last tag when backspace is pressed on empty input
      removeTag(tags.length - 1)
    }
  }

  const addTag = () => {
    const trimmedValue = inputValue.trim()
    if (trimmedValue && !tags.includes(trimmedValue)) {
      onChange([...tags, trimmedValue])
      setInputValue('')
      setShowSuggestions(false)
    }
  }

  const removeTag = (index: number) => {
    onChange(tags.filter((_, i) => i !== index))
  }

  const addSuggestion = (suggestion: string) => {
    if (!tags.includes(suggestion)) {
      onChange([...tags, suggestion])
      setInputValue('')
      setShowSuggestions(false)
    }
  }

  return (
    <div className="space-y-2">
      {/* Tags Display */}
      <div className="flex flex-wrap gap-2 rounded-lg border border-gray-300 bg-white p-3">
        {tags.map((tag, index) => (
          <span
            key={index}
            className="inline-flex items-center gap-1 rounded-full bg-primary-100 px-3 py-1 text-sm font-medium text-primary-800"
          >
            {tag}
            {!disabled && (
              <button
                type="button"
                onClick={() => removeTag(index)}
                className="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-full hover:bg-primary-200"
              >
                <svg
                  className="h-3 w-3"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            )}
          </span>
        ))}

        {/* Input */}
        <div className="relative flex-1">
          <input
            type="text"
            value={inputValue}
            onChange={(e) => {
              setInputValue(e.target.value)
              setShowSuggestions(e.target.value.length > 0)
            }}
            onKeyDown={handleKeyDown}
            onBlur={() => {
              // Delay hiding suggestions to allow clicking on them
              setTimeout(() => setShowSuggestions(false), 200)
            }}
            onFocus={() => setShowSuggestions(inputValue.length > 0)}
            placeholder={tags.length === 0 ? placeholder : ''}
            disabled={disabled}
            className="min-w-[120px] border-none bg-transparent px-0 py-1 text-sm focus:outline-none disabled:cursor-not-allowed disabled:text-gray-400"
          />

          {/* Suggestions Dropdown */}
          {showSuggestions && filteredSuggestions.length > 0 && (
            <div className="absolute left-0 top-full z-10 mt-1 w-48 rounded-lg border border-gray-200 bg-white py-1 shadow-lg">
              {filteredSuggestions.map((suggestion, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => addSuggestion(suggestion)}
                  className="w-full px-3 py-2 text-left text-sm hover:bg-gray-100"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Help Text */}
      <p className="text-xs text-gray-500">
        Press Enter or comma to add tags. Backspace to remove.
      </p>

      {/* Common Tags (if suggestions provided) */}
      {suggestions.length > 0 && (
        <div>
          <p className="mb-2 text-xs font-medium text-gray-700">
            Common tags:
          </p>
          <div className="flex flex-wrap gap-2">
            {suggestions
              .filter((s) => !tags.includes(s))
              .slice(0, 8)
              .map((suggestion, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => addSuggestion(suggestion)}
                  disabled={disabled}
                  className="rounded-full border border-gray-300 bg-white px-3 py-1 text-xs text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  + {suggestion}
                </button>
              ))}
          </div>
        </div>
      )}
    </div>
  )
}
