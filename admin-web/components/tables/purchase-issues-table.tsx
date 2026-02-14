'use client'

import { useRouter } from 'next/navigation'

interface PurchaseIssue {
  id: string
  user_id: string | null
  user_email: string | null
  issue_type: string
  description: string
  payment_id: string | null
  order_id: string | null
  status: string
  admin_notes: string | null
  created_at: string
  updated_at: string | null
}

interface PurchaseIssuesTableProps {
  issues: PurchaseIssue[]
}

export function PurchaseIssuesTable({ issues }: PurchaseIssuesTableProps) {
  const router = useRouter()

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      pending: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300',
      investigating: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300',
      resolved: 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300',
      closed: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300',
    }
    return colors[status] || colors.pending
  }

  const getIssueTypeLabel = (issueType: string) => {
    const labels: Record<string, string> = {
      wrong_amount: 'Wrong Amount',
      payment_failed: 'Payment Failed',
      double_charge: 'Double Charge',
      refund_request: 'Refund Request',
      missing_tokens: 'Missing Tokens',
      other: 'Other'
    }
    return labels[issueType] || issueType
  }

  if (issues.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
        <p className="text-gray-500 dark:text-gray-400">No purchase issues found</p>
      </div>
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Issue Type
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              User
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Payment/Order ID
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Status
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Reported
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
          {issues.map((issue) => (
            <tr
              key={issue.id}
              className="cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800"
              onClick={() => router.push(`/issues/purchase/${issue.id}`)}
            >
              <td className="whitespace-nowrap px-6 py-4">
                <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                  {getIssueTypeLabel(issue.issue_type)}
                </div>
                <div className="text-sm text-gray-500 dark:text-gray-400 line-clamp-1">
                  {issue.description}
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="text-sm text-gray-900 dark:text-gray-100">
                  {issue.user_email || 'Anonymous'}
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="text-sm">
                  {issue.payment_id && (
                    <div className="text-gray-900 dark:text-gray-100 font-mono text-xs">
                      Pay: {issue.payment_id.substring(0, 20)}...
                    </div>
                  )}
                  {issue.order_id && (
                    <div className="text-gray-500 dark:text-gray-400 font-mono text-xs">
                      Order: {issue.order_id.substring(0, 20)}...
                    </div>
                  )}
                  {!issue.payment_id && !issue.order_id && (
                    <span className="text-sm italic text-gray-400">—</span>
                  )}
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${getStatusColor(issue.status)}`}>
                  {issue.status}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {new Date(issue.created_at).toLocaleDateString()} <br />
                {new Date(issue.created_at).toLocaleTimeString()}
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <button
                  onClick={(e) => {
                    e.stopPropagation()
                    router.push(`/issues/purchase/${issue.id}`)
                  }}
                  className="text-primary hover:text-primary-600 font-medium text-sm"
                >
                  View Details →
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
