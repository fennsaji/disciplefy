'use client'

import { Fragment, useState } from 'react'
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

  const LANG_LABELS: Record<string, string> = {
    en: 'English', hi: 'Hindi', ml: 'Malayalam', esv: 'English (ESV)',
    ta: 'Tamil', te: 'Telugu', kn: 'Kannada',
  }

  const getLanguageDisplay = (verse: DailyVerse) => {
    if (verse.language) return verse.language.toUpperCase()
    // Derive from translation keys when language column is null
    const keys = Object.keys(verse.verse_data?.translations ?? {})
    if (keys.length > 0) return keys.map(k => k.toUpperCase()).join(' · ')
    return 'Multi'
  }

  const renderVerseData = (verse_data: Record<string, any>) => {
    const { reference, text, date, translations, referenceTranslations, ...rest } = verse_data

    return (
      <div className="space-y-5">
        {/* Translations */}
        {translations && Object.keys(translations).length > 0 && (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {Object.entries(translations).map(([lang, txt]) => (
              <div key={lang} className="rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 p-4 shadow-sm">
                <p className="mb-2 text-xs font-bold uppercase tracking-widest text-indigo-600 dark:text-indigo-400">
                  {LANG_LABELS[lang] ?? lang}
                </p>
                <p className="text-sm leading-relaxed text-gray-700 dark:text-gray-300 italic">
                  "{txt as string}"
                </p>
              </div>
            ))}
          </div>
        )}

        {/* Reference Translations */}
        {referenceTranslations && Object.keys(referenceTranslations).length > 0 && (
          <div className="flex flex-wrap gap-2">
            {Object.entries(referenceTranslations).map(([lang, ref]) => (
              <div key={lang} className="rounded-lg bg-amber-50 dark:bg-amber-400/10 border border-amber-200 dark:border-amber-400/20 px-3 py-1.5">
                <span className="text-xs font-medium text-amber-700 dark:text-amber-400">{LANG_LABELS[lang] ?? lang}: </span>
                <span className="text-xs text-amber-900 dark:text-amber-300">{ref as string}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    )
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
            <Fragment key={verse.id}>
              <tr className="hover:bg-gray-50 dark:hover:bg-gray-800">
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
                  {getLanguageDisplay(verse)}
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
                  <td colSpan={5} className="px-6 py-5 bg-gray-50 dark:bg-gray-800/60">
                    <div className="space-y-4 max-w-3xl">
                      {/* Reference + ESV text */}
                      <div>
                        <p className="text-sm font-bold text-gray-900 dark:text-gray-100">
                          {verse.verse_data?.reference}
                        </p>
                        {verse.verse_data?.translations?.esv && (
                          <p className="mt-1 text-sm italic text-gray-600 dark:text-gray-400">
                            "{verse.verse_data.translations.esv}"
                          </p>
                        )}
                      </div>

                      {/* Structured verse_data */}
                      {renderVerseData(verse.verse_data)}

                      {/* Timestamps */}
                      <div className="flex gap-6 text-xs text-gray-400 dark:text-gray-500 pt-1 border-t border-gray-200 dark:border-gray-700">
                        <span><span className="font-semibold">Created:</span> {new Date(verse.created_at).toLocaleString()}</span>
                        <span><span className="font-semibold">Updated:</span> {new Date(verse.updated_at).toLocaleString()}</span>
                      </div>
                    </div>
                  </td>
                </tr>
              )}
            </Fragment>
          ))}
        </tbody>
      </table>

      {verses.length === 0 && (
        <EmptyState title="No daily verses" description="No daily verses match the current filter." icon="📖" />
      )}
    </div>
  )
}
