'use client'

import { useEffect, useState } from 'react'
import { useQuery, useMutation, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'
import { StatsCard } from '@/components/ui/stats-card'
import CreateFellowshipDialog from '@/components/dialogs/create-fellowship-dialog'

const PAGE_SIZE = 50

const LANGUAGE_LABELS: Record<string, string> = { en: 'English', hi: 'Hindi', ml: 'Malayalam' }
const FREQUENCY_LABELS: Record<number, string> = { 1: 'Daily', 2: 'Every 2 days', 7: 'Weekly' }
const REPLY_MODE_LABELS: Record<string, string> = {
  off: 'Off',
  auto: 'Replies on its own',
  review: 'Drafts replies for a mentor to approve',
}
const REPLY_SCOPE_LABELS: Record<string, string> = { all: 'Any question', lessons_only: 'Lesson questions only' }
const REPLY_DELAY_LABELS: Record<number, string> = {
  0: 'Replies straight away',
  30: 'Waits 30 minutes for a mentor',
  120: 'Waits 2 hours for a mentor',
  720: 'Waits 12 hours for a mentor',
}

type TabType = 'fellowships' | 'activity'

const TABS = [
  { value: 'fellowships', label: 'Fellowships', icon: '🤝' },
  { value: 'activity', label: 'Discipler activity', icon: '✨' },
]

const FILTERS = [
  { value: '', label: 'All' },
  { value: 'official', label: 'Official' },
  { value: 'discipler', label: 'Discipler on' },
  { value: 'daily_post', label: 'Daily posts on' },
  { value: 'inactive', label: 'Inactive' },
]

interface Mentor {
  user_id: string
  email: string
}

interface FellowshipRow {
  id: string
  name: string
  description: string | null
  language: string
  is_public: boolean
  is_active: boolean
  is_official: boolean
  discipler_allowed: boolean
  daily_post_allowed: boolean
  daily_post_preview_allowed: boolean
  daily_post_regenerate_allowed: boolean
  daily_post_post_now_allowed: boolean
  discipler_reply_mode: string
  discipler_reply_scope: string
  discipler_reply_delay_min: number
  discipler_react_enabled: boolean
  daily_post_on: boolean
  daily_post_frequency_days: number
  daily_post_auto_advance: boolean
  daily_post_time: string
  daily_post_skip_date: string | null
  daily_post_paused_until: string | null
  max_members: number | null
  member_count: number
  mentors: Mentor[]
  replies_today: number
  cost_today_usd: number
  last_daily_post_date: string | null
  created_at: string
}

interface Summary {
  active: number
  discipler: number
  daily_post: number
  replies_today: number
  cost_today_usd: number
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

function formatDate(iso: string | null): string {
  if (!iso) return 'Never'
  const d = new Date(iso.length === 10 ? `${iso}T00:00:00` : iso)
  return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
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
  const label = total === 1 ? noun.replace(/s$/, '') : noun
  if (totalPages === 1) {
    return (
      <p className="border-t border-gray-100 px-4 py-3 text-sm text-gray-500 dark:border-gray-700 dark:text-gray-400">
        {total} {label}
      </p>
    )
  }
  return (
    <div className="flex items-center justify-between border-t border-gray-100 px-4 py-3 dark:border-gray-700">
      <p className="text-sm text-gray-600 dark:text-gray-400">
        Page {page + 1} of {totalPages} ({total} {noun})
      </p>
      <div className="flex gap-2">
        <button
          onClick={() => onChange(Math.max(0, page - 1))}
          disabled={page === 0 || isFetching}
          className="rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
        >
          Previous
        </button>
        <button
          onClick={() => onChange(page + 1)}
          disabled={page + 1 >= totalPages || isFetching}
          className="rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
        >
          Next
        </button>
      </div>
    </div>
  )
}

/** Pill-style single choice, used for list filters. */
function FilterPills({
  options,
  value,
  onChange,
}: {
  options: { value: string; label: string }[]
  value: string
  onChange: (value: string) => void
}) {
  return (
    <div className="flex flex-wrap gap-2" role="group" aria-label="Filter">
      {options.map((o) => (
        <button
          key={o.value}
          onClick={() => onChange(o.value)}
          aria-pressed={value === o.value}
          className={`rounded-full border px-3 py-1 text-sm font-medium transition-colors ${
            value === o.value
              ? 'border-primary bg-primary text-white'
              : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700'
          }`}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}

function Badge({ tone, children }: { tone: 'amber' | 'gray' | 'red' | 'green' | 'indigo'; children: React.ReactNode }) {
  const tones = {
    amber: 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
    gray: 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300',
    red: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300',
    green: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300',
    indigo: 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300',
  }
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${tones[tone]}`}>
      {children}
    </span>
  )
}

/** A labelled on/off switch with an optional explanation. */
function ToggleRow({
  label,
  description,
  checked,
  disabled,
  onChange,
}: {
  label: string
  description?: string
  checked: boolean
  disabled?: boolean
  onChange: (checked: boolean) => void
}) {
  return (
    <div className="flex items-start justify-between gap-4 py-3">
      <div className="min-w-0">
        <p className="text-sm font-medium text-gray-900 dark:text-gray-100">{label}</p>
        {description && <p className="mt-0.5 text-xs text-gray-500 dark:text-gray-400">{description}</p>}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={`relative mt-0.5 inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 ${
          checked ? 'bg-primary' : 'bg-gray-300 dark:bg-gray-600'
        }`}
      >
        <span
          className={`inline-block h-4 w-4 rounded-full bg-white shadow transition-transform ${
            checked ? 'translate-x-6' : 'translate-x-1'
          }`}
        />
      </button>
    </div>
  )
}

function DetailSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="border-t border-gray-100 px-3 py-3 sm:px-6 sm:py-4 dark:border-gray-700">
      <h3 className="mb-1 text-sm font-semibold text-gray-900 dark:text-gray-100">{title}</h3>
      {children}
    </section>
  )
}

/** Read-only label/value line for settings mentors control in the app. */
function InfoRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 py-1.5 text-sm">
      <span className="text-gray-500 dark:text-gray-400">{label}</span>
      <span className="text-right text-gray-900 dark:text-gray-100">{value}</span>
    </div>
  )
}

export default function FellowshipsPage() {
  const [activeTab, setActiveTab] = useState<TabType>('fellowships')

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="🤝 Fellowships" description="Groups, their mentors, and what Discipler may do in each" />
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
  const [filter, setFilter] = useState('')
  const [page, setPage] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)
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
    queryKey: ['admin', 'fellowships', debouncedSearch, filter, page],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set('limit', String(PAGE_SIZE))
      params.set('offset', String(page * PAGE_SIZE))
      if (debouncedSearch) params.set('search', debouncedSearch)
      if (filter) params.set('filter', filter)
      const response = await fetch(`/api/admin/fellowships?${params}`, { credentials: 'include' })
      if (!response.ok) throw new Error('Failed to fetch fellowships')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const fellowships: FellowshipRow[] = data?.data ?? []
  const total: number = data?.total ?? 0
  const summary: Summary | undefined = data?.summary
  const selected = fellowships.find((f) => f.id === selectedId) ?? null

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
    <div className="space-y-4 sm:space-y-6">
      <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
        <StatsCard title="Active fellowships" value={summary?.active ?? '—'} icon="🤝" />
        <StatsCard title="Discipler on" value={summary?.discipler ?? '—'} icon="✨" />
        <StatsCard title="Daily posts on" value={summary?.daily_post ?? '—'} icon="📅" />
        <StatsCard
          title="Discipler replies today"
          value={summary?.replies_today ?? '—'}
          subtitle={summary ? `$${summary.cost_today_usd.toFixed(4)} spent` : undefined}
          icon="💬"
        />
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-col gap-3 md:flex-row md:items-center">
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name"
            aria-label="Search fellowships by name"
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 md:w-64"
          />
          <FilterPills
            options={FILTERS}
            value={filter}
            onChange={(v) => {
              setFilter(v)
              setPage(0)
            }}
          />
        </div>
        <button
          onClick={() => setIsCreateOpen(true)}
          className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
        >
          Create fellowship
        </button>
      </div>

      <div className="overflow-hidden rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
        {isLoading ? (
          <div className="flex h-64 items-center justify-center text-sm text-gray-500 dark:text-gray-400">
            Loading fellowships…
          </div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Couldn&apos;t load fellowships.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Try again
            </button>
          </div>
        ) : fellowships.length === 0 ? (
          <p className="py-16 text-center text-sm text-gray-500 dark:text-gray-400">
            {debouncedSearch || filter ? 'No fellowships match this search.' : 'No fellowships yet. Create one to get started.'}
          </p>
        ) : (
          <>
            <div className="hidden grid-cols-[minmax(0,2.2fr)_minmax(0,0.8fr)_minmax(0,1.4fr)_minmax(0,1.6fr)_minmax(0,0.9fr)] gap-4 border-b border-gray-100 px-4 py-2 text-xs font-medium text-gray-500 dark:border-gray-700 dark:text-gray-400 md:grid">
              <span>Fellowship</span>
              <span>Members</span>
              <span>Mentors</span>
              <span>Discipler</span>
              <span className="text-right">Today</span>
            </div>
            <ul className="divide-y divide-gray-100 dark:divide-gray-700">
              {fellowships.map((f) => (
                <li key={f.id}>
                  <button
                    onClick={() => setSelectedId(f.id)}
                    className={`grid w-full gap-2 px-4 py-3 text-left text-sm transition-colors hover:bg-gray-50 focus:outline-none focus-visible:bg-gray-50 dark:hover:bg-gray-700/50 dark:focus-visible:bg-gray-700/50 md:grid-cols-[minmax(0,2.2fr)_minmax(0,0.8fr)_minmax(0,1.4fr)_minmax(0,1.6fr)_minmax(0,0.9fr)] md:items-center md:gap-4 ${
                      selectedId === f.id ? 'bg-primary/5 dark:bg-primary/10' : ''
                    }`}
                  >
                    <span className="min-w-0">
                      <span className="flex flex-wrap items-center gap-2">
                        <span className="truncate font-medium text-gray-900 dark:text-gray-100">{f.name}</span>
                        {f.is_official && <Badge tone="amber">Official</Badge>}
                        {!f.is_public && <Badge tone="gray">Private</Badge>}
                        {!f.is_active && <Badge tone="red">Inactive</Badge>}
                      </span>
                      <span className="mt-0.5 block text-xs text-gray-500 dark:text-gray-400">
                        {LANGUAGE_LABELS[f.language] ?? f.language}
                      </span>
                    </span>
                    <span className="text-gray-700 dark:text-gray-300">
                      {f.member_count}
                      <span className="text-gray-400 dark:text-gray-500"> / {f.max_members ?? '∞'}</span>
                      {/* The column header says Members on desktop; on phones the value stands alone. */}
                      <span className="text-gray-500 dark:text-gray-400 md:hidden"> members</span>
                    </span>
                    <span className="min-w-0 truncate text-gray-700 dark:text-gray-300">
                      {f.mentors.length === 0 ? (
                        <span className="text-red-600 dark:text-red-400">No mentor</span>
                      ) : (
                        <>
                          {f.mentors[0].email}
                          {f.mentors.length > 1 && (
                            <span className="text-gray-400 dark:text-gray-500"> +{f.mentors.length - 1}</span>
                          )}
                        </>
                      )}
                    </span>
                    <span className="flex flex-wrap gap-1.5">
                      <Badge tone={f.discipler_allowed ? 'green' : 'gray'}>
                        Replies {f.discipler_allowed ? 'on' : 'off'}
                      </Badge>
                      <Badge tone={f.daily_post_allowed ? 'green' : 'gray'}>
                        Daily {f.daily_post_allowed ? (f.daily_post_on ? 'on' : 'paused by mentor') : 'off'}
                      </Badge>
                    </span>
                    <span className="flex items-center justify-between gap-3 text-gray-700 dark:text-gray-300 md:justify-end">
                      <span className="md:text-right">
                        {f.replies_today} {f.replies_today === 1 ? 'reply' : 'replies'}
                        <span className="block text-xs text-gray-400 dark:text-gray-500">${f.cost_today_usd.toFixed(4)}</span>
                      </span>
                      <span aria-hidden="true" className="text-gray-300 dark:text-gray-600">›</span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
            <Pagination page={page} total={total} isFetching={isFetching} onChange={setPage} noun="fellowships" />
          </>
        )}
      </div>

      {selected && (
        <FellowshipDetail
          fellowship={selected}
          saving={patchMutation.isPending || mentorMutation.isPending}
          onClose={() => setSelectedId(null)}
          onPatch={(changes) => patchMutation.mutate({ fellowship_id: selected.id, ...changes })}
          onMentor={(action, userId) => mentorMutation.mutate({ fellowship_id: selected.id, action, user_id: userId })}
        />
      )}

      <CreateFellowshipDialog isOpen={isCreateOpen} onClose={() => setIsCreateOpen(false)} onCreated={invalidate} />
    </div>
  )
}

/** Side panel with every admin setting for one fellowship. */
function FellowshipDetail({
  fellowship: f,
  saving,
  onClose,
  onPatch,
  onMentor,
}: {
  fellowship: FellowshipRow
  saving: boolean
  onClose: () => void
  onPatch: (changes: Record<string, unknown>) => void
  onMentor: (action: 'add_mentor' | 'remove_mentor', userId: string) => void
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  const today = new Date().toISOString().slice(0, 10)
  const paused = f.daily_post_paused_until && f.daily_post_paused_until >= today
  // A skip for today no longer applies once today's post has gone out.
  const skipping = f.daily_post_skip_date &&
    (f.daily_post_skip_date > today || (f.daily_post_skip_date === today && f.last_daily_post_date !== today))

  return (
    <div className="fixed inset-0 z-40 flex justify-end" role="dialog" aria-modal="true" aria-labelledby="fellowship-detail-title">
      <button className="absolute inset-0 bg-gray-900/40" onClick={onClose} aria-label="Close" tabIndex={-1} />
      <aside className="relative flex h-full w-full max-w-lg flex-col overflow-y-auto bg-white shadow-xl dark:bg-gray-800">
        <header className="sticky top-0 z-10 flex items-start justify-between gap-4 border-b border-gray-100 bg-white px-3 py-3 sm:px-6 sm:py-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="min-w-0">
            <h2 id="fellowship-detail-title" className="truncate text-lg font-semibold text-gray-900 dark:text-gray-100">
              {f.name}
            </h2>
            <p className="mt-0.5 text-xs text-gray-500 dark:text-gray-400">Created {formatDate(f.created_at)}</p>
          </div>
          <button
            onClick={onClose}
            className="rounded-lg p-1.5 text-gray-500 hover:bg-gray-100 hover:text-gray-700 dark:hover:bg-gray-700 dark:hover:text-gray-200"
            aria-label="Close"
          >
            ✕
          </button>
        </header>

        {f.description && (
          <p className="px-3 py-3 sm:px-6 sm:py-4 text-sm text-gray-600 dark:text-gray-300">{f.description}</p>
        )}

        <DetailSection title="General">
          <div className="flex items-center justify-between gap-4 py-3">
            <label htmlFor="fellowship-language" className="text-sm font-medium text-gray-900 dark:text-gray-100">
              Language
            </label>
            <select
              id="fellowship-language"
              value={f.language}
              disabled={saving}
              onChange={(e) => {
                const language = e.target.value
                if (language === f.language) return
                if (!confirm(`Change "${f.name}" to ${LANGUAGE_LABELS[language] ?? language}? Daily posts and Discipler replies will use the new language from now on.`)) {
                  e.target.value = f.language
                  return
                }
                onPatch({ language })
              }}
              className="rounded-md border border-gray-300 bg-white px-2 py-1.5 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            >
              {Object.entries(LANGUAGE_LABELS).map(([code, label]) => (
                <option key={code} value={code}>{label}</option>
              ))}
            </select>
          </div>
          <div className="flex items-end justify-between gap-4 py-3">
            <span className="pb-2 text-sm font-medium text-gray-900 dark:text-gray-100">Member limit</span>
            <MemberLimitEditor
              key={`${f.id}-${f.max_members ?? 'unlimited'}`}
              memberCount={f.member_count}
              maxMembers={f.max_members}
              disabled={saving}
              onSave={(maxMembers) => onPatch({ max_members: maxMembers })}
            />
          </div>
          <ToggleRow
            label="Public"
            description="Anyone can find and join it from Discover."
            checked={f.is_public}
            disabled={saving}
            onChange={(v) => onPatch({ is_public: v })}
          />
          <ToggleRow
            label="Official"
            description="Shows the Official badge to members."
            checked={f.is_official}
            disabled={saving}
            onChange={(v) => onPatch({ is_official: v })}
          />
          <ToggleRow
            label="Active"
            description="Inactive fellowships are hidden and get no Discipler activity."
            checked={f.is_active}
            disabled={saving}
            onChange={(v) => {
              if (!v && !confirm(`Deactivate "${f.name}"? Members will no longer see it.`)) return
              onPatch({ is_active: v })
            }}
          />
        </DetailSection>

        <DetailSection title={`Mentors (${f.mentors.length})`}>
          <ul className="divide-y divide-gray-100 dark:divide-gray-700">
            {f.mentors.map((m) => (
              <li key={m.user_id} className="flex items-center justify-between gap-3 py-2 text-sm">
                <span className="min-w-0 truncate text-gray-900 dark:text-gray-100">{m.email}</span>
                <button
                  onClick={() => {
                    if (!confirm(`Remove ${m.email} as mentor? They stay in the group as a member.`)) return
                    onMentor('remove_mentor', m.user_id)
                  }}
                  disabled={saving}
                  className="shrink-0 rounded-md px-2 py-1 text-xs font-medium text-red-600 hover:bg-red-50 disabled:opacity-50 dark:text-red-400 dark:hover:bg-red-900/30"
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
          <AddMentorForm disabled={saving} onAdd={(userId) => onMentor('add_mentor', userId)} />
        </DetailSection>

        <DetailSection title="Discipler replies">
          <ToggleRow
            label="Allow Discipler"
            description="Discipler may reply to questions and react to posts in this group."
            checked={f.discipler_allowed}
            disabled={saving}
            onChange={(v) => onPatch({ discipler_allowed: v })}
          />
          {f.discipler_allowed && (
            <div className="mt-1 rounded-lg bg-gray-50 px-3 py-2 dark:bg-gray-900/40">
              <p className="mb-1 text-xs font-medium text-gray-500 dark:text-gray-400">Set by the mentor in the app</p>
              <InfoRow label="Replies" value={REPLY_MODE_LABELS[f.discipler_reply_mode] ?? f.discipler_reply_mode} />
              <InfoRow label="Answers" value={REPLY_SCOPE_LABELS[f.discipler_reply_scope] ?? f.discipler_reply_scope} />
              <InfoRow
                label="Timing"
                value={REPLY_DELAY_LABELS[f.discipler_reply_delay_min] ?? `Waits ${f.discipler_reply_delay_min} minutes`}
              />
              <InfoRow label="Reactions" value={f.discipler_react_enabled ? 'On' : 'Off'} />
            </div>
          )}
        </DetailSection>

        <DetailSection title="Daily posts">
          <ToggleRow
            label="Allow daily posts"
            description="Discipler posts the group's current lesson on the mentor's schedule."
            checked={f.daily_post_allowed}
            disabled={saving}
            onChange={(v) => onPatch({ daily_post_allowed: v })}
          />
          <div className={f.daily_post_allowed ? '' : 'opacity-60'}>
            <p className="mt-2 text-xs font-medium text-gray-500 dark:text-gray-400">
              Mentor controls that use AI (each one costs a generation)
            </p>
            <ToggleRow
              label="Preview next post"
              description="The mentor can see the next post before it goes out."
              checked={f.daily_post_preview_allowed}
              disabled={saving || !f.daily_post_allowed}
              onChange={(v) => onPatch({ daily_post_preview_allowed: v })}
            />
            <ToggleRow
              label="Regenerate teaser"
              description="The mentor can ask for a new teaser, up to 3 times a day."
              checked={f.daily_post_regenerate_allowed}
              disabled={saving || !f.daily_post_allowed}
              onChange={(v) => onPatch({ daily_post_regenerate_allowed: v })}
            />
            <ToggleRow
              label="Post now"
              description="The mentor can publish today's post straight away, or post a recent one again with a new version (up to 3 a day, no limit for official groups)."
              checked={f.daily_post_post_now_allowed}
              disabled={saving || !f.daily_post_allowed}
              onChange={(v) => onPatch({ daily_post_post_now_allowed: v })}
            />
          </div>
          {f.daily_post_allowed && (
            <div className="mt-2 rounded-lg bg-gray-50 px-3 py-2 dark:bg-gray-900/40">
              <p className="mb-1 text-xs font-medium text-gray-500 dark:text-gray-400">Set by the mentor in the app</p>
              <InfoRow label="Posting" value={f.daily_post_on ? 'On' : 'Off'} />
              <InfoRow
                label="How often"
                value={FREQUENCY_LABELS[f.daily_post_frequency_days] ?? `Every ${f.daily_post_frequency_days} days`}
              />
              <InfoRow label="Time" value={`${f.daily_post_time} IST`} />
              <InfoRow label="Moves to the next lesson" value={f.daily_post_auto_advance ? 'Yes' : 'No'} />
              {skipping && <InfoRow label="Skipping" value={formatDate(f.daily_post_skip_date)} />}
              {paused && <InfoRow label="Paused until" value={formatDate(f.daily_post_paused_until)} />}
              <InfoRow label="Last post" value={formatDate(f.last_daily_post_date)} />
            </div>
          )}
        </DetailSection>

        <DetailSection title="Today">
          <InfoRow label="Discipler replies" value={f.replies_today} />
          <InfoRow label="Cost" value={`$${f.cost_today_usd.toFixed(4)}`} />
        </DetailSection>
      </aside>
    </div>
  )
}

function AddMentorForm({ onAdd, disabled }: { onAdd: (userId: string) => void; disabled: boolean }) {
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
      className="mt-3 flex gap-2"
    >
      <input
        type="text"
        value={userId}
        onChange={(e) => setUserId(e.target.value)}
        placeholder="User ID of a member to promote"
        aria-label="User ID of a member to promote to mentor"
        className="min-w-0 flex-1 rounded-md border border-gray-300 px-3 py-1.5 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
      />
      <button
        type="submit"
        disabled={disabled || !userId.trim()}
        className="rounded-md border border-gray-300 px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
      >
        Add mentor
      </button>
    </form>
  )
}

const KIND_OPTIONS = [
  { value: '', label: 'All' },
  { value: 'draft', label: 'Drafts' },
  { value: 'reply', label: 'Replies' },
  { value: 'react', label: 'Reactions' },
  { value: 'daily_post', label: 'Daily posts' },
]

const KIND_LABELS: Record<ActivityRow['kind'], string> = {
  draft: 'Draft',
  reply: 'Reply',
  react: 'Reaction',
  daily_post: 'Daily post',
}

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
      toast.success('Deleted')
      queryClient.invalidateQueries({ queryKey: ['admin', 'fellowships', 'activity'] })
    },
    onError: (e: Error) => toast.error(e.message),
  })

  return (
    <div className="space-y-4 sm:space-y-6">
      <FilterPills
        options={KIND_OPTIONS}
        value={kindFilter}
        onChange={(v) => {
          setKindFilter(v)
          setPage(0)
        }}
      />

      <div className="overflow-hidden rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
        {isLoading ? (
          <div className="flex h-64 items-center justify-center text-sm text-gray-500 dark:text-gray-400">Loading activity…</div>
        ) : error ? (
          <div className="flex h-64 flex-col items-center justify-center gap-3">
            <p className="text-sm text-red-600 dark:text-red-400">Couldn&apos;t load activity.</p>
            <button
              onClick={() => refetch()}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              Try again
            </button>
          </div>
        ) : rows.length === 0 ? (
          <p className="py-16 text-center text-sm text-gray-500 dark:text-gray-400">No Discipler activity yet.</p>
        ) : (
          <>
            <ul className="divide-y divide-gray-100 dark:divide-gray-700">
              {rows.map((r) => (
                <li key={r.id} className="flex flex-col gap-2 px-4 py-3 text-sm md:flex-row md:items-start md:gap-4">
                  <div className="w-full shrink-0 md:w-48">
                    <p className="font-medium text-gray-900 dark:text-gray-100">{r.fellowship_name}</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400">{new Date(r.created_at).toLocaleString()}</p>
                  </div>
                  <div className="min-w-0 flex-1 space-y-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge tone="indigo">
                        {KIND_LABELS[r.kind] ?? r.kind}
                        {r.reaction ? ` ${r.reaction}` : ''}
                      </Badge>
                      {r.language && <span className="text-xs uppercase text-gray-500 dark:text-gray-400">{r.language}</span>}
                      {r.comment_pending && !r.comment_deleted && <Badge tone="amber">Waiting for review</Badge>}
                      {r.comment_deleted && <Badge tone="gray">Deleted</Badge>}
                    </div>
                    <p className="text-gray-700 dark:text-gray-300">{r.summary}</p>
                    {(r.comment_content || r.post_content) && (
                      <p
                        className={`line-clamp-2 text-xs text-gray-500 dark:text-gray-400 ${r.comment_deleted ? 'line-through' : ''}`}
                        title={r.comment_content ?? r.post_content ?? undefined}
                      >
                        {r.comment_content ?? r.post_content}
                      </p>
                    )}
                  </div>
                  {r.comment_id && !r.comment_deleted && (
                    <button
                      onClick={() => {
                        if (!confirm('Delete this Discipler comment? This cannot be undone from here.')) return
                        deleteMutation.mutate(r.comment_id!)
                      }}
                      disabled={deleteMutation.isPending}
                      className="self-start rounded-md border border-red-300 px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-red-700 dark:text-red-400 dark:hover:bg-red-900/30"
                    >
                      Delete
                    </button>
                  )}
                </li>
              ))}
            </ul>
            <Pagination page={page} total={total} isFetching={isFetching} onChange={setPage} noun="events" />
          </>
        )}
      </div>
    </div>
  )
}

/**
 * Member limit for one fellowship: a whole number (at least 2) or unlimited.
 * Lowering the limit below the current member count removes nobody; it only
 * stops new people joining until the group is under the limit again.
 */
function MemberLimitEditor({
  memberCount,
  maxMembers,
  disabled,
  onSave,
}: {
  memberCount: number
  maxMembers: number | null
  disabled: boolean
  onSave: (maxMembers: number | null) => void
}) {
  const [unlimited, setUnlimited] = useState(maxMembers === null)
  const [value, setValue] = useState(String(maxMembers ?? Math.max(12, memberCount)))

  const parsed = Number(value)
  const valid = unlimited || (Number.isInteger(parsed) && parsed >= 2)
  const next = unlimited ? null : parsed
  const changed = valid && next !== maxMembers

  const save = () => {
    if (!changed) return
    if (next !== null && next < memberCount &&
      !confirm(`This group already has ${memberCount} members. Nobody is removed, but no one new can join until it is under ${next}. Continue?`)) {
      return
    }
    onSave(next)
  }

  return (
    <div className="flex flex-col items-end gap-1.5">
      <span className="text-xs text-gray-500 dark:text-gray-400">
        {memberCount} {memberCount === 1 ? 'member' : 'members'} now
      </span>
      <div className="flex items-center gap-2">
        <input
          type="number"
          min={2}
          step={1}
          value={unlimited ? '' : value}
          placeholder="∞"
          disabled={disabled || unlimited}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') save() }}
          aria-label="Member limit"
          className="w-20 rounded-md border border-gray-300 bg-white px-2 py-1 text-sm disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        />
        <label className="flex items-center gap-1 text-xs text-gray-700 dark:text-gray-300">
          <input
            type="checkbox"
            checked={unlimited}
            disabled={disabled}
            onChange={(e) => setUnlimited(e.target.checked)}
          />
          Unlimited
        </label>
        {changed && (
          <button
            onClick={save}
            disabled={disabled}
            className="rounded-md bg-primary px-2 py-1 text-xs font-medium text-white hover:bg-primary/90 disabled:opacity-50"
          >
            Save
          </button>
        )}
      </div>
      {!valid && <span className="text-xs text-red-600 dark:text-red-400">Enter 2 or more</span>}
    </div>
  )
}
