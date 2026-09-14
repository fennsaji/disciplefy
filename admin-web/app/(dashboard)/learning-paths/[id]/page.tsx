'use client'

import { useState, useEffect, use } from 'react'
import { useRouter } from 'next/navigation'
import { PathTopicOrganizer } from '@/components/dialogs/path-topic-organizer'
import type { LearningPathWithDetails } from '@/types/admin'
import { getLearningPath } from '@/lib/api/admin'

interface PageProps {
  params: Promise<{ id: string }>
}

// Map icon names to emojis (matches learning-paths-table)
const iconMap: Record<string, string> = {
  auto_stories: '📖',
  trending_up: '📈',
  volunteer_activism: '🤝',
  shield: '🛡️',
  family_restroom: '👨‍👩‍👧‍👦',
  psychology: '🧠',
  spa: '🕊️',
  favorite: '❤️',
  lightbulb: '💡',
  school: '🎓',
}

export default function LearningPathDetailPage({ params }: PageProps) {
  const { id } = use(params)
  const router = useRouter()
  const [path, setPath] = useState<LearningPathWithDetails | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadPath()
  }, [id])

  const loadPath = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const response = await getLearningPath(id)
      setPath(response.learning_path)
    } catch (err) {
      console.error('Failed to load path:', err)
      setError('Failed to load learning path details. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  if (isLoading) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center">
        <div className="text-center">
          <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
          <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">Loading learning path...</p>
        </div>
      </div>
    )
  }

  if (error || !path) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center">
        <div className="rounded-lg bg-red-50 p-4 sm:p-6 text-center dark:bg-red-900/20">
          <svg
            className="mx-auto h-12 w-12 text-red-600 dark:text-red-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <h3 className="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">
            {error || 'Learning path not found'}
          </h3>
          <button
            onClick={() => router.push('/learning-paths')}
            className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
          >
            Back to Learning Paths
          </button>
        </div>
      </div>
    )
  }

  return (
    // The dashboard shell already pads the page, so no padding of its own here.
    <div className="space-y-4 sm:space-y-6">
      {/* Header */}
      <div>
        <button
          onClick={() => router.push('/learning-paths')}
          className="mb-3 flex items-center gap-1.5 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
        >
          <svg
            className="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M15 19l-7-7 7-7"
            />
          </svg>
          Back to Learning Paths
        </button>

        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div className="min-w-0">
            <div className="flex items-center gap-3">
              <div
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg text-xl sm:h-12 sm:w-12 sm:text-2xl"
                style={{ backgroundColor: `${path.color}20` }}
              >
                <span>{iconMap[path.icon_name] || '📚'}</span>
              </div>
              <div className="min-w-0">
                <h1 className="text-xl font-bold leading-tight text-gray-900 sm:text-2xl dark:text-gray-100">{path.title}</h1>
                <p className="mt-0.5 truncate text-xs text-gray-500 sm:text-sm dark:text-gray-400">{path.slug}</p>
              </div>
            </div>
            {path.description && (
              <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">{path.description}</p>
            )}
          </div>

          <button
            onClick={() => router.push(`/learning-paths/${id}/edit`)}
            className="flex shrink-0 items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
          >
            <svg
              className="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
              />
            </svg>
            Edit Details
          </button>
        </div>

        {/* Stats */}
        <dl className="mt-4 grid grid-cols-2 gap-2 sm:mt-6 sm:grid-cols-4 sm:gap-4">
          {[
            { label: 'Topics', value: path.topics?.length || 0 },
            { label: 'Total XP', value: path.total_xp },
            { label: 'Enrolled', value: path.enrolled_count || 0 },
            { label: 'Level', value: path.disciple_level, capitalize: true },
          ].map((stat) => (
            <div
              key={stat.label}
              className="rounded-lg bg-white px-3 py-2 shadow-sm sm:p-4 dark:bg-gray-800 dark:shadow-gray-900"
            >
              <dt className="text-xs text-gray-500 sm:text-sm dark:text-gray-400">{stat.label}</dt>
              <dd
                className={`mt-0.5 text-lg font-semibold text-gray-900 sm:mt-1 sm:text-2xl dark:text-gray-100 ${stat.capitalize ? 'capitalize' : ''}`}
              >
                {stat.value}
              </dd>
            </div>
          ))}
        </dl>
      </div>

      {/* Topics Management: the organizer carries its own heading */}
      <div className="rounded-lg bg-white p-3 shadow-sm sm:p-6 dark:bg-gray-800 dark:shadow-gray-900">
        <PathTopicOrganizer pathId={id} />
      </div>
    </div>
  )
}
