'use client'

import { formatCurrency } from '@/lib/utils/date'
import type { CrossBreakdownItem } from '@/types/admin'

interface CostCrossBreakdownTableProps {
  data: CrossBreakdownItem[]
}

const LANGUAGE_DISPLAY: Record<string, string> = {
  en: '🇺🇸 English',
  hi: '🇮🇳 Hindi',
  ml: '🇮🇳 Malayalam',
}

const STUDY_MODE_DISPLAY: Record<string, string> = {
  quick: 'Quick',
  standard: 'Standard',
  deep: 'Deep Study',
  lectio: 'Lectio Divina',
  sermon: 'Sermon Outline',
}

export function CostCrossBreakdownTable({ data }: CostCrossBreakdownTableProps) {
  if (data.length === 0) {
    return (
      <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
          Cost by Language × Study Mode
        </h2>
        <p className="text-sm text-gray-500 dark:text-gray-400">
          No data available for the selected date range.
        </p>
      </div>
    )
  }

  const languages = [...new Set(data.map((d) => d.language))].sort()
  const studyModes = [...new Set(data.map((d) => d.study_mode))].sort()

  const lookup = new Map<string, CrossBreakdownItem>()
  data.forEach((d) => lookup.set(`${d.language}|${d.study_mode}`, d))

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
        Cost by Language × Study Mode
      </h2>
      <div className="overflow-x-auto">
        <table className="min-w-full">
          <thead className="border-b border-gray-200 dark:border-gray-700">
            <tr>
              <th className="pb-3 text-left text-sm font-medium text-gray-600 dark:text-gray-400 sticky left-0 z-20 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] dark:bg-gray-800">
                Language
              </th>
              {studyModes.map((mode) => (
                <th
                  key={mode}
                  className="pb-3 text-right text-sm font-medium text-gray-600 dark:text-gray-400"
                >
                  {STUDY_MODE_DISPLAY[mode] ?? mode}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {languages.map((lang) => (
              <tr key={lang} className="group">
                <td className="py-3 text-sm font-medium text-gray-900 dark:text-gray-100 sticky left-0 z-10 bg-white shadow-[2px_0_5px_rgba(0,0,0,0.06)] group-hover:bg-gray-50 dark:bg-gray-800 dark:group-hover:bg-gray-700">
                  {LANGUAGE_DISPLAY[lang] ?? lang}
                </td>
                {studyModes.map((mode) => {
                  const cell = lookup.get(`${lang}|${mode}`)
                  return (
                    <td key={mode} className="py-3 text-right text-sm text-gray-600 dark:text-gray-400">
                      {cell ? (
                        <div className="flex flex-col items-end">
                          <span className="font-medium text-gray-900 dark:text-gray-100">
                            {formatCurrency(cell.cost_usd)}
                          </span>
                          <span className="text-xs text-gray-500 dark:text-gray-400">
                            {cell.operations} ops
                          </span>
                        </div>
                      ) : (
                        <span className="text-gray-400 dark:text-gray-600">—</span>
                      )}
                    </td>
                  )
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
