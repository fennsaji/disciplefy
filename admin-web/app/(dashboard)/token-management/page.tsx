'use client'

import { useState } from 'react'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { toast } from 'sonner'
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

interface TokenBalancePage {
  balances: UserTokenBalance[]
  total: number
  limit: number
  offset: number
}

const PAGE_SIZE = 50
const EXPORT_PAGE_SIZE = 200
const MAX_EXPORT_ROWS = 5000

function balancesUrl(params: {
  search: string
  plan: string
  limit: number
  offset: number
}) {
  const qs = new URLSearchParams()
  if (params.search) qs.set('search', params.search)
  if (params.plan && params.plan !== 'all') qs.set('plan', params.plan)
  qs.set('limit', String(params.limit))
  qs.set('offset', String(params.offset))
  return `/api/admin/user-token-balances?${qs.toString()}`
}

export default function TokenManagementPage() {
  const [searchQuery, setSearchQuery] = useState('')
  const [planFilter, setPlanFilter] = useState<'all' | 'free' | 'standard' | 'plus' | 'premium'>('all')
  const [page, setPage] = useState(0)
  const [isExporting, setIsExporting] = useState(false)

  // Search + plan filter run in the database, so results and counts cover
  // every matching row — not just the first page the browser happens to hold.
  const {
    data: balancePage,
    isLoading,
    isFetching,
    error,
  } = useQuery<TokenBalancePage>({
    queryKey: ['user-token-balances', searchQuery, planFilter, page],
    queryFn: async () => {
      const response = await fetch(
        balancesUrl({ search: searchQuery, plan: planFilter, limit: PAGE_SIZE, offset: page * PAGE_SIZE }),
        { credentials: 'include' }
      )
      if (!response.ok) throw new Error('Failed to fetch token balances')
      return response.json()
    },
    placeholderData: keepPreviousData,
  })

  const balances = balancePage?.balances ?? []
  const matchingTotal = balancePage?.total ?? 0
  const totalPages = Math.max(1, Math.ceil(matchingTotal / PAGE_SIZE))

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

  /** Page through the API so the export covers every matching row, not just the page on screen. */
  const fetchAllMatching = async (): Promise<UserTokenBalance[]> => {
    const all: UserTokenBalance[] = []
    for (let offset = 0; offset < MAX_EXPORT_ROWS; offset += EXPORT_PAGE_SIZE) {
      const response = await fetch(
        balancesUrl({ search: searchQuery, plan: planFilter, limit: EXPORT_PAGE_SIZE, offset }),
        { credentials: 'include' }
      )
      if (!response.ok) throw new Error('Failed to fetch token balances')
      const chunk: TokenBalancePage = await response.json()
      all.push(...chunk.balances)
      if (chunk.balances.length < EXPORT_PAGE_SIZE || all.length >= chunk.total) break
    }
    return all
  }

  const handleExportCSV = async () => {
    if (!matchingTotal) return

    setIsExporting(true)
    let exportRows: UserTokenBalance[]
    try {
      exportRows = await fetchAllMatching()
    } catch {
      setIsExporting(false)
      toast.error('Failed to export token balances. Please try again.')
      return
    }
    setIsExporting(false)

    const headers = ['Email', 'Plan', 'Daily Tokens', 'Purchased Tokens', 'Daily Limit', 'Used Today', 'Last Reset']
    const rows = exportRows.map(balance => {
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
          onChange={(value) => {
            setSearchQuery(value)
            setPage(0)
          }}
          onSearch={handleSearch}
          isLoading={isFetching}
        />

        {/* Filters and Export */}
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-wrap items-center gap-3">
            {/* Plan Filter */}
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Plan:</label>
              <select
                value={planFilter}
                onChange={(e) => {
                  setPlanFilter(e.target.value as typeof planFilter)
                  setPage(0)
                }}
                className="w-full sm:w-auto rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
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
            disabled={!matchingTotal || isExporting}
            className="w-full sm:w-auto flex items-center gap-2 rounded-lg border border-primary bg-white px-4 py-2 text-sm font-medium text-primary hover:bg-primary/10 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-gray-800 dark:hover:bg-gray-700"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            {isExporting ? 'Exporting…' : `Export CSV (${matchingTotal})`}
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
            subtitle={`${formatCompactNumber(matchingTotal)} matching filters`}
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

        {isLoading && <LoadingState label="Loading token balances..." />}

        {!isLoading && balancePage && (
          <>
            {balances.length > 0 ? (
              <TokenManagementTable balances={balances} />
            ) : (
              <div className="rounded-lg border border-gray-200 bg-white p-12 text-center dark:border-gray-700 dark:bg-gray-800">
                <p className="text-gray-500 dark:text-gray-400">
                  No users match the selected filters. Try adjusting your search or filters.
                </p>
              </div>
            )}

            {/* Pagination — pages are cut in the database, not in the browser */}
            <div className="mt-4 flex items-center justify-between">
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Page {page + 1} of {totalPages} ({matchingTotal} matching users)
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => setPage(p => Math.max(0, p - 1))}
                  disabled={page === 0 || isFetching}
                  className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
                >
                  Previous
                </button>
                <button
                  onClick={() => setPage(p => p + 1)}
                  disabled={page + 1 >= totalPages || isFetching}
                  className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
                >
                  Next
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
