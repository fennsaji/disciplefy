'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { SecurityEventsTable } from '@/components/tables/security-events-table'
import { AdminLogsTable } from '@/components/tables/admin-logs-table'
import { UsageAlertsTable } from '@/components/tables/usage-alerts-table'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'

type TabType = 'security-events' | 'admin-logs' | 'usage-alerts'

const TABS = [
  { value: 'security-events', label: 'LLM Security Events', icon: '⚠️' },
  { value: 'admin-logs', label: 'Admin Activity Logs', icon: '📋' },
  { value: 'usage-alerts', label: 'Usage Alerts', icon: '🔔' },
]

export default function SecurityDashboardPage() {
  const [activeTab, setActiveTab] = useState<TabType>('security-events')

  return (
    <div className="space-y-6">
      <PageHeader
        title="🔒 Security Dashboard"
        description="Monitor security events, admin activity, and usage alerts"
      />

      <TabNav
        tabs={TABS}
        activeTab={activeTab}
        onChange={(v) => setActiveTab(v as TabType)}
      />

      {/* Tab Content */}
      <div className="mt-6">
        {activeTab === 'security-events' && <SecurityEventsTab />}
        {activeTab === 'admin-logs' && <AdminLogsTab />}
        {activeTab === 'usage-alerts' && <UsageAlertsTab />}
      </div>
    </div>
  )
}

function SecurityEventsTab() {
  const [eventTypeFilter, setEventTypeFilter] = useState('all')
  const [riskScoreFilter, setRiskScoreFilter] = useState('all')
  const [rangeFilter, setRangeFilter] = useState('week')

  const { data: events, isLoading } = useQuery({
    queryKey: ['security-events', eventTypeFilter, riskScoreFilter, rangeFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (eventTypeFilter !== 'all') params.append('event_type', eventTypeFilter)
      if (riskScoreFilter !== 'all') params.append('min_risk_score', riskScoreFilter)
      params.append('range', rangeFilter)

      const response = await fetch(`/api/admin/security-events?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch security events')
      return response.json()
    },
  })

  const stats = events
    ? {
        total: events.length,
        high_risk: events.filter((e: any) => e.risk_score >= 0.7).length,
        blocked: events.filter((e: any) => e.action_taken === 'blocked').length,
        unique_users: new Set(events.map((e: any) => e.user_id).filter(Boolean)).size,
      }
    : null

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex items-center gap-4 flex-wrap">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Event Type:
          </label>
          <select
            value={eventTypeFilter}
            onChange={(e) => setEventTypeFilter(e.target.value)}
            className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="all">All Events</option>
            <option value="prompt_injection">Prompt Injection</option>
            <option value="rate_limit_exceeded">Rate Limit Exceeded</option>
            <option value="toxic_content">Toxic Content</option>
            <option value="excessive_length">Excessive Length</option>
            <option value="unauthorized_access">Unauthorized Access</option>
            <option value="malicious_pattern">Malicious Pattern</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Risk Score:
          </label>
          <select
            value={riskScoreFilter}
            onChange={(e) => setRiskScoreFilter(e.target.value)}
            className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="all">All Scores</option>
            <option value="0.7">High Risk (≥70%)</option>
            <option value="0.4">Medium Risk (≥40%)</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Time Range:
          </label>
          <select
            value={rangeFilter}
            onChange={(e) => setRangeFilter(e.target.value)}
            className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="today">Today</option>
            <option value="week">Last 7 Days</option>
            <option value="month">Last 30 Days</option>
            <option value="all">All Time</option>
          </select>
        </div>
      </div>

      {/* Stats */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-4">
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Events</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">{stats.total}</p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">High Risk</p>
            <p className="mt-1 text-2xl font-bold text-red-600 dark:text-red-400">{stats.high_risk}</p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Blocked</p>
            <p className="mt-1 text-2xl font-bold text-orange-600 dark:text-orange-400">{stats.blocked}</p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Unique Users</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">{stats.unique_users}</p>
          </div>
        </div>
      )}

      {/* Events Table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">Security Events</h2>
        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading security events...</div>
          </div>
        ) : (
          <SecurityEventsTable events={events || []} />
        )}
      </div>
    </div>
  )
}

function AdminLogsTab() {
  const [actionFilter, setActionFilter] = useState('')
  const [rangeFilter, setRangeFilter] = useState('week')

  const { data: logs, isLoading } = useQuery({
    queryKey: ['admin-logs', actionFilter, rangeFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (actionFilter) params.append('action', actionFilter)
      params.append('range', rangeFilter)

      const response = await fetch(`/api/admin/admin-logs?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch admin logs')
      return response.json()
    },
  })

  const stats = logs
    ? {
        total: logs.length,
        unique_admins: new Set(logs.map((l: any) => l.admin_user_id)).size,
        today: logs.filter((l: any) => {
          const logDate = new Date(l.created_at)
          const today = new Date()
          return logDate.toDateString() === today.toDateString()
        }).length,
      }
    : null

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex items-center gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Time Range:
          </label>
          <select
            value={rangeFilter}
            onChange={(e) => setRangeFilter(e.target.value)}
            className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="today">Today</option>
            <option value="week">Last 7 Days</option>
            <option value="month">Last 30 Days</option>
            <option value="all">All Time</option>
          </select>
        </div>
      </div>

      {/* Stats */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-3">
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Actions</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">{stats.total}</p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Active Admins</p>
            <p className="mt-1 text-2xl font-bold text-blue-600 dark:text-blue-400">{stats.unique_admins}</p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Actions Today</p>
            <p className="mt-1 text-2xl font-bold text-green-600 dark:text-green-400">{stats.today}</p>
          </div>
        </div>
      )}

      {/* Logs Table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">Admin Activity Logs</h2>
        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading admin logs...</div>
          </div>
        ) : (
          <AdminLogsTable logs={logs || []} />
        )}
      </div>
    </div>
  )
}

function UsageAlertsTab() {
  const [editModal, setEditModal] = useState<any>(null)
  const [formData, setFormData] = useState({
    alert_type: '',
    threshold_value: '',
    notification_channel: 'database',
    is_active: true,
  })
  const queryClient = useQueryClient()

  const { data: alerts, isLoading } = useQuery({
    queryKey: ['usage-alerts'],
    queryFn: async () => {
      const response = await fetch('/api/admin/usage-alerts', {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch usage alerts')
      return response.json()
    },
  })

  const toggleAlertMutation = useMutation({
    mutationFn: async ({ id, is_active }: { id: string; is_active: boolean }) => {
      const alert = alerts.find((a: any) => a.id === id)
      const response = await fetch('/api/admin/usage-alerts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ ...alert, is_active }),
      })
      if (!response.ok) throw new Error('Failed to update alert')
      return response.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['usage-alerts'] })
    },
  })

  const saveAlertMutation = useMutation({
    mutationFn: async (data: any) => {
      const response = await fetch('/api/admin/usage-alerts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          ...data,
          threshold_value: data.threshold_value ? parseFloat(data.threshold_value) : null,
        }),
      })
      if (!response.ok) throw new Error('Failed to save alert')
      return response.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['usage-alerts'] })
      setEditModal(null)
      setFormData({
        alert_type: '',
        threshold_value: '',
        notification_channel: 'database',
        is_active: true,
      })
    },
  })

  const handleCreateAlert = () => {
    setFormData({
      alert_type: '',
      threshold_value: '',
      notification_channel: 'database',
      is_active: true,
    })
    setEditModal({ mode: 'create' })
  }

  const handleEditAlert = (alert: any) => {
    setFormData({
      alert_type: alert.alert_type,
      threshold_value: alert.threshold_value?.toString() || '',
      notification_channel: alert.notification_channel || 'database',
      is_active: alert.is_active,
    })
    setEditModal({ mode: 'edit', id: alert.id })
  }

  const handleSaveAlert = () => {
    const data = editModal.mode === 'edit' ? { id: editModal.id, ...formData } : formData
    saveAlertMutation.mutate(data)
  }

  return (
    <div className="space-y-6">
      {/* Alerts Table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">Usage Alerts Configuration</h2>
        {isLoading ? (
          <div className="flex h-64 items-center justify-center">
            <div className="text-gray-500 dark:text-gray-400">Loading usage alerts...</div>
          </div>
        ) : (
          <UsageAlertsTable
            alerts={alerts || []}
            onToggleAlert={(id, isActive) => toggleAlertMutation.mutate({ id, is_active: isActive })}
            onEditAlert={handleEditAlert}
            onCreateAlert={handleCreateAlert}
          />
        )}
      </div>

      {/* Edit/Create Modal */}
      {editModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div className="w-full max-w-md rounded-lg bg-white p-6 dark:bg-gray-800">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {editModal.mode === 'create' ? 'Create Usage Alert' : 'Edit Usage Alert'}
            </h3>

            <div className="mt-4 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Alert Type
                </label>
                <select
                  value={formData.alert_type}
                  onChange={(e) => setFormData({ ...formData, alert_type: e.target.value })}
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                >
                  <option value="">Select type...</option>
                  <option value="cost_spike">Cost Spike</option>
                  <option value="usage_anomaly">Usage Anomaly</option>
                  <option value="rate_limit_exceeded">Rate Limit Exceeded</option>
                  <option value="negative_profitability">Negative Profitability</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Threshold Value
                </label>
                <input
                  type="number"
                  value={formData.threshold_value}
                  onChange={(e) => setFormData({ ...formData, threshold_value: e.target.value })}
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                  placeholder="Enter threshold value..."
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Notification Channel
                </label>
                <select
                  value={formData.notification_channel}
                  onChange={(e) => setFormData({ ...formData, notification_channel: e.target.value })}
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                >
                  <option value="email">Email</option>
                  <option value="slack">Slack</option>
                  <option value="database">Database Only</option>
                </select>
              </div>

              <div className="flex items-center">
                <input
                  type="checkbox"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                  className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                />
                <label className="ml-2 text-sm text-gray-700 dark:text-gray-300">
                  Alert is active
                </label>
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-3">
              <button
                onClick={() => setEditModal(null)}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveAlert}
                disabled={!formData.alert_type || saveAlertMutation.isPending}
                className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50"
              >
                {saveAlertMutation.isPending ? 'Saving...' : 'Save Alert'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
