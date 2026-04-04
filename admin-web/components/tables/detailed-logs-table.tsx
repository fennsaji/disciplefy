'use client'

import { useState, useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { fetchUsageLogs } from '@/lib/api/admin'
import { formatCurrency, formatCompactNumber, formatDateForAPI } from '@/lib/utils/date'
import type { DateRange } from '@/lib/utils/date'
import type { DetailedLogItem } from '@/types/admin'

interface DetailedLogsTableProps {
  dateRange: DateRange
}

const LANGUAGE_OPTIONS = [
  { value: '', label: 'All Languages' },
  { value: 'en', label: '🇺🇸 English' },
  { value: 'hi', label: '🇮🇳 Hindi' },
  { value: 'ml', label: '🇮🇳 Malayalam' },
]

const STUDY_MODE_OPTIONS = [
  { value: '', label: 'All Modes' },
  { value: 'quick', label: 'Quick' },
  { value: 'standard', label: 'Standard' },
  { value: 'deep', label: 'Deep Study' },
  { value: 'lectio', label: 'Lectio Divina' },
  { value: 'sermon', label: 'Sermon Outline' },
]

const TIER_OPTIONS = [
  { value: '', label: 'All Tiers' },
  { value: 'free', label: 'Free' },
  { value: 'standard', label: 'Standard' },
  { value: 'plus', label: 'Plus' },
  { value: 'premium', label: 'Premium' },
]

const LIMIT_OPTIONS = [25, 50, 100]

function formatUserId(id: string): string {
  return id.substring(0, 8) + '...'
}

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatLanguage(code: string | null): string {
  if (!code) return '—'
  const map: Record<string, string> = { en: '🇺🇸 EN', hi: '🇮🇳 HI', ml: '🇮🇳 ML' }
  return map[code] ?? code
}

function formatStudyMode(mode: string | null): string {
  if (!mode) return '—'
  const map: Record<string, string> = {
    quick: 'Quick',
    standard: 'Standard',
    deep: 'Deep',
    lectio: 'Lectio',
    sermon: 'Sermon Outline',
  }
  return map[mode] ?? mode
}

export function DetailedLogsTable({ dateRange }: DetailedLogsTableProps) {
  const [language, setLanguage] = useState('')
  const [studyMode, setStudyMode] = useState('')
  const [tier, setTier] = useState('')
  const [page, setPage] = useState(1)
  const [limit, setLimit] = useState(25)

  // Reset to page 1 when the date range changes
  useEffect(() => {
    setPage(1)
  }, [dateRange.from, dateRange.to])

  const { data, isLoading, error } = useQuery({
    queryKey: [
      'usage-logs',
      {
        language,
        studyMode,
        tier,
        page,
        limit,
        start_date: formatDateForAPI(dateRange.from),
        end_date: formatDateForAPI(dateRange.to),
      },
    ],
    queryFn: () =>
      fetchUsageLogs({
        start_date: formatDateForAPI(dateRange.from),
        end_date: formatDateForAPI(dateRange.to),
        language: language || undefined,
        study_mode: studyMode || undefined,
        tier: tier || undefined,
        page,
        limit,
      }),
  })

  function handleFilterChange(setter: (v: string) => void) {
    return (e: React.ChangeEvent<HTMLSelectElement>) => {
      setter(e.target.value)
      setPage(1)
    }
  }

  // Use the limit returned in the response to avoid stale state during limit changes
  const totalPages = data ? Math.ceil(data.total / (data.limit ?? limit)) : 0

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
        Detailed Generation Logs
      </h2>

      {/* Filters */}
      <div className="mb-4 flex flex-wrap gap-3">
        <select
          value={language}
          onChange={handleFilterChange(setLanguage)}
          className="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
        >
          {LANGUAGE_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>

        <select
          value={studyMode}
          onChange={handleFilterChange(setStudyMode)}
          className="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
        >
          {STUDY_MODE_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>

        <select
          value={tier}
          onChange={handleFilterChange(setTier)}
          className="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
        >
          {TIER_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>

        <select
          value={limit}
          onChange={(e) => {
            setLimit(Number(e.target.value))
            setPage(1)
          }}
          className="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
        >
          {LIMIT_OPTIONS.map((n) => (
            <option key={n} value={n}>
              {n} rows
            </option>
          ))}
        </select>

        {data && (
          <span className="ml-auto self-center text-sm text-gray-500 dark:text-gray-400">
            {data.total} total records
          </span>
        )}
      </div>

      {/* Loading */}
      {isLoading && (
        <div className="py-8 text-center text-sm text-gray-500 dark:text-gray-400">
          Loading logs...
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400">
          Failed to load logs: {error instanceof Error ? error.message : 'Unknown error'}
        </div>
      )}

      {/* Empty */}
      {!isLoading && !error && data?.items.length === 0 && (
        <div className="py-8 text-center text-sm text-gray-500 dark:text-gray-400">
          No records found for the selected filters.
        </div>
      )}

      {/* Table */}
      {data && data.items.length > 0 && (
        <>
          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead className="border-b border-gray-200 dark:border-gray-700">
                <tr>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400 sticky left-0 z-20 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] dark:bg-gray-800">
                    Date/Time
                  </th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                    User ID
                  </th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                    Language
                  </th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                    Study Mode
                  </th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                    Tier
                  </th>
                  <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                    In Tokens
                  </th>
                  <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                    Out Tokens
                  </th>
                  <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                    Cost
                  </th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                    Model
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                {data.items.map((item: DetailedLogItem) => (
                  <tr key={item.id} className="group">
                    <td className="whitespace-nowrap py-3 text-sm text-gray-600 dark:text-gray-400 sticky left-0 z-10 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] group-hover:bg-gray-50 dark:bg-gray-800 dark:group-hover:bg-gray-700">
                      {formatDateTime(item.created_at)}
                    </td>
                    <td className="py-3 font-mono text-sm text-gray-500 dark:text-gray-400">
                      {formatUserId(item.user_id)}
                    </td>
                    <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                      {formatLanguage(item.language)}
                    </td>
                    <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                      {formatStudyMode(item.study_mode)}
                    </td>
                    <td className="py-3 text-sm capitalize text-gray-600 dark:text-gray-400">
                      {item.tier}
                    </td>
                    <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                      {item.llm_input_tokens != null
                        ? formatCompactNumber(item.llm_input_tokens)
                        : '—'}
                    </td>
                    <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                      {item.llm_output_tokens != null
                        ? formatCompactNumber(item.llm_output_tokens)
                        : '—'}
                    </td>
                    <td className="py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                      {item.llm_cost_usd != null ? formatCurrency(item.llm_cost_usd) : '—'}
                    </td>
                    <td className="py-3 text-sm text-gray-500 dark:text-gray-400">
                      {item.llm_model ?? '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="mt-4 flex items-center justify-between">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page <= 1}
              className="rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-700 disabled:opacity-40 dark:border-gray-600 dark:text-gray-300"
            >
              Previous
            </button>
            <span className="text-sm text-gray-600 dark:text-gray-400">
              Page {page} of {totalPages}
            </span>
            <button
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page >= totalPages}
              className="rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-700 disabled:opacity-40 dark:border-gray-600 dark:text-gray-300"
            >
              Next
            </button>
          </div>
        </>
      )}
    </div>
  )
}
