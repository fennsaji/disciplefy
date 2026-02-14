'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { StatsCard } from '@/components/ui/stats-card'
import AchievementsTable from '@/components/tables/achievements-table'
import UserAchievementsTable from '@/components/tables/user-achievements-table'
import StreaksTable from '@/components/tables/streaks-table'
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip, BarChart, Bar, XAxis, YAxis, CartesianGrid } from 'recharts'

type TabType = 'achievements-catalog' | 'user-achievements' | 'streak-analytics'

export default function GamificationPage() {
  const [activeTab, setActiveTab] = useState<TabType>('achievements-catalog')
  const queryClient = useQueryClient()

  // Filters
  const [achievementsFilters, setAchievementsFilters] = useState({
    category: '',
    type: '',
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
      if (achievementsFilters.type) params.set('type', achievementsFilters.type)

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
        {stats && (Object.keys(stats.by_category).length > 0 || Object.keys(stats.by_tier).length > 0) && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Category Distribution */}
            {Object.keys(stats.by_category).length > 0 && (
              <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
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
                      label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {Object.keys(stats.by_category).map((_, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip contentStyle={{ backgroundColor: '#1F2937', borderRadius: '8px' }} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Tier Distribution */}
            {Object.keys(stats.by_tier).length > 0 && (
              <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                  Achievements by Tier
                </h3>
                <ResponsiveContainer width="100%" height={250}>
                  <BarChart data={Object.entries(stats.by_tier).map(([name, value]) => ({ name, value }))}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                    <XAxis dataKey="name" stroke="#9CA3AF" />
                    <YAxis stroke="#9CA3AF" />
                    <Tooltip contentStyle={{ backgroundColor: '#1F2937', borderRadius: '8px' }} />
                    <Bar dataKey="value" fill="#8B5CF6" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
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
            <option value="learning_path">Learning Path</option>
            <option value="engagement">Engagement</option>
          </select>

          <select
            value={achievementsFilters.type}
            onChange={(e) => setAchievementsFilters({ ...achievementsFilters, type: e.target.value })}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="">All Types</option>
            <option value="milestone">Milestone</option>
            <option value="streak">Streak</option>
            <option value="completion">Completion</option>
            <option value="proficiency">Proficiency</option>
          </select>
        </div>

        {/* Table */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
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
        {stats && (Object.keys(stats.by_category || {}).length > 0 || Object.keys(stats.by_tier || {}).length > 0) && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Category Distribution */}
            {Object.keys(stats.by_category || {}).length > 0 && (
              <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
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
                      label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {Object.keys(stats.by_category).map((_, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip contentStyle={{ backgroundColor: '#1F2937', borderRadius: '8px' }} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Tier Distribution */}
            {Object.keys(stats.by_tier || {}).length > 0 && (
              <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                  Unlocks by Tier
                </h3>
                <ResponsiveContainer width="100%" height={250}>
                  <BarChart data={Object.entries(stats.by_tier).map(([name, value]) => ({ name, value }))}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                    <XAxis dataKey="name" stroke="#9CA3AF" />
                    <YAxis stroke="#9CA3AF" />
                    <Tooltip contentStyle={{ backgroundColor: '#1F2937', borderRadius: '8px' }} />
                    <Bar dataKey="value" fill="#3B82F6" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
          </div>
        )}

        {/* Table */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
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
              title="Active Streakers"
              value={stats.active_streakers}
              icon="🔥"
              trend={undefined}
            />
            <StatsCard
              title="Avg Current Streak"
              value={`${stats.avg_current_streak} days`}
              icon="📊"
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
          <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Streak Distribution
            </h3>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={Object.entries(stats.streak_distribution).map(([name, value]) => ({
                name: name.replace('_', ' '),
                value
              }))}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis dataKey="name" stroke="#9CA3AF" />
                <YAxis stroke="#9CA3AF" />
                <Tooltip contentStyle={{ backgroundColor: '#1F2937', borderRadius: '8px' }} />
                <Bar dataKey="value" fill="#10B981" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* Leaderboards */}
        {leaderboards && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Top Current Streaks */}
            <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                🔥 Top Current Streaks
              </h3>
              <div className="space-y-3">
                {leaderboards.top_current_streaks?.slice(0, 5).map((streak: any, index: number) => (
                  <div key={streak.id} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-lg font-bold text-primary">#{index + 1}</span>
                      <div className="text-sm">
                        <div className="font-medium text-gray-900 dark:text-gray-100">
                          {streak.user_name}
                        </div>
                      </div>
                    </div>
                    <span className="text-lg font-bold text-primary">
                      {streak.current_streak} days
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Top Longest Streaks */}
            <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                🏅 Top Longest Streaks
              </h3>
              <div className="space-y-3">
                {leaderboards.top_longest_streaks?.slice(0, 5).map((streak: any, index: number) => (
                  <div key={streak.id} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-lg font-bold text-yellow-600">#{index + 1}</span>
                      <div className="text-sm">
                        <div className="font-medium text-gray-900 dark:text-gray-100">
                          {streak.user_name}
                        </div>
                      </div>
                    </div>
                    <span className="text-lg font-bold text-yellow-600">
                      {streak.longest_streak} days
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Top XP Earners */}
            <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                ⭐ Top XP Earners
              </h3>
              <div className="space-y-3">
                {leaderboards.top_xp_earners?.slice(0, 5).map((streak: any, index: number) => (
                  <div key={streak.id} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-lg font-bold text-purple-600">#{index + 1}</span>
                      <div className="text-sm">
                        <div className="font-medium text-gray-900 dark:text-gray-100">
                          {streak.user_name}
                        </div>
                      </div>
                    </div>
                    <span className="text-sm font-bold text-purple-600">
                      {streak.total_xp_earned?.toLocaleString() || 0} XP
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Sort Control */}
        <div className="flex items-center gap-4">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Sort by:
          </label>
          <select
            value={streaksSort}
            onChange={(e) => setStreaksSort(e.target.value)}
            className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
            <option value="current_streak">Current Streak</option>
            <option value="longest_streak">Longest Streak</option>
            <option value="total_xp_earned">Total XP</option>
            <option value="last_study_date">Last Study Date</option>
          </select>
        </div>

        {/* Table */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
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
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">
          Gamification Manager
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mt-1">
          Manage achievements, track user progress, and analyze engagement
        </p>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200 dark:border-gray-700">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('achievements-catalog')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'achievements-catalog'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            🏆 Achievements Catalog
          </button>
          <button
            onClick={() => setActiveTab('user-achievements')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'user-achievements'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            🎯 User Achievements
          </button>
          <button
            onClick={() => setActiveTab('streak-analytics')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'streak-analytics'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300'
            }`}
          >
            🔥 Streak Analytics
          </button>
        </nav>
      </div>

      {/* Tab Content */}
      {activeTab === 'achievements-catalog' && renderAchievementsCatalogTab()}
      {activeTab === 'user-achievements' && renderUserAchievementsTab()}
      {activeTab === 'streak-analytics' && renderStreakAnalyticsTab()}
    </div>
  )
}
