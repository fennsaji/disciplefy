'use client'

interface Streak {
  id: string
  user_id: string
  user_email: string
  user_name: string
  current_streak: number
  longest_streak: number
  total_xp_earned: number
  last_study_date: string | null
  created_at: string
}

interface StreaksTableProps {
  streaks: Streak[]
}

export default function StreaksTable({ streaks }: StreaksTableProps) {
  const getStreakStatus = (lastStudyDate: string | null) => {
    if (!lastStudyDate) {
      return { label: 'Inactive', color: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200' }
    }

    const now = new Date()
    const lastStudy = new Date(lastStudyDate)
    const daysDiff = Math.floor((now.getTime() - lastStudy.getTime()) / (1000 * 60 * 60 * 24))

    if (daysDiff === 0) {
      return { label: 'Active Today', color: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' }
    } else if (daysDiff === 1) {
      return { label: 'Active', color: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' }
    } else if (daysDiff <= 7) {
      return { label: 'At Risk', color: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200' }
    } else {
      return { label: 'Broken', color: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200' }
    }
  }

  const getStreakBadge = (days: number) => {
    if (days === 0) return null
    if (days >= 100) {
      return { icon: '💎', label: '100+ Day Streak!', color: 'text-cyan-600 dark:text-cyan-400' }
    } else if (days >= 30) {
      return { icon: '🔥', label: '30+ Day Streak!', color: 'text-orange-600 dark:text-orange-400' }
    } else if (days >= 7) {
      return { icon: '⚡', label: '1 Week Streak!', color: 'text-yellow-600 dark:text-yellow-400' }
    }
    return null
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              User
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Current Streak
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Longest Streak
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Total XP
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Status
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Last Study
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
          {streaks.map((streak) => {
            const status = getStreakStatus(streak.last_study_date)
            const badge = getStreakBadge(streak.current_streak)

            return (
              <tr key={streak.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                <td className="px-6 py-4">
                  <div className="text-sm">
                    <div className="font-medium text-gray-900 dark:text-gray-100">
                      {streak.user_name}
                    </div>
                    <div className="text-gray-500 dark:text-gray-400">
                      {streak.user_email}
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center gap-2">
                    <span className="text-2xl font-bold text-primary">
                      {streak.current_streak}
                    </span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">days</span>
                    {badge && (
                      <span className={`text-xl ${badge.color}`} title={badge.label}>
                        {badge.icon}
                      </span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center gap-2">
                    <span className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                      {streak.longest_streak}
                    </span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">days</span>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-primary">
                  {streak.total_xp_earned?.toLocaleString() || 0} XP
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${status.color}`}>
                    {status.label}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                  {streak.last_study_date
                    ? new Date(streak.last_study_date).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric'
                      })
                    : 'Never'}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>

      {streaks.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 dark:text-gray-400">No streaks found</p>
        </div>
      )}
    </div>
  )
}
