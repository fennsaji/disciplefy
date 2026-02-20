'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { StatsCard } from '@/components/ui/stats-card'
import AchievementsTable from '@/components/tables/achievements-table'
import UserAchievementsTable from '@/components/tables/user-achievements-table'
import StreaksTable from '@/components/tables/streaks-table'
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip, BarChart, Bar, XAxis, YAxis, CartesianGrid } from 'recharts'
import { useTheme } from '@/components/theme-provider'
import { CHART_COLORS, getTooltipStyle, getAxisStroke, getGridStroke } from '@/components/charts/chart-config'
import { TabNav } from '@/components/ui/tab-nav'
import { PageHeader } from '@/components/ui/page-header'

type TabType = 'achievements-catalog' | 'user-achievements' | 'streak-analytics'

const GAMIFICATION_TABS = [
  { value: 'achievements-catalog', label: 'Achievements Catalog', icon: '🏆' },
  { value: 'user-achievements', label: 'User Achievements', icon: '🎯' },
  { value: 'streak-analytics', label: 'Streak Analytics', icon: '🔥' },
]

export default function GamificationPage() {
  const [activeTab, setActiveTab] = useState<TabType>('achievements-catalog')
  const queryClient = useQueryClient()
  const { resolvedTheme } = useTheme()
  const isDark = resolvedTheme === 'dark'

  // Filters
  const [achievementsFilters, setAchievementsFilters] = useState({
    category: '',
  })

  const [userAchievementsFilters, setUserAchievementsFilters] = useState({
    user_id: '',
    achievement_id: '',
  })

  const [streaksSort, setStreaksSort] = useState('current_streak')

  // Fetch Achievements Catalog
  const { data: achievementsData, isLoading: achievementsLoading } = useQuery({
    queryKey: ['gamification-achievements', achievementsFilters],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (achievementsFilters.category) params.set('category', achievementsFilters.category)

      const res = await fetch(`/api/admin/gamification/achievements?${params}`)
      if (!res.ok) throw new Error('Failed to fetch achievements')
      return res.json()
    },
    enabled: activeTab === 'achievements-catalog'
  })

  // Fetch User Achievements
  const { data: userAchievementsData, isLoading: userAchievementsLoading } = useQuery({
    queryKey: ['gamification-user-achievements', userAchievementsFilters],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (userAchievementsFilters.user_id) params.set('user_id', userAchievementsFilters.user_id)
      if (userAchievementsFilters.achievement_id) params.set('achievement_id', userAchievementsFilters.achievement_id)

      const res = await fetch(`/api/admin/gamification/user-achievements?${params}`)
      if (!res.ok) throw new Error('Failed to fetch user achievements')
      return res.json()
    },
    enabled: activeTab === 'user-achievements'
  })

  // Fetch Streak Analytics
  const { data: streaksData, isLoading: streaksLoading } = useQuery({
    queryKey: ['gamification-streaks', streaksSort],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set('sort_by', streaksSort)

      const res = await fetch(`/api/admin/gamification/streaks?${params}`)
      if (!res.ok) throw new Error('Failed to fetch streaks')
      return res.json()
    },
    enabled: activeTab === 'streak-analytics'
  })

  // Delete Achievement
  const deleteAchievement = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/admin/gamification/achievements?id=${id}`, {
        method: 'DELETE',
      })
      if (!res.ok) throw new Error('Failed to delete achievement')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gamification-achievements'] })
      toast.success('Achievement deleted successfully')
    },
    onError: () => {
      toast.error('Failed to delete achievement')
    }
  })

  // Revoke User Achievement
  const revokeUserAchievement = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/admin/gamification/user-achievements?id=${id}`, {
        method: 'DELETE',
      })
      if (!res.ok) throw new Error('Failed to revoke achievement')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gamification-user-achievements'] })
      toast.success('Achievement revoked successfully')
    },
    onError: () => {
      toast.error('Failed to revoke achievement')
    }
  })

  // Render Achievements Catalog Tab
  const renderAchievementsCatalogTab = () => {
    const stats = achievementsData?.stats
    const COLORS = ['#8B5CF6', '#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#EC4899']

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Achievements"
              value={stats.total}
              icon="🏆"
              trend={undefined}
            />
            <StatsCard
              title="Total Unlocks"
              value={stats.total_unlocks}
              icon="✅"
              trend={undefined}
            />
            <StatsCard
              title="Study Achievements"
              value={stats.by_category?.study || 0}
              icon="📚"
              trend={undefined}
            />
            <StatsCard
              title="Streak Achievements"
              value={stats.by_category?.streak || 0}
              icon="🔥"
              trend={undefined}
            />
          </div>
        )}

        {/* Charts */}
        {stats && Object.keys(stats.by_category || {}).length > 0 && (
          <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Achievements by Category
            </h3>
            <ResponsiveContainer width="100%" height={250}>
              <PieChart>
                <Pie
                  data={Object.entries(stats.by_category).map(([name, value]) => ({ name, value }))}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name}: ${((percent ?? 0) * 100).toFixed(0)}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {Object.keys(stats.by_category).map((_, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip contentStyle={getTooltipStyle(isDark)} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* Filters */}
        <div className="flex flex-wrap gap-4">
          <select
            value={achievementsFilters.category}
            onChange={(e) => setAchievementsFilters({ ...achievementsFilters, category: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Categories</option>
            <option value="study">Study</option>
            <option value="memory">Memory</option>
            <option value="streak">Streak</option>
            <option value="voice">Voice</option>
            <option value="saved">Saved</option>
          </select>
        </div>

        {/* Table */}
        <div className="rounded-lg bg-white shadow-sm dark:bg-gray-800">
          {achievementsLoading ? (
            <div className="text-center py-12">
              <p className="text-gray-500 dark:text-gray-400">Loading...</p>
            </div>
          ) : (
            <AchievementsTable
              achievements={achievementsData?.achievements || []}
              onEdit={(achievement) => {
                toast.info('Edit functionality to be implemented')
              }}
              onDelete={(id) => deleteAchievement.mutate(id)}
            />
          )}
        </div>
      </div>
    )
  }

  // Render User Achievements Tab
  const renderUserAchievementsTab = () => {
    const stats = userAchievementsData?.stats
    const COLORS = ['#8B5CF6', '#3B82F6', '#10B981', '#F59E0B', '#EF4444']

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Unlocks"
              value={stats.total_unlocks}
              icon="🎯"
              trend={undefined}
            />
            <StatsCard
              title="Unique Users"
              value={stats.unique_users}
              icon="👥"
              trend={undefined}
            />
            <StatsCard
              title="Unique Achievements"
              value={stats.unique_achievements}
              icon="🏆"
              trend={undefined}
            />
            <StatsCard
              title="Total XP Awarded"
              value={stats.total_xp_awarded?.toLocaleString() || 0}
              icon="⭐"
              trend={undefined}
            />
          </div>
        )}

        {/* Charts */}
        {stats && Object.keys(stats.by_category || {}).length > 0 && (
          <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Unlocks by Category
            </h3>
            <ResponsiveContainer width="100%" height={250}>
              <PieChart>
                <Pie
                  data={Object.entries(stats.by_category).map(([name, value]) => ({ name, value }))}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name}: ${((percent ?? 0) * 100).toFixed(0)}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {Object.keys(stats.by_category).map((_, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip contentStyle={getTooltipStyle(isDark)} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* Table */}
        <div className="rounded-lg bg-white shadow-sm dark:bg-gray-800">
          {userAchievementsLoading ? (
            <div className="text-center py-12">
              <p className="text-gray-500 dark:text-gray-400">Loading...</p>
            </div>
          ) : (
            <UserAchievementsTable
              userAchievements={userAchievementsData?.user_achievements || []}
              onRevoke={(id) => revokeUserAchievement.mutate(id)}
            />
          )}
        </div>
      </div>
    )
  }

  // Render Streak Analytics Tab
  const renderStreakAnalyticsTab = () => {
    const stats = streaksData?.stats
    const leaderboards = streaksData?.leaderboards

    return (
      <div className="space-y-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatsCard
              title="Total Users"
              value={stats.total_users}
              icon="👥"
              trend={undefined}
            />
            <StatsCard
              title="Active Study Streakers"
              value={`${stats.active_streakers} / ${stats.users_with_study_streak}`}
              icon="🔥"
              trend={undefined}
            />
            <StatsCard
              title="Active Verse Streakers"
              value={`${stats.active_verse_streakers} / ${stats.users_with_verse_streak}`}
              icon="📖"
              trend={undefined}
            />
            <StatsCard
              title="Max Streak Record"
              value={`${stats.max_longest_streak} days`}
              icon="🏅"
              trend={undefined}
            />
          </div>
        )}

        {/* Streak Distribution Chart */}
        {stats && (
          <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Study Streak Distribution
            </h3>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={Object.entries(stats.streak_distribution).map(([name, value]) => ({
                name,
                value
              }))}>
                <CartesianGrid strokeDasharray="3 3" stroke={getGridStroke(isDark)} />
                <XAxis dataKey="name" stroke={getAxisStroke(isDark)} />
                <YAxis stroke={getAxisStroke(isDark)} />
                <Tooltip contentStyle={getTooltipStyle(isDark)} />
                <Bar dataKey="value" fill="#10B981" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* Leaderboards */}
        {leaderboards && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {/* Top Current Study Streaks */}
            <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                🔥 Top Study Streaks
              </h3>
              <div className="space-y-3">
                {leaderboards.top_current_streaks?.length > 0
                  ? leaderboards.top_current_streaks.slice(0, 5).map((streak: any, index: number) => (
                    <div key={streak.id} className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-bold text-primary">#{index + 1}</span>
                        <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                          {streak.user_name}
                        </div>
                      </div>
                      <span className="text-lg font-bold text-primary">
                        {streak.current_streak}d
                      </span>
                    </div>
                  ))
                  : <p className="text-sm text-gray-400">No study streaks yet</p>
                }
              </div>
            </div>

            {/* Top Longest Streaks */}
            <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                🏅 Best Ever Streaks
              </h3>
              <div className="space-y-3">
                {leaderboards.top_longest_streaks?.length > 0
                  ? leaderboards.top_longest_streaks.slice(0, 5).map((streak: any, index: number) => (
                    <div key={streak.id} className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-bold text-yellow-600">#{index + 1}</span>
                        <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                          {streak.user_name}
                        </div>
                      </div>
                      <span className="text-lg font-bold text-yellow-600">
                        {streak.longest_streak}d
                      </span>
                    </div>
                  ))
                  : <p className="text-sm text-gray-400">No data yet</p>
                }
              </div>
            </div>

            {/* Top Daily Verse Streaks */}
            <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                📖 Top Verse Streaks
              </h3>
              <div className="space-y-3">
                {leaderboards.top_verse_streaks?.length > 0
                  ? leaderboards.top_verse_streaks.slice(0, 5).map((streak: any, index: number) => (
                    <div key={streak.user_id} className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-bold text-blue-600">#{index + 1}</span>
                        <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                          {streak.user_name}
                        </div>
                      </div>
                      <span className="text-lg font-bold text-blue-600">
                        {streak.current_streak}d
                      </span>
                    </div>
                  ))
                  : <p className="text-sm text-gray-400">No verse streaks yet</p>
                }
              </div>
            </div>

            {/* Top XP Earners */}
            <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                ⭐ Top XP Earners
              </h3>
              <div className="space-y-3">
                {leaderboards.top_xp_earners?.length > 0
                  ? leaderboards.top_xp_earners.slice(0, 5).map((entry: any, index: number) => (
                    <div key={entry.id} className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-bold text-purple-600">#{index + 1}</span>
                        <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                          {entry.user_name}
                        </div>
                      </div>
                      <span className="text-sm font-bold text-purple-600">
                        {entry.total_xp_earned?.toLocaleString() || 0} XP
                      </span>
                    </div>
                  ))
                  : <p className="text-sm text-gray-400">No XP earned yet</p>
                }
              </div>
            </div>
          </div>
        )}

        {/* Sort Control */}
        <div className="flex items-center gap-4">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Sort study streaks by:
          </label>
          <select
            value={streaksSort}
            onChange={(e) => setStreaksSort(e.target.value)}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="current_streak">Current Streak</option>
            <option value="longest_streak">Longest Streak</option>
            <option value="total_study_days">Total Study Days</option>
            <option value="last_study_date">Last Study Date</option>
          </select>
        </div>

        {/* Table */}
        <div className="rounded-lg bg-white shadow-sm dark:bg-gray-800">
          {streaksLoading ? (
            <div className="text-center py-12">
              <p className="text-gray-500 dark:text-gray-400">Loading...</p>
            </div>
          ) : (
            <StreaksTable streaks={streaksData?.streaks || []} />
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Gamification Manager"
        description="Manage achievements, track user progress, and analyze engagement"
      />
      <TabNav
        tabs={GAMIFICATION_TABS}
        activeTab={activeTab}
        onChange={(v) => setActiveTab(v as TabType)}
      />

      {/* Tab Content */}
      {activeTab === 'achievements-catalog' && renderAchievementsCatalogTab()}
      {activeTab === 'user-achievements' && renderUserAchievementsTab()}
      {activeTab === 'streak-analytics' && renderStreakAnalyticsTab()}
    </div>
  )
}
