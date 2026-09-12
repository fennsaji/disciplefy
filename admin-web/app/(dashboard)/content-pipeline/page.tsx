'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'

type JobName = 'telegram_daily_post' | 'prewarm'
type Language = 'en' | 'hi' | 'ml'
type PathStatus = 'done' | 'current' | 'partial' | 'pending' | 'skipped'

interface LanguageStatus {
  language: Language
  done: boolean
  blog_published: boolean | null
}

interface Lesson {
  learning_path_topic_id: string
  topic_id: string
  title: string
  position: number
  languages: LanguageStatus[]
  done: boolean
  before_start: boolean
  is_next: boolean
}

interface PathProgress {
  id: string
  title: string
  display_order: number
  total: number
  done: number
  status: PathStatus
  lessons: Lesson[]
}

interface Overview {
  job_name: JobName
  start: {
    learning_path_id: string | null
    learning_path_title: string | null
    learning_path_topic_id: string | null
    topic_title: string | null
    updated_at: string
  } | null
  total_topics: number
  done_topics: number
  by_language: { language: Language; done: number; total: number }[]
  next: {
    learning_path_id: string
    path_title: string
    learning_path_topic_id: string
    topic_title: string
    blocked_languages: Language[]
  } | null
  paths: PathProgress[]
  telegram_history: {
    post_date: string
    language: Language
    status: 'sent' | 'failed'
    error: string | null
    topic_title: string
    created_at: string
  }[] | null
  prewarm_runs: {
    phase: 'pass1' | 'pass2'
    status: 'submitted' | 'completed' | 'failed'
    request_count: number
    guides_written: number
    note: string | null
    created_at: string
    updated_at: string
  }[] | null
  prewarm_budget: { monthly_budget_usd: number; spent_this_month_usd: number } | null
}

interface CronConfig {
  name: string
  enabled: boolean
  schedule: string
  label: string
}

const JOBS: Record<JobName, { label: string; doneWord: string; unit: string }> = {
  telegram_daily_post: { label: 'Telegram channel', doneWord: 'Posted', unit: 'posted' },
  prewarm: { label: 'Pre-warm guides', doneWord: 'Generated', unit: 'generated' },
}

const TABS = [
  { value: 'telegram_daily_post', label: 'Telegram channel', icon: '📣' },
  { value: 'prewarm', label: 'Pre-warm guides', icon: '⚡' },
]

const LANGUAGE_NAMES: Record<Language, string> = { en: 'English', hi: 'Hindi', ml: 'Malayalam' }

const PATH_STATUS: Record<PathStatus, { label: string; className: string }> = {
  done: { label: 'Done', className: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300' },
  current: { label: 'In progress', className: 'bg-primary/10 text-primary dark:bg-primary/20 dark:text-indigo-300' },
  partial: { label: 'Partly done', className: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300' },
  pending: { label: 'Not started', className: 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300' },
  skipped: { label: 'Skipped', className: 'bg-gray-100 text-gray-400 line-through dark:bg-gray-800 dark:text-gray-500' },
}

type Filter = 'all' | 'unfinished' | 'done'

async function fetchOverview(job: JobName): Promise<Overview> {
  const res = await fetch(`/api/admin/content-pipeline/${job}`, { cache: 'no-store' })
  const body = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(body?.error?.message ?? body?.error ?? `Failed to load (${res.status})`)
  return body.data as Overview
}

async function fetchCrons(): Promise<CronConfig[]> {
  const res = await fetch('/api/admin/cron/status', { cache: 'no-store' })
  if (!res.ok) throw new Error(`Failed to load cron status (${res.status})`)
  const body = await res.json()
  return body.crons ?? []
}

function percent(done: number, total: number) {
  return total === 0 ? 0 : Math.round((done / total) * 100)
}

function formatDateTime(iso: string) {
  return new Date(iso).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })
}

function ProgressBar({ done, total, muted }: { done: number; total: number; muted?: boolean }) {
  return (
    <div className="h-1.5 w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700">
      <div
        className={`h-full rounded-full ${muted ? 'bg-gray-400' : 'bg-primary'}`}
        style={{ width: `${percent(done, total)}%` }}
      />
    </div>
  )
}

export default function ContentPipelinePage() {
  const [job, setJob] = useState<JobName>('telegram_daily_post')
  const [expanded, setExpanded] = useState<Record<string, boolean>>({})
  const [filter, setFilter] = useState<Filter>('all')
  const [search, setSearch] = useState('')
  const queryClient = useQueryClient()

  const overview = useQuery({
    queryKey: ['content-pipeline', job],
    queryFn: () => fetchOverview(job),
    staleTime: 0,
  })

  const crons = useQuery({ queryKey: ['cron-status'], queryFn: fetchCrons, staleTime: 0 })
  const cron = crons.data?.find((c) => c.name === job)

  const setStart = useMutation({
    mutationFn: async (target: { learning_path_id?: string | null; learning_path_topic_id?: string | null }) => {
      const res = await fetch(`/api/admin/content-pipeline/${job}/start`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(target),
      })
      const body = await res.json().catch(() => ({}))
      if (!res.ok) throw new Error(body?.error?.message ?? body?.error ?? 'Failed to update start point')
      return body.data as Overview
    },
    onSuccess: (data, target) => {
      queryClient.setQueryData(['content-pipeline', job], data)
      const cleared = !target.learning_path_id && !target.learning_path_topic_id
      toast.success(
        cleared
          ? `${JOBS[job].label} now continues from the first unfinished lesson`
          : `${JOBS[job].label} now continues from ${data.next ? `“${data.next.topic_title}”` : 'the chosen point'}`,
      )
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const cronAction = useMutation({
    mutationFn: async (action: 'enable' | 'disable' | 'trigger') => {
      const res = await fetch(`/api/admin/cron/${job}/${action}`, { method: 'POST' })
      if (!res.ok) throw new Error((await res.text()) || `Failed to ${action}`)
      return action
    },
    onSuccess: (action) => {
      toast.success(
        action === 'trigger'
          ? `${JOBS[job].label} run started`
          : `${JOBS[job].label} ${action === 'enable' ? 'resumed' : 'paused'}`,
      )
      queryClient.invalidateQueries({ queryKey: ['cron-status'] })
      if (action === 'trigger') {
        setTimeout(() => queryClient.invalidateQueries({ queryKey: ['content-pipeline', job] }), 5000)
      }
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const data = overview.data

  const visiblePaths = useMemo(() => {
    if (!data) return []
    const q = search.trim().toLowerCase()
    return data.paths.filter((p) => {
      if (filter === 'done' && p.status !== 'done') return false
      if (filter === 'unfinished' && p.status === 'done') return false
      if (!q) return true
      return p.title.toLowerCase().includes(q) || p.lessons.some((l) => l.title.toLowerCase().includes(q))
    })
  }, [data, filter, search])

  const confirmStart = (label: string, target: { learning_path_id?: string; learning_path_topic_id?: string }) => {
    if (!confirm(`Move ${JOBS[job].label} to continue from ${label}?\n\nEarlier unfinished lessons will be skipped. Nothing already ${JOBS[job].unit} is undone.`)) return
    setStart.mutate(target)
  }

  const clearStart = () => {
    if (!confirm(`Clear the start point? ${JOBS[job].label} will go back to the first unfinished lesson in the catalogue.`)) return
    setStart.mutate({ learning_path_id: null, learning_path_topic_id: null })
  }

  const toggleExpanded = (id: string) => setExpanded((prev) => ({ ...prev, [id]: !prev[id] }))

  const inFlightRun = data?.prewarm_runs?.find((r) => r.status === 'submitted')
  const budget = data?.prewarm_budget
  const budgetLeft = budget ? Math.max(0, budget.monthly_budget_usd - budget.spent_this_month_usd) : 0
  const lastPost = data?.telegram_history?.[0]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Content Pipeline"
        description="Where the Telegram channel and guide pre-warming are in the learning-path catalogue, and where they go next."
        actions={
          <button
            onClick={() => {
              overview.refetch()
              crons.refetch()
            }}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-800"
          >
            {overview.isFetching ? 'Refreshing…' : 'Refresh'}
          </button>
        }
      />

      <TabNav
        tabs={TABS}
        activeTab={job}
        onChange={(v) => {
          setJob(v as JobName)
          setExpanded({})
        }}
      />

      {/* Job control */}
      <section className="flex flex-col gap-3 rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800 md:flex-row md:items-center md:justify-between">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-medium text-gray-900 dark:text-gray-100">{JOBS[job].label} job</span>
            {cron && (
              <span
                className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                  cron.enabled
                    ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300'
                    : 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300'
                }`}
              >
                {cron.enabled ? 'Running on schedule' : 'Paused'}
              </span>
            )}
          </div>
          <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
            {cron ? `${cron.label} · ` : ''}
            <code className="text-xs">{cron?.schedule ?? '—'}</code>
            {' · '}
            <Link href="/crons" className="text-primary hover:underline">Edit schedule</Link>
          </p>
        </div>
        <div className="flex gap-2">
          <button
            disabled={!cron || cronAction.isPending}
            onClick={() => cron && cronAction.mutate(cron.enabled ? 'disable' : 'enable')}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 disabled:opacity-50 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
          >
            {cron?.enabled ? 'Pause' : 'Resume'}
          </button>
          <button
            disabled={cronAction.isPending}
            onClick={() => {
              const warning =
                job === 'telegram_daily_post'
                  ? 'This posts today’s lesson to the public channel now (once per language per day).'
                  : 'This runs one pre-warm tick now: it may submit a Batch API run and spend budget.'
              if (confirm(`Run ${JOBS[job].label} now?\n\n${warning}`)) cronAction.mutate('trigger')
            }}
            className="rounded-lg bg-primary px-3 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
          >
            Run now
          </button>
        </div>
      </section>

      {overview.isLoading && (
        <div className="py-16 text-center text-sm text-gray-500">Loading pipeline…</div>
      )}
      {overview.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300">
          {(overview.error as Error).message}
        </div>
      )}

      {data && (
        <>
          {/* Summary */}
          <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <div className="rounded-lg border border-gray-200 bg-white p-5 dark:border-gray-700 dark:bg-gray-800">
              <p className="text-sm text-gray-500 dark:text-gray-400">Lessons {JOBS[job].unit} in all languages</p>
              <p className="mt-2 text-3xl font-bold tabular-nums text-gray-900 dark:text-gray-100">
                {data.done_topics}
                <span className="text-lg font-medium text-gray-400"> / {data.total_topics}</span>
              </p>
              <div className="mt-3">
                <ProgressBar done={data.done_topics} total={data.total_topics} />
              </div>
              <p className="mt-2 text-xs text-gray-500">{percent(data.done_topics, data.total_topics)}% of the catalogue</p>
            </div>

            <div className="rounded-lg border border-gray-200 bg-white p-5 dark:border-gray-700 dark:bg-gray-800">
              <p className="text-sm text-gray-500 dark:text-gray-400">Next lesson</p>
              {data.next ? (
                <>
                  <p className="mt-2 font-semibold text-gray-900 dark:text-gray-100">{data.next.topic_title}</p>
                  <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{data.next.path_title}</p>
                  <button
                    onClick={() => {
                      setFilter('all')
                      setSearch('')
                      setExpanded((prev) => ({ ...prev, [data.next!.learning_path_id]: true }))
                      document.getElementById(`path-${data.next!.learning_path_id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
                    }}
                    className="mt-2 text-xs text-primary hover:underline"
                  >
                    Show in catalogue
                  </button>
                </>
              ) : (
                <p className="mt-2 font-semibold text-emerald-600">Every lesson is done</p>
              )}
            </div>

            <div className="rounded-lg border border-gray-200 bg-white p-5 dark:border-gray-700 dark:bg-gray-800">
              <p className="text-sm text-gray-500 dark:text-gray-400">By language</p>
              <ul className="mt-3 space-y-2.5">
                {data.by_language.map((l) => (
                  <li key={l.language}>
                    <div className="mb-1 flex justify-between text-xs">
                      <span className="text-gray-700 dark:text-gray-300">{LANGUAGE_NAMES[l.language]}</span>
                      <span className="tabular-nums text-gray-500">{l.done} / {l.total}</span>
                    </div>
                    <ProgressBar done={l.done} total={l.total} />
                  </li>
                ))}
              </ul>
            </div>

            {job === 'telegram_daily_post' ? (
              <div className="rounded-lg border border-gray-200 bg-white p-5 dark:border-gray-700 dark:bg-gray-800">
                <p className="text-sm text-gray-500 dark:text-gray-400">Last post</p>
                {lastPost ? (
                  <>
                    <p className="mt-2 font-semibold text-gray-900 dark:text-gray-100">{lastPost.topic_title}</p>
                    <p className="mt-1 text-sm text-gray-500">
                      {lastPost.post_date} · {LANGUAGE_NAMES[lastPost.language]} ·{' '}
                      <span className={lastPost.status === 'sent' ? 'text-emerald-600' : 'text-red-600'}>
                        {lastPost.status}
                      </span>
                    </p>
                  </>
                ) : (
                  <p className="mt-2 text-sm text-gray-500">Nothing posted yet</p>
                )}
              </div>
            ) : (
              <div className="rounded-lg border border-gray-200 bg-white p-5 dark:border-gray-700 dark:bg-gray-800">
                <p className="text-sm text-gray-500 dark:text-gray-400">This month’s budget</p>
                {budget && (
                  <>
                    <p className="mt-2 text-3xl font-bold tabular-nums text-gray-900 dark:text-gray-100">
                      ${budget.spent_this_month_usd.toFixed(2)}
                      <span className="text-lg font-medium text-gray-400"> / ${budget.monthly_budget_usd.toFixed(2)}</span>
                    </p>
                    <div className="mt-3">
                      <ProgressBar done={budget.spent_this_month_usd} total={budget.monthly_budget_usd} />
                    </div>
                    <p className="mt-2 text-xs text-gray-500">
                      ${budgetLeft.toFixed(2)} left ·{' '}
                      <Link href="/system-config" className="text-primary hover:underline">Change budget</Link>
                    </p>
                  </>
                )}
              </div>
            )}
          </section>

          {/* Attention */}
          {data.next && data.next.blocked_languages.length > 0 && (
            <div className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-800 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-200">
              <p className="font-medium">
                {new Intl.ListFormat('en', { type: 'conjunction' }).format(
                  data.next.blocked_languages.map((l) => LANGUAGE_NAMES[l]),
                )}{' '}
                {data.next.blocked_languages.length === 1 ? 'is' : 'are'} stuck on “{data.next.topic_title}”
              </p>
              <p className="mt-1">
                The channel posts one lesson for all languages and needs a published article in each. Until one is
                published, these languages skip every day.{' '}
                <Link href="/blogs" className="font-medium underline">Open blog posts</Link> or move the start point past this lesson.
              </p>
            </div>
          )}
          {job === 'prewarm' && inFlightRun && (
            <div className="rounded-lg border border-blue-200 bg-blue-50 p-4 text-sm text-blue-800 dark:border-blue-900 dark:bg-blue-950/40 dark:text-blue-200">
              A batch is in flight ({inFlightRun.phase === 'pass1' ? 'first pass' : 'second pass'}, {inFlightRun.request_count} requests, submitted {formatDateTime(inFlightRun.created_at)}).
              Its lessons were chosen when it started — a new start point applies to the next batch.
            </div>
          )}
          {job === 'prewarm' && budget && budgetLeft <= 0 && (
            <div className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-800 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-200">
              This month’s pre-warm budget is spent. Nothing new starts until next month or until the budget is raised.
            </div>
          )}

          {/* Start point */}
          <section className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
              <div>
                <p className="font-medium text-gray-900 dark:text-gray-100">Start point</p>
                {data.start ? (
                  <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
                    Continuing from{' '}
                    <span className="font-medium">{data.start.learning_path_title}</span>
                    {data.start.topic_title && <> › <span className="font-medium">{data.start.topic_title}</span></>}
                    <span className="text-gray-400"> · set {formatDateTime(data.start.updated_at)}</span>
                  </p>
                ) : (
                  <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
                    None — the job takes the first unfinished lesson in catalogue order. Use <span className="font-medium">Start here</span> on a path or lesson below to jump.
                  </p>
                )}
              </div>
              {data.start && (
                <button
                  onClick={clearStart}
                  disabled={setStart.isPending}
                  className="self-start rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 disabled:opacity-50 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700 md:self-auto"
                >
                  Clear start point
                </button>
              )}
            </div>
          </section>

          {/* Catalogue */}
          <section className="rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
            <div className="flex flex-col gap-3 border-b border-gray-200 p-4 dark:border-gray-700 md:flex-row md:items-center md:justify-between">
              <p className="font-medium text-gray-900 dark:text-gray-100">
                Learning paths <span className="text-sm font-normal text-gray-500">({data.paths.length})</span>
              </p>
              <div className="flex flex-col gap-2 sm:flex-row">
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Find a path or lesson"
                  className="rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-sm dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                />
                <div className="flex overflow-hidden rounded-lg border border-gray-300 text-sm dark:border-gray-600">
                  {(['all', 'unfinished', 'done'] as Filter[]).map((f) => (
                    <button
                      key={f}
                      onClick={() => setFilter(f)}
                      className={`px-3 py-1.5 capitalize ${
                        filter === f
                          ? 'bg-primary text-white'
                          : 'text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700'
                      }`}
                    >
                      {f}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <ul className="divide-y divide-gray-100 dark:divide-gray-700">
              {visiblePaths.map((p) => {
                const isOpen = expanded[p.id] ?? false
                const isStartPath = data.start?.learning_path_id === p.id
                return (
                  <li key={p.id} id={`path-${p.id}`} className="scroll-mt-4">
                    <div
                      className={`flex flex-col gap-3 px-4 py-3 md:flex-row md:items-center ${
                        p.status === 'current' ? 'bg-primary/5 dark:bg-primary/10' : ''
                      }`}
                    >
                      <button
                        onClick={() => toggleExpanded(p.id)}
                        className="flex min-w-0 flex-1 items-center gap-3 text-left"
                        aria-expanded={isOpen}
                      >
                        <span className={`text-xs text-gray-400 transition-transform ${isOpen ? 'rotate-90' : ''}`}>▶</span>
                        <span className="w-8 shrink-0 text-right text-sm tabular-nums text-gray-400">{p.display_order}</span>
                        <span className="min-w-0 flex-1">
                          <span className="block truncate font-medium text-gray-900 dark:text-gray-100">{p.title}</span>
                          <span className="mt-1.5 flex items-center gap-2">
                            <span className="w-40 max-w-full">
                              <ProgressBar done={p.done} total={p.total} muted={p.status === 'skipped'} />
                            </span>
                            <span className="text-xs tabular-nums text-gray-500">{p.done}/{p.total}</span>
                          </span>
                        </span>
                      </button>
                      <div className="flex items-center gap-2 pl-14 md:pl-0">
                        {isStartPath && !data.start?.learning_path_topic_id && (
                          <span className="rounded-full bg-violet-100 px-2 py-0.5 text-xs font-medium text-violet-700 dark:bg-violet-900/40 dark:text-violet-300">
                            Start point
                          </span>
                        )}
                        <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${PATH_STATUS[p.status].className}`}>
                          {PATH_STATUS[p.status].label}
                        </span>
                        <button
                          disabled={setStart.isPending || p.status === 'done'}
                          onClick={() => confirmStart(`“${p.title}”`, { learning_path_id: p.id })}
                          className="rounded-lg border border-gray-300 px-2.5 py-1 text-xs text-gray-700 hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-40 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                        >
                          Start here
                        </button>
                      </div>
                    </div>

                    {isOpen && (
                      <div className="overflow-x-auto border-t border-gray-100 bg-gray-50 dark:border-gray-700 dark:bg-gray-900/40">
                        <table className="w-full min-w-[640px] text-sm">
                          <thead>
                            <tr className="text-left text-xs text-gray-500">
                              <th className="w-12 px-4 py-2 text-right font-medium">#</th>
                              <th className="px-3 py-2 font-medium">Lesson</th>
                              {(['en', 'hi', 'ml'] as Language[]).map((l) => (
                                <th key={l} className="w-24 px-2 py-2 text-center font-medium">{LANGUAGE_NAMES[l]}</th>
                              ))}
                              <th className="w-28 px-3 py-2 font-medium" />
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                            {p.lessons.map((l) => {
                              const isStartLesson = data.start?.learning_path_topic_id === l.learning_path_topic_id
                              return (
                                <tr
                                  key={l.learning_path_topic_id}
                                  className={l.is_next ? 'bg-primary/10' : l.before_start && !l.done ? 'opacity-50' : ''}
                                >
                                  <td className="px-4 py-2 text-right tabular-nums text-gray-400">{l.position}</td>
                                  <td className="px-3 py-2">
                                    <span className="text-gray-900 dark:text-gray-100">{l.title}</span>
                                    {l.is_next && (
                                      <span className="ml-2 rounded-full bg-primary px-2 py-0.5 text-[11px] font-medium text-white">Next</span>
                                    )}
                                    {isStartLesson && (
                                      <span className="ml-2 rounded-full bg-violet-100 px-2 py-0.5 text-[11px] font-medium text-violet-700 dark:bg-violet-900/40 dark:text-violet-300">
                                        Start point
                                      </span>
                                    )}
                                    {l.before_start && !l.done && (
                                      <span className="ml-2 text-xs text-gray-500">skipped</span>
                                    )}
                                  </td>
                                  {l.languages.map((s) => (
                                    <td key={s.language} className="px-2 py-2 text-center">
                                      {s.done ? (
                                        <span className="text-emerald-600" title={`${JOBS[job].doneWord} in ${LANGUAGE_NAMES[s.language]}`}>✓</span>
                                      ) : s.blog_published === false ? (
                                        <span
                                          className="rounded bg-amber-100 px-1.5 py-0.5 text-[11px] text-amber-700 dark:bg-amber-900/40 dark:text-amber-300"
                                          title="No published article in this language — the channel cannot post it"
                                        >
                                          no article
                                        </span>
                                      ) : (
                                        <span className="text-gray-300 dark:text-gray-600">—</span>
                                      )}
                                    </td>
                                  ))}
                                  <td className="px-3 py-2 text-right">
                                    {!l.done && !l.is_next && (
                                      <button
                                        disabled={setStart.isPending}
                                        onClick={() =>
                                          confirmStart(`“${l.title}” in ${p.title}`, {
                                            learning_path_topic_id: l.learning_path_topic_id,
                                          })
                                        }
                                        className="rounded-lg border border-gray-300 px-2 py-0.5 text-xs text-gray-700 hover:bg-white disabled:opacity-40 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                                      >
                                        Start here
                                      </button>
                                    )}
                                  </td>
                                </tr>
                              )
                            })}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </li>
                )
              })}
              {visiblePaths.length === 0 && (
                <li className="px-4 py-10 text-center text-sm text-gray-500">No paths match.</li>
              )}
            </ul>
          </section>

          {/* History */}
          {job === 'telegram_daily_post' && data.telegram_history && (
            <section className="rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
              <p className="border-b border-gray-200 p-4 font-medium text-gray-900 dark:border-gray-700 dark:text-gray-100">Recent posts</p>
              {data.telegram_history.length === 0 ? (
                <p className="px-4 py-8 text-center text-sm text-gray-500">Nothing posted yet.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[640px] text-sm">
                    <thead>
                      <tr className="text-left text-xs text-gray-500">
                        <th className="px-4 py-2 font-medium">Date</th>
                        <th className="px-3 py-2 font-medium">Language</th>
                        <th className="px-3 py-2 font-medium">Lesson</th>
                        <th className="px-3 py-2 font-medium">Result</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                      {data.telegram_history.map((h, i) => (
                        <tr key={`${h.post_date}-${h.language}-${i}`}>
                          <td className="px-4 py-2 tabular-nums text-gray-600 dark:text-gray-300">{h.post_date}</td>
                          <td className="px-3 py-2 text-gray-600 dark:text-gray-300">{LANGUAGE_NAMES[h.language]}</td>
                          <td className="px-3 py-2 text-gray-900 dark:text-gray-100">{h.topic_title}</td>
                          <td className="px-3 py-2">
                            {h.status === 'sent' ? (
                              <span className="text-emerald-600">Sent</span>
                            ) : (
                              <span className="text-red-600" title={h.error ?? undefined}>Failed{h.error ? `: ${h.error}` : ''}</span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          )}

          {job === 'prewarm' && data.prewarm_runs && (
            <section className="rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
              <p className="border-b border-gray-200 p-4 font-medium text-gray-900 dark:border-gray-700 dark:text-gray-100">Recent batch runs</p>
              {data.prewarm_runs.length === 0 ? (
                <p className="px-4 py-8 text-center text-sm text-gray-500">No batch runs yet.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[640px] text-sm">
                    <thead>
                      <tr className="text-left text-xs text-gray-500">
                        <th className="px-4 py-2 font-medium">Started</th>
                        <th className="px-3 py-2 font-medium">Pass</th>
                        <th className="px-3 py-2 font-medium">Status</th>
                        <th className="px-3 py-2 text-right font-medium">Requests</th>
                        <th className="px-3 py-2 text-right font-medium">Guides written</th>
                        <th className="px-3 py-2 font-medium">Note</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                      {data.prewarm_runs.map((r, i) => (
                        <tr key={`${r.created_at}-${i}`}>
                          <td className="px-4 py-2 text-gray-600 dark:text-gray-300">{formatDateTime(r.created_at)}</td>
                          <td className="px-3 py-2 text-gray-600 dark:text-gray-300">{r.phase === 'pass1' ? 'First' : 'Second'}</td>
                          <td className="px-3 py-2">
                            <span
                              className={
                                r.status === 'completed'
                                  ? 'text-emerald-600'
                                  : r.status === 'failed'
                                    ? 'text-red-600'
                                    : 'text-blue-600'
                              }
                            >
                              {r.status === 'submitted' ? 'In flight' : r.status === 'completed' ? 'Completed' : 'Failed'}
                            </span>
                          </td>
                          <td className="px-3 py-2 text-right tabular-nums">{r.request_count}</td>
                          <td className="px-3 py-2 text-right tabular-nums">{r.guides_written}</td>
                          <td className="px-3 py-2 text-gray-500">{r.note ?? ''}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          )}
        </>
      )}
    </div>
  )
}
