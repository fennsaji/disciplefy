'use client'

import { useParams, useRouter } from 'next/navigation'
import { useQuery } from '@tanstack/react-query'
import { searchUsers } from '@/lib/api/admin'
import { format } from 'date-fns'
import type { PaymentHistoryResponse } from '@/types/admin'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'

export default function UserDetailsPage() {
  const params = useParams()
  const router = useRouter()
  const userId = params.userId as string

  // Fetch user details
  const { data, isLoading, error } = useQuery({
    queryKey: ['user-details', userId],
    queryFn: async () => {
      const result = await searchUsers({ query: userId })
      const user = result.users.find(u => u.id === userId)
      if (!user) throw new Error('User not found')
      return user
    },
  })

  // Fetch payment history
  const { data: paymentData } = useQuery<PaymentHistoryResponse>({
    queryKey: ['payment-history', userId],
    queryFn: async () => {
      const response = await fetch(`/api/admin/payment-history/${userId}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch payment history')
      return response.json()
    },
    enabled: !!userId,
  })

  const formatDate = (dateString: string | null | undefined) => {
    if (!dateString) return 'N/A'
    return format(new Date(dateString), 'MMM dd, yyyy')
  }

  const formatDateTime = (dateString: string | null | undefined) => {
    if (!dateString) return 'N/A'
    return format(new Date(dateString), 'MMM dd, yyyy HH:mm')
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
    }).format(amount)
  }

  // Check for active, trial, in_progress, or pending_cancellation subscriptions
  const activeSubscription = data?.subscriptions.find(s =>
    ['active', 'trial', 'in_progress', 'pending_cancellation'].includes(s.status)
  )

  if (isLoading) {
    return <LoadingState label="Loading subscriptions..." />
  }

  if (error || !data) {
    return (
      <ErrorState title="Error loading subscriptions" message={error instanceof Error ? error.message : 'User not found'} />
    )
  }

  return (
    <div className="space-y-6">
      {/* Back Button */}
      <button
        onClick={() => router.push('/subscriptions')}
        className="mb-4 flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
      >
        <svg
          className="h-4 w-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 19l-7-7 7-7"
          />
        </svg>
        Back to Subscriptions
      </button>

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">User Details</h1>
          <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
            Complete user information and subscription history
          </p>
        </div>
        <button
          onClick={() => router.push(`/subscriptions/${userId}/edit`)}
          className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
        >
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
          Edit Subscription
        </button>
      </div>

      {/* Basic Information Card */}
      <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
        <div className="mb-4 flex items-center gap-2">
          <div className="rounded-full bg-primary-100 p-2">
            <svg className="h-5 w-5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </div>
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
            Basic Information
          </h2>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Full Name</p>
            <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
              {data.full_name || 'N/A'}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Email</p>
            <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
              {data.email || 'N/A'}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Phone</p>
            <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
              {data.phone || 'N/A'}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">User ID</p>
            <p className="mt-1 font-mono text-xs text-gray-900 dark:text-gray-100">
              {data.id}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-600 dark:text-gray-400">Created At</p>
            <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
              {formatDate(data.created_at)}
            </p>
          </div>
        </div>
      </div>

      {/* Active Subscription Card */}
      <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
        <div className="mb-4 flex items-center gap-2">
          <div className="rounded-full bg-green-100 p-2">
            <svg className="h-5 w-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
            </svg>
          </div>
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
            Active Subscription
          </h2>
        </div>
        {activeSubscription ? (
          <div className="space-y-6">
            {/* Primary Info */}
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Tier</p>
                <div className="mt-1 flex items-center gap-2">
                  <span
                    className={`h-3 w-3 rounded-full ${
                      activeSubscription.tier === 'premium'
                        ? 'bg-purple-500'
                        : activeSubscription.tier === 'plus'
                        ? 'bg-blue-500'
                        : activeSubscription.tier === 'standard'
                        ? 'bg-green-500'
                        : 'bg-gray-400'
                    }`}
                  />
                  <span className="font-medium capitalize text-gray-900 dark:text-gray-100">
                    {activeSubscription.tier}
                  </span>
                </div>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Status</p>
                <span
                  className={`mt-1 inline-flex rounded-full px-3 py-1 text-sm font-medium ${
                    activeSubscription.status === 'active'
                      ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                      : activeSubscription.status === 'trial'
                      ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                      : activeSubscription.status === 'pending_cancellation'
                      ? 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200'
                      : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                  }`}
                >
                  {activeSubscription.status}
                </span>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Plan Name</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {activeSubscription.subscription_plans?.plan_name || 'N/A'}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Billing Cycle</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {activeSubscription.subscription_plans?.billing_cycle || 'N/A'}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Provider</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {activeSubscription.provider || 'N/A'}
                </p>
              </div>
              {activeSubscription.subscription_plans?.price_inr && (
                <div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">Price</p>
                  <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                    ₹{activeSubscription.subscription_plans.price_inr}
                  </p>
                </div>
              )}
            </div>

            {/* Billing Dates */}
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Subscription Started</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {formatDate(activeSubscription.start_date)}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Current Period Start</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {formatDate(activeSubscription.current_period_start)}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Current Period End</p>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {formatDate(activeSubscription.current_period_end)}
                </p>
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-600 dark:text-gray-400">Next Payment Date</p>
                <p className="mt-1 font-semibold text-gray-900 dark:text-gray-100">
                  {activeSubscription.next_billing_at ? formatDate(activeSubscription.next_billing_at) : 'Not scheduled'}
                </p>
              </div>
              {activeSubscription.cancelled_at && (
                <div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">Cancelled At</p>
                  <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                    {formatDate(activeSubscription.cancelled_at)}
                  </p>
                </div>
              )}
            </div>

            {/* Provider Info */}
            {activeSubscription.provider_subscription_id && (
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Provider Subscription ID</p>
                <p className="mt-1 font-mono text-xs text-gray-900 dark:text-gray-100">
                  {activeSubscription.provider_subscription_id}
                </p>
              </div>
            )}

            {/* Cancellation Reason */}
            {activeSubscription.cancellation_reason && (
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Cancellation Reason</p>
                <p className="mt-1 text-gray-900 dark:text-gray-100">
                  {activeSubscription.cancellation_reason}
                </p>
              </div>
            )}
          </div>
        ) : (
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-8 text-center dark:border-gray-700 dark:bg-gray-700">
            <p className="text-sm text-gray-600 dark:text-gray-400">No active subscription</p>
          </div>
        )}
      </div>

      {/* Payment History Card */}
      {paymentData && paymentData.payments.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="mb-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="rounded-full bg-blue-100 p-2">
                <svg className="h-5 w-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
              <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                Payment History ({paymentData.total_payments})
              </h2>
            </div>
            <div className="text-right">
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Spent</p>
              <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                {formatCurrency(paymentData.total_spent)}
              </p>
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-200 dark:border-gray-700">
                <tr>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Date</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Amount</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Method</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Status</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Receipt</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Payment ID</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {paymentData.payments.map((payment) => (
                  <tr key={payment.id}>
                    <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                      {formatDateTime(payment.purchased_at)}
                    </td>
                    <td className="py-3 text-sm font-medium text-gray-900 dark:text-gray-100">
                      {formatCurrency(parseFloat(payment.cost_rupees))}
                    </td>
                    <td className="py-3 text-sm capitalize text-gray-900 dark:text-gray-100">
                      {payment.payment_method}
                    </td>
                    <td className="py-3">
                      <span
                        className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                          payment.status === 'completed'
                            ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                            : payment.status === 'pending'
                            ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                            : payment.status === 'failed'
                            ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                            : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                        }`}
                      >
                        {payment.status}
                      </span>
                    </td>
                    <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                      {payment.receipt_number || 'N/A'}
                    </td>
                    <td className="py-3 font-mono text-xs text-gray-600 dark:text-gray-400">
                      {payment.payment_id}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Subscription Invoices Card */}
      {paymentData && paymentData.invoices && paymentData.invoices.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="mb-4 flex items-center gap-2">
            <div className="rounded-full bg-purple-100 p-2">
              <svg className="h-5 w-5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              Subscription Invoices ({paymentData.invoices.length})
            </h2>
          </div>
          <p className="mb-4 text-sm text-gray-600 dark:text-gray-400">
            Recurring subscription billing records
          </p>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-gray-200 dark:border-gray-700">
                <tr>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Invoice #</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Amount</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Due Date</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Payment Date</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Status</th>
                  <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Subscription ID</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {paymentData.invoices.map((invoice) => (
                  <tr key={invoice.id}>
                    <td className="py-3 text-sm font-medium text-gray-900 dark:text-gray-100">
                      {invoice.invoice_number || 'N/A'}
                    </td>
                    <td className="py-3 text-sm font-medium text-gray-900 dark:text-gray-100">
                      {formatCurrency((invoice.amount_minor || 0) / 100)} {invoice.currency || 'INR'}
                    </td>
                    <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                      {invoice.due_date ? formatDateTime(invoice.due_date) : 'N/A'}
                    </td>
                    <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                      {invoice.payment_date ? formatDateTime(invoice.payment_date) : 'Pending'}
                    </td>
                    <td className="py-3">
                      <span
                        className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                          invoice.payment_status === 'paid'
                            ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                            : invoice.payment_status === 'pending'
                            ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                            : invoice.payment_status === 'failed'
                            ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                            : invoice.payment_status === 'refunded'
                            ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                            : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                        }`}
                      >
                        {invoice.payment_status || 'unknown'}
                      </span>
                    </td>
                    <td className="py-3 font-mono text-xs text-gray-600 dark:text-gray-400">
                      {invoice.subscription_id ? invoice.subscription_id.substring(0, 8) + '...' : 'N/A'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Subscription History Card */}
      {data.subscriptions.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
            Subscription History ({data.subscriptions.length})
          </h2>
          <div className="space-y-3">
            {data.subscriptions.map((sub) => (
              <div
                key={sub.id}
                className="flex items-center justify-between rounded-lg border border-gray-200 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-700"
              >
                <div className="flex items-center gap-4">
                  <span
                    className={`inline-flex items-center rounded-full px-3 py-1 text-sm font-medium capitalize ${
                      sub.tier === 'premium'
                        ? 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200'
                        : sub.tier === 'plus'
                        ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                        : sub.tier === 'standard'
                        ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                        : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                    }`}
                  >
                    {sub.tier}
                  </span>
                  <span
                    className={`inline-flex rounded-full px-3 py-1 text-sm font-medium ${
                      sub.status === 'active'
                        ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                        : sub.status === 'trial'
                        ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                        : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
                    }`}
                  >
                    {sub.status}
                  </span>
                </div>
                <div className="text-sm text-gray-600 dark:text-gray-400">
                  {formatDate(sub.start_date)} → {sub.end_date ? formatDate(sub.end_date) : 'Active'}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
