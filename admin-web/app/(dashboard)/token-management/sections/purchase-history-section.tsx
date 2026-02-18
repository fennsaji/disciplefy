'use client'

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'

export default function PurchaseHistorySection() {
  const [dateRange, setDateRange] = useState('today')
  const [statusFilter, setStatusFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')

  const { data, isLoading } = useQuery({
    queryKey: ['token-purchases', dateRange, statusFilter, searchQuery],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.append('range', dateRange)
      if (statusFilter !== 'all') params.append('status', statusFilter)
      if (searchQuery) params.append('search', searchQuery)

      const response = await fetch(`/api/admin/token-purchases?${params}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch purchases')
      return response.json()
    },
  })

  const purchases = data?.purchases || []
  const summary = data?.summary || { total_purchases: 0, total_tokens_sold: 0, total_revenue: 0 }

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800">
      <div className="mb-6">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">🛒 Token Purchase History</h2>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Track token purchases and revenue across all users
        </p>
      </div>

      {/* Filters */}
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center">
        <select
          value={dateRange}
          onChange={(e) => setDateRange(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="today">Today</option>
          <option value="week">This Week</option>
          <option value="month">This Month</option>
          <option value="all">All Time</option>
        </select>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
        >
          <option value="all">All Status</option>
          <option value="completed">Completed</option>
          <option value="pending">Pending</option>
          <option value="failed">Failed</option>
        </select>

        <div className="relative flex-1">
          <input
            type="text"
            placeholder="Search by email or payment ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 pl-10 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          />
          <svg className="absolute left-3 top-2.5 h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </div>
      </div>

      {/* Summary */}
      <div className="mb-4 grid gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-gray-200 px-4 py-3 dark:border-gray-700">
          <p className="text-xs text-gray-600 dark:text-gray-400">Total Purchases</p>
          <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">{summary.total_purchases}</p>
        </div>
        <div className="rounded-lg border border-gray-200 px-4 py-3 dark:border-gray-700">
          <p className="text-xs text-gray-600 dark:text-gray-400">Tokens Sold</p>
          <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">{summary.total_tokens_sold.toLocaleString()}</p>
        </div>
        <div className="rounded-lg border border-gray-200 px-4 py-3 dark:border-gray-700">
          <p className="text-xs text-gray-600 dark:text-gray-400">Total Revenue</p>
          <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">₹{summary.total_revenue.toFixed(2)}</p>
        </div>
      </div>

      {/* Table */}
      {isLoading ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-gray-500 dark:text-gray-400">Loading purchases...</div>
        </div>
      ) : purchases.length === 0 ? (
        <div className="flex h-64 items-center justify-center">
          <div className="text-gray-500 dark:text-gray-400">No purchases found</div>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-700">
          <table className="w-full">
            <thead className="border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
              <tr>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Date</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">User</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Tokens</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Amount</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Payment Method</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Status</th>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Payment ID</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {purchases.map((purchase: any) => (
                <tr key={purchase.id} className="hover:bg-gray-50 dark:hover:bg-gray-900">
                  <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                    {new Date(purchase.purchased_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                    {purchase.user_email || 'Anonymous'}
                  </td>
                  <td className="px-4 py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    {purchase.token_amount}
                  </td>
                  <td className="px-4 py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                    ₹{purchase.cost_rupees}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                    {purchase.payment_method || '-'}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                      purchase.status === 'completed' ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' :
                      purchase.status === 'pending' ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200' :
                      'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                    }`}>
                      {purchase.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                    {purchase.payment_id ? (
                      <span className="font-mono text-xs">{purchase.payment_id.substring(0, 16)}...</span>
                    ) : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
