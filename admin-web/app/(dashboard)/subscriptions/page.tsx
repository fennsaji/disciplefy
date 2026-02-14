'use client'

import { useState, useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { UserSearchInput } from '@/components/ui/user-search-input'
import { SubscriptionTable } from '@/components/tables/subscription-table'
import { StatsCard } from '@/components/ui/stats-card'
import { searchUsers } from '@/lib/api/admin'
import { formatCompactNumber } from '@/lib/utils/date'
import type { SubscriptionTier } from '@/types/admin'

export default function SubscriptionsPage() {
  const [searchQuery, setSearchQuery] = useState('')
  const [filterTier, setFilterTier] = useState<SubscriptionTier | 'all'>('all')
  const [filterStatus, setFilterStatus] = useState<'all' | 'active' | 'cancelled' | 'expired'>('all')

  // Search users query - always enabled to load all users initially
  const {
    data: searchResults,
    isLoading: isSearching,
    error: searchError,
  } = useQuery({
    queryKey: ['users-search', searchQuery],
    queryFn: () => searchUsers({ query: searchQuery || '' }),
    enabled: true, // Always enabled to show users on page load
  })

  // Filter results based on tier and status
  const filteredUsers = useMemo(() => {
    if (!searchResults?.users) return []

    return searchResults.users.filter(user => {
      const activeSub = user.subscriptions.find(s => s.status === 'active')

      // Filter by tier
      if (filterTier !== 'all') {
        if (!activeSub || activeSub.tier !== filterTier) return false
      }

      // Filter by status
      if (filterStatus !== 'all') {
        if (!activeSub || activeSub.status !== filterStatus) return false
      }

      return true
    })
  }, [searchResults, filterTier, filterStatus])

  // Calculate stats from filtered results
  const stats = searchResults?.users
    ? {
        total: filteredUsers.length,
        free: filteredUsers.filter(u => u.subscriptions.some(s => s.tier === 'free' && s.status === 'active')).length,
        standard: filteredUsers.filter(u => u.subscriptions.some(s => s.tier === 'standard' && s.status === 'active')).length,
        plus: filteredUsers.filter(u => u.subscriptions.some(s => s.tier === 'plus' && s.status === 'active')).length,
        premium: filteredUsers.filter(u => u.subscriptions.some(s => s.tier === 'premium' && s.status === 'active')).length,
      }
    : null

  const handleSearch = () => {
    // Search will auto-trigger via React Query when searchQuery changes
    // This function is kept for compatibility but not needed
  }

  const handleExportCSV = () => {
    if (!filteredUsers.length) return

    const headers = ['Name', 'Email', 'Phone', 'Tier', 'Status', 'Plan Name', 'Billing Cycle', 'Start Date', 'End Date', 'Price']
    const rows = filteredUsers.map(user => {
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
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">Subscription Management</h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Manage user subscriptions, update plans, and apply custom discounts
          </p>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="space-y-4">
        <UserSearchInput
          value={searchQuery}
          onChange={setSearchQuery}
          onSearch={handleSearch}
          isLoading={isSearching}
        />

        {/* Filters and Export */}
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            {/* Tier Filter */}
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Tier:</label>
              <select
                value={filterTier}
                onChange={(e) => setFilterTier(e.target.value as SubscriptionTier | 'all')}
                className="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
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
                onChange={(e) => setFilterStatus(e.target.value as 'all' | 'active' | 'cancelled' | 'expired')}
                className="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
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
            disabled={!filteredUsers.length}
            className="flex items-center gap-2 rounded-lg border border-primary bg-white px-4 py-2 text-sm font-medium text-primary hover:bg-primary/10 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-gray-800 dark:hover:bg-gray-700"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Export CSV ({filteredUsers.length})
          </button>
        </div>
      </div>

      {/* Error State */}
      {searchError && (
        <div className="rounded-lg bg-red-50 p-4 text-red-800 dark:bg-red-900/20 dark:text-red-300">
          <p className="font-medium">Error searching users</p>
          <p className="mt-1 text-sm">{searchError instanceof Error ? searchError.message : 'Unknown error'}</p>
        </div>
      )}

      {/* Stats cards */}
      {stats && (
        <div className="grid gap-6 md:grid-cols-4">
          <StatsCard
            title="Total Results"
            value={formatCompactNumber(stats.total)}
            subtitle={`${searchResults?.users.length || 0} shown`}
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
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">User Subscriptions</h2>

        {!searchResults && !isSearching && !searchError && (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
            <svg className="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <p className="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">Search for users</p>
            <p className="mt-2 text-gray-600 dark:text-gray-400">
              Enter an email, name, or user ID to view and manage subscriptions
            </p>
          </div>
        )}

        {isSearching && (
          <div className="flex items-center justify-center py-12">
            <div className="text-center">
              <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-primary border-r-transparent"></div>
              <p className="mt-4 text-gray-600 dark:text-gray-400">Searching users...</p>
            </div>
          </div>
        )}

        {searchResults && (
          <>
            {filteredUsers.length > 0 ? (
              <SubscriptionTable users={filteredUsers} />
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
