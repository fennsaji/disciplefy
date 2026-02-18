'use client'

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'

export default function UsageHistorySection() {
  const [dateRange, setDateRange] = useState('today')
  const [featureFilter, setFeatureFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')

  const { data, isLoading } = useQuery({
    queryKey: ['token-usage-history', dateRange, featureFilter, searchQuery],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.append('range', dateRange)
      if (featureFilter !== 'all') params.append('feature', featureFilter)
      if (searchQuery) params.append('search', searchQuery)

      const response = await fetch(`/api/admin/token-usage-history?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch usage history')
      return response.json()
    },
  })

  const usageHistory = data?.usage_history || []
  const summary = data?.summary || { total_entries: 0, total_tokens: 0 }

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
      <div className="mb-6">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">📈 Token Usage History</h2>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Track token consumption across all features and users
        </p>
      </div>

      {/* Filters */}
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center">
        <select
          value={dateRange}
          onChange={(e) => setDateRange(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="today">Today</option>
          <option value="week">This Week</option>
          <option value="month">This Month</option>
          <option value="all">All Time</option>
        </select>

        <select
          value={featureFilter}
          onChange={(e) => setFeatureFilter(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="all">All Features</option>
          <option value="study_guide">Study Guide</option>
          <option value="conversation">Conversation</option>
          <option value="voice">Voice</option>
          <option value="daily_verse">Daily Verse</option>
        </select>

        <div className="relative flex-1">
          <input
            type="text"
            placeholder="Search by user email..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 pl-10 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          />
          <svg className="absolute left-3 top-2.5 h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </div>
      </div>

      {/* Summary */}
      <div className="mb-4 flex gap-4">
        <div className="rounded-lg border border-gray-200 px-4 py-2 dark:border-gray-700">
          <p className="text-xs text-gray-600 dark:text-gray-400">Total Entries</p>
          <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">{summary.total_entries}</p>
        </div>
        <div className="rounded-lg border border-gray-200 px-4 py-2 dark:border-gray-700">
          <p className="text-xs text-gray-600 dark:text-gray-400">Total Tokens</p>
          <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">{summary.total_tokens}</p>
        </div>
      </div>

      {/* Table */}
      {isLoading ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-gray-500 dark:text-gray-400">Loading usage history...</div>
        </div>
      ) : usageHistory.length === 0 ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-gray-500 dark:text-gray-400">No usage data found</div>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-700">
          <table className="w-full">
            <thead className="border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
              <tr>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Time</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">User</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Feature</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Details</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Tokens</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Source</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {usageHistory.map((record: any) => (
                <tr key={record.id} className="hover:bg-gray-50 dark:hover:bg-gray-900">
                  <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                    {new Date(record.created_at).toLocaleString('en-US', {
                      month: 'short',
                      day: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                    {record.user_email || 'Anonymous'}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                    {record.feature_name}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                    {record.study_mode && <span className="mr-2">Mode: {record.study_mode}</span>}
                    {record.language && <span>Lang: {record.language}</span>}
                  </td>
                  <td className="px-4 py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    {record.token_cost}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <span className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                      record.source_type === 'daily' ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' :
                      'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                    }`}>
                      {record.source_type}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
