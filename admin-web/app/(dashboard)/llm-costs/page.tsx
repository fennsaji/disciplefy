'use client'

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { DateRangePicker } from '@/components/ui/date-range-picker'
import { StatsCard } from '@/components/ui/stats-card'
import { CostTrendChart } from '@/components/charts/cost-trend-chart'
import { BreakdownTables } from '@/components/tables/breakdown-tables'
import { fetchUsageAnalytics } from '@/lib/api/admin'
import { getDateRangePreset, formatCurrency, formatCompactNumber, formatDateForAPI } from '@/lib/utils/date'
import type { DateRange } from '@/lib/utils/date'

export default function LLMCostsPage() {
  const [dateRange, setDateRange] = useState<DateRange>(
    getDateRangePreset('7days')
  )

  // Fetch usage analytics with React Query
  const { data, isLoading, error } = useQuery({
    queryKey: ['usage-analytics', dateRange],
    queryFn: () =>
      fetchUsageAnalytics({
        start_date: formatDateForAPI(dateRange.from),
        end_date: formatDateForAPI(dateRange.to),
      }),
    refetchInterval: 60000, // Refetch every minute
  })

  // Calculate top provider
  const topProvider = data?.by_provider
    ? Object.entries(data.by_provider).reduce((top, [provider, stats]) =>
        stats.cost_usd > (top.cost || 0) ? { name: provider, cost: stats.cost_usd } : top,
        { name: '', cost: 0 }
      ).name
    : '-'

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">LLM Cost Analytics</h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Monitor and analyze LLM API usage and costs across all users and tiers
          </p>
        </div>
      </div>

      {/* Date Range Picker */}
      <DateRangePicker value={dateRange} onChange={setDateRange} />

      {/* Error State */}
      {error && (
        <div className="rounded-lg bg-red-50 p-4 text-red-800 dark:bg-red-900/20 dark:text-red-300">
          <p className="font-medium">Error loading analytics data</p>
          <p className="mt-1 text-sm">{error instanceof Error ? error.message : 'Unknown error'}</p>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="flex items-center justify-center py-12">
          <div className="text-center">
            <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-primary border-r-transparent"></div>
            <p className="mt-4 text-gray-600 dark:text-gray-400">Loading analytics data...</p>
          </div>
        </div>
      )}

      {/* Stats Cards */}
      {data && (
        <>
          <div className="grid gap-6 md:grid-cols-4">
            <StatsCard
              title="Total Cost"
              value={formatCurrency(data.overview.total_llm_cost_usd)}
              subtitle={`${formatCompactNumber(data.overview.total_operations)} operations`}
              icon="💰"
            />
            <StatsCard
              title="Total Tokens"
              value={formatCompactNumber(data.overview.total_llm_tokens)}
              subtitle="Input + Output"
              icon="📊"
            />
            <StatsCard
              title="Avg Cost/Request"
              value={formatCurrency(data.overview.avg_cost_per_operation)}
              subtitle={`${data.overview.unique_users} unique users`}
              icon="📈"
            />
            <StatsCard
              title="Top Provider"
              value={topProvider === 'openai' ? 'OpenAI' : topProvider === 'anthropic' ? 'Anthropic' : topProvider}
              subtitle="By total cost"
              icon="🏆"
            />
          </div>

          {/* Cost Trend Chart */}
          {data.daily_costs && data.daily_costs.length > 0 && (
            <CostTrendChart data={data.daily_costs} />
          )}

          {/* Breakdown Tables */}
          <BreakdownTables
            byFeature={data.by_feature}
            byTier={data.by_tier}
            byProvider={data.by_provider}
            byModel={data.by_model}
          />
        </>
      )}

      {/* Empty State */}
      {!isLoading && !error && data && data.overview.total_operations === 0 && (
        <div className="rounded-lg bg-gray-50 p-12 text-center dark:bg-gray-800">
          <p className="text-lg font-medium text-gray-900 dark:text-gray-100">No data available</p>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            No LLM operations found for the selected date range.
          </p>
        </div>
      )}
    </div>
  )
}
