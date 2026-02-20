'use client'

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts'
import { useTheme } from '@/components/theme-provider'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'
import { getTooltipStyle, getAxisStroke, getGridStroke } from '@/components/charts/chart-config'
import { PieChartWithLegend } from '@/components/charts/pie-chart-with-legend'

type TabType = 'events' | 'engagement' | 'features'

const ANALYTICS_TABS = [
  { value: 'events', label: 'Analytics Events', icon: '📈' },
  { value: 'engagement', label: 'User Engagement', icon: '👥' },
  { value: 'features', label: 'Feature Adoption', icon: '🚀' },
]

export default function AnalyticsDashboardPage() {
  const [activeTab, setActiveTab] = useState<TabType>('events')

  return (
    <div className="space-y-6">
      <PageHeader
        title="Analytics Dashboard"
        description="Track analytics events, user engagement, and feature adoption"
      />
      <TabNav
        tabs={ANALYTICS_TABS}
        activeTab={activeTab}
        onChange={(v) => setActiveTab(v as TabType)}
      />
      <div>
        {activeTab === 'events' && <AnalyticsEventsTab />}
        {activeTab === 'engagement' && <UserEngagementTab />}
        {activeTab === 'features' && <FeatureAdoptionTab />}
      </div>
    </div>
  )
}

function AnalyticsEventsTab() {
  const [rangeFilter, setRangeFilter] = useState('week')
  const { resolvedTheme } = useTheme()
  const isDark = resolvedTheme === 'dark'

  const { data, isLoading } = useQuery({
    queryKey: ['analytics-events', rangeFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.append('range', rangeFilter)

      const response = await fetch(`/api/admin/analytics/events?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch analytics events')
      return response.json()
    },
  })

  const eventTypeData = data?.by_type
    ? Object.entries(data.by_type).map(([name, value]) => ({
        name: name.replace(/_/g, ' '),
        value: Number(value),
      }))
    : []

  return (
    <div className="space-y-6">
      {/* Filters */}
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
          <option value="quarter">Last 3 Months</option>
          <option value="year">Last Year</option>
        </select>
      </div>

      {/* Stats */}
      {data && (
        <div className="grid gap-4 md:grid-cols-4">
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Events</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
              {data.total.toLocaleString()}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Unique Users</p>
            <p className="mt-1 text-2xl font-bold text-blue-600 dark:text-blue-400">
              {data.unique_users.toLocaleString()}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Unique Sessions</p>
            <p className="mt-1 text-2xl font-bold text-purple-600 dark:text-purple-400">
              {data.unique_sessions.toLocaleString()}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Event Types</p>
            <p className="mt-1 text-2xl font-bold text-green-600 dark:text-green-400">
              {Object.keys(data.by_type).length}
            </p>
          </div>
        </div>
      )}

      {isLoading ? (
        <div className="flex h-96 items-center justify-center">
          <div className="text-gray-500 dark:text-gray-400">Loading analytics...</div>
        </div>
      ) : data ? (
        <div className="grid gap-6 md:grid-cols-2">
          {/* Timeline Chart */}
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
              Events Timeline
            </h3>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={data.timeline}>
                <CartesianGrid strokeDasharray="3 3" stroke={getGridStroke(isDark)} />
                <XAxis dataKey="date" stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <YAxis stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <Tooltip
                  contentStyle={getTooltipStyle(isDark)}
                />
                <Legend wrapperStyle={{ color: getAxisStroke(isDark) }} />
                <Line
                  type="monotone"
                  dataKey="count"
                  stroke="#8B5CF6"
                  strokeWidth={2}
                  dot={{ fill: '#8B5CF6' }}
                  name="Events"
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Event Types Pie Chart */}
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
              Events by Type
            </h3>
            <PieChartWithLegend data={eventTypeData} />
          </div>
        </div>
      ) : null}
    </div>
  )
}

function UserEngagementTab() {
  const [rangeFilter, setRangeFilter] = useState('month')
  const { resolvedTheme } = useTheme()
  const isDark = resolvedTheme === 'dark'

  const { data, isLoading } = useQuery({
    queryKey: ['analytics-engagement', rangeFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.append('range', rangeFilter)

      const response = await fetch(`/api/admin/analytics/engagement?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch engagement metrics')
      return response.json()
    },
  })

  const retentionData = data?.retention
    ? [
        { name: '1+ Days', users: data.retention['1_day'] },
        { name: '3+ Days', users: data.retention['3_days'] },
        { name: '7+ Days', users: data.retention['7_days'] },
        { name: '14+ Days', users: data.retention['14_days'] }
      ]
    : []

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Time Range:
        </label>
        <select
          value={rangeFilter}
          onChange={(e) => setRangeFilter(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="week">Last 7 Days</option>
          <option value="month">Last 30 Days</option>
          <option value="quarter">Last 3 Months</option>
        </select>
      </div>

      {/* Stats */}
      {data?.overview && (
        <div className="grid gap-4 md:grid-cols-4">
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Total Users</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
              {data.overview.total_users.toLocaleString()}
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Active Users</p>
            <p className="mt-1 text-2xl font-bold text-blue-600 dark:text-blue-400">
              {data.overview.active_users.toLocaleString()}
            </p>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {data.overview.engagement_rate}% engagement
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Avg Current Streak</p>
            <p className="mt-1 text-2xl font-bold text-green-600 dark:text-green-400">
              {data.overview.avg_current_streak} days
            </p>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <p className="text-sm text-gray-600 dark:text-gray-400">Completed Topics</p>
            <p className="mt-1 text-2xl font-bold text-purple-600 dark:text-purple-400">
              {data.overview.completed_topics.toLocaleString()}
            </p>
          </div>
        </div>
      )}

      {isLoading ? (
        <div className="flex h-96 items-center justify-center">
          <div className="text-gray-500 dark:text-gray-400">Loading engagement data...</div>
        </div>
      ) : data ? (
        <div className="grid gap-6 md:grid-cols-2">
          {/* Daily Active Users */}
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
              Daily Active Users
            </h3>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={data.daily_active_users}>
                <CartesianGrid strokeDasharray="3 3" stroke={getGridStroke(isDark)} />
                <XAxis dataKey="date" stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <YAxis stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <Tooltip
                  contentStyle={getTooltipStyle(isDark)}
                />
                <Legend wrapperStyle={{ color: getAxisStroke(isDark) }} />
                <Line
                  type="monotone"
                  dataKey="active_users"
                  stroke="#3B82F6"
                  strokeWidth={2}
                  dot={{ fill: '#3B82F6' }}
                  name="Active Users"
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Retention */}
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
              User Retention
            </h3>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={retentionData}>
                <CartesianGrid strokeDasharray="3 3" stroke={getGridStroke(isDark)} />
                <XAxis dataKey="name" stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <YAxis stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <Tooltip
                  contentStyle={getTooltipStyle(isDark)}
                />
                <Legend wrapperStyle={{ color: getAxisStroke(isDark) }} />
                <Bar dataKey="users" fill="#10B981" name="Retained Users" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      ) : null}

      {/* Additional Metrics */}
      {data?.overview && (
        <div className="grid gap-4 md:grid-cols-3">
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h4 className="text-sm font-medium text-gray-600 dark:text-gray-400">Avg Longest Streak</h4>
            <p className="mt-2 text-3xl font-bold text-orange-600 dark:text-orange-400">
              {data.overview.avg_longest_streak} days
            </p>
          </div>
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h4 className="text-sm font-medium text-gray-600 dark:text-gray-400">New Enrollments</h4>
            <p className="mt-2 text-3xl font-bold text-blue-600 dark:text-blue-400">
              {data.overview.new_enrollments.toLocaleString()}
            </p>
          </div>
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h4 className="text-sm font-medium text-gray-600 dark:text-gray-400">Avg Path Progress</h4>
            <p className="mt-2 text-3xl font-bold text-purple-600 dark:text-purple-400">
              {data.overview.avg_path_progress}%
            </p>
          </div>
        </div>
      )}
    </div>
  )
}

function FeatureAdoptionTab() {
  const [rangeFilter, setRangeFilter] = useState('month')
  const { resolvedTheme } = useTheme()
  const isDark = resolvedTheme === 'dark'

  const { data, isLoading } = useQuery({
    queryKey: ['analytics-features', rangeFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.append('range', rangeFilter)

      const response = await fetch(`/api/admin/analytics/features?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch feature adoption')
      return response.json()
    },
  })

  const studyModesData = data?.study_modes
    ? Object.entries(data.study_modes).map(([name, value]) => ({
        name: name.replace(/_/g, ' '),
        value: Number(value),
      }))
    : []

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Time Range:
        </label>
        <select
          value={rangeFilter}
          onChange={(e) => setRangeFilter(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="week">Last 7 Days</option>
          <option value="month">Last 30 Days</option>
          <option value="quarter">Last 3 Months</option>
        </select>
      </div>

      {isLoading ? (
        <div className="flex h-96 items-center justify-center">
          <div className="text-gray-500 dark:text-gray-400">Loading feature adoption...</div>
        </div>
      ) : data ? (
        <div className="space-y-6">
          {/* Feature Adoption Chart */}
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
              Feature Adoption Rates
            </h3>
            <ResponsiveContainer width="100%" height={400}>
              <BarChart data={data.features}>
                <CartesianGrid strokeDasharray="3 3" stroke={getGridStroke(isDark)} />
                <XAxis dataKey="name" stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <YAxis stroke={getAxisStroke(isDark)} tick={{ fill: getAxisStroke(isDark) }} />
                <Tooltip
                  contentStyle={getTooltipStyle(isDark)}
                />
                <Legend wrapperStyle={{ color: getAxisStroke(isDark) }} />
                <Bar dataKey="users" fill="#8B5CF6" name="Active Users" />
                <Bar dataKey="usage_count" fill="#3B82F6" name="Total Usage" />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Feature Details Table */}
          <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
            <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
              Feature Details
            </h3>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead className="bg-gray-50 dark:bg-gray-900">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Feature
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Category
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Users
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Usage Count
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                      Adoption Rate
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
                  {data.features.map((feature: any) => (
                    <tr key={feature.name}>
                      <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-gray-900 dark:text-gray-100">
                        {feature.name}
                      </td>
                      <td className="whitespace-nowrap px-6 py-4 text-sm">
                        <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                          feature.category === 'core' ? 'bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-300' :
                          feature.category === 'engagement' ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300' :
                          feature.category === 'premium' ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300' :
                          'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300'
                        }`}>
                          {feature.category}
                        </span>
                      </td>
                      <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                        {feature.users.toLocaleString()}
                      </td>
                      <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                        {feature.usage_count.toLocaleString()}
                      </td>
                      <td className="whitespace-nowrap px-6 py-4 text-sm">
                        <div className="flex items-center">
                          <div className="mr-2 h-2 w-20 bg-gray-200 rounded-full dark:bg-gray-700">
                            <div
                              className="h-2 rounded-full bg-primary"
                              style={{ width: `${Math.min(parseFloat(feature.adoption_rate), 100)}%` }}
                            />
                          </div>
                          <span className="font-medium text-gray-900 dark:text-gray-100">
                            {feature.adoption_rate}%
                          </span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Study Modes Breakdown */}
          {studyModesData.length > 0 && (
            <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
              <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
                Study Modes Usage
              </h3>
              <PieChartWithLegend data={studyModesData} />
            </div>
          )}
        </div>
      ) : null}
    </div>
  )
}
