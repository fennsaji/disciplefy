'use client'

import { useState, use } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useRouter } from 'next/navigation'

export default function PurchaseIssueDetailsPage({ params }: { params: Promise<{ issueId: string }> }) {
  const router = useRouter()
  const queryClient = useQueryClient()
  const [newStatus, setNewStatus] = useState('')
  const [adminNotes, setAdminNotes] = useState('')

  // Unwrap params Promise
  const { issueId } = use(params)

  const { data, isLoading } = useQuery({
    queryKey: ['purchase-issue-details', issueId],
    queryFn: async () => {
      const response = await fetch(`/api/admin/purchase-issue-details/${issueId}`, {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch issue details')
      return response.json()
    },
  })

  const updateIssueMutation = useMutation({
    mutationFn: async (updateData: { status: string; admin_notes: string }) => {
      const response = await fetch('/api/admin/update-purchase-issue', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          issue_id: issueId,
          ...updateData,
        }),
      })
      if (!response.ok) throw new Error('Failed to update issue')
      return response.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['purchase-issue-details', issueId] })
      queryClient.invalidateQueries({ queryKey: ['purchase-issues'] })
    },
  })

  const handleUpdateIssue = () => {
    if (!newStatus) return
    updateIssueMutation.mutate({
      status: newStatus,
      admin_notes: adminNotes,
    })
  }

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="text-gray-500 dark:text-gray-400">Loading issue details...</div>
      </div>
    )
  }

  if (!data) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="text-red-500">Issue not found</div>
      </div>
    )
  }

  const { issue, dbPayment, razorpayPayment, razorpayOrder, purchaseHistory } = data

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      pending: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300',
      investigating: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300',
      resolved: 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300',
      closed: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300',
    }
    return colors[status] || colors.pending
  }

  return (
    <div className="space-y-6 p-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <button
            onClick={() => router.back()}
            className="mb-4 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
          >
            ← Back to Issues
          </button>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">
            Purchase Issue Details
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Complete information about this purchase issue
          </p>
        </div>
        <span className={`inline-flex rounded-full px-4 py-2 text-sm font-semibold ${getStatusColor(issue.status)}`}>
          {issue.status}
        </span>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Issue Information */}
        <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800">
          <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
            Issue Information
          </h2>
          <dl className="space-y-3">
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Issue ID</dt>
              <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{issue.id}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Issue Type</dt>
              <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{issue.issue_type}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Description</dt>
              <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{issue.description}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">User ID</dt>
              <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{issue.user_id || 'Anonymous'}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">User Email</dt>
              <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{issue.user_email || 'Anonymous'}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Purchase ID</dt>
              <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{issue.purchase_id || '—'}</dd>
            </div>
            {issue.screenshot_urls && issue.screenshot_urls.length > 0 && (
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Screenshots</dt>
                <dd className="mt-1 space-y-2">
                  {issue.screenshot_urls.map((url: string, idx: number) => (
                    <a
                      key={idx}
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block text-sm text-primary hover:underline"
                    >
                      Screenshot {idx + 1}
                    </a>
                  ))}
                </dd>
              </div>
            )}
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Reported At</dt>
              <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                {new Date(issue.created_at).toLocaleString()}
              </dd>
            </div>
            {issue.updated_at && (
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Last Updated</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {new Date(issue.updated_at).toLocaleString()}
                </dd>
              </div>
            )}
            {issue.resolved_by && (
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Resolved By</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{issue.resolved_by}</dd>
              </div>
            )}
            {issue.resolved_at && (
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Resolved At</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {new Date(issue.resolved_at).toLocaleString()}
                </dd>
              </div>
            )}
          </dl>
        </div>

        {/* Payment Information from Issue */}
        <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800">
          <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
            Reported Payment Details
          </h2>
          <dl className="space-y-3">
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Payment ID</dt>
              <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{issue.payment_id}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Order ID</dt>
              <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{issue.order_id}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Token Amount</dt>
              <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{issue.token_amount} tokens</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Cost Paid</dt>
              <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">₹{issue.cost_rupees}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Purchase Time</dt>
              <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                {new Date(issue.purchased_at).toLocaleString()}
              </dd>
            </div>
          </dl>
        </div>

        {/* Admin Actions */}
        <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800">
          <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
            Admin Actions
          </h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Update Status
              </label>
              <select
                value={newStatus || issue.status}
                onChange={(e) => setNewStatus(e.target.value)}
                className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              >
                <option value="pending">Pending</option>
                <option value="investigating">Investigating</option>
                <option value="resolved">Resolved</option>
                <option value="closed">Closed</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Admin Notes
              </label>
              <textarea
                value={adminNotes || issue.admin_notes || ''}
                onChange={(e) => setAdminNotes(e.target.value)}
                rows={4}
                className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                placeholder="Add notes about investigation or resolution..."
              />
            </div>

            <button
              onClick={handleUpdateIssue}
              disabled={!newStatus || updateIssueMutation.isPending}
              className="w-full rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50"
            >
              {updateIssueMutation.isPending ? 'Updating...' : 'Update Issue'}
            </button>
          </div>
        </div>

        {/* Database Payment Record */}
        {dbPayment && (
          <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800 lg:col-span-2">
            <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
              Database Payment Record
            </h2>
            <div className="grid gap-4 md:grid-cols-3">
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Record ID</dt>
                <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{dbPayment.id}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Payment ID</dt>
                <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{dbPayment.payment_id}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Order ID</dt>
                <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{dbPayment.order_id}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Amount (Rupees)</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">₹{dbPayment.cost_rupees}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Amount (Paise)</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{dbPayment.cost_paise} paise</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Token Amount</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{dbPayment.token_amount} tokens</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Status</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                    dbPayment.status === 'completed' ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300' :
                    dbPayment.status === 'pending' ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300' :
                    'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300'
                  }`}>
                    {dbPayment.status}
                  </span>
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Payment Method</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{dbPayment.payment_method}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Payment Provider</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{dbPayment.payment_provider}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Receipt Number</dt>
                <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{dbPayment.receipt_number || '—'}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Receipt URL</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {dbPayment.receipt_url ? (
                    <a href={dbPayment.receipt_url} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">
                      View Receipt
                    </a>
                  ) : '—'}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Saved Payment Method</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{dbPayment.saved_payment_method_id || '—'}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Purchased At</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {new Date(dbPayment.purchased_at).toLocaleString()}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Created At</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {new Date(dbPayment.created_at).toLocaleString()}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Updated At</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {new Date(dbPayment.updated_at).toLocaleString()}
                </dd>
              </div>
            </div>
          </div>
        )}

        {/* Razorpay Payment Details */}
        {razorpayPayment && (
          <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800 lg:col-span-2">
            <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
              Razorpay Payment Details
            </h2>
            <div className="grid gap-4 md:grid-cols-3">
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Payment ID</dt>
                <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{razorpayPayment.id}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Amount</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  ₹{(razorpayPayment.amount / 100).toFixed(2)}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Status</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{razorpayPayment.status}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Method</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{razorpayPayment.method}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Email</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{razorpayPayment.email}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Contact</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{razorpayPayment.contact}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Created At</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {new Date(razorpayPayment.created_at * 1000).toLocaleString()}
                </dd>
              </div>
              {razorpayPayment.error_code && (
                <div>
                  <dt className="text-sm font-medium text-red-500">Error Code</dt>
                  <dd className="mt-1 text-sm text-red-600 dark:text-red-400">{razorpayPayment.error_code}</dd>
                </div>
              )}
              {razorpayPayment.error_description && (
                <div className="md:col-span-2">
                  <dt className="text-sm font-medium text-red-500">Error Description</dt>
                  <dd className="mt-1 text-sm text-red-600 dark:text-red-400">{razorpayPayment.error_description}</dd>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Razorpay Order Details */}
        {razorpayOrder && (
          <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800 lg:col-span-2">
            <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
              Razorpay Order Details
            </h2>
            <div className="grid gap-4 md:grid-cols-3">
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Order ID</dt>
                <dd className="mt-1 text-sm font-mono text-gray-900 dark:text-gray-100">{razorpayOrder.id}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Amount</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  ₹{(razorpayOrder.amount / 100).toFixed(2)}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Amount Paid</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  ₹{(razorpayOrder.amount_paid / 100).toFixed(2)}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Status</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{razorpayOrder.status}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Attempts</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">{razorpayOrder.attempts}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Created At</dt>
                <dd className="mt-1 text-sm text-gray-900 dark:text-gray-100">
                  {new Date(razorpayOrder.created_at * 1000).toLocaleString()}
                </dd>
              </div>
            </div>
          </div>
        )}

        {/* Razorpay Data Unavailable Warning */}
        {!razorpayPayment && !razorpayOrder && (
          <div className="rounded-lg border-2 border-yellow-300 bg-yellow-50 p-6 dark:border-yellow-700 dark:bg-yellow-900/20 lg:col-span-2">
            <div className="flex items-start">
              <div className="flex-shrink-0">
                <span className="text-2xl">⚠️</span>
              </div>
              <div className="ml-3">
                <h3 className="text-sm font-medium text-yellow-800 dark:text-yellow-300">
                  Razorpay Data Unavailable
                </h3>
                <div className="mt-2 text-sm text-yellow-700 dark:text-yellow-400">
                  <p>Unable to fetch payment and order details from Razorpay API. This could be due to:</p>
                  <ul className="mt-2 list-disc space-y-1 pl-5">
                    <li>Razorpay API credentials not configured in environment variables</li>
                    <li>API rate limiting or temporary service unavailability</li>
                    <li>Invalid or expired payment/order IDs</li>
                  </ul>
                  <p className="mt-2">
                    <strong>Note:</strong> Database payment record above contains the essential information for investigation.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Purchase History */}
        {purchaseHistory && purchaseHistory.length > 0 && (
          <div className="rounded-lg bg-white p-6 shadow dark:bg-gray-800 lg:col-span-2">
            <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
              Purchase History
            </h2>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead>
                  <tr>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400">
                      Payment ID
                    </th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400">
                      Tokens
                    </th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400">
                      Amount
                    </th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400">
                      Status
                    </th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400">
                      Date
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                  {purchaseHistory.map((purchase: any) => (
                    <tr key={purchase.id}>
                      <td className="px-4 py-2 text-sm font-mono text-gray-900 dark:text-gray-100">
                        {purchase.payment_id?.substring(0, 20)}...
                      </td>
                      <td className="px-4 py-2 text-sm text-gray-900 dark:text-gray-100">
                        {purchase.token_amount} tokens
                      </td>
                      <td className="px-4 py-2 text-sm text-gray-900 dark:text-gray-100">
                        ₹{purchase.cost_rupees || (purchase.cost_paise / 100).toFixed(2)}
                      </td>
                      <td className="px-4 py-2 text-sm text-gray-900 dark:text-gray-100">
                        {purchase.status}
                      </td>
                      <td className="px-4 py-2 text-sm text-gray-900 dark:text-gray-100">
                        {new Date(purchase.purchased_at).toLocaleDateString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* No Purchase History Message */}
        {(!purchaseHistory || purchaseHistory.length === 0) && (
          <div className="rounded-lg border border-gray-300 bg-gray-50 p-6 dark:border-gray-700 dark:bg-gray-800 lg:col-span-2">
            <div className="text-center">
              <span className="text-2xl">📋</span>
              <h3 className="mt-2 text-sm font-medium text-gray-900 dark:text-gray-100">
                No Purchase History
              </h3>
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                This user has no other completed purchases in the database.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
