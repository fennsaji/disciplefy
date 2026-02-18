'use client'

import { useState, useEffect } from 'react'

interface UserSearchInputProps {
  value: string
  onChange: (value: string) => void
  onSearch: () => void
  isLoading?: boolean
}

export function UserSearchInput({
  value,
  onChange,
  onSearch,
  isLoading = false,
}: UserSearchInputProps) {
  const [localValue, setLocalValue] = useState(value)

  useEffect(() => {
    setLocalValue(value)
  }, [value])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && localValue.length >= 2) {
      onChange(localValue)
      onSearch()
    }
  }

  const handleSearch = () => {
    if (localValue.length >= 2) {
      onChange(localValue)
      onSearch()
    }
  }

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <div className="flex gap-4">
        <div className="flex-1">
          <input
            type="text"
            value={localValue}
            onChange={(e) => setLocalValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Search users by email, name, or ID..."
            className="w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
            disabled={isLoading}
          />
          {localValue.length > 0 && localValue.length < 2 && (
            <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
              Enter at least 2 characters to search
            </p>
          )}
        </div>
        <button
          onClick={handleSearch}
          disabled={isLoading || localValue.length < 2}
          className="rounded-lg bg-primary px-6 py-2 text-white hover:bg-primary-600 disabled:opacity-50"
        >
          {isLoading ? (
            <span className="flex items-center gap-2">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
              Searching...
            </span>
          ) : (
            'Search'
          )}
        </button>
      </div>
    </div>
  )
}
