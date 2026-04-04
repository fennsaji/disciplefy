'use client'

import type { PlByTierItem } from '@/types/admin'

interface PlByTierTableProps {
  data: PlByTierItem[]
  exchangeRateUsed: number
  exchangeRateIsLive: boolean
}

const PLAN_LABELS: Record<string, string> = {
  free: 'Free',
  standard: 'Standard',
  plus: 'Plus',
  premium: 'Premium',
  total: 'Total',
}

function formatInr(value: number | null): string {
  return `₹${(value ?? 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`
}

function rowClass(item: PlByTierItem): string {
  if (item.plan_code === 'total') return 'font-bold bg-gray-100 dark:bg-gray-700'
  if (item.plan_code === 'free') return 'text-gray-400 dark:text-gray-500'
  if ((item.gross_profit_inr ?? 0) > 0) return 'bg-green-50 dark:bg-green-950/20'
  if ((item.gross_profit_inr ?? 0) < 0) return 'bg-red-50 dark:bg-red-950/20'
  return ''
}

export function PlByTierTable({ data, exchangeRateUsed, exchangeRateIsLive }: PlByTierTableProps) {
  return (
    <div className="rounded-lg bg-white shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">P&L by Subscription Tier</h2>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full">
          <thead className="border-b border-gray-200 dark:border-gray-700">
            <tr>
              <th className="px-6 py-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400 sticky left-0 z-20 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] dark:bg-gray-800">Plan</th>
              <th className="px-6 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Active Users</th>
              <th className="px-6 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Revenue (₹)</th>
              <th className="px-6 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">LLM Cost (₹)</th>
              <th className="px-6 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Gross Profit (₹)</th>
              <th className="px-6 py-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">Margin %</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {data.length === 0 && (
              <tr><td colSpan={6} className="py-6 text-center text-sm text-gray-400 dark:text-gray-500">No subscription data for this period</td></tr>
            )}
            {data.map((item) => (
              <tr key={item.plan_code} className={`${rowClass(item)} group`}>
                <td className="px-6 py-3 text-sm font-medium text-gray-900 dark:text-gray-100 sticky left-0 z-10 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] group-hover:bg-gray-50 dark:bg-gray-800 dark:group-hover:bg-gray-700">
                  {PLAN_LABELS[item.plan_code] ?? item.plan_code}
                </td>
                <td className="px-6 py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                  {(item.active_users ?? 0).toLocaleString()}
                </td>
                <td className="px-6 py-3 text-right text-sm text-gray-900 dark:text-gray-100">
                  {formatInr(item.revenue_inr)}
                </td>
                <td className="px-6 py-3 text-right text-sm text-gray-900 dark:text-gray-100">
                  {formatInr(item.llm_cost_inr)}
                </td>
                <td className={`px-6 py-3 text-right text-sm font-medium ${
                  (item.gross_profit_inr ?? 0) >= 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'
                }`}>
                  {formatInr(item.gross_profit_inr)}
                </td>
                <td className="px-6 py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                  {item.margin_pct != null ? `${item.margin_pct.toFixed(1)}%` : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="px-6 py-3 text-xs text-gray-500 dark:text-gray-400 border-t border-gray-200 dark:border-gray-700">
        {exchangeRateIsLive
          ? `Exchange rate: $1 = ₹${exchangeRateUsed.toFixed(2)} (live)`
          : `Exchange rate: $1 = ₹${exchangeRateUsed.toFixed(2)} (fallback — live rate unavailable)`}
      </div>
    </div>
  )
}
