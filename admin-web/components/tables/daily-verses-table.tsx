'use client'

import { useState } from 'react'
import { DeleteIcon, ViewIcon, ToggleIcon, actionButtonStyles } from '@/components/ui/action-icons'
import { EmptyState } from '@/components/ui/empty-state'

interface DailyVerse {
  id: string
  date_key: string
  language: string
  verse_data: {
    reference?: string
    text?: string
    [key: string]: any
  }
  is_active: boolean
  created_at: string
  updated_at: string
}

interface DailyVersesTableProps {
  verses: DailyVerse[]
  onToggleActive: (id: string, isActive: boolean) => void
  onDelete: (id: string) => void
}

export default function DailyVersesTable({
  verses,
  onToggleActive,
  onDelete
}: DailyVersesTableProps) {
  const [expandedId, setExpandedId] = useState<string | null>(null)

  const getStatusColor = (isActive: boolean, dateKey: string) => {
    const isPast = new Date(dateKey) < new Date()
    const isFuture = new Date(dateKey) > new Date()

    if (!isActive) {
      return 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
    }
    if (isPast) {
      return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
    }
    if (isFuture) {
      return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
    }
    return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
  }

  const getStatusLabel = (isActive: boolean, dateKey: string) => {
    if (!isActive) return 'Inactive'
    const isPast = new Date(dateKey) < new Date()
    const isFuture = new Date(dateKey) > new Date()
    if (isPast) return 'Past'
    if (isFuture) return 'Upcoming'
    return 'Current'
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Date
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Verse Reference
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Language
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Status
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          {verses.map((verse) => (
            <>
              <tr key={verse.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                  {new Date(verse.date_key).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric'
                  })}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                  {verse.verse_data?.reference || 'N/A'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                  {verse.language?.toUpperCase() || 'N/A'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(verse.is_active, verse.date_key)}`}>
                    {getStatusLabel(verse.is_active, verse.date_key)}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <div className="flex items-center justify-end gap-2">
                    <button
                      type="button"
                      onClick={() => setExpandedId(expandedId === verse.id ? null : verse.id)}
                      className={actionButtonStyles.view}
                      title="View"
                    >
                      <ViewIcon />
                    </button>
                    <button
                      type="button"
                      onClick={() => onToggleActive(verse.id, !verse.is_active)}
                      className={verse.is_active ? actionButtonStyles.toggleActive : actionButtonStyles.toggleInactive}
                      title={verse.is_active ? 'Deactivate' : 'Activate'}
                    >
                      <ToggleIcon />
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        if (confirm('Are you sure you want to delete this daily verse?')) {
                          onDelete(verse.id)
                        }
                      }}
                      className={actionButtonStyles.delete}
                      title="Delete"
                    >
                      <DeleteIcon />
                    </button>
                  </div>
                </td>
              </tr>
              {expandedId === verse.id && (
                <tr>
                  <td colSpan={5} className="px-6 py-4 bg-gray-50 dark:bg-gray-800">
                    <div className="space-y-3">
                      <div>
                        <h4 className="text-sm font-semibold text-gray-900 dark:text-gray-100 mb-1">
                          {verse.verse_data?.reference}
                        </h4>
                        <p className="text-sm text-gray-700 dark:text-gray-300 italic">
                          "{verse.verse_data?.text || 'N/A'}"
                        </p>
                      </div>
                      <div className="grid grid-cols-2 gap-4 text-xs text-gray-600 dark:text-gray-400">
                        <div>
                          <span className="font-semibold">Created:</span>{' '}
                          {new Date(verse.created_at).toLocaleString()}
                        </div>
                        <div>
                          <span className="font-semibold">Updated:</span>{' '}
                          {new Date(verse.updated_at).toLocaleString()}
                        </div>
                      </div>
                      {Object.keys(verse.verse_data).length > 2 && (
                        <div>
                          <h4 className="text-sm font-semibold text-gray-900 dark:text-gray-100 mb-2">
                            Additional Data
                          </h4>
                          <pre className="text-xs bg-gray-100 dark:bg-gray-900 p-3 rounded overflow-x-auto">
                            {JSON.stringify(verse.verse_data, null, 2)}
                          </pre>
                        </div>
                      )}
                    </div>
                  </td>
                </tr>
              )}
            </>
          ))}
        </tbody>
      </table>

      {verses.length === 0 && (
        <EmptyState title="No daily verses" description="No daily verses match the current filter." icon="📖" />
      )}
    </div>
  )
}
