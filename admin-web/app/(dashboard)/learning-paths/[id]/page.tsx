'use client'

import { useState, useEffect, use } from 'react'
import { useRouter } from 'next/navigation'
import { PathTopicOrganizer } from '@/components/dialogs/path-topic-organizer'
import type { LearningPathWithDetails } from '@/types/admin'
import { getLearningPath } from '@/lib/api/admin'

interface PageProps {
  params: Promise<{ id: string }>
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
      <div className="flex min-h-screen items-center justify-center dark:bg-gray-900">
        <div className="text-center">
          <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
          <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">Loading learning path...</p>
        </div>
      </div>
    )
  }

  if (error || !path) {
    return (
      <div className="flex min-h-screen items-center justify-center dark:bg-gray-900">
        <div className="rounded-lg bg-red-50 p-6 text-center dark:bg-red-900/20">
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
            className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark"
          >
            Back to Learning Paths
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6 dark:bg-gray-900">
      {/* Header */}
      <div className="mb-6">
        <button
          onClick={() => router.push('/learning-paths')}
          className="mb-4 flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
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

        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-3">
              <div
                className="flex h-12 w-12 items-center justify-center rounded-lg text-2xl"
                style={{ backgroundColor: `${path.color}20` }}
              >
                {path.icon_name && (
                  <span>{['📖', '📈', '🤝', '🛡️', '👨‍👩‍👧‍👦', '🧠', '🕊️', '❤️', '💡', '🎓'].find(() => true) || '📚'}</span>
                )}
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">{path.title}</h1>
                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{path.slug}</p>
              </div>
            </div>
            {path.description && (
              <p className="mt-3 text-sm text-gray-600 dark:text-gray-400">{path.description}</p>
            )}
          </div>

          <button
            onClick={() => router.push(`/learning-paths/${id}/edit`)}
            className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark"
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
        <div className="mt-6 grid grid-cols-4 gap-4">
          <div className="rounded-lg bg-white p-4 shadow-sm dark:bg-gray-800 dark:shadow-gray-900">
            <p className="text-sm text-gray-500 dark:text-gray-400">Topics</p>
            <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
              {path.topics?.length || 0}
            </p>
          </div>
          <div className="rounded-lg bg-white p-4 shadow-sm dark:bg-gray-800 dark:shadow-gray-900">
            <p className="text-sm text-gray-500 dark:text-gray-400">Total XP</p>
            <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">{path.total_xp}</p>
          </div>
          <div className="rounded-lg bg-white p-4 shadow-sm dark:bg-gray-800 dark:shadow-gray-900">
            <p className="text-sm text-gray-500 dark:text-gray-400">Enrolled Users</p>
            <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
              {path.enrolled_count || 0}
            </p>
          </div>
          <div className="rounded-lg bg-white p-4 shadow-sm dark:bg-gray-800 dark:shadow-gray-900">
            <p className="text-sm text-gray-500 dark:text-gray-400">Disciple Level</p>
            <p className="mt-1 text-lg font-semibold capitalize text-gray-900 dark:text-gray-100">
              {path.disciple_level}
            </p>
          </div>
        </div>
      </div>

      {/* Topics Management */}
      <div className="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800 dark:shadow-gray-900">
        <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Manage Topics</h2>
        <PathTopicOrganizer pathId={id} />
      </div>
    </div>
  )
}
