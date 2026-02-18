'use client'

import { useState, useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { PageHeader } from '@/components/ui/page-header'
import { UserSearchInput } from '@/components/ui/user-search-input'
import { TokenManagementTable } from '@/components/tables/token-management-table'
import { StatsCard } from '@/components/ui/stats-card'
import { formatCompactNumber } from '@/lib/utils/date'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'

interface UserTokenBalance {
  id: string
  identifier: string
  user_email?: string
  user_name?: string
  user_plan: string
  available_tokens: number
  purchased_tokens: number
  daily_limit: number
  last_reset: string
  total_consumed_today: number
  created_at: string
  updated_at: string
}

export default function TokenManagementPage() {
  const [searchQuery, setSearchQuery] = useState('')
  const [planFilter, setPlanFilter] = useState<'all' | 'free' | 'standard' | 'plus' | 'premium'>('all')

  // Fetch all user token balances
  const {
    data: allBalances,
    isLoading,
    error,
  } = useQuery<UserTokenBalance[]>({
    queryKey: ['all-user-token-balances'],
    queryFn: async () => {
      const response = await fetch('/api/admin/user-token-balances', {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch token balances')
      return response.json()
    },
  })

  // Fetch token stats from API
  const { data: tokenStats } = useQuery({
    queryKey: ['token-stats'],
    queryFn: async () => {
      const response = await fetch('/api/admin/token-stats', {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch token stats')
      return response.json()
    },
  })

  // Filter balances based on search and plan filter
  const filteredBalances = useMemo(() => {
    if (!allBalances) return []

    return allBalances.filter(balance => {
      // Filter by search query (email or identifier)
      const matchesSearch = !searchQuery ||
        balance.user_email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        balance.identifier.toLowerCase().includes(searchQuery.toLowerCase())

      // Filter by plan
      const matchesPlan = planFilter === 'all' || balance.user_plan === planFilter

      return matchesSearch && matchesPlan
    })
  }, [allBalances, searchQuery, planFilter])

  // Use stats from API (already excludes premium users from daily tokens)
  const stats = tokenStats
    ? {
        total: tokenStats.total_users_with_tokens,
        totalDailyTokens: tokenStats.total_available_tokens,
        totalPurchasedTokens: tokenStats.total_purchased_tokens,
        totalConsumedToday: tokenStats.total_consumed_today,
      }
    : null

  const handleSearch = () => {
    // Search auto-triggers via React Query when searchQuery changes
  }

  const handleExportCSV = () => {
    if (!filteredBalances.length) return

    const headers = ['Email', 'Plan', 'Daily Tokens', 'Purchased Tokens', 'Daily Limit', 'Used Today', 'Last Reset']
    const rows = filteredBalances.map(balance => {
      return [
        balance.user_email || 'Anonymous',
        balance.user_plan,
        balance.daily_limit >= 999999999 ? 'Unlimited' : balance.available_tokens.toString(),
        balance.purchased_tokens.toString(),
        balance.daily_limit >= 999999999 ? 'Unlimited' : balance.daily_limit.toString(),
        balance.total_consumed_today.toString(),
        new Date(balance.last_reset).toLocaleDateString(),
      ].map(cell => `"${cell}"`)
    })

    const csv = [headers.join(','), ...rows.map(row => row.join(','))].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `token-balances-${new Date().toISOString().split('T')[0]}.csv`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Token Management"
        description="Manage user token balances, view consumption, and track purchases"
      />

      {/* Search and Filters */}
      <div className="space-y-4">
        <UserSearchInput
          value={searchQuery}
          onChange={setSearchQuery}
          onSearch={handleSearch}
          isLoading={isLoading}
        />

        {/* Filters and Export */}
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            {/* Plan Filter */}
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Plan:</label>
              <select
                value={planFilter}
                onChange={(e) => setPlanFilter(e.target.value as typeof planFilter)}
                className="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              >
                <option value="all">All Plans</option>
                <option value="free">Free</option>
                <option value="standard">Standard</option>
                <option value="plus">Plus</option>
                <option value="premium">Premium</option>
              </select>
            </div>
          </div>

          {/* Export Button */}
          <button
            onClick={handleExportCSV}
            disabled={!filteredBalances.length}
            className="flex items-center gap-2 rounded-lg border border-primary bg-white px-4 py-2 text-sm font-medium text-primary hover:bg-primary/10 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-gray-800 dark:hover:bg-gray-700"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Export CSV ({filteredBalances.length})
          </button>
        </div>
      </div>

      {/* Error State */}
      {error && (
        <ErrorState title="Error loading token data" message={error instanceof Error ? error.message : 'Unknown error'} />
      )}

      {/* Stats cards */}
      {stats && (
        <div className="grid gap-6 md:grid-cols-4">
          <StatsCard
            title="Total Users"
            value={formatCompactNumber(stats.total)}
            subtitle={`${filteredBalances.length} shown`}
            icon="👥"
          />
          <StatsCard
            title="Daily Tokens"
            value={formatCompactNumber(stats.totalDailyTokens)}
            subtitle="Available today"
            icon="🌅"
          />
          <StatsCard
            title="Purchased Tokens"
            value={formatCompactNumber(stats.totalPurchasedTokens)}
            subtitle="User balances"
            icon="🛒"
          />
          <StatsCard
            title="Consumed Today"
            value={formatCompactNumber(stats.totalConsumedToday)}
            subtitle="Total usage"
            icon="📊"
          />
        </div>
      )}

      {/* User table */}
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">User Token Balances</h2>

        {!allBalances && !isLoading && !error && (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
            <svg className="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <p className="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">Search for users</p>
            <p className="mt-2 text-gray-600 dark:text-gray-400">
              Enter an email or user ID to view token balances
            </p>
          </div>
        )}

        {isLoading && <LoadingState label="Loading token balances..." />}

        {allBalances && (
          <>
            {filteredBalances.length > 0 ? (
              <TokenManagementTable balances={filteredBalances} />
            ) : (
              <div className="rounded-lg border border-gray-200 bg-white p-12 text-center dark:border-gray-700 dark:bg-gray-800">
                <p className="text-gray-500 dark:text-gray-400">
                  No users match the selected filters. Try adjusting your search or filters.
                </p>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
