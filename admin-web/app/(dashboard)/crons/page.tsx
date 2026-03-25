'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { toast } from 'sonner'
import { CronExpressionParser } from 'cron-parser'
import { PageHeader } from '@/components/ui/page-header'

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
    const interval = CronExpressionParser.parse(fiveField)
    return interval.next().toDate().toUTCString()
  } catch {
    return 'Invalid expression'
  }
}

function isValidExpr(expr: string): boolean {
  try {
    const parts = expr.trim().split(/\s+/)
    const fiveField = parts.length === 6 ? parts.slice(1).join(' ') : expr
    CronExpressionParser.parse(fiveField)
    return true
  } catch {
    return false
  }
}

export default function CronsPage() {
  const [status, setStatus] = useState<CronStatus | null>(null)
  const [loading, setLoading] = useState(true)
  const [editingName, setEditingName] = useState<string | null>(null)
  const [presetValue, setPresetValue] = useState('')
  const [customExpr, setCustomExpr] = useState('')
  const [customLabel, setCustomLabel] = useState('')
  const [saving, setSaving] = useState(false)
  const [toggling, setToggling] = useState<string | null>(null)
  const pollRef = useRef<NodeJS.Timeout | null>(null)

  const fetchStatus = useCallback(async () => {
    try {
      const res = await fetch('/api/admin/cron/status')
      if (!res.ok) return
      const data: CronStatus = await res.json()
      setStatus(data)
      setLoading(false)
      // Poll every 10s while a job is running
      if (data.is_running) {
        pollRef.current = setTimeout(fetchStatus, 10_000)
      }
    } catch {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchStatus()
    return () => { if (pollRef.current) clearTimeout(pollRef.current) }
  }, [fetchStatus])

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

  const handleTrigger = async (_name: string) => {
    try {
      const res = await fetch('/api/admin/blogs/cron', { method: 'POST' })
      if (!res.ok) throw new Error(await res.text())
      toast.success('Blog generation triggered')
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
                <>
                  <tr key={cron.name} className="hover:bg-white/5 transition-colors">
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
                </>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
