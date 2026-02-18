'use client'

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'

interface TokenUsage {
  id: string
  user_id: string
  user_email?: string
  token_cost: number
  daily_tokens_used: number
  purchased_tokens_used: number
  feature_name: string
  operation_type: string
  user_plan: string
  study_mode?: string
  language: string
  content_title?: string
  content_reference?: string
  input_type?: string
  created_at: string
}

export default function UsageHistoryTab() {
  const [dateRange, setDateRange] = useState('today')
  const [featureFilter, setFeatureFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')

  const { data: usageHistory, isLoading } = useQuery<TokenUsage[]>({
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

  const formatDateTime = (date: string) => {
    return new Date(date).toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
        {/* Date Range */}
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

        {/* Feature Filter */}
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

        {/* Search */}
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

      {/* Table */}
      {isLoading ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-gray-500">Loading usage history...</div>
        </div>
      ) : !usageHistory || usageHistory.length === 0 ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-gray-500">No usage records found</div>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
          <table className="w-full">
            <thead className="border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
              <tr>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Time</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">User</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Feature</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Details</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Cost</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Source</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {usageHistory.map((usage) => (
                <tr key={usage.id} className="hover:bg-gray-50 dark:hover:bg-gray-900">
                  <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                    {formatDateTime(usage.created_at)}
                  </td>
                  <td className="px-4 py-3">
                    <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                      {usage.user_email || 'Anonymous'}
                    </div>
                    <div className="text-xs text-gray-500 dark:text-gray-400">
                      {usage.user_plan}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                    {usage.feature_name}
                  </td>
                  <td className="px-4 py-3">
                    <div className="text-sm text-gray-900 dark:text-gray-100">
                      {usage.content_title || usage.content_reference || usage.operation_type}
                    </div>
                    {usage.study_mode && (
                      <div className="text-xs text-gray-500 dark:text-gray-400">
                        Mode: {usage.study_mode} | Lang: {usage.language}
                      </div>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    {usage.token_cost}
                  </td>
                  <td className="px-4 py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {usage.daily_tokens_used > 0 ? (
                      <span className="text-green-600 dark:text-green-400">Daily</span>
                    ) : (
                      <span className="text-purple-600 dark:text-purple-400">Purchased</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Summary */}
          <div className="border-t border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-900">
            <div className="flex justify-between text-sm font-medium text-gray-900 dark:text-gray-100">
              <span>Total Entries: {usageHistory.length}</span>
              <span>Total Tokens: {usageHistory.reduce((sum, u) => sum + u.token_cost, 0)}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
