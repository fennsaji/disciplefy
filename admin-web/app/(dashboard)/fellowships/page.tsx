'use client'

import { useEffect, useState } from 'react'
import { useQuery, useMutation, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'
import CreateFellowshipDialog from '@/components/dialogs/create-fellowship-dialog'

const PAGE_SIZE = 50

type TabType = 'fellowships' | 'activity'

const TABS = [
  { value: 'fellowships', label: 'Fellowships', icon: '🤝' },
  { value: 'activity', label: 'Discipler activity', icon: '✨' },
]

interface Mentor {
  user_id: string
  email: string
}

interface FellowshipRow {
  id: string
  name: string
  language: string
  is_public: boolean
  is_active: boolean
  is_official: boolean
  discipler_allowed: boolean
  daily_post_allowed: boolean
  discipler_reply_mode: string
  discipler_reply_scope: string
  discipler_reply_delay_min: number
  discipler_react_enabled: boolean
  daily_post_on: boolean
  max_members: number | null
  member_count: number
  mentors: Mentor[]
  replies_today: number
  cost_today_usd: number
  created_at: string
}

interface ActivityRow {
  id: string
  fellowship_id: string
  fellowship_name: string
  kind: 'reply' | 'react' | 'draft' | 'daily_post'
  reaction: string | null
  language: string | null
  summary: string
  reviewed_at: string | null
  created_at: string
  comment_id: string | null
  comment_content: string | null
  comment_pending: boolean
  comment_deleted: boolean
  post_content: string | null
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

function AddMentorForm({ onAdd }: { onAdd: (userId: string) => void }) {
  const [userId, setUserId] = useState('')
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        const trimmed = userId.trim()
        if (!trimmed) return
        onAdd(trimmed)
        setUserId('')
      }}
      className="mt-1 flex gap-1"
    >
      <input
        type="text"
        value={userId}
        onChange={(e) => setUserId(e.target.value)}
        placeholder="user id"
        className="w-28 rounded border border-gray-300 px-1.5 py-0.5 text-xs dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
      />
      <button
        type="submit"
        className="rounded border border-gray-300 px-2 py-0.5 text-xs text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
      >
        Add
      </button>
    </form>
  )
}

export default function FellowshipsPage() {
  const [activeTab, setActiveTab] = useState<TabType>('fellowships')

  return (
    <div className="space-y-6">
      <PageHeader title="🤝 Fellowships" description="Manage fellowships, Discipler flags and mentors" />

      <TabNav tabs={TABS} activeTab={activeTab} onChange={(v) => setActiveTab(v as TabType)} />

      <div className="mt-6">
        {activeTab === 'fellowships' && <FellowshipsTab />}
        {activeTab === 'activity' && <ActivityTab />}
      </div>
    </div>
  )
}

function FellowshipsTab() {
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [page, setPage] = useState(0)
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const queryClient = useQueryClient()

  useEffect(() => {
    const t = setTimeout(() => {
      setDebouncedSearch(search)
      setPage(0)
    }, 300)
    return () => clearTimeout(t)
  }, [search])

  const { data, isLoading, isFetching, error, refetch } = useQuery({
    queryKey: ['admin', 'fellowships', debouncedSearch, page],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set('limit', String(PAGE_SIZE))
      params.set('offset', String(page * PAGE_SIZE))
      if (debouncedSearch) params.set('search', debouncedSearch)
      const response = await fetch(`/api/admin/fellowships?${params}`, { credentials: 'include' })
      if (!response.ok) throw new Error('Failed to fetch fellowships')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const fellowships: FellowshipRow[] = data?.data ?? []
  const total = data?.total ?? 0

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin', 'fellowships'] })

  const patchMutation = useMutation({
    mutationFn: async (body: Record<string, unknown>) => {
      const response = await fetch('/api/admin/fellowships', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(body),
      })
      const json = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(json.error || 'Failed to update fellowship')
      return json
    },
    onSuccess: () => {
      toast.success('Saved')
      invalidate()
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const mentorMutation = useMutation({
    mutationFn: async (body: { fellowship_id: string; action: 'add_mentor' | 'remove_mentor'; user_id: string }) => {
      const response = await fetch('/api/admin/fellowships', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(body),
      })
      const json = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(json.error || 'Failed to update mentors')
      return json
    },
    onSuccess: () => {
      toast.success('Saved')
      invalidate()
    },
    onError: (e: Error) => toast.error(e.message),
  })

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by name..."
          className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 sm:w-64"
        />
        <button
          onClick={() => setIsCreateOpen(true)}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
        >
          Create fellowship
        </button>
      </div>

      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading fellowships...</div>
          </div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Failed to load fellowships. Please try again.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Retry
            </button>
          </div>
        ) : fellowships.length === 0 ? (
          <p className="py-12 text-center text-sm text-gray-500 dark:text-gray-400">No fellowships found.</p>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead>
                  <tr className="text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    <th className="px-3 py-2">Name</th>
                    <th className="px-3 py-2">Language</th>
                    <th className="px-3 py-2">Members</th>
                    <th className="px-3 py-2">Mentors</th>
                    <th className="px-3 py-2">Official</th>
                    <th className="px-3 py-2">Discipler</th>
                    <th className="px-3 py-2">Daily post</th>
                    <th className="px-3 py-2">Mentor settings</th>
                    <th className="px-3 py-2">Today</th>
                    <th className="px-3 py-2">Public</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                  {fellowships.map((f) => (
                    <tr key={f.id} className="align-top text-sm text-gray-700 dark:text-gray-300">
                      <td className="px-3 py-2">
                        <div className="flex items-center gap-2">
                          <span>{f.name}</span>
                          {f.is_official && (
                            <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-700 dark:bg-amber-900/40 dark:text-amber-300">
                              Official
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-2 uppercase">{f.language}</td>
                      <td className="px-3 py-2">{f.max_members === null ? 'Unlimited' : `${f.member_count} / ${f.max_members}`}</td>
                      <td className="px-3 py-2">
                        <div className="flex flex-col gap-1">
                          {f.mentors.map((m) => (
                            <span key={m.user_id} className="flex items-center gap-1">
                              <span>{m.email}</span>
                              <button
                                onClick={() => {
                                  if (!confirm(`Remove ${m.email} as mentor?`)) return
                                  mentorMutation.mutate({ fellowship_id: f.id, action: 'remove_mentor', user_id: m.user_id })
                                }}
                                disabled={mentorMutation.isPending}
                                className="text-red-500 hover:text-red-700 disabled:opacity-50"
                                aria-label={`Remove mentor ${m.email}`}
                              >
                                ×
                              </button>
                            </span>
                          ))}
                          <AddMentorForm
                            onAdd={(userId) => mentorMutation.mutate({ fellowship_id: f.id, action: 'add_mentor', user_id: userId })}
                          />
                        </div>
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="checkbox"
                          checked={f.is_official}
                          disabled={patchMutation.isPending}
                          onChange={(e) => patchMutation.mutate({ fellowship_id: f.id, is_official: e.target.checked })}
                          className="h-4 w-4 text-primary border-gray-300 rounded focus:ring-primary"
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="checkbox"
                          checked={f.discipler_allowed}
                          disabled={!f.is_official || patchMutation.isPending}
                          onChange={(e) => patchMutation.mutate({ fellowship_id: f.id, discipler_allowed: e.target.checked })}
                          className="h-4 w-4 text-primary border-gray-300 rounded focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50"
                        />
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="checkbox"
                          checked={f.daily_post_allowed}
                          disabled={!f.is_official || patchMutation.isPending}
                          onChange={(e) => patchMutation.mutate({ fellowship_id: f.id, daily_post_allowed: e.target.checked })}
                          className="h-4 w-4 text-primary border-gray-300 rounded focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50"
                        />
                      </td>
                      <td className="px-3 py-2 text-xs text-gray-500 dark:text-gray-400">
                        {f.discipler_reply_mode} / {f.discipler_reply_scope} / {f.discipler_reply_delay_min}min /{' '}
                        react {f.discipler_react_enabled ? 'on' : 'off'} / daily {f.daily_post_on ? 'on' : 'off'}
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap">
                        {f.replies_today} · ${f.cost_today_usd.toFixed(4)}
                      </td>
                      <td className="px-3 py-2">
                        <input
                          type="checkbox"
                          checked={f.is_public}
                          disabled={patchMutation.isPending}
                          onChange={(e) => patchMutation.mutate({ fellowship_id: f.id, is_public: e.target.checked })}
                          className="h-4 w-4 text-primary border-gray-300 rounded focus:ring-primary"
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination page={page} total={total} isFetching={isFetching} onChange={setPage} noun="fellowships" />
          </>
        )}
      </div>

      <CreateFellowshipDialog
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        onCreated={invalidate}
      />
    </div>
  )
}

const KIND_OPTIONS = [
  { value: '', label: 'All' },
  { value: 'draft', label: 'Drafts' },
  { value: 'reply', label: 'Replies' },
  { value: 'react', label: 'Reactions' },
  { value: 'daily_post', label: 'Daily' },
]

function ActivityTab() {
  const [kindFilter, setKindFilter] = useState('')
  const [page, setPage] = useState(0)
  const queryClient = useQueryClient()

  const { data, isLoading, isFetching, error, refetch } = useQuery({
    queryKey: ['admin', 'fellowships', 'activity', kindFilter, page],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set('view', 'activity')
      params.set('limit', String(PAGE_SIZE))
      params.set('offset', String(page * PAGE_SIZE))
      if (kindFilter) params.set('kind', kindFilter)
      const response = await fetch(`/api/admin/fellowships?${params}`, { credentials: 'include' })
      if (!response.ok) throw new Error('Failed to fetch Discipler activity')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const rows: ActivityRow[] = data?.data ?? []
  const total = data?.total ?? 0

  const deleteMutation = useMutation({
    mutationFn: async (comment_id: string) => {
      const response = await fetch('/api/admin/fellowships', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ comment_id }),
      })
      const json = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(json.error || 'Failed to delete comment')
      return json
    },
    onSuccess: () => {
      toast.success('Saved')
      queryClient.invalidateQueries({ queryKey: ['admin', 'fellowships', 'activity'] })
    },
    onError: (e: Error) => toast.error(e.message),
  })

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <select
          value={kindFilter}
          onChange={(e) => {
            setKindFilter(e.target.value)
            setPage(0)
          }}
          className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 sm:w-auto"
        >
          {KIND_OPTIONS.map((k) => (
            <option key={k.value} value={k.value}>
              {k.label}
            </option>
          ))}
        </select>
      </div>

      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading activity...</div>
          </div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Failed to load activity. Please try again.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Retry
            </button>
          </div>
        ) : rows.length === 0 ? (
          <p className="py-12 text-center text-sm text-gray-500 dark:text-gray-400">No Discipler activity found.</p>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead>
                  <tr className="text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    <th className="px-3 py-2">When</th>
                    <th className="px-3 py-2">Fellowship</th>
                    <th className="px-3 py-2">Kind</th>
                    <th className="px-3 py-2">Language</th>
                    <th className="px-3 py-2">Summary</th>
                    <th className="px-3 py-2">Reply</th>
                    <th className="px-3 py-2">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                  {rows.map((r) => (
                    <tr key={r.id} className="align-top text-sm text-gray-700 dark:text-gray-300">
                      <td className="px-3 py-2 whitespace-nowrap">{new Date(r.created_at).toLocaleString()}</td>
                      <td className="px-3 py-2">{r.fellowship_name}</td>
                      <td className="px-3 py-2">
                        <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300">
                          {r.kind}
                          {r.reaction ? `: ${r.reaction}` : ''}
                        </span>
                      </td>
                      <td className="px-3 py-2 uppercase">{r.language ?? '—'}</td>
                      <td className="max-w-xs px-3 py-2">
                        <p className="truncate" title={r.summary}>
                          {r.summary}
                        </p>
                      </td>
                      <td className="max-w-xs px-3 py-2">
                        {r.comment_content ? (
                          <div className="space-y-1">
                            <p className={`truncate ${r.comment_deleted ? 'text-gray-400 line-through dark:text-gray-500' : ''}`} title={r.comment_content}>
                              {r.comment_content}
                            </p>
                            {r.comment_pending && !r.comment_deleted && (
                              <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-700 dark:bg-amber-900/40 dark:text-amber-300">
                                Pending
                              </span>
                            )}
                          </div>
                        ) : r.post_content ? (
                          <p className="truncate" title={r.post_content}>
                            {r.post_content}
                          </p>
                        ) : (
                          '—'
                        )}
                      </td>
                      <td className="px-3 py-2">
                        {r.comment_id && !r.comment_deleted && (
                          <button
                            onClick={() => {
                              if (!confirm('Delete this Discipler comment? This cannot be undone from here.')) return
                              deleteMutation.mutate(r.comment_id!)
                            }}
                            disabled={deleteMutation.isPending}
                            className="rounded-md border border-red-300 px-2 py-1 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-red-700 dark:text-red-400 dark:hover:bg-red-900/30"
                          >
                            Delete
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination page={page} total={total} isFetching={isFetching} onChange={setPage} noun="activity events" />
          </>
        )}
      </div>
    </div>
  )
}
