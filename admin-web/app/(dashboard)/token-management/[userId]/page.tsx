'use client'

import { useParams, useRouter } from 'next/navigation'
import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { format } from 'date-fns'

export default function UserTokenDetailsPage() {
  const params = useParams()
  const router = useRouter()
  const userId = params.userId as string
  const queryClient = useQueryClient()

  const [showAdjustModal, setShowAdjustModal] = useState(false)
  const [adjustType, setAdjustType] = useState<'add' | 'remove'>('add')
  const [adjustAmount, setAdjustAmount] = useState('')
  const [adjustReason, setAdjustReason] = useState('')

  // Fetch user token balance
  const { data: balance, isLoading: balanceLoading, error: balanceError } = useQuery({
    queryKey: ['user-token-balance', userId],
    queryFn: async () => {
      const response = await fetch(`/api/admin/user-token-balances?search=${userId}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch balance')
      const data = await response.json()
      return data.find((b: any) => b.identifier === userId)
    },
  })

  // Fetch usage history
  const { data: usageData } = useQuery({
    queryKey: ['token-usage-history', userId],
    queryFn: async () => {
      const response = await fetch(`/api/admin/token-usage-history?range=all&search=${balance?.user_email || userId}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch usage history')
      return response.json()
    },
    enabled: !!balance,
  })

  // Fetch purchase history
  const { data: purchaseData } = useQuery({
    queryKey: ['token-purchases', userId],
    queryFn: async () => {
      const response = await fetch(`/api/admin/token-purchases?range=all&search=${balance?.user_email || userId}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch purchases')
      return response.json()
    },
    enabled: !!balance,
  })

  // Adjust tokens mutation
  const adjustTokensMutation = useMutation({
    mutationFn: async (data: { identifier: string; amount: number; reason: string; type: 'add' | 'remove' }) => {
      const response = await fetch('/api/admin/adjust-user-tokens', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(data),
      })
      if (!response.ok) throw new Error('Failed to adjust tokens')
      return response.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-token-balance', userId] })
      setShowAdjustModal(false)
      setAdjustAmount('')
      setAdjustReason('')
    },
  })

  const handleAdjustTokens = () => {
    if (!adjustAmount || !adjustReason) return

    adjustTokensMutation.mutate({
      identifier: userId,
      amount: parseInt(adjustAmount),
      reason: adjustReason,
      type: adjustType,
    })
  }

  if (balanceLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="inline-block h-12 w-12 animate-spin rounded-full border-4 border-solid border-primary border-r-transparent"></div>
          <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">Loading token details...</p>
        </div>
      </div>
    )
  }

  if (balanceError || !balance) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="rounded-lg border border-red-200 bg-red-50 p-6 text-center dark:border-red-800 dark:bg-red-900/20">
          <p className="font-medium text-red-800 dark:text-red-300">Error loading token details</p>
          <p className="mt-2 text-sm text-red-600 dark:text-red-400">
            {balanceError instanceof Error ? balanceError.message : 'User not found'}
          </p>
          <button
            onClick={() => router.push('/token-management')}
            className="mt-4 rounded-lg bg-red-100 px-4 py-2 text-sm font-medium text-red-800 hover:bg-red-200 dark:bg-red-900/40 dark:text-red-300 dark:hover:bg-red-900/60"
          >
            Back to Token Management
          </button>
        </div>
      </div>
    )
  }

  const usageHistory = usageData?.usage_history || []
  const purchases = purchaseData?.purchases || []

  return (
    <div className="space-y-6">
      {/* Back Button */}
      <button
        onClick={() => router.push('/token-management')}
        className="mb-4 flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
      >
        <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to Token Management
      </button>

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Token Details</h1>
          <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
            Complete token information and transaction history
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={() => {
              setAdjustType('add')
              setShowAdjustModal(true)
            }}
            className="flex items-center gap-2 rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            Add Tokens
          </button>
          <button
            onClick={() => {
              setAdjustType('remove')
              setShowAdjustModal(true)
            }}
            className="flex items-center gap-2 rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 12H4" />
            </svg>
            Remove Tokens
          </button>
        </div>
      </div>

      {/* Basic Information Card */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
        <div className="mb-4 flex items-center gap-2">
          <div className="rounded-full bg-primary-100 p-2 dark:bg-primary-900">
            <svg className="h-5 w-5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </div>
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">User Information</h2>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Email</p>
            <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">{balance.user_email || 'Anonymous'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">User ID</p>
            <p className="mt-1 font-mono text-sm text-gray-900 dark:text-gray-100">{balance.identifier}</p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Subscription Plan</p>
            <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">{balance.user_plan}</p>
          </div>
        </div>
      </div>

      {/* Token Balance Card */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
        <div className="mb-4 flex items-center gap-2">
          <div className="rounded-full bg-yellow-100 p-2 dark:bg-yellow-900">
            <svg className="h-5 w-5 text-yellow-600 dark:text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Token Balance</h2>
        </div>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-4">
          <div className="rounded-lg bg-blue-50 p-4 dark:bg-blue-900/20">
            <p className="text-sm text-blue-600 dark:text-blue-400">Daily Tokens</p>
            <p className="mt-2 text-3xl font-bold text-blue-900 dark:text-blue-100">{balance.available_tokens.toLocaleString()}</p>
            <p className="mt-1 text-xs text-blue-600 dark:text-blue-400">/ {balance.daily_limit.toLocaleString()} limit</p>
          </div>
          <div className="rounded-lg bg-green-50 p-4 dark:bg-green-900/20">
            <p className="text-sm text-green-600 dark:text-green-400">Purchased Tokens</p>
            <p className="mt-2 text-3xl font-bold text-green-900 dark:text-green-100">{balance.purchased_tokens.toLocaleString()}</p>
          </div>
          <div className="rounded-lg bg-purple-50 p-4 dark:bg-purple-900/20">
            <p className="text-sm text-purple-600 dark:text-purple-400">Used Today</p>
            <p className="mt-2 text-3xl font-bold text-purple-900 dark:text-purple-100">{balance.total_consumed_today.toLocaleString()}</p>
          </div>
          <div className="rounded-lg bg-gray-50 p-4 dark:bg-gray-900/20">
            <p className="text-sm text-gray-600 dark:text-gray-400">Last Reset</p>
            <p className="mt-2 text-lg font-medium text-gray-900 dark:text-gray-100">
              {format(new Date(balance.last_reset), 'MMM dd, yyyy')}
            </p>
            <p className="mt-1 text-xs text-gray-500 dark:text-gray-500">
              {format(new Date(balance.last_reset), 'HH:mm')}
            </p>
          </div>
        </div>
      </div>

      {/* Usage History */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
        <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Token Usage History</h2>
        {usageHistory.length === 0 ? (
          <p className="text-center text-gray-500 dark:text-gray-400">No usage history found</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
                <tr>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Date</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Feature</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Details</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Tokens</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Source</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {usageHistory.slice(0, 20).map((record: any) => (
                  <tr key={record.id} className="hover:bg-gray-50 dark:hover:bg-gray-900">
                    <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                      {format(new Date(record.created_at), 'MMM dd, HH:mm')}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">{record.feature_name}</td>
                    <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                      {record.study_mode && <span className="mr-2">{record.study_mode}</span>}
                      {record.language && <span>({record.language})</span>}
                    </td>
                    <td className="px-4 py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                      {record.token_cost}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                        record.source_type === 'daily' ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' :
                        'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                      }`}>
                        {record.source_type}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {usageHistory.length > 20 && (
              <p className="mt-4 text-center text-sm text-gray-500 dark:text-gray-400">
                Showing 20 of {usageHistory.length} records
              </p>
            )}
          </div>
        )}
      </div>

      {/* Purchase History */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
        <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Purchase History</h2>
        {purchases.length === 0 ? (
          <p className="text-center text-gray-500 dark:text-gray-400">No purchases found</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
                <tr>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Date</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Tokens</th>
                  <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Amount</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Method</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Status</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Payment ID</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {purchases.map((purchase: any) => (
                  <tr key={purchase.id} className="hover:bg-gray-50 dark:hover:bg-gray-900">
                    <td className="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">
                      {format(new Date(purchase.purchased_at), 'MMM dd, yyyy')}
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
                    <td className="px-4 py-3 text-sm font-mono text-gray-600 dark:text-gray-400">
                      {purchase.payment_id ? purchase.payment_id.substring(0, 16) + '...' : '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Adjust Tokens Modal */}
      {showAdjustModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div className="w-full max-w-md rounded-lg bg-white p-6 dark:bg-gray-800">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {adjustType === 'add' ? 'Add' : 'Remove'} Tokens
            </h3>

            <div className="mt-4 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Token Amount
                </label>
                <input
                  type="number"
                  value={adjustAmount}
                  onChange={(e) => setAdjustAmount(e.target.value)}
                  min="1"
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                  placeholder="Enter amount"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Reason (required)
                </label>
                <textarea
                  value={adjustReason}
                  onChange={(e) => setAdjustReason(e.target.value)}
                  rows={3}
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                  placeholder="Why are you adjusting tokens?"
                />
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-3">
              <button
                onClick={() => {
                  setShowAdjustModal(false)
                  setAdjustAmount('')
                  setAdjustReason('')
                }}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleAdjustTokens}
                disabled={!adjustAmount || !adjustReason || adjustTokensMutation.isPending}
                className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50"
              >
                {adjustTokensMutation.isPending ? 'Processing...' : 'Confirm'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
