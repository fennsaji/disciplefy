'use client'

import { useRouter } from 'next/navigation'
import { ManageIcon, actionButtonStyles } from '@/components/ui/action-icons'

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

interface TokenManagementTableProps {
  balances: UserTokenBalance[]
}

export function TokenManagementTable({ balances }: TokenManagementTableProps) {
  const router = useRouter()

  if (balances.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-12 text-center dark:border-gray-700 dark:bg-gray-800">
        <p className="text-gray-500 dark:text-gray-400">No users found. Try a different search query.</p>
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-md dark:border-gray-700 dark:bg-gray-800 dark:shadow-gray-900">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              User
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Plan
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Daily Tokens
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Purchased
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Used Today
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Last Reset
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-800">
          {balances.map((balance) => {
            const totalTokens = balance.available_tokens + balance.purchased_tokens

            return (
              <tr key={balance.id} className="hover:bg-gray-50 dark:hover:bg-gray-700">
                <td className="px-6 py-4">
                  <div className="flex flex-col">
                    <span className="font-medium text-gray-900 dark:text-gray-100">
                      {balance.user_name || balance.user_email || 'Anonymous'}
                    </span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">{balance.user_email}</span>
                    <span className="text-xs text-gray-400 dark:text-gray-500">
                      {balance.identifier.substring(0, 8)}...
                    </span>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <span className={`inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-medium ${getPlanColor(balance.user_plan)}`}>
                    {getPlanIcon(balance.user_plan)}
                    {formatPlanName(balance.user_plan)}
                  </span>
                </td>
                <td className="px-6 py-4 text-right">
                  <div className="flex flex-col items-end">
                    <span className="font-medium text-gray-900 dark:text-gray-100">
                      {balance.daily_limit >= 999999999 ? '∞' : balance.available_tokens.toLocaleString()}
                    </span>
                    <span className="text-xs text-gray-500 dark:text-gray-400">
                      / {balance.daily_limit >= 999999999 ? 'Unlimited' : `${balance.daily_limit.toLocaleString()} limit`}
                    </span>
                  </div>
                </td>
                <td className="px-6 py-4 text-right font-medium text-gray-900 dark:text-gray-100">
                  {balance.purchased_tokens.toLocaleString()}
                </td>
                <td className="px-6 py-4 text-right">
                  <div className="flex flex-col items-end">
                    <span className="font-medium text-gray-900 dark:text-gray-100">
                      {balance.total_consumed_today.toLocaleString()}
                    </span>
                    <span className="text-xs text-gray-500 dark:text-gray-400">
                      {totalTokens > 0 ? Math.round((balance.total_consumed_today / totalTokens) * 100) : 0}%
                    </span>
                  </div>
                </td>
                <td className="px-6 py-4 text-sm text-gray-600 dark:text-gray-400">
                  {new Date(balance.last_reset).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric',
                  })}
                </td>
                <td className="px-6 py-4">
                  <div className="flex justify-end gap-3">
                    <button
                      onClick={() => router.push(`/token-management/${balance.identifier}`)}
                      className={actionButtonStyles.manage}
                      title="View Details"
                    >
                      <ManageIcon />
                    </button>
                  </div>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

// Helper functions
function formatPlanName(plan: string): string {
  return plan.charAt(0).toUpperCase() + plan.slice(1)
}

function getPlanIcon(plan: string): string {
  const icons: Record<string, string> = {
    free: '🆓',
    standard: '⭐',
    plus: '✨',
    premium: '👑',
  }
  return icons[plan] || '📊'
}

function getPlanColor(plan: string): string {
  const colors: Record<string, string> = {
    free: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200',
    standard: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
    plus: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
    premium: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
  }
  return colors[plan] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
}
