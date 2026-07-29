'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { FeedbackTable } from '@/components/tables/feedback-table'
import { PurchaseIssuesTable } from '@/components/tables/purchase-issues-table'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'

type TabType = 'purchase-issues' | 'feedback'

const PAGE_SIZE = 50

/** Prev/next controls for a server-paged list. */
function Pagination({
  page,
  total,
  isFetching,
  onChange,
  noun,
}: {
  page: number
  total: number
  isFetching: boolean
  onChange: (page: number) => void
  noun: string
}) {
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))
  return (
    <div className="mt-4 flex items-center justify-between">
      <p className="text-sm text-gray-600 dark:text-gray-400">
        Page {page + 1} of {totalPages} ({total} {noun})
      </p>
      <div className="flex gap-2">
        <button
          onClick={() => onChange(Math.max(0, page - 1))}
          disabled={page === 0 || isFetching}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
        >
          Previous
        </button>
        <button
          onClick={() => onChange(page + 1)}
          disabled={page + 1 >= totalPages || isFetching}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
        >
          Next
        </button>
      </div>
    </div>
  )
}

const TABS = [
  { value: 'purchase-issues', label: 'Purchase Issues', icon: '💳' },
  { value: 'feedback', label: 'User Feedback', icon: '💬' },
]

export default function IssuesPage() {
  const [activeTab, setActiveTab] = useState<TabType>('purchase-issues')

  return (
    <div className="space-y-6">
      <PageHeader
        title="⚠️ Issues & Feedback"
        description="Manage purchase issues and user feedback"
      />

      <TabNav
        tabs={TABS}
        activeTab={activeTab}
        onChange={(v) => setActiveTab(v as TabType)}
      />

      {/* Tab Content */}
      <div className="mt-6">
        {activeTab === 'purchase-issues' && <PurchaseIssuesTab />}
        {activeTab === 'feedback' && <FeedbackTab />}
      </div>
    </div>
  )
}

function PurchaseIssuesTab() {
  const [statusFilter, setStatusFilter] = useState('all')
  const [page, setPage] = useState(0)

  const { data, isLoading, isFetching, error, refetch } = useQuery({
    queryKey: ['purchase-issues', statusFilter, page],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (statusFilter !== 'all') params.append('status', statusFilter)
      params.set('limit', String(PAGE_SIZE))
      params.set('offset', String(page * PAGE_SIZE))

      const response = await fetch(`/api/admin/purchase-issues?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch issues')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const issues = data?.issues ?? []
  const total = data?.total ?? 0
  const byStatus: Record<string, number> = data?.stats?.by_status ?? {}

  return (
    <div className="space-y-6">
      {/* Filter */}
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value)
            setPage(0)
          }}
          className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 sm:w-auto"
        >
          <option value="all">All Status</option>
          <option value="pending">Pending</option>
          <option value="investigating">Investigating</option>
          <option value="resolved">Resolved</option>
          <option value="closed">Closed</option>
        </select>
      </div>

      {/* Status breakdown — counted by Postgres across the whole table */}
      <div className="grid gap-4 md:grid-cols-4">
        {['pending', 'investigating', 'resolved', 'closed'].map((s) => (
          <div key={s} className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm capitalize text-gray-600 dark:text-gray-400">{s}</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">{byStatus[s] ?? 0}</p>
          </div>
        ))}
      </div>

      {/* Purchase Issues Table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">Purchase Issues</h2>

        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading issues...</div>
          </div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Failed to load purchase issues. Please try again.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Retry
            </button>
          </div>
        ) : (
          <>
            <PurchaseIssuesTable issues={issues} />
            <Pagination
              page={page}
              total={total}
              isFetching={isFetching}
              onChange={setPage}
              noun="matching issues"
            />
          </>
        )}
      </div>
    </div>
  )
}

function FeedbackTab() {
  const [categoryFilter, setCategoryFilter] = useState('all')
  const [helpfulFilter, setHelpfulFilter] = useState('all')
  const [page, setPage] = useState(0)

  const { data, isLoading, isFetching, error, refetch } = useQuery({
    queryKey: ['feedback', categoryFilter, helpfulFilter, page],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (categoryFilter !== 'all') params.append('category', categoryFilter)
      if (helpfulFilter !== 'all') params.append('helpful', helpfulFilter)
      params.set('limit', String(PAGE_SIZE))
      params.set('offset', String(page * PAGE_SIZE))

      const response = await fetch(`/api/admin/feedback?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch feedback')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const feedback = data?.feedback ?? []
  const total = data?.total ?? 0
  // Counts and the sentiment average come from the database, over every row
  // matching the filters — not from the rows on this page.
  const stats = data?.stats

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Category:
          </label>
          <select
            value={categoryFilter}
            onChange={(e) => {
              setCategoryFilter(e.target.value)
              setPage(0)
            }}
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 sm:w-auto"
          >
            <option value="all">All Categories</option>
            <option value="general">General</option>
            <option value="bug_report">Bug Report</option>
            <option value="feature_request">Feature Request</option>
            <option value="content_feedback">Content Feedback</option>
            <option value="study_guide">Study Guide</option>
            <option value="memory_verse">Memory Verse</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Helpful:
          </label>
          <select
            value={helpfulFilter}
            onChange={(e) => {
              setHelpfulFilter(e.target.value)
              setPage(0)
            }}
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 sm:w-auto"
          >
            <option value="all">All Feedback</option>
            <option value="true">👍 Helpful</option>
            <option value="false">👎 Not Helpful</option>
          </select>
        </div>
      </div>

      {/* Stats Summary — counted by Postgres over every matching row */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-4">
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Feedback</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
              {stats.total}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Helpful</p>
            <p className="mt-1 text-2xl font-bold text-green-600 dark:text-green-400">
              {stats.helpful}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Not Helpful</p>
            <p className="mt-1 text-2xl font-bold text-red-600 dark:text-red-400">
              {stats.not_helpful}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Avg Sentiment</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
              {stats.avg_sentiment.toFixed(2)}
            </p>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {stats.sentiment_sample_size} scored
            </p>
          </div>
        </div>
      )}

      {/* Feedback Table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">User Feedback</h2>

        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading feedback...</div>
          </div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Failed to load feedback. Please try again.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Retry
            </button>
          </div>
        ) : (
          <>
            <FeedbackTable feedback={feedback} />
            <Pagination
              page={page}
              total={total}
              isFetching={isFetching}
              onChange={setPage}
              noun="matching entries"
            />
          </>
        )}
      </div>
    </div>
  )
}
