'use client'

import { useRouter } from 'next/navigation'

interface Feedback {
  id: string
  user_id: string | null
  user_email: string | null
  user_name: string | null
  was_helpful: boolean
  message: string | null
  category: string
  sentiment_score: number | null
  context_type: string | null
  context_id: string | null
  created_at: string
}

interface FeedbackTableProps {
  feedback: Feedback[]
}

export function FeedbackTable({ feedback }: FeedbackTableProps) {
  const router = useRouter()
  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      general: 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300',
      bug_report: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300',
      feature_request: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-300',
      content_feedback: 'bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-300',
      study_guide: 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300',
      memory_verse: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-300',
    }
    return colors[category] || colors.general
  }

  const getCategoryLabel = (category: string) => {
    const labels: Record<string, string> = {
      general: 'General',
      bug_report: 'Bug Report',
      feature_request: 'Feature Request',
      content_feedback: 'Content Feedback',
      study_guide: 'Study Guide',
      memory_verse: 'Memory Verse',
    }
    return labels[category] || category
  }

  const getSentimentEmoji = (score: number | null) => {
    if (score === null) return '😐'
    if (score >= 0.5) return '😊'
    if (score >= 0) return '😐'
    if (score >= -0.5) return '😕'
    return '😞'
  }

  if (feedback.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
        <p className="text-gray-500 dark:text-gray-400">No feedback found</p>
      </div>
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              User
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Category
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Helpful
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Sentiment
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Date
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
          {feedback.map((item) => (
            <tr key={item.id} className="cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800" onClick={() => router.push(`/issues/${item.id}`)}>
              <td className="whitespace-nowrap px-6 py-4">
                <div className="text-sm">
                  <div className="font-medium text-gray-900 dark:text-gray-100">
                    {item.user_name || 'Anonymous'}
                  </div>
                  <div className="text-gray-500 dark:text-gray-400">
                    {item.user_email || 'No email'}
                  </div>
                </div>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${getCategoryColor(item.category)}`}>
                  {getCategoryLabel(item.category)}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <span className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-semibold ${
                  item.was_helpful
                    ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300'
                    : 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300'
                }`}>
                  {item.was_helpful ? '👍 Yes' : '👎 No'}
                </span>
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-center text-2xl">
                {getSentimentEmoji(item.sentiment_score)}
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {new Date(item.created_at).toLocaleDateString()} <br />
                {new Date(item.created_at).toLocaleTimeString()}
              </td>
              <td className="whitespace-nowrap px-6 py-4">
                <button
                  onClick={(e) => {
                    e.stopPropagation()
                    router.push(`/issues/${item.id}`)
                  }}
                  className="text-primary hover:text-primary-600 font-medium text-sm"
                >
                  View Details →
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
