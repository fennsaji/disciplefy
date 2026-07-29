'use client'

import { useState } from 'react'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { UserSearchInput } from '@/components/ui/user-search-input'
import { SubscriptionTable } from '@/components/tables/subscription-table'
import { StatsCard } from '@/components/ui/stats-card'
import { searchUsers, getSubscriptionStats } from '@/lib/api/admin'
import { formatCompactNumber } from '@/lib/utils/date'
import type { SubscriptionTier } from '@/types/admin'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'

const PAGE_SIZE = 50
const EXPORT_PAGE_SIZE = 200
const MAX_EXPORT_ROWS = 5000

export default function SubscriptionsPage() {
  const [searchQuery, setSearchQuery] = useState('')
  const [filterTier, setFilterTier] = useState<SubscriptionTier | 'all'>('all')
  const [filterStatus, setFilterStatus] = useState<'all' | 'active' | 'cancelled' | 'expired'>('all')
  const [page, setPage] = useState(0)
  const [isExporting, setIsExporting] = useState(false)

  // Search AND tier/status filters all run in the database, so `total` and the
  // returned rows describe every matching user — not just this page.
  const {
    data: searchResults,
    isLoading: isSearching,
    isFetching,
    error: searchError,
  } = useQuery({
    queryKey: ['users-search', searchQuery, filterTier, filterStatus, page],
    queryFn: () =>
      searchUsers({
        query: searchQuery || '',
        tier: filterTier,
        status: filterStatus,
        limit: PAGE_SIZE,
        offset: page * PAGE_SIZE,
      }),
    placeholderData: keepPreviousData,
  })

  // Tier counts come from COUNT queries over the whole subscriptions table
  const { data: dbStats } = useQuery({
    queryKey: ['subscription-stats'],
    queryFn: getSubscriptionStats,
  })

  const users = searchResults?.users ?? []
  const totalResults = searchResults?.total || 0
  const totalPages = Math.max(1, Math.ceil(totalResults / PAGE_SIZE))

  const stats = dbStats
    ? {
        total: dbStats.total_users,
        free: dbStats.by_tier.free,
        standard: dbStats.by_tier.standard,
        plus: dbStats.by_tier.plus,
        premium: dbStats.by_tier.premium,
      }
    : null

  const handleSearch = () => {
    // Search will auto-trigger via React Query when searchQuery changes
    // This function is kept for compatibility but not needed
  }

  /** Page through the API so the export covers every matching user, not just the page on screen. */
  const fetchAllMatching = async () => {
    const all: typeof users = []
    for (let offset = 0; offset < MAX_EXPORT_ROWS; offset += EXPORT_PAGE_SIZE) {
      const chunk = await searchUsers({
        query: searchQuery || '',
        tier: filterTier,
        status: filterStatus,
        limit: EXPORT_PAGE_SIZE,
        offset,
      })
      all.push(...chunk.users)
      if (chunk.users.length < EXPORT_PAGE_SIZE || all.length >= chunk.total) break
    }
    return all
  }

  const handleExportCSV = async () => {
    if (!totalResults) return

    setIsExporting(true)
    let exportRows: typeof users
    try {
      exportRows = await fetchAllMatching()
    } catch {
      setIsExporting(false)
      toast.error('Failed to export subscriptions. Please try again.')
      return
    }
    setIsExporting(false)

    const headers = ['Name', 'Email', 'Phone', 'Tier', 'Status', 'Plan Name', 'Billing Cycle', 'Start Date', 'End Date', 'Price']
    const rows = exportRows.map(user => {
      const activeSub = user.subscriptions.find(s => s.status === 'active')
      return [
        user.full_name || '',
        user.email || '',
        user.phone || '',
        activeSub?.tier || 'None',
        activeSub?.status || 'None',
        activeSub?.subscription_plans?.plan_name || '',
        activeSub?.subscription_plans?.billing_cycle || '',
        activeSub?.start_date || '',
        activeSub?.end_date || '',
        activeSub?.subscription_plans?.price_inr || '',
      ].map(cell => `"${cell}"`)
    })

    const csv = [headers.join(','), ...rows.map(row => row.join(','))].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `subscriptions-${new Date().toISOString().split('T')[0]}.csv`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Subscription Management"
        description="Manage user subscriptions, update plans, and apply custom discounts"
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
            {/* Tier Filter */}
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Tier:</label>
              <select
                value={filterTier}
                onChange={(e) => {
                  setFilterTier(e.target.value as SubscriptionTier | 'all')
                  setPage(0)
                }}
                className="w-full sm:w-auto rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              >
                <option value="all">All Tiers</option>
                <option value="free">Free</option>
                <option value="standard">Standard</option>
                <option value="plus">Plus</option>
                <option value="premium">Premium</option>
              </select>
            </div>

            {/* Status Filter */}
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Status:</label>
              <select
                value={filterStatus}
                onChange={(e) => {
                  setFilterStatus(e.target.value as 'all' | 'active' | 'cancelled' | 'expired')
                  setPage(0)
                }}
                className="w-full sm:w-auto rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              >
                <option value="all">All Status</option>
                <option value="active">Active</option>
                <option value="cancelled">Cancelled</option>
                <option value="expired">Expired</option>
              </select>
            </div>
          </div>

          {/* Export Button */}
          <button
            onClick={handleExportCSV}
            disabled={!totalResults || isExporting}
            className="w-full sm:w-auto flex items-center gap-2 rounded-lg border border-primary bg-white px-4 py-2 text-sm font-medium text-primary hover:bg-primary/10 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-gray-800 dark:hover:bg-gray-700"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            {isExporting ? 'Exporting…' : `Export CSV (${totalResults})`}
          </button>
        </div>
      </div>

      {/* Error State */}
      {searchError && (
        <ErrorState title="Error loading subscriptions" message={searchError instanceof Error ? searchError.message : 'Unknown error'} />
      )}

      {/* Stats cards */}
      {stats && (
        <div className="grid gap-6 md:grid-cols-4">
          <StatsCard
            title="Total Users"
            value={formatCompactNumber(stats.total)}
            subtitle={`${formatCompactNumber(totalResults)} matching filters`}
            icon="👥"
          />
          <StatsCard
            title="Free Users"
            value={formatCompactNumber(stats.free)}
            subtitle="Basic tier"
            icon="🆓"
          />
          <StatsCard
            title="Standard Users"
            value={formatCompactNumber(stats.standard)}
            subtitle="Standard tier"
            icon="⭐"
          />
          <StatsCard
            title="Premium Users"
            value={formatCompactNumber(stats.premium + stats.plus)}
            subtitle="Plus & Premium"
            icon="👑"
          />
        </div>
      )}

      {/* User table */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">User Subscriptions</h2>

        {isSearching && <LoadingState label="Loading subscriptions..." />}

        {!isSearching && searchResults && (
          <>
            {users.length > 0 ? (
              <SubscriptionTable users={users} />
            ) : (
              <div className="rounded-lg border border-gray-200 bg-white p-12 text-center dark:border-gray-700 dark:bg-gray-800">
                <p className="text-gray-500 dark:text-gray-400">
                  No users match the selected filters. Try adjusting your search or filters.
                </p>
              </div>
            )}

            {/* Pagination */}
            <div className="mt-4 flex items-center justify-between">
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Page {page + 1} of {totalPages} ({totalResults} matching users)
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
