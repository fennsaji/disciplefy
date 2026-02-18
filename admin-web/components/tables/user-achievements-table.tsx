'use client'

import { DeleteIcon, actionButtonStyles } from '@/components/ui/action-icons'
import { EmptyState } from '@/components/ui/empty-state'

interface UserAchievement {
  id: string
  user_id: string
  achievement_id: string
  user_email: string
  user_name: string
  achievement_title: string
  achievement_category: string
  achievement_tier: string
  achievement_icon: string
  xp_reward: number
  unlocked_at: string
}

interface UserAchievementsTableProps {
  userAchievements: UserAchievement[]
  onRevoke: (id: string) => void
}

export default function UserAchievementsTable({
  userAchievements,
  onRevoke
}: UserAchievementsTableProps) {
  const getTierColor = (tier: string) => {
    const colors: Record<string, string> = {
      bronze: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200',
      silver: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200',
      gold: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
      platinum: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
      diamond: 'bg-cyan-100 text-cyan-800 dark:bg-cyan-900 dark:text-cyan-200',
    }
    return colors[tier] || colors.bronze
  }

  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      study: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
      memory: 'bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-200',
      streak: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
      learning_path: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
      engagement: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200',
    }
    return colors[category] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
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
              Achievement
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Category
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Tier
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              XP Earned
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Unlocked
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          {userAchievements.map((ua) => (
            <tr key={ua.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
              <td className="px-6 py-4">
                <div className="text-sm">
                  <div className="font-medium text-gray-900 dark:text-gray-100">
                    {ua.user_name}
                  </div>
                  <div className="text-gray-500 dark:text-gray-400">
                    {ua.user_email}
                  </div>
                </div>
              </td>
              <td className="px-6 py-4">
                <div className="flex items-center gap-2">
                  <span className="text-2xl">{ua.achievement_icon}</span>
                  <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    {ua.achievement_title}
                  </span>
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getCategoryColor(ua.achievement_category)}`}>
                  {ua.achievement_category?.replace('_', ' ')}
                </span>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getTierColor(ua.achievement_tier)}`}>
                  {ua.achievement_tier}
                </span>
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-primary">
                +{ua.xp_reward} XP
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                {new Date(ua.unlocked_at).toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'short',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit'
                })}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <button
                  type="button"
                  onClick={() => {
                    if (confirm(`Are you sure you want to revoke "${ua.achievement_title}" from ${ua.user_name}?`)) {
                      onRevoke(ua.id)
                    }
                  }}
                  className={actionButtonStyles.delete}
                  title="Revoke"
                >
                  <DeleteIcon />
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {userAchievements.length === 0 && (
        <EmptyState title="No user achievements" description="No user achievements match the current filter." icon="🎖️" />
      )}
    </div>
  )
}
