'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { StatsCard } from '@/components/ui/stats-card'
import StudyGuidesTable from '@/components/tables/study-guides-table'
import DailyVersesTable from '@/components/tables/daily-verses-table'
import SuggestedVersesTable from '@/components/tables/suggested-verses-table'

type TabType = 'study-guides' | 'daily-verses' | 'suggested-verses'

export default function ContentManagementPage() {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<TabType>('study-guides')
  const queryClient = useQueryClient()

  // Filters
  const [studyGuidesFilters, setStudyGuidesFilters] = useState({
    input_type: '',
    study_mode: '',
    language: '',
  })

  const [dailyVersesFilters, setDailyVersesFilters] = useState({
    language: '',
    is_active: '',
  })

  const [suggestedVersesFilters, setSuggestedVersesFilters] = useState({
    category: '',
    language: '',
  })

  // Fetch Study Guides
  const { data: studyGuidesData, isLoading: studyGuidesLoading } = useQuery({
    queryKey: ['content-study-guides', studyGuidesFilters],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (studyGuidesFilters.input_type) params.set('input_type', studyGuidesFilters.input_type)
      if (studyGuidesFilters.study_mode) params.set('study_mode', studyGuidesFilters.study_mode)
      if (studyGuidesFilters.language) params.set('language', studyGuidesFilters.language)

      const res = await fetch(`/api/admin/content/study-guides?${params}`)
      if (!res.ok) throw new Error('Failed to fetch study guides')
      return res.json()
    },
    enabled: activeTab === 'study-guides'
  })

  // Fetch Daily Verses
  const { data: dailyVersesData, isLoading: dailyVersesLoading } = useQuery({
    queryKey: ['content-daily-verses', dailyVersesFilters],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (dailyVersesFilters.language) params.set('language', dailyVersesFilters.language)
      if (dailyVersesFilters.is_active) params.set('is_active', dailyVersesFilters.is_active)

      const res = await fetch(`/api/admin/content/daily-verses?${params}`)
      if (!res.ok) throw new Error('Failed to fetch daily verses')
      return res.json()
    },
    enabled: activeTab === 'daily-verses'
  })

  // Fetch Suggested Verses
  const { data: suggestedVersesData, isLoading: suggestedVersesLoading } = useQuery({
    queryKey: ['content-suggested-verses', suggestedVersesFilters],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (suggestedVersesFilters.category) params.set('category', suggestedVersesFilters.category)
      if (suggestedVersesFilters.language) params.set('language', suggestedVersesFilters.language)

      const res = await fetch(`/api/admin/content/suggested-verses?${params}`)
      if (!res.ok) throw new Error('Failed to fetch suggested verses')
      return res.json()
    },
    enabled: activeTab === 'suggested-verses'
  })

  // Delete Study Guide
  const deleteStudyGuide = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/admin/content/study-guides?id=${id}`, {
        method: 'DELETE',
      })
      if (!res.ok) throw new Error('Failed to delete study guide')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['content-study-guides'] })
      toast.success('Study guide deleted successfully')
    },
    onError: () => {
      toast.error('Failed to delete study guide')
    }
  })

  // Toggle Daily Verse Active Status
  const toggleDailyVerseActive = useMutation({
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
    }
  })

  // Delete Daily Verse
  const deleteDailyVerse = useMutation({
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
    }
  })

  // Delete Suggested Verse
  const deleteSuggestedVerse = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/admin/content/suggested-verses?id=${id}`, {
        method: 'DELETE',
      })
      if (!res.ok) throw new Error('Failed to delete suggested verse')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['content-suggested-verses'] })
      toast.success('Suggested verse deleted successfully')
    },
    onError: () => {
      toast.error('Failed to delete suggested verse')
    }
  })

  // Render Study Guides Tab
  const renderStudyGuidesTab = () => {
    const stats = studyGuidesData?.stats

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Study Guides"
              value={stats.total}
              icon="📚"
              trend={undefined}
            />
            <StatsCard
              title="Verse Guides"
              value={stats.by_input_type?.verse || 0}
              icon="📖"
              trend={undefined}
            />
            <StatsCard
              title="Topic Guides"
              value={stats.by_input_type?.topic || 0}
              icon="💭"
              trend={undefined}
            />
            <StatsCard
              title="Passage Guides"
              value={stats.by_input_type?.passage || 0}
              icon="📜"
              trend={undefined}
            />
          </div>
        )}

        {/* Filters */}
        <div className="flex flex-wrap gap-4">
          <select
            value={studyGuidesFilters.input_type}
            onChange={(e) => setStudyGuidesFilters({ ...studyGuidesFilters, input_type: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Input Types</option>
            <option value="verse">Verse</option>
            <option value="topic">Topic</option>
            <option value="passage">Passage</option>
            <option value="question">Question</option>
          </select>

          <select
            value={studyGuidesFilters.study_mode}
            onChange={(e) => setStudyGuidesFilters({ ...studyGuidesFilters, study_mode: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Study Modes</option>
            <option value="standard">Standard</option>
            <option value="deep">Deep</option>
            <option value="lectio">Lectio Divina</option>
            <option value="sermon">Sermon</option>
            <option value="recommended">Recommended</option>
          </select>

          <select
            value={studyGuidesFilters.language}
            onChange={(e) => setStudyGuidesFilters({ ...studyGuidesFilters, language: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Languages</option>
            <option value="en">English</option>
            <option value="hi">Hindi</option>
            <option value="ml">Malayalam</option>
          </select>
        </div>

        {/* Table */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
          {studyGuidesLoading ? (
            <div className="text-center py-12">
              <p className="text-gray-500 dark:text-gray-400">Loading...</p>
            </div>
          ) : (
            <StudyGuidesTable
              guides={studyGuidesData?.study_guides || []}
              onEdit={(guide) => {
                // Build URL with pre-filled parameters
                const params = new URLSearchParams()
                params.set('input_type', guide.input_type)
                params.set('input_value', guide.input_value)
                if (guide.study_mode) params.set('study_mode', guide.study_mode)
                params.set('language', guide.language)

                // Redirect to study generator with pre-filled values
                router.push(`/study-generator?${params.toString()}`)
              }}
              onDelete={(id) => deleteStudyGuide.mutate(id)}
            />
          )}
        </div>
      </div>
    )
  }

  // Render Daily Verses Tab
  const renderDailyVersesTab = () => {
    const stats = dailyVersesData?.stats

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Verses"
              value={stats.total}
              icon="📅"
              trend={undefined}
            />
            <StatsCard
              title="Active Verses"
              value={stats.active}
              icon="✅"
              trend={undefined}
            />
            <StatsCard
              title="Upcoming"
              value={stats.upcoming_count}
              icon="⏭️"
              trend={undefined}
            />
            <StatsCard
              title="Past"
              value={stats.past_count}
              icon="⏮️"
              trend={undefined}
            />
          </div>
        )}

        {/* Filters */}
        <div className="flex flex-wrap gap-4">
          <select
            value={dailyVersesFilters.language}
            onChange={(e) => setDailyVersesFilters({ ...dailyVersesFilters, language: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Languages</option>
            <option value="en">English</option>
            <option value="hi">Hindi</option>
            <option value="ml">Malayalam</option>
          </select>

          <select
            value={dailyVersesFilters.is_active}
            onChange={(e) => setDailyVersesFilters({ ...dailyVersesFilters, is_active: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Status</option>
            <option value="true">Active</option>
            <option value="false">Inactive</option>
          </select>
        </div>

        {/* Current Active Verses */}
        {dailyVersesData?.active_verses && dailyVersesData.active_verses.length > 0 && (
          <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4">
            <h3 className="text-lg font-semibold text-green-900 dark:text-green-100 mb-3">
              🌟 Current Active Verses
            </h3>
            <div className="space-y-2">
              {dailyVersesData.active_verses.map((verse: any) => (
                <div key={verse.id} className="flex items-center justify-between bg-white dark:bg-gray-800 rounded p-3">
                  <div>
                    <span className="font-semibold text-gray-900 dark:text-gray-100">
                      {verse.language?.toUpperCase() || 'N/A'}:
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
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
          {dailyVersesLoading ? (
            <div className="text-center py-12">
              <p className="text-gray-500 dark:text-gray-400">Loading...</p>
            </div>
          ) : (
            <DailyVersesTable
              verses={dailyVersesData?.daily_verses || []}
              onToggleActive={(id, is_active) => toggleDailyVerseActive.mutate({ id, is_active })}
              onDelete={(id) => deleteDailyVerse.mutate(id)}
            />
          )}
        </div>
      </div>
    )
  }

  // Render Suggested Verses Tab
  const renderSuggestedVersesTab = () => {
    const stats = suggestedVersesData?.stats

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Verses"
              value={stats.total}
              icon="⭐"
              trend={undefined}
            />
            <StatsCard
              title="English"
              value={stats.translation_coverage?.en || 0}
              icon="🇺🇸"
              trend={undefined}
            />
            <StatsCard
              title="Hindi"
              value={stats.translation_coverage?.hi || 0}
              icon="🇮🇳"
              trend={undefined}
            />
            <StatsCard
              title="Malayalam"
              value={stats.translation_coverage?.ml || 0}
              icon="🇮🇳"
              trend={undefined}
            />
          </div>
        )}

        {/* Category Breakdown */}
        {stats?.by_category && Object.keys(stats.by_category).length > 0 && (
          <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Category Breakdown
            </h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {Object.entries(stats.by_category).map(([category, count]) => (
                <div key={category} className="text-center">
                  <div className="text-2xl font-bold text-primary">{count as number}</div>
                  <div className="text-sm text-gray-600 dark:text-gray-400 capitalize">{category}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Filters */}
        <div className="flex flex-wrap gap-4">
          <select
            value={suggestedVersesFilters.category}
            onChange={(e) => setSuggestedVersesFilters({ ...suggestedVersesFilters, category: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Categories</option>
            <option value="salvation">Salvation</option>
            <option value="comfort">Comfort</option>
            <option value="strength">Strength</option>
            <option value="wisdom">Wisdom</option>
            <option value="promise">Promise</option>
            <option value="guidance">Guidance</option>
            <option value="faith">Faith</option>
            <option value="love">Love</option>
          </select>

          <select
            value={suggestedVersesFilters.language}
            onChange={(e) => setSuggestedVersesFilters({ ...suggestedVersesFilters, language: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Languages</option>
            <option value="en">English</option>
            <option value="hi">Hindi</option>
            <option value="ml">Malayalam</option>
          </select>
        </div>

        {/* Table */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
          {suggestedVersesLoading ? (
            <div className="text-center py-12">
              <p className="text-gray-500 dark:text-gray-400">Loading...</p>
            </div>
          ) : (
            <SuggestedVersesTable
              verses={suggestedVersesData?.suggested_verses || []}
              onEdit={(verse) => {
                toast.info('Edit functionality to be implemented')
              }}
              onDelete={(id) => deleteSuggestedVerse.mutate(id)}
            />
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">
          Content Management
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mt-1">
          Manage study guides, daily verses, and suggested verses
        </p>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200 dark:border-gray-700">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('study-guides')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'study-guides'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            📚 Study Guides Library
          </button>
          <button
            onClick={() => setActiveTab('daily-verses')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'daily-verses'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            📅 Daily Verses Manager
          </button>
          <button
            onClick={() => setActiveTab('suggested-verses')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'suggested-verses'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            ⭐ Suggested Verses Curator
          </button>
        </nav>
      </div>

      {/* Tab Content */}
      {activeTab === 'study-guides' && renderStudyGuidesTab()}
      {activeTab === 'daily-verses' && renderDailyVersesTab()}
      {activeTab === 'suggested-verses' && renderSuggestedVersesTab()}
    </div>
  )
}
