'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { StatsCard } from '@/components/ui/stats-card'
import DailyVersesTable from '@/components/tables/daily-verses-table'
import { PageHeader } from '@/components/ui/page-header'

export default function ContentManagementPage() {
  const queryClient = useQueryClient()

  const [filters, setFilters] = useState({
    language: '',
    is_active: '',
  })

  const { data, isLoading } = useQuery({
    queryKey: ['content-daily-verses', filters],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (filters.language) params.set('language', filters.language)
      if (filters.is_active) params.set('is_active', filters.is_active)

      const res = await fetch(`/api/admin/content/daily-verses?${params}`)
      if (!res.ok) throw new Error('Failed to fetch daily verses')
      return res.json()
    },
  })

  const toggleActive = useMutation({
    mutationFn: async ({ id, is_active }: { id: string; is_active: boolean }) => {
      const res = await fetch('/api/admin/content/daily-verses', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, is_active }),
      })
      if (!res.ok) throw new Error('Failed to update daily verse')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['content-daily-verses'] })
      toast.success('Daily verse updated successfully')
    },
    onError: () => {
      toast.error('Failed to update daily verse')
    },
  })

  const deleteVerse = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/admin/content/daily-verses?id=${id}`, {
        method: 'DELETE',
      })
      if (!res.ok) throw new Error('Failed to delete daily verse')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['content-daily-verses'] })
      toast.success('Daily verse deleted successfully')
    },
    onError: () => {
      toast.error('Failed to delete daily verse')
    },
  })

  const stats = data?.stats

  return (
    <div className="space-y-6">
      <PageHeader
        title="Daily Verses"
        description="Manage daily verses"
      />

      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <StatsCard title="Total Verses" value={stats.total} icon="📅" trend={undefined} />
          <StatsCard title="Active Verses" value={stats.active} icon="✅" trend={undefined} />
          <StatsCard title="Upcoming" value={stats.upcoming_count} icon="⏭️" trend={undefined} />
          <StatsCard title="Past" value={stats.past_count} icon="⏮️" trend={undefined} />
        </div>
      )}

      {/* Filters */}
      <div className="flex flex-wrap gap-4">
        <select
          value={filters.language}
          onChange={(e) => setFilters({ ...filters, language: e.target.value })}
          className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
        >
          <option value="">All Languages</option>
          <option value="en">English</option>
          <option value="hi">Hindi</option>
          <option value="ml">Malayalam</option>
        </select>

        <select
          value={filters.is_active}
          onChange={(e) => setFilters({ ...filters, is_active: e.target.value })}
          className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
        >
          <option value="">All Status</option>
          <option value="true">Active</option>
          <option value="false">Inactive</option>
        </select>
      </div>

      {/* Current Active Verses */}
      {data?.active_verses && data.active_verses.length > 0 && (
        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4">
          <h3 className="text-lg font-semibold text-green-900 dark:text-green-100 mb-3">
            🌟 Current Active Verses
          </h3>
          <div className="space-y-2">
            {data.active_verses.map((verse: any) => (
              <div key={verse.id} className="flex items-center justify-between bg-white dark:bg-gray-800 rounded p-3">
                <div>
                  <span className="font-semibold text-gray-900 dark:text-gray-100">
                    {verse.language
                      ? verse.language.toUpperCase()
                      : Object.keys(verse.verse_data?.translations ?? {}).map((k: string) => k.toUpperCase()).join(' · ') || 'Multi'}:
                  </span>{' '}
                  <span className="text-gray-700 dark:text-gray-300">
                    {verse.verse_data?.reference || 'N/A'}
                  </span>
                </div>
                <span className="text-sm text-gray-500 dark:text-gray-400">
                  {new Date(verse.date_key).toLocaleDateString()}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Table */}
      <div className="rounded-lg bg-white shadow-sm dark:bg-gray-800">
        {isLoading ? (
          <div className="text-center py-12">
            <p className="text-gray-500 dark:text-gray-400">Loading...</p>
          </div>
        ) : (
          <DailyVersesTable
            verses={data?.daily_verses || []}
            onToggleActive={(id, is_active) => toggleActive.mutate({ id, is_active })}
            onDelete={(id) => deleteVerse.mutate(id)}
          />
        )}
      </div>
    </div>
  )
}
