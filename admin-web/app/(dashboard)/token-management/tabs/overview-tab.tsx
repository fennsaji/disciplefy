'use client'

import { useQuery } from '@tanstack/react-query'

interface TokenStats {
  total_users_with_tokens: number
  total_available_tokens: number
  total_purchased_tokens: number
  total_consumed_today: number
  total_consumed_this_month: number
  total_revenue_this_month: number
  avg_tokens_per_user_by_plan: {
    free: number
    standard: number
    plus: number
    premium: number
  }
  top_consuming_features: Array<{
    feature_name: string
    total_tokens: number
    usage_count: number
  }>
}

export default function OverviewTab() {
  const { data: stats, isLoading } = useQuery<TokenStats>({
    queryKey: ['token-stats'],
    queryFn: async () => {
      const response = await fetch('/api/admin/token-stats', {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch stats')
      return response.json()
    },
  })

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="text-gray-500">Loading statistics...</div>
      </div>
    )
  }

  if (!stats) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="text-gray-500">No data available</div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Key Metrics Grid */}
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {/* Total Users with Tokens */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">Total Users</p>
              <p className="mt-2 text-3xl font-bold text-gray-900 dark:text-gray-100">
                {stats.total_users_with_tokens.toLocaleString()}
              </p>
            </div>
            <div className="rounded-full bg-blue-100 p-3 dark:bg-blue-900">
              <svg className="h-6 w-6 text-blue-600 dark:text-blue-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
          </div>
          <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
            Users with active token balances
          </p>
        </div>

        {/* Total Available Tokens */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">Daily Tokens</p>
              <p className="mt-2 text-3xl font-bold text-gray-900 dark:text-gray-100">
                {stats.total_available_tokens.toLocaleString()}
              </p>
            </div>
            <div className="rounded-full bg-green-100 p-3 dark:bg-green-900">
              <svg className="h-6 w-6 text-green-600 dark:text-green-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
            Total available (daily allocation)
          </p>
        </div>

        {/* Total Purchased Tokens */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">Purchased Tokens</p>
              <p className="mt-2 text-3xl font-bold text-gray-900 dark:text-gray-100">
                {stats.total_purchased_tokens.toLocaleString()}
              </p>
            </div>
            <div className="rounded-full bg-purple-100 p-3 dark:bg-purple-900">
              <svg className="h-6 w-6 text-purple-600 dark:text-purple-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
          </div>
          <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
            Total purchased (never reset)
          </p>
        </div>

        {/* Monthly Revenue */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">Monthly Revenue</p>
              <p className="mt-2 text-3xl font-bold text-gray-900 dark:text-gray-100">
                ₹{stats.total_revenue_this_month.toLocaleString()}
              </p>
            </div>
            <div className="rounded-full bg-yellow-100 p-3 dark:bg-yellow-900">
              <svg className="h-6 w-6 text-yellow-600 dark:text-yellow-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
            Token purchase revenue (this month)
          </p>
        </div>
      </div>

      {/* Usage Stats */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Consumption Stats */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Token Consumption</h3>
          <div className="mt-4 space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600 dark:text-gray-400">Today</span>
              <span className="text-lg font-bold text-gray-900 dark:text-gray-100">
                {stats.total_consumed_today.toLocaleString()} tokens
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600 dark:text-gray-400">This Month</span>
              <span className="text-lg font-bold text-gray-900 dark:text-gray-100">
                {stats.total_consumed_this_month.toLocaleString()} tokens
              </span>
            </div>
          </div>
        </div>

        {/* Average Tokens by Plan */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Avg Tokens per User by Plan</h3>
          <div className="mt-4 space-y-3">
            {Object.entries(stats.avg_tokens_per_user_by_plan).map(([plan, avg]) => (
              <div key={plan} className="flex items-center justify-between">
                <span className="text-sm capitalize text-gray-600 dark:text-gray-400">{plan}</span>
                <span className="font-medium text-gray-900 dark:text-gray-100">
                  {avg.toFixed(1)} tokens
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Top Consuming Features */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Top Consuming Features</h3>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full">
            <thead className="border-b border-gray-200 dark:border-gray-700">
              <tr>
                <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Feature</th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Total Tokens</th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Usage Count</th>
                <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Avg Cost</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {stats.top_consuming_features.map((feature) => (
                <tr key={feature.feature_name}>
                  <td className="py-3 text-sm font-medium text-gray-900 dark:text-gray-100">
                    {feature.feature_name}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-900 dark:text-gray-100">
                    {feature.total_tokens.toLocaleString()}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {feature.usage_count.toLocaleString()}
                  </td>
                  <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                    {(feature.total_tokens / feature.usage_count).toFixed(1)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
