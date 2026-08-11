'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'

type TabType = 'reports' | 'blocks'

const PAGE_SIZE = 50

interface ModerationReport {
  id: string
  fellowship_id: string
  content_type: 'post' | 'comment'
  content_id: string
  content_excerpt: string | null
  content_is_deleted: boolean | null
  reporter_user_id: string
  reporter_email: string | null
  author_user_id: string | null
  author_email: string | null
  reason: string
  source: 'flag' | 'block'
  status: 'pending' | 'reviewed' | 'dismissed'
  created_at: string
}

interface ModerationBlock {
  id: string
  blocker_id: string
  blocker_email: string | null
  blocked_id: string
  blocked_email: string | null
  reason: string | null
  created_at: string
}

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
  { value: 'reports', label: 'Reports', icon: '🚩' },
  { value: 'blocks', label: 'Blocks', icon: '🚫' },
]

export default function ModerationPage() {
  const [activeTab, setActiveTab] = useState<TabType>('reports')

  return (
    <div className="space-y-6">
      <PageHeader
        title="🚫 Moderation"
        description="Review flagged content and user blocks"
      />

      <TabNav
        tabs={TABS}
        activeTab={activeTab}
        onChange={(v) => setActiveTab(v as TabType)}
      />

      <div className="mt-6">
        {activeTab === 'reports' && <ReportsTab />}
        {activeTab === 'blocks' && <BlocksTab />}
      </div>
    </div>
  )
}

function ReportsTab() {
  const [statusFilter, setStatusFilter] = useState('pending')
  const [page, setPage] = useState(0)
  const queryClient = useQueryClient()

  const { data, isLoading, isFetching, error, refetch } = useQuery({
    queryKey: ['moderation', 'reports', statusFilter, page],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set('tab', 'reports')
      params.set('status', statusFilter)
      params.set('limit', String(PAGE_SIZE))
      params.set('offset', String(page * PAGE_SIZE))

      const response = await fetch(`/api/admin/moderation?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch reports')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const reports: ModerationReport[] = data?.data ?? []
  const total = data?.total ?? 0

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['moderation', 'reports'] })

  const statusMutation = useMutation({
    mutationFn: async ({ report_id, status }: { report_id: string; status: 'reviewed' | 'dismissed' }) => {
      const response = await fetch('/api/admin/moderation', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ report_id, status }),
      })
      if (!response.ok) throw new Error('Failed to update report')
      return response.json()
    },
    onSuccess: () => {
      toast.success('Report updated')
      invalidate()
    },
    onError: () => toast.error('Failed to update report'),
  })

  const deleteMutation = useMutation({
    mutationFn: async ({ content_type, content_id }: { content_type: 'post' | 'comment'; content_id: string }) => {
      const response = await fetch('/api/admin/moderation', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ content_type, content_id }),
      })
      if (!response.ok) throw new Error('Failed to delete content')
      return response.json()
    },
    onSuccess: () => {
      toast.success('Content deleted')
      invalidate()
    },
    onError: () => toast.error('Failed to delete content'),
  })

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value)
            setPage(0)
          }}
          className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 sm:w-auto"
        >
          <option value="pending">Pending</option>
          <option value="reviewed">Reviewed</option>
          <option value="dismissed">Dismissed</option>
        </select>
      </div>

      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">Reports</h2>

        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading reports...</div>
          </div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Failed to load reports. Please try again.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Retry
            </button>
          </div>
        ) : reports.length === 0 ? (
          <p className="py-12 text-center text-sm text-gray-500 dark:text-gray-400">No reports found.</p>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead>
                  <tr className="text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    <th className="px-3 py-2">Content</th>
                    <th className="px-3 py-2">Type</th>
                    <th className="px-3 py-2">Source</th>
                    <th className="px-3 py-2">Reporter</th>
                    <th className="px-3 py-2">Author</th>
                    <th className="px-3 py-2">Reported</th>
                    <th className="px-3 py-2">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                  {reports.map((r) => (
                    <tr key={r.id} className="text-sm text-gray-700 dark:text-gray-300">
                      <td className="max-w-xs px-3 py-2">
                        <p className="truncate" title={r.content_excerpt ?? undefined}>
                          {r.content_excerpt ?? '(deleted or unavailable)'}
                        </p>
                        {r.content_is_deleted && (
                          <span className="text-xs text-red-500">already deleted</span>
                        )}
                      </td>
                      <td className="px-3 py-2 capitalize">{r.content_type}</td>
                      <td className="px-3 py-2">
                        <span
                          className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                            r.source === 'block'
                              ? 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'
                              : 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300'
                          }`}
                        >
                          {r.source === 'block' ? 'Block' : 'Flag'}
                        </span>
                      </td>
                      <td className="px-3 py-2">{r.reporter_email ?? r.reporter_user_id}</td>
                      <td className="px-3 py-2">{r.author_email ?? r.author_user_id ?? '—'}</td>
                      <td className="px-3 py-2 whitespace-nowrap">{new Date(r.created_at).toLocaleString()}</td>
                      <td className="px-3 py-2">
                        <div className="flex flex-wrap gap-2">
                          <button
                            onClick={() => statusMutation.mutate({ report_id: r.id, status: 'reviewed' })}
                            disabled={statusMutation.isPending || r.status !== 'pending'}
                            className="rounded-md border border-green-300 px-2 py-1 text-xs font-medium text-green-700 hover:bg-green-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-green-700 dark:text-green-400 dark:hover:bg-green-900/30"
                          >
                            Resolve
                          </button>
                          <button
                            onClick={() => statusMutation.mutate({ report_id: r.id, status: 'dismissed' })}
                            disabled={statusMutation.isPending || r.status !== 'pending'}
                            className="rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
                          >
                            Dismiss
                          </button>
                          <button
                            onClick={() => {
                              if (!confirm('Delete this content? This cannot be undone from here.')) return
                              deleteMutation.mutate({ content_type: r.content_type, content_id: r.content_id })
                            }}
                            disabled={deleteMutation.isPending || !!r.content_is_deleted}
                            className="rounded-md border border-red-300 px-2 py-1 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-red-700 dark:text-red-400 dark:hover:bg-red-900/30"
                          >
                            Delete Content
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination page={page} total={total} isFetching={isFetching} onChange={setPage} noun="matching reports" />
          </>
        )}
      </div>
    </div>
  )
}

function BlocksTab() {
  const [page, setPage] = useState(0)

  const { data, isLoading, isFetching, error, refetch } = useQuery({
    queryKey: ['moderation', 'blocks', page],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set('tab', 'blocks')
      params.set('limit', String(PAGE_SIZE))
      params.set('offset', String(page * PAGE_SIZE))

      const response = await fetch(`/api/admin/moderation?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch blocks')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const blocks: ModerationBlock[] = data?.data ?? []
  const total = data?.total ?? 0

  return (
    <div className="space-y-6">
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">Blocks</h2>

        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading blocks...</div>
          </div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Failed to load blocks. Please try again.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Retry
            </button>
          </div>
        ) : blocks.length === 0 ? (
          <p className="py-12 text-center text-sm text-gray-500 dark:text-gray-400">No blocks found.</p>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead>
                  <tr className="text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    <th className="px-3 py-2">Blocker</th>
                    <th className="px-3 py-2">Blocked</th>
                    <th className="px-3 py-2">Created</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                  {blocks.map((b) => (
                    <tr key={b.id} className="text-sm text-gray-700 dark:text-gray-300">
                      <td className="px-3 py-2">{b.blocker_email ?? b.blocker_id}</td>
                      <td className="px-3 py-2">{b.blocked_email ?? b.blocked_id}</td>
                      <td className="px-3 py-2 whitespace-nowrap">{new Date(b.created_at).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination page={page} total={total} isFetching={isFetching} onChange={setPage} noun="matching blocks" />
          </>
        )}
      </div>
    </div>
  )
}
