'use client'

import { useRouter } from 'next/navigation'
import { format } from 'date-fns'
import type { UserWithSubscription, SubscriptionTier } from '@/types/admin'
import { ManageIcon, EditIcon, actionButtonStyles } from '@/components/ui/action-icons'

interface SubscriptionTableProps {
  users: UserWithSubscription[]
}

export function SubscriptionTable({ users }: SubscriptionTableProps) {
  const router = useRouter()
  if (users.length === 0) {
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
              Current Tier
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Plan Details
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Status
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Period
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Price
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-800">
          {users.map((user) => {
            // Check for active, trial, in_progress, or pending_cancellation subscriptions
            const activeSub = user.subscriptions.find(sub =>
              ['active', 'trial', 'in_progress', 'pending_cancellation'].includes(sub.status)
            )

            return (
              <tr key={user.id} className="hover:bg-gray-50 dark:hover:bg-gray-700">
                <td className="px-6 py-4">
                  <div className="flex flex-col">
                    <span className="font-medium text-gray-900 dark:text-gray-100">{user.full_name || 'No name'}</span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">{user.email}</span>
                    {user.phone && (
                      <span className="text-xs text-gray-400 dark:text-gray-500">{user.phone}</span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4">
                  {activeSub ? (
                    <span className={`inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-medium ${getTierColor(activeSub.tier)}`}>
                      {getTierIcon(activeSub.tier)}
                      {formatTierName(activeSub.tier)}
                    </span>
                  ) : (
                    <span className="text-sm text-gray-500 dark:text-gray-400">No active subscription</span>
                  )}
                </td>
                <td className="px-6 py-4">
                  {activeSub?.subscription_plans ? (
                    <div className="flex flex-col">
                      <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                        {activeSub.subscription_plans.plan_name}
                      </span>
                      <span className="text-xs text-gray-500 dark:text-gray-400">
                        {activeSub.subscription_plans.billing_cycle}
                      </span>
                    </div>
                  ) : (
                    <span className="text-sm text-gray-400 dark:text-gray-500">-</span>
                  )}
                </td>
                <td className="px-6 py-4">
                  {activeSub ? (
                    <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${getStatusColor(activeSub.status)}`}>
                      {activeSub.status}
                    </span>
                  ) : (
                    <span className="text-sm text-gray-400 dark:text-gray-500">-</span>
                  )}
                </td>
                <td className="px-6 py-4">
                  {activeSub ? (
                    <div className="flex flex-col text-sm">
                      <span className="text-gray-600 dark:text-gray-400">
                        {format(new Date(activeSub.start_date), 'MMM dd, yyyy')}
                      </span>
                      <span className="text-xs text-gray-500 dark:text-gray-500">
                        to {format(new Date(activeSub.end_date || ''), 'MMM dd, yyyy')}
                      </span>
                    </div>
                  ) : (
                    '-'
                  )}
                </td>
                <td className="px-6 py-4 text-sm text-gray-600 dark:text-gray-400">
                  {activeSub?.subscription_plans ? (
                    <div className="flex flex-col">
                      <span className="font-medium text-gray-900 dark:text-gray-100">
                        ₹{activeSub.subscription_plans.price_inr}
                      </span>
                    </div>
                  ) : (
                    '-'
                  )}
                </td>
                <td className="px-6 py-4">
                  <div className="flex justify-end gap-3">
                    <button
                      onClick={() => router.push(`/subscriptions/${user.id}`)}
                      className={actionButtonStyles.manage}
                      title="View Details"
                    >
                      <ManageIcon />
                    </button>
                    <button
                      onClick={() => router.push(`/subscriptions/${user.id}/edit`)}
                      className={actionButtonStyles.edit}
                      title="Edit Subscription"
                    >
                      <EditIcon />
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
function formatTierName(tier: SubscriptionTier): string {
  return tier.charAt(0).toUpperCase() + tier.slice(1)
}

function getTierIcon(tier: SubscriptionTier): string {
  const icons: Record<SubscriptionTier, string> = {
    free: '🆓',
    standard: '⭐',
    plus: '✨',
    premium: '👑',
  }
  return icons[tier] || '📊'
}

function getTierColor(tier: SubscriptionTier): string {
  const colors: Record<SubscriptionTier, string> = {
    free: 'bg-gray-100 text-gray-800',
    standard: 'bg-blue-100 text-blue-800',
    plus: 'bg-purple-100 text-purple-800',
    premium: 'bg-yellow-100 text-yellow-800',
  }
  return colors[tier] || 'bg-gray-100 text-gray-800'
}

function getStatusColor(status: string): string {
  const colors: Record<string, string> = {
    active: 'bg-green-100 text-green-800',
    cancelled: 'bg-red-100 text-red-800',
    expired: 'bg-gray-100 text-gray-800',
    pending_cancellation: 'bg-yellow-100 text-yellow-800',
  }
  return colors[status] || 'bg-gray-100 text-gray-800'
}
