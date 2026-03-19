'use client'

import { formatCurrency, formatCompactNumber } from '@/lib/utils/date'
import type { AggregateBreakdown } from '@/types/admin'

interface CostByLanguageTableProps {
  data: Record<string, AggregateBreakdown>
}

const LANGUAGE_DISPLAY: Record<string, { flag: string; name: string }> = {
  en: { flag: '🇺🇸', name: 'English' },
  hi: { flag: '🇮🇳', name: 'Hindi' },
  ml: { flag: '🇮🇳', name: 'Malayalam' },
}

function formatLanguage(code: string): string {
  const d = LANGUAGE_DISPLAY[code]
  return d ? `${d.flag} ${d.name}` : code
}

export function CostByLanguageTable({ data }: CostByLanguageTableProps) {
  const entries = Object.entries(data).sort((a, b) => b[1].cost_usd - a[1].cost_usd)
  const totalCost = entries.reduce((sum, [, v]) => sum + v.cost_usd, 0)

  if (entries.length === 0) {
    return (
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
          Cost by Language
        </h2>
        <p className="text-sm text-gray-500 dark:text-gray-400">
          No data available for the selected date range.
        </p>
      </div>
    )
  }

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
        Cost by Language
      </h2>
      <div className="overflow-x-auto">
        <table className="min-w-full">
          <thead className="border-b border-gray-200 dark:border-gray-700">
            <tr>
              <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400">
                Language
              </th>
              <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                Operations
              </th>
              <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                Total Cost
              </th>
              <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                Avg/Op
              </th>
              <th className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400">
                % of Total
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {entries.map(([code, stats]) => (
              <tr key={code}>
                <td className="py-3 text-sm text-gray-900 dark:text-gray-100">
                  {formatLanguage(code)}
                </td>
                <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                  {formatCompactNumber(stats.operations)}
                </td>
                <td className="py-3 text-right text-sm font-medium text-gray-900 dark:text-gray-100">
                  {formatCurrency(stats.cost_usd)}
                </td>
                <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                  {formatCurrency(stats.avg_cost_per_operation)}
                </td>
                <td className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                  {totalCost > 0
                    ? `${((stats.cost_usd / totalCost) * 100).toFixed(1)}%`
                    : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
