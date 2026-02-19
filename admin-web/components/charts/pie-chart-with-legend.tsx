'use client'

import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts'
import { useTheme } from '@/components/theme-provider'
import { CHART_COLORS, getTooltipStyle } from '@/components/charts/chart-config'

interface DataItem {
  name: string
  value: number
}

interface Props {
  data: DataItem[]
  title?: string
}

function CustomTooltip({ active, payload }: any) {
  const { resolvedTheme } = useTheme()
  const isDark = resolvedTheme === 'dark'

  if (!active || !payload?.length) return null
  const item = payload[0]
  const total = item.payload?.total ?? 0
  const pct = total > 0 ? ((item.value / total) * 100).toFixed(1) : '0'

  return (
    <div style={getTooltipStyle(isDark)} className="px-3 py-2 text-sm">
      <p className="font-semibold capitalize">{item.name}</p>
      <p className="mt-0.5">
        {item.value.toLocaleString()} · {pct}%
      </p>
    </div>
  )
}

export function PieChartWithLegend({ data, title }: Props) {
  if (!data || data.length === 0) return null

  const total = data.reduce((sum, d) => sum + (d.value as number), 0)

  // Attach total to each entry so the tooltip can compute %
  const enriched = data
    .map((d) => ({ ...d, total }))
    .sort((a, b) => (b.value as number) - (a.value as number))

  const maxValue = enriched[0]?.value ?? 1

  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
      {/* Donut */}
      <div className="shrink-0 sm:w-48">
        {title && (
          <p className="mb-2 text-center text-xs font-medium text-gray-500 dark:text-gray-400 sm:hidden">
            {title}
          </p>
        )}
        <ResponsiveContainer width="100%" height={180}>
          <PieChart>
            <Pie
              data={enriched}
              cx="50%"
              cy="50%"
              innerRadius={52}
              outerRadius={80}
              paddingAngle={2}
              dataKey="value"
              stroke="none"
            >
              {enriched.map((_, index) => (
                <Cell
                  key={`cell-${index}`}
                  fill={CHART_COLORS[index % CHART_COLORS.length]}
                />
              ))}
            </Pie>
            <Tooltip content={<CustomTooltip />} />
          </PieChart>
        </ResponsiveContainer>
        {/* Center total */}
        <p className="mt-1 text-center text-sm text-gray-500 dark:text-gray-400">
          <span className="block text-xl font-bold text-gray-900 dark:text-gray-100">
            {total.toLocaleString()}
          </span>
          total
        </p>
      </div>

      {/* Legend list */}
      <div className="flex-1 overflow-y-auto" style={{ maxHeight: 260 }}>
        <div className="space-y-2">
          {enriched.map((item, index) => {
            const pct = total > 0 ? ((item.value / total) * 100).toFixed(1) : '0'
            const barWidth = total > 0 ? (item.value / maxValue) * 100 : 0
            const color = CHART_COLORS[index % CHART_COLORS.length]

            return (
              <div key={item.name} className="group flex items-center gap-2.5 rounded-lg px-2 py-1.5 transition-colors hover:bg-gray-50 dark:hover:bg-white/5">
                {/* Color swatch */}
                <span
                  className="h-3 w-3 shrink-0 rounded-sm"
                  style={{ backgroundColor: color }}
                />

                {/* Name */}
                <span className="flex-1 truncate text-sm capitalize text-gray-700 dark:text-gray-300">
                  {item.name}
                </span>

                {/* Bar + numbers */}
                <div className="flex items-center gap-2">
                  <div className="hidden w-20 sm:block">
                    <div className="h-1.5 w-full rounded-full bg-gray-100 dark:bg-white/10">
                      <div
                        className="h-1.5 rounded-full transition-all"
                        style={{ width: `${barWidth}%`, backgroundColor: color }}
                      />
                    </div>
                  </div>
                  <span className="w-10 text-right text-xs font-medium text-gray-900 dark:text-gray-100">
                    {item.value.toLocaleString()}
                  </span>
                  <span className="w-10 text-right text-xs text-gray-400 dark:text-gray-500">
                    {pct}%
                  </span>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
