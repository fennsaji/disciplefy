'use client'

import Link from 'next/link'
import type { HeavyUserItem } from '@/types/admin'

interface TopHeavyUsersTableProps {
  data: HeavyUserItem[]
}

function formatInr(value: number): string {
  return `₹${value.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`
}

export function TopHeavyUsersTable({ data }: TopHeavyUsersTableProps) {
  return (
    <div className="rounded-lg bg-white shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Top 10 Heavy Users</h2>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Sorted by LLM spend (highest first)</p>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full">
          <thead className="border-b border-gray-200 dark:border-gray-700">
            <tr>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400 w-8 sticky left-0 z-20 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] dark:bg-gray-800">#</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Email</th>
              <th className="px-4 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">Plan</th>
              <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Ops</th>
              <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">LLM Cost</th>
              <th className="px-4 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Revenue</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-600 dark:text-gray-400">Profitable</th>
              <th className="px-4 py-3 text-center text-sm font-medium text-gray-600 dark:text-gray-400">—</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {data.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-sm text-gray-500 dark:text-gray-400">
                  No data for this period
                </td>
              </tr>
            )}
            {data.map((user) => (
              <tr key={user.user_id} className="hover:bg-gray-50 dark:hover:bg-gray-700/30 group">
                <td className="px-4 py-3 text-sm text-gray-500 dark:text-gray-400 sticky left-0 z-10 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] group-hover:bg-gray-50 dark:bg-gray-800 dark:group-hover:bg-gray-700">{user.rank}</td>
                <td className="px-4 py-3 font-mono text-xs text-gray-900 dark:text-gray-100 max-w-[200px] truncate">
                  {user.email}
                </td>
                <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 capitalize">{user.tier}</td>
                <td className="px-4 py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                  {user.operations.toLocaleString()}
                </td>
                <td className="px-4 py-3 text-right text-sm font-medium text-red-600 dark:text-red-400">
                  {formatInr(user.llm_cost_inr)}
                </td>
                <td className="px-4 py-3 text-right text-sm font-medium text-green-600 dark:text-green-400">
                  {formatInr(user.revenue_inr)}
                </td>
                <td className="px-4 py-3 text-center">
                  {user.is_profitable ? (
                    <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400">
                      ✓
                    </span>
                  ) : (
                    <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400">
                      ✗
                    </span>
                  )}
                </td>
                <td className="px-4 py-3 text-center">
                  <Link
                    href={`/dashboard/subscriptions/${user.user_id}`}
                    className="text-xs text-blue-600 hover:underline dark:text-blue-400"
                  >
                    View
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
