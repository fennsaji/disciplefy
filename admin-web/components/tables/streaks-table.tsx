'use client'

interface Streak {
  id: string
  user_id: string
  user_email: string
  user_name: string
  current_streak: number
  longest_streak: number
  total_study_days: number
  total_xp_earned: number
  last_study_date: string | null
  verse_streak: number
  created_at: string
}

interface StreaksTableProps {
  streaks: Streak[]
}

export default function StreaksTable({ streaks }: StreaksTableProps) {
  const getStudyStatus = (lastStudyDate: string | null) => {
    if (!lastStudyDate) {
      return { label: 'Never Started', color: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200' }
    }
    const daysDiff = Math.floor((Date.now() - new Date(lastStudyDate).getTime()) / (1000 * 60 * 60 * 24))
    if (daysDiff === 0) return { label: 'Active Today', color: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' }
    if (daysDiff === 1) return { label: 'At Risk', color: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200' }
    return { label: 'Broken', color: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200' }
  }

  const getStreakBadge = (days: number) => {
    if (days >= 100) return { icon: '💎', label: '100+ day streak' }
    if (days >= 30) return { icon: '🔥', label: '30+ day streak' }
    if (days >= 7) return { icon: '⚡', label: '7+ day streak' }
    return null
  }

  return (
    <div className="overflow-x-auto">
      {/* Table title row */}
      <div className="px-6 py-3 border-b border-gray-200 dark:border-gray-700 flex items-center gap-4 text-xs font-semibold text-gray-500 dark:text-gray-400">
        <span>📚 Study Guide Streaks — sorted by selected column</span>
      </div>

      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              User
            </th>

            {/* Study streak columns — grouped with a top label */}
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider">
              <div className="flex flex-col gap-0.5">
                <span className="text-blue-500 dark:text-blue-400">📚 Study Streak</span>
                <span className="text-gray-400 font-normal normal-case">Current / Best</span>
              </div>
            </th>

            {/* Verse streak column */}
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider">
              <div className="flex flex-col gap-0.5">
                <span className="text-purple-500 dark:text-purple-400">📖 Verse Streak</span>
                <span className="text-gray-400 font-normal normal-case">Daily verse</span>
              </div>
            </th>

            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Total XP
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Study Status
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Last Study Date
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
          {streaks.map((streak) => {
            const status = getStudyStatus(streak.last_study_date)
            const badge = getStreakBadge(streak.current_streak)

            return (
              <tr key={streak.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                {/* User */}
                <td className="px-6 py-4">
                  <div className="text-sm">
                    <div className="font-medium text-gray-900 dark:text-gray-100">{streak.user_name}</div>
                    <div className="text-gray-500 dark:text-gray-400 text-xs">{streak.user_email}</div>
                  </div>
                </td>

                {/* Study streak: current / best */}
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center gap-1.5">
                    <span className="text-2xl font-bold text-blue-600 dark:text-blue-400">
                      {streak.current_streak}
                    </span>
                    <span className="text-xs text-gray-400">d</span>
                    <span className="text-gray-300 dark:text-gray-600 mx-1">/</span>
                    <span className="text-sm font-semibold text-gray-500 dark:text-gray-400">
                      {streak.longest_streak}
                    </span>
                    <span className="text-xs text-gray-400">best</span>
                    {badge && (
                      <span title={badge.label} className="ml-1 text-base">{badge.icon}</span>
                    )}
                  </div>
                  <div className="text-xs text-gray-400 mt-0.5">
                    {streak.total_study_days} total study days
                  </div>
                </td>

                {/* Verse streak */}
                <td className="px-6 py-4 whitespace-nowrap">
                  {streak.verse_streak > 0 ? (
                    <div className="flex items-center gap-1.5">
                      <span className="text-2xl font-bold text-purple-600 dark:text-purple-400">
                        {streak.verse_streak}
                      </span>
                      <span className="text-xs text-gray-400">d</span>
                    </div>
                  ) : (
                    <span className="text-xs text-gray-400">—</span>
                  )}
                </td>

                {/* Total XP */}
                <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-green-600 dark:text-green-400">
                  {streak.total_xp_earned?.toLocaleString() || 0} XP
                </td>

                {/* Study status */}
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${status.color}`}>
                    {status.label}
                  </span>
                </td>

                {/* Last study date */}
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                  {streak.last_study_date
                    ? new Date(streak.last_study_date).toLocaleDateString('en-US', {
                        year: 'numeric', month: 'short', day: 'numeric',
                      })
                    : <span className="text-gray-300 dark:text-gray-600">Never</span>
                  }
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>

      {streaks.length === 0 && (
        <div className="text-center py-12 text-gray-500 dark:text-gray-400">
          <p className="text-2xl mb-2">📚</p>
          <p className="font-medium">No study guide streaks yet</p>
          <p className="text-xs mt-1 text-gray-400">Streaks appear once users complete their first study guide session</p>
        </div>
      )}
    </div>
  )
}
