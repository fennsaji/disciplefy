'use client'

import { useState } from 'react'

interface UsageAlert {
  id: string
  alert_type: string
  threshold_value: number | null
  notification_channel: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

interface UsageAlertsTableProps {
  alerts: UsageAlert[]
  onToggleAlert: (id: string, isActive: boolean) => void
  onEditAlert: (alert: UsageAlert) => void
  onCreateAlert: () => void
}

export function UsageAlertsTable({ alerts, onToggleAlert, onEditAlert, onCreateAlert }: UsageAlertsTableProps) {
  const getAlertTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      cost_spike: 'Cost Spike',
      usage_anomaly: 'Usage Anomaly',
      rate_limit_exceeded: 'Rate Limit Exceeded',
      negative_profitability: 'Negative Profitability',
    }
    return labels[type] || type
  }

  const getAlertTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      cost_spike: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300',
      usage_anomaly: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300',
      rate_limit_exceeded: 'bg-orange-100 text-orange-800 dark:bg-orange-900/20 dark:text-orange-300',
      negative_profitability: 'bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-300',
    }
    return colors[type] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
  }

  return (
    <div className="space-y-4">
      {/* Create Alert Button */}
      <div className="flex justify-end">
        <button
          onClick={onCreateAlert}
          className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
        >
          <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Create Alert
        </button>
      </div>

      {/* Alerts List */}
      {alerts.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
          <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
          </svg>
          <p className="mt-4 text-gray-500 dark:text-gray-400">No usage alerts configured</p>
          <p className="mt-2 text-sm text-gray-400">Create your first alert to monitor system usage</p>
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {alerts.map((alert) => (
            <div key={alert.id} className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3">
                    <span className={`inline-flex rounded-full px-3 py-1 text-sm font-semibold ${getAlertTypeColor(alert.alert_type)}`}>
                      {getAlertTypeLabel(alert.alert_type)}
                    </span>
                    <span className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ${
                      alert.is_active
                        ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300'
                        : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
                    }`}>
                      {alert.is_active ? '✓ Active' : '✗ Inactive'}
                    </span>
                  </div>

                  <div className="mt-4 space-y-2 text-sm">
                    {alert.threshold_value && (
                      <div>
                        <span className="font-medium text-gray-700 dark:text-gray-300">Threshold:</span>
                        <span className="ml-2 text-gray-900 dark:text-gray-100">
                          {alert.threshold_value.toLocaleString()}
                        </span>
                      </div>
                    )}
                    {alert.notification_channel && (
                      <div>
                        <span className="font-medium text-gray-700 dark:text-gray-300">Channel:</span>
                        <span className="ml-2 text-gray-900 dark:text-gray-100">
                          {alert.notification_channel}
                        </span>
                      </div>
                    )}
                    <div className="text-xs text-gray-500 dark:text-gray-400">
                      Updated: {new Date(alert.updated_at).toLocaleString()}
                    </div>
                  </div>
                </div>

                <div className="ml-4 flex flex-col gap-2">
                  <button
                    onClick={() => onEditAlert(alert)}
                    className="rounded-lg border border-gray-300 px-3 py-1 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => onToggleAlert(alert.id, !alert.is_active)}
                    className={`rounded-lg px-3 py-1 text-sm font-medium ${
                      alert.is_active
                        ? 'border border-gray-300 text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700'
                        : 'bg-primary text-white hover:bg-primary-600'
                    }`}
                  >
                    {alert.is_active ? 'Disable' : 'Enable'}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
