'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'

interface DashboardStats {
  llmCost: {
    value: number
    change: number
  }
  subscriptions: {
    total: number
    todayCount: number
  }
  promoCodes: {
    active: number
    expiringSoon: number
  }
  tokens: {
    total: number
    change: number
  }
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchStats() {
      try {
        const response = await fetch('/api/dashboard/stats')
        if (!response.ok) throw new Error('Failed to fetch stats')
        const data = await response.json()
        setStats(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load dashboard stats')
      } finally {
        setLoading(false)
      }
    }

    fetchStats()
  }, [])

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(value)
  }

  const formatNumber = (value: number) => {
    if (value >= 1_000_000) {
      return `${(value / 1_000_000).toFixed(1)}M`
    }
    if (value >= 1_000) {
      return `${(value / 1_000).toFixed(1)}K`
    }
    return value.toLocaleString()
  }

  const formatChange = (value: number) => {
    const sign = value >= 0 ? '+' : ''
    return `${sign}${value.toFixed(1)}%`
  }

  const quickStats = stats
    ? [
        {
          name: 'Total LLM Cost (30d)',
          value: formatCurrency(stats.llmCost.value),
          change: formatChange(stats.llmCost.change),
          href: '/llm-costs',
          icon: '💰',
        },
        {
          name: 'Active Subscriptions',
          value: formatNumber(stats.subscriptions.total),
          change: `+${stats.subscriptions.todayCount} today`,
          href: '/subscriptions',
          icon: '👥',
        },
        {
          name: 'Active Promo Codes',
          value: stats.promoCodes.active.toString(),
          change: `${stats.promoCodes.expiringSoon} expiring soon`,
          href: '/promo-codes',
          icon: '🎟️',
        },
        {
          name: 'Total Tokens (30d)',
          value: formatNumber(stats.tokens.total),
          change: formatChange(stats.tokens.change),
          href: '/llm-costs',
          icon: '📊',
        },
      ]
    : []

  if (loading) {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">Admin Dashboard</h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">Loading dashboard statistics...</p>
        </div>
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="rounded-lg bg-white p-6 shadow-md animate-pulse dark:bg-gray-800">
              <div className="h-4 bg-gray-200 rounded w-3/4 mb-4 dark:bg-gray-700"></div>
              <div className="h-8 bg-gray-200 rounded w-1/2 mb-2 dark:bg-gray-700"></div>
              <div className="h-4 bg-gray-200 rounded w-1/3 dark:bg-gray-700"></div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">Admin Dashboard</h1>
          <p className="mt-2 text-red-600 dark:text-red-400">Error: {error}</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">Admin Dashboard</h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          Welcome to the Disciplefy admin dashboard. Manage LLM costs, subscriptions, and promotional campaigns.
        </p>
      </div>

      {/* Quick Stats */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        {quickStats.map((stat) => (
          <Link
            key={stat.name}
            href={stat.href}
            className="rounded-lg bg-white p-6 shadow-md transition-shadow hover:shadow-lg dark:bg-gray-800 dark:shadow-gray-900"
          >
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{stat.name}</p>
                <p className="mt-2 text-3xl font-bold text-gray-900 dark:text-gray-100">{stat.value}</p>
                <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">{stat.change}</p>
              </div>
              <div className="ml-4 text-4xl">{stat.icon}</div>
            </div>
          </Link>
        ))}
      </div>

      {/* Quick Actions */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Quick Actions</h2>
        <div className="mt-4 grid gap-4 md:grid-cols-3">
          <Link
            href="/llm-costs"
            className="flex items-center gap-4 rounded-lg border border-gray-200 p-4 transition-colors hover:border-primary hover:bg-gray-50 dark:border-gray-700 dark:hover:bg-gray-700"
          >
            <span className="text-3xl">📈</span>
            <div>
              <p className="font-medium text-gray-900 dark:text-gray-100">View LLM Analytics</p>
              <p className="text-sm text-gray-500 dark:text-gray-400">Cost breakdown and trends</p>
            </div>
          </Link>

          <Link
            href="/subscriptions"
            className="flex items-center gap-4 rounded-lg border border-gray-200 p-4 transition-colors hover:border-primary hover:bg-gray-50 dark:border-gray-700 dark:hover:bg-gray-700"
          >
            <span className="text-3xl">⚡</span>
            <div>
              <p className="font-medium text-gray-900 dark:text-gray-100">Manage Subscriptions</p>
              <p className="text-sm text-gray-500 dark:text-gray-400">Update user plans</p>
            </div>
          </Link>

          <Link
            href="/promo-codes"
            className="flex items-center gap-4 rounded-lg border border-gray-200 p-4 transition-colors hover:border-primary hover:bg-gray-50 dark:border-gray-700 dark:hover:bg-gray-700"
          >
            <span className="text-3xl">➕</span>
            <div>
              <p className="font-medium text-gray-900 dark:text-gray-100">Create Promo Code</p>
              <p className="text-sm text-gray-500 dark:text-gray-400">New promotional campaign</p>
            </div>
          </Link>
        </div>
      </div>

      {/* Token Management Overview */}
      <TokenManagementOverview />

      {/* Recent Activity */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Recent Activity</h2>
        <div className="mt-4 text-center text-gray-500 dark:text-gray-400">
          <p>Activity feed will be implemented in future updates</p>
          <p className="mt-2 text-sm">Track admin actions, subscription changes, and promo code usage</p>
        </div>
      </div>
    </div>
  )
}

function TokenManagementOverview() {
  const [tokenStats, setTokenStats] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchTokenStats() {
      try {
        const response = await fetch('/api/admin/token-stats')
        if (!response.ok) throw new Error('Failed to fetch token stats')
        const data = await response.json()
        setTokenStats(data)
      } catch (err) {
        console.error('Failed to load token stats:', err)
      } finally {
        setLoading(false)
      }
    }

    fetchTokenStats()
  }, [])

  if (loading) {
    return (
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Token Management Overview</h2>
        <div className="mt-4 grid gap-4 md:grid-cols-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="rounded-lg border border-gray-200 p-4 animate-pulse dark:border-gray-700">
              <div className="h-4 bg-gray-200 rounded w-3/4 mb-2 dark:bg-gray-700"></div>
              <div className="h-8 bg-gray-200 rounded w-1/2 dark:bg-gray-700"></div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (!tokenStats) return null

  const formatNumber = (value: number) => {
    if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`
    if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`
    return value.toLocaleString()
  }

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">🪙 Token Management Overview</h2>
        <Link
          href="/token-management"
          className="text-sm text-primary hover:underline dark:text-primary"
        >
          View Details →
        </Link>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
          <p className="text-sm text-gray-600 dark:text-gray-400">Total Users</p>
          <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
            {formatNumber(tokenStats.total_users_with_tokens)}
          </p>
        </div>

        <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
          <p className="text-sm text-gray-600 dark:text-gray-400">Available Tokens</p>
          <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
            {formatNumber(tokenStats.total_available_tokens)}
          </p>
        </div>

        <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
          <p className="text-sm text-gray-600 dark:text-gray-400">Consumed Today</p>
          <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
            {formatNumber(tokenStats.total_consumed_today)}
          </p>
        </div>

        <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
          <p className="text-sm text-gray-600 dark:text-gray-400">Monthly Revenue</p>
          <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-100">
            ₹{formatNumber(tokenStats.total_revenue_this_month)}
          </p>
        </div>
      </div>

      {/* Top Features */}
      {tokenStats.top_consuming_features && tokenStats.top_consuming_features.length > 0 && (
        <div className="mt-4">
          <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Top Consuming Features</h3>
          <div className="space-y-2">
            {tokenStats.top_consuming_features.slice(0, 3).map((feature: any, idx: number) => (
              <div key={idx} className="flex items-center justify-between text-sm">
                <span className="text-gray-600 dark:text-gray-400">{feature.feature_name}</span>
                <span className="font-medium text-gray-900 dark:text-gray-100">
                  {formatNumber(feature.total_tokens)} tokens
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
