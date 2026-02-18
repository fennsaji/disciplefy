'use client'

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { PageHeader } from '@/components/ui/page-header'
import { DateRangePicker } from '@/components/ui/date-range-picker'
import { StatsCard } from '@/components/ui/stats-card'
import { CostTrendChart } from '@/components/charts/cost-trend-chart'
import { BreakdownTables } from '@/components/tables/breakdown-tables'
import { fetchUsageAnalytics } from '@/lib/api/admin'
import { getDateRangePreset, formatCurrency, formatCompactNumber, formatDateForAPI } from '@/lib/utils/date'
import type { DateRange } from '@/lib/utils/date'
import { LoadingState } from '@/components/ui/loading-spinner'
import { EmptyState, ErrorState } from '@/components/ui/empty-state'

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
      <PageHeader
        title="LLM Cost Analytics"
        description="Monitor and analyze LLM API usage and costs across all users and tiers"
      />

      {/* Date Range Picker */}
      <DateRangePicker value={dateRange} onChange={setDateRange} />

      {/* Error State */}
      {error && (
        <ErrorState title="Error loading analytics data" message={error instanceof Error ? error.message : 'Unknown error'} />
      )}

      {/* Loading State */}
      {isLoading && <LoadingState label="Loading analytics data..." />}

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
        <EmptyState title="No data available" description="No LLM operations found for the selected date range." icon="📭" />
      )}
    </div>
  )
}
