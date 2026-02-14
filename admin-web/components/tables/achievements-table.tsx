'use client'

interface Achievement {
  id: string
  title: string
  description: string
  category: string
  type: string
  tier: string
  icon: string
  xp_reward: number
  requirement_value: number
  total_unlocks: number
  unique_users: number
  created_at: string
}

interface AchievementsTableProps {
  achievements: Achievement[]
  onEdit: (achievement: Achievement) => void
  onDelete: (id: string) => void
}

export default function AchievementsTable({
  achievements,
  onEdit,
  onDelete
}: AchievementsTableProps) {
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
              Achievement
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Category
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Tier
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              XP Reward
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Unlocks
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
          {achievements.map((achievement) => (
            <tr key={achievement.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
              <td className="px-6 py-4">
                <div className="flex items-center gap-3">
                  <span className="text-3xl">{achievement.icon}</span>
                  <div>
                    <div className="text-sm font-medium text-gray-900 dark:text-gray-100">
                      {achievement.title}
                    </div>
                    <div className="text-sm text-gray-500 dark:text-gray-400">
                      {achievement.description}
                    </div>
                    <div className="text-xs text-gray-400 dark:text-gray-500 mt-1">
                      Requirement: {achievement.requirement_value} {achievement.type}
                    </div>
                  </div>
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getCategoryColor(achievement.category)}`}>
                  {achievement.category.replace('_', ' ')}
                </span>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getTierColor(achievement.tier)}`}>
                  {achievement.tier}
                </span>
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-primary">
                +{achievement.xp_reward} XP
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm text-gray-900 dark:text-gray-100">
                  <div className="font-medium">{achievement.total_unlocks} unlocks</div>
                  <div className="text-gray-500 dark:text-gray-400">
                    {achievement.unique_users} users
                  </div>
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <button
                  onClick={() => onEdit(achievement)}
                  className="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300 mr-4"
                >
                  Edit
                </button>
                <button
                  onClick={() => {
                    if (confirm(`Are you sure you want to delete "${achievement.title}"? This will remove it from all users.`)) {
                      onDelete(achievement.id)
                    }
                  }}
                  className="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300"
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {achievements.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 dark:text-gray-400">No achievements found</p>
        </div>
      )}
    </div>
  )
}
