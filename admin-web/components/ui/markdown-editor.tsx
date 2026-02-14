'use client'

import { useState } from 'react'
import ReactMarkdown from 'react-markdown'

interface MarkdownEditorProps {
  value: string
  onChange: (value: string) => void
  placeholder?: string
  rows?: number
  disabled?: boolean
  label?: string
  showPreview?: boolean
}

export function MarkdownEditor({
  value,
  onChange,
  placeholder = 'Enter markdown text...',
  rows = 8,
  disabled = false,
  label,
  showPreview = true,
}: MarkdownEditorProps) {
  const [activeTab, setActiveTab] = useState<'write' | 'preview'>('write')

  return (
    <div className="space-y-2">
      {/* Label */}
      {label && (
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
          {label}
        </label>
      )}

      {/* Tabs */}
      {showPreview && (
        <div className="flex gap-2 border-b border-gray-200 dark:border-gray-700">
          <button
            type="button"
            onClick={() => setActiveTab('write')}
            disabled={disabled}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              activeTab === 'write'
                ? 'border-b-2 border-primary text-primary dark:text-primary-400'
                : 'text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100'
            } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
          >
            ✏️ Write
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('preview')}
            disabled={disabled}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              activeTab === 'preview'
                ? 'border-b-2 border-primary text-primary dark:text-primary-400'
                : 'text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100'
            } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
          >
            👁️ Preview
          </button>
        </div>
      )}

      {/* Editor / Preview */}
      <div className="rounded-lg border border-gray-300 bg-white dark:border-gray-600 dark:bg-gray-800">
        {activeTab === 'write' ? (
          <textarea
            value={value}
            onChange={(e) => onChange(e.target.value)}
            placeholder={placeholder}
            rows={rows}
            disabled={disabled}
            className="w-full rounded-lg border-none bg-transparent p-4 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 disabled:text-gray-500 dark:text-gray-100 dark:placeholder-gray-500 dark:disabled:bg-gray-700"
          />
        ) : (
          <div className="prose prose-sm max-w-none p-4 dark:prose-invert">
            {value ? (
              <ReactMarkdown>{value}</ReactMarkdown>
            ) : (
              <p className="text-gray-400 dark:text-gray-500">Nothing to preview</p>
            )}
          </div>
        )}
      </div>

      {/* Markdown Help */}
      <div className="rounded-lg bg-gray-50 p-3 dark:bg-gray-800">
        <p className="mb-2 text-xs font-medium text-gray-700 dark:text-gray-300">
          Markdown Quick Reference:
        </p>
        <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-gray-600 dark:text-gray-400 md:grid-cols-4">
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300">**bold**</code>
          </div>
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300">*italic*</code>
          </div>
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300"># Heading</code>
          </div>
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300">- List</code>
          </div>
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300">[link](url)</code>
          </div>
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300">`code`</code>
          </div>
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300">&gt; Quote</code>
          </div>
          <div>
            <code className="rounded bg-gray-200 px-1 dark:bg-gray-700 dark:text-gray-300">---</code> (divider)
          </div>
        </div>
      </div>

      {/* Character Count */}
      <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400">
        <span>{value.length} characters</span>
        <span>{value.split(/\s+/).filter(Boolean).length} words</span>
      </div>
    </div>
  )
}
