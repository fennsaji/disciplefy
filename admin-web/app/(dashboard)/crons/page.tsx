'use client'

import { Fragment, useState, useEffect, useCallback, useRef } from 'react'
import { toast } from 'sonner'
import { CronExpressionParser } from 'cron-parser'
import { PageHeader } from '@/components/ui/page-header'
import { listLearningPaths } from '@/lib/api/admin'
import type { LearningPath } from '@/types/admin'

interface CronConfig {
  name: string
  enabled: boolean
  schedule: string
  label: string
  updated_at: string
}

interface CronStatus {
  is_running: boolean
  crons: CronConfig[]
}

interface ContentPipelineProgress {
  job_name: string
  start_learning_path_id: string | null
  start_learning_path_title: string | null
  updated_at: string
  current_learning_path_id: string | null
  current_learning_path_title: string | null
  current_topic_title: string | null
}

const PIPELINE_JOB_LABELS: Record<string, string> = {
  telegram_daily_post: 'Telegram channel post',
  prewarm: 'Pre-warm (Batch API)',
}

const PRESETS = [
  { label: 'Every 1 hour',                        schedule: '0 0 */1 * * *' },
  { label: 'Every 2 hours',                       schedule: '0 0 */2 * * *' },
  { label: 'Every 4 hours',                       schedule: '0 0 */4 * * *' },
  { label: 'Every 6 hours',                       schedule: '0 0 */6 * * *' },
  { label: 'Every 12 hours',                      schedule: '0 0 */12 * * *' },
  { label: 'Daily at midnight UTC (5:30 AM IST)', schedule: '0 0 0 * * *' },
]

function parseNextRun(expr: string): string {
  try {
    // cron-parser uses 5-field; our schedules are 6-field (with seconds). Strip leading seconds field.
    const parts = expr.trim().split(/\s+/)
    const fiveField = parts.length === 6 ? parts.slice(1).join(' ') : expr
    // rs-backend's scheduler runs these fields as UTC (they're written and
    // documented as UTC everywhere else, e.g. "Daily at midnight UTC"). Without
    // an explicit tz, cron-parser resolves the fields in the *browser's* local
    // timezone — for an IST admin that silently shifted every preview by 5:30h
    // (e.g. "09:00 UTC" previewed as if it meant "09:00 IST", landing on what
    // was actually the previous day's 03:30 UTC run).
    const interval = CronExpressionParser.parse(fiveField, { tz: 'UTC' })
    return interval.next().toDate().toUTCString()
  } catch {
    return 'Invalid expression'
  }
}

function isValidExpr(expr: string): boolean {
  try {
    const parts = expr.trim().split(/\s+/)
    const fiveField = parts.length === 6 ? parts.slice(1).join(' ') : expr
    CronExpressionParser.parse(fiveField, { tz: 'UTC' })
    return true
  } catch {
    return false
  }
}

export default function CronsPage() {
  const [status, setStatus] = useState<CronStatus | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [editingName, setEditingName] = useState<string | null>(null)
  const [presetValue, setPresetValue] = useState('')
  const [customExpr, setCustomExpr] = useState('')
  const [customLabel, setCustomLabel] = useState('')
  const [saving, setSaving] = useState(false)
  const [toggling, setToggling] = useState<string | null>(null)
  const pollRef = useRef<NodeJS.Timeout | null>(null)

  const [pipelineProgress, setPipelineProgress] = useState<ContentPipelineProgress[]>([])
  const [pipelineLoading, setPipelineLoading] = useState(true)
  const [learningPaths, setLearningPaths] = useState<LearningPath[]>([])
  const [pipelineSaving, setPipelineSaving] = useState<string | null>(null)
  const [pipelineSelection, setPipelineSelection] = useState<Record<string, string>>({})

  const fetchStatus = useCallback(async () => {
    // Clear any pending poll so overlapping calls don't multiply timer chains
    if (pollRef.current) {
      clearTimeout(pollRef.current)
      pollRef.current = null
    }
    try {
      const res = await fetch('/api/admin/cron/status')
      if (!res.ok) {
        setError(`Failed to load cron status (${res.status})`)
        setLoading(false)
        return
      }
      const data: CronStatus = await res.json()
      setStatus(data)
      setError(null)
      setLoading(false)
      // Poll every 10s while a job is running
      if (data.is_running) {
        pollRef.current = setTimeout(fetchStatus, 10_000)
      }
    } catch {
      setError('Failed to load cron status')
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchStatus()
    return () => { if (pollRef.current) clearTimeout(pollRef.current) }
  }, [fetchStatus])

  const fetchPipelineProgress = useCallback(async () => {
    try {
      const res = await fetch('/api/admin/content-pipeline/progress')
      if (!res.ok) throw new Error(await res.text())
      const data = await res.json()
      const rows: ContentPipelineProgress[] = data.data ?? []
      setPipelineProgress(rows)
      setPipelineSelection(
        Object.fromEntries(
          rows.map(r => [r.job_name, r.start_learning_path_id ?? r.current_learning_path_id ?? ''])
        )
      )
    } catch {
      toast.error('Failed to load content pipeline progress')
    } finally {
      setPipelineLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchPipelineProgress()
    listLearningPaths()
      .then(res => setLearningPaths(
        [...res.learning_paths].sort((a, b) => a.display_order - b.display_order)
      ))
      .catch(() => toast.error('Failed to load learning paths'))
  }, [fetchPipelineProgress])

  const handleSaveStartPath = async (jobName: string) => {
    const selected = pipelineSelection[jobName] ?? ''
    setPipelineSaving(jobName)
    try {
      const res = await fetch(`/api/admin/content-pipeline/${jobName}/start-path`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ learning_path_id: selected || null }),
      })
      if (!res.ok) {
        const d = await res.json().catch(() => ({}))
        throw new Error(d.error || 'Failed to save')
      }
      toast.success(
        selected
          ? `${PIPELINE_JOB_LABELS[jobName] ?? jobName} will now start from the selected path`
          : `${PIPELINE_JOB_LABELS[jobName] ?? jobName} reset to the catalogue's earliest topic`
      )
      await fetchPipelineProgress()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Failed to save')
    } finally {
      setPipelineSaving(null)
    }
  }

  const handleToggle = async (cron: CronConfig) => {
    setToggling(cron.name)
    const action = cron.enabled ? 'disable' : 'enable'
    try {
      const res = await fetch(`/api/admin/cron/${cron.name}/${action}`, { method: 'POST' })
      if (!res.ok) throw new Error(await res.text())
      toast.success(`${cron.name} ${action}d`)
      await fetchStatus()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Failed')
    } finally {
      setToggling(null)
    }
  }

  const handleTrigger = async (name: string) => {
    // Every job can be run now. Blog generation keeps its own route, which
    // predates the generic one; everything else goes through rs-backend's
    // trigger endpoint. A job that posts publicly runs for real, hence the
    // confirm naming it.
    if (!confirm(`Run ${name} now?`)) return
    try {
      const url =
        name === 'blog_generation'
          ? '/api/admin/blogs/cron'
          : `/api/admin/cron/${name}/trigger`
      const res = await fetch(url, { method: 'POST' })
      if (!res.ok) throw new Error(await res.text())
      toast.success(`${name} triggered`)
      await fetchStatus()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Failed to trigger')
    }
  }

  const openEdit = (cron: CronConfig) => {
    const preset = PRESETS.find(p => p.schedule === cron.schedule)
    if (preset) {
      setPresetValue(preset.schedule)
      setCustomExpr(cron.schedule)
      setCustomLabel(cron.label) // pre-populate in case user switches to Custom
    } else {
      setPresetValue('custom')
      setCustomExpr(cron.schedule)
      setCustomLabel(cron.label)
    }
    setEditingName(cron.name)
  }

  const handleSaveSchedule = async (name: string) => {
    const schedule = presetValue === 'custom' ? customExpr : presetValue
    const label = presetValue === 'custom'
      ? customLabel
      : PRESETS.find(p => p.schedule === presetValue)?.label ?? schedule
    if (!schedule.trim()) return

    setSaving(true)
    try {
      const res = await fetch(`/api/admin/cron/${name}/schedule`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ schedule, label }),
      })
      if (!res.ok) {
        const d = await res.json()
        throw new Error(d.error || 'Failed')
      }
      toast.success('Schedule updated')
      setEditingName(null)
      await fetchStatus()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Cron Jobs"
        description="Manage scheduled background tasks"
        actions={
          status?.is_running ? (
            <span className="flex items-center gap-1.5 rounded-full bg-emerald-500/20 px-3 py-1 text-xs font-medium text-emerald-300">
              <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-emerald-400" />
              1 job running
            </span>
          ) : null
        }
      />

      {loading ? (
        <div className="py-12 text-center text-sm text-indigo-400/60">Loading…</div>
      ) : error ? (
        <div className="py-12 text-center">
          <p className="text-sm text-red-400">{error}</p>
          <button
            onClick={() => { setLoading(true); fetchStatus() }}
            className="mt-3 rounded-lg border border-white/10 px-4 py-2 text-xs text-indigo-300 hover:bg-white/5 transition-colors"
          >
            Retry
          </button>
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-white/10">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Job</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Schedule</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Status</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-indigo-400/70">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {(status?.crons ?? []).map(cron => (
                <Fragment key={cron.name}>
                  <tr className="hover:bg-white/5 transition-colors">
                    <td className="px-4 py-3">
                      <p className="font-mono text-xs font-semibold text-white">{cron.name}</p>
                      <p className="text-xs text-slate-400">{cron.label}</p>
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-mono text-xs text-indigo-300">{cron.schedule}</p>
                      <button
                        onClick={() => editingName === cron.name ? setEditingName(null) : openEdit(cron)}
                        className="mt-0.5 text-[10px] text-indigo-400/60 hover:text-indigo-300 underline"
                      >
                        {editingName === cron.name ? 'Cancel edit' : 'Edit Schedule'}
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        cron.enabled
                          ? 'bg-emerald-500/20 text-emerald-300'
                          : 'bg-slate-500/20 text-slate-400'
                      }`}>
                        {cron.enabled ? '● Enabled' : '○ Disabled'}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => handleToggle(cron)}
                          disabled={toggling === cron.name}
                          className={`rounded px-2 py-1 text-xs transition-colors disabled:opacity-50 ${
                            cron.enabled
                              ? 'text-amber-300 hover:bg-amber-500/10'
                              : 'text-emerald-300 hover:bg-emerald-500/10'
                          }`}
                        >
                          {toggling === cron.name ? '…' : cron.enabled ? 'Disable' : 'Enable'}
                        </button>
                        <button
                          onClick={() => handleTrigger(cron.name)}
                          className="rounded px-2 py-1 text-xs text-indigo-300 hover:bg-indigo-500/10 transition-colors"
                        >
                          ▶ Trigger
                        </button>
                      </div>
                    </td>
                  </tr>
                  {editingName === cron.name && (
                    <tr key={`${cron.name}-edit`} className="bg-white/[0.03]">
                      <td colSpan={4} className="px-4 py-4">
                        <div className="space-y-3">
                          <div>
                            <label className="mb-1 block text-xs text-indigo-400/70">Schedule</label>
                            <select
                              value={presetValue}
                              onChange={e => {
                                setPresetValue(e.target.value)
                                if (e.target.value !== 'custom') {
                                  setCustomExpr(e.target.value)
                                }
                              }}
                              className="w-full rounded-lg border border-white/10 bg-[#161240] px-3 py-2 text-sm text-white outline-none"
                            >
                              <option value="">Select preset…</option>
                              {PRESETS.map(p => (
                                <option key={p.schedule} value={p.schedule}>{p.label}</option>
                              ))}
                              <option value="custom">Custom…</option>
                            </select>
                          </div>
                          <div>
                            <label className="mb-1 block text-xs text-indigo-400/70">Expression</label>
                            <input
                              type="text"
                              value={customExpr}
                              onChange={e => setCustomExpr(e.target.value)}
                              disabled={presetValue !== 'custom'}
                              placeholder="0 0 */4 * * *"
                              className="w-full rounded-lg border border-white/10 bg-[#161240] px-3 py-2 font-mono text-sm text-white outline-none disabled:opacity-50"
                            />
                          </div>
                          {presetValue === 'custom' && (
                            <div>
                              <label className="mb-1 block text-xs text-indigo-400/70">Label</label>
                              <input
                                type="text"
                                value={customLabel}
                                onChange={e => setCustomLabel(e.target.value)}
                                placeholder="e.g. Every 3 hours"
                                className="w-full rounded-lg border border-white/10 bg-[#161240] px-3 py-2 text-sm text-white outline-none"
                              />
                            </div>
                          )}
                          {customExpr && (
                            <p className="text-xs text-indigo-400/70">
                              Next run:{' '}
                              {isValidExpr(customExpr)
                                ? parseNextRun(customExpr)
                                : <span className="text-red-400">Invalid expression</span>
                              }
                            </p>
                          )}
                          <div className="flex gap-2">
                            <button
                              onClick={() => handleSaveSchedule(cron.name)}
                              disabled={saving || !customExpr.trim() || !isValidExpr(customExpr)}
                              className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50 transition-colors"
                            >
                              {saving ? 'Saving…' : 'Save'}
                            </button>
                            <button
                              onClick={() => setEditingName(null)}
                              className="rounded-lg border border-white/10 px-4 py-2 text-xs text-indigo-300 hover:bg-white/5 transition-colors"
                            >
                              Cancel
                            </button>
                          </div>
                        </div>
                      </td>
                    </tr>
                  )}
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="rounded-xl border border-white/10 bg-white/5 p-5">
        <h2 className="text-sm font-semibold text-white">Content pipeline position</h2>
        <p className="mt-1 text-xs text-indigo-300/70">
          Shows the learning path each job is currently working through. Pick a different
          path and save to jump the job there — it continues forward from that path.
        </p>
        {pipelineLoading ? (
          <div className="py-8 text-center text-sm text-indigo-400/60">Loading…</div>
        ) : (
          <div className="mt-4 space-y-4">
            {(['telegram_daily_post', 'prewarm'] as const).map(jobName => {
              const row = pipelineProgress.find(p => p.job_name === jobName)
              const baseline = row?.start_learning_path_id ?? row?.current_learning_path_id ?? ''
              const selected = pipelineSelection[jobName] ?? ''
              const isDirty = selected !== baseline
              return (
                <div
                  key={jobName}
                  className="flex flex-col gap-3 rounded-lg border border-white/10 bg-black/20 p-4 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div>
                    <p className="text-sm font-medium text-white">
                      {PIPELINE_JOB_LABELS[jobName] ?? jobName}
                    </p>
                    <p className="mt-0.5 text-xs text-indigo-300/60">
                      Currently on: {row?.current_learning_path_title ?? 'all topics covered'}
                      {row?.current_topic_title ? ` — next: ${row.current_topic_title}` : ''}
                    </p>
                    {row?.start_learning_path_id && (
                      <p className="mt-0.5 text-xs text-amber-400/80">
                        Manual override active: {row.start_learning_path_title}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    <select
                      value={selected}
                      onChange={e =>
                        setPipelineSelection(prev => ({ ...prev, [jobName]: e.target.value }))
                      }
                      className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white focus:border-indigo-500 focus:outline-none"
                    >
                      <option value="">Earliest (reset override)</option>
                      {learningPaths.map(lp => (
                        <option key={lp.id} value={lp.id}>
                          {lp.display_order}. {lp.title}
                        </option>
                      ))}
                    </select>
                    <button
                      onClick={() => handleSaveStartPath(jobName)}
                      disabled={pipelineSaving === jobName || !isDirty}
                      className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50 transition-colors"
                    >
                      {pipelineSaving === jobName ? 'Saving…' : 'Save'}
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
