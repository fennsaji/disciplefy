'use client'

import React, { useState } from 'react'
import { EditIcon, DeleteIcon, ViewIcon, actionButtonStyles } from '@/components/ui/action-icons'
import { EmptyState } from '@/components/ui/empty-state'

interface Translation {
  reference: string
  text: string
}

interface SuggestedVerse {
  id: string
  category: string
  display_order: number
  created_at: string
  translations: Record<string, Translation>
}

interface SuggestedVersesTableProps {
  verses: SuggestedVerse[]
  onEdit: (verse: SuggestedVerse) => void
  onDelete: (id: string) => void
}

export default function SuggestedVersesTable({
  verses,
  onEdit,
  onDelete
}: SuggestedVersesTableProps) {
  const [expandedId, setExpandedId] = useState<string | null>(null)

  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      salvation: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
      comfort: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
      strength: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
      wisdom: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
      promise: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
      guidance: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200',
      faith: 'bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-200',
      love: 'bg-rose-100 text-rose-800 dark:bg-rose-900 dark:text-rose-200',
    }
    return colors[category] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
  }

  const getTranslationCoverage = (translations: Record<string, Translation>) => {
    const languages = Object.keys(translations)
    const total = 3 // en, hi, ml
    const coverage = (languages.length / total) * 100
    return {
      percentage: coverage,
      languages,
      color: coverage === 100 ? 'text-green-600' : coverage >= 66 ? 'text-yellow-600' : 'text-red-600'
    }
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Order
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Category
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Reference (EN)
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Translations
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          {verses.map((verse) => {
            const coverage = getTranslationCoverage(verse.translations)
            return (
              <React.Fragment key={verse.id}>
                <tr className="hover:bg-gray-50 dark:hover:bg-gray-800">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                    #{verse.display_order}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getCategoryColor(verse.category)}`}>
                      {verse.category}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                    {verse.translations.en?.reference || 'N/A'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-2">
                      <span className={`text-sm font-medium ${coverage.color}`}>
                        {coverage.percentage.toFixed(0)}%
                      </span>
                      <div className="flex gap-1">
                        {['en', 'hi', 'ml'].map(lang => (
                          <span
                            key={lang}
                            className={`px-1.5 py-0.5 text-xs rounded ${
                              coverage.languages.includes(lang)
                                ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                                : 'bg-gray-100 text-gray-400 dark:bg-gray-700 dark:text-gray-500'
                            }`}
                          >
                            {lang.toUpperCase()}
                          </span>
                        ))}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
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
                        onClick={() => onEdit(verse)}
                        className={actionButtonStyles.edit}
                        title="Edit"
                      >
                        <EditIcon />
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          if (confirm('Are you sure you want to delete this suggested verse?')) {
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
                      <div className="space-y-4">
                        {Object.entries(verse.translations).map(([lang, translation]) => (
                          <div key={lang} className="border-l-4 border-primary pl-4">
                            <div className="flex items-center gap-2 mb-2">
                              <span className="px-2 py-1 bg-primary text-white text-xs font-semibold rounded">
                                {lang.toUpperCase()}
                              </span>
                              <span className="text-sm font-semibold text-gray-900 dark:text-gray-100">
                                {translation.reference}
                              </span>
                            </div>
                            <p className="text-sm text-gray-700 dark:text-gray-300 italic">
                              "{translation.text}"
                            </p>
                          </div>
                        ))}
                      </div>
                    </td>
                  </tr>
                )}
              </React.Fragment>
            )
          })}
        </tbody>
      </table>

      {verses.length === 0 && (
        <EmptyState title="No verses found" description="No suggested verses match the current filter." icon="📖" />
      )}
    </div>
  )
}
