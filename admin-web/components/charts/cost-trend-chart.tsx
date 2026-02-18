'use client'

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import { format } from 'date-fns'
import { useTheme } from '@/components/theme-provider'
import { formatCurrency } from '@/lib/utils/date'
import { getTooltipStyle, getAxisStroke, getGridStroke } from '@/components/charts/chart-config'
import type { DailyCost } from '@/types/admin'

interface CostTrendChartProps {
  data: DailyCost[]
}

export function CostTrendChart({ data }: CostTrendChartProps) {
  const { resolvedTheme } = useTheme()
  const isDark = resolvedTheme === 'dark'

  // Format data for chart
  const chartData = data.map((item) => ({
    date: format(new Date(item.date), 'MMM dd'),
    cost: item.total_cost_usd,
    operations: item.operations,
  }))

  return (
    <div className="rounded-lg bg-white p-6 shadow-md dark:bg-gray-800 dark:shadow-gray-900">
      <h2 className="mb-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
        Daily Cost Trend
      </h2>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke={getGridStroke(isDark)} />
          <XAxis
            dataKey="date"
            stroke={getAxisStroke(isDark)}
            fontSize={12}
            tickLine={false}
          />
          <YAxis
            stroke={getAxisStroke(isDark)}
            fontSize={12}
            tickLine={false}
            tickFormatter={(value) => `$${value.toFixed(2)}`}
          />
          <Tooltip
            contentStyle={getTooltipStyle(isDark)}
            formatter={(value: number | undefined) =>
              value !== undefined ? [formatCurrency(value), 'Cost'] : ['N/A', 'Cost']
            }
            labelStyle={{ color: isDark ? '#D1D5DB' : '#374151', fontWeight: 600 }}
          />
          <Legend
            wrapperStyle={{ paddingTop: '20px' }}
            iconType="line"
          />
          <Line
            type="monotone"
            dataKey="cost"
            stroke="#6A4FB6"
            strokeWidth={2}
            dot={{ fill: '#6A4FB6', r: 4 }}
            activeDot={{ r: 6 }}
            name="Daily Cost"
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
