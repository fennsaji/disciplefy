'use client'

import { useState, useEffect, use } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import type { StudyGuide } from '@/types/admin'

interface PageProps {
  params: Promise<{ id: string }>
}

export default function TopicContentPage({ params }: PageProps) {
  const { id } = use(params)
  const router = useRouter()
  const searchParams = useSearchParams()
  const pathId = searchParams.get('path')

  const [studyGuides, setStudyGuides] = useState<StudyGuide[]>([])
  const [topicTitle, setTopicTitle] = useState<string>('')
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadStudyGuides()
  }, [id])

  const loadStudyGuides = async () => {
    setIsLoading(true)
    setError(null)
    try {
      // Fetch topic details
      const topicResponse = await fetch(`/api/admin/topics/${id}`)
      if (!topicResponse.ok) {
        throw new Error('Failed to load topic details')
      }
      const topicData = await topicResponse.json()
      setTopicTitle(topicData.topic?.title || 'Unknown Topic')

      // Fetch study guides for this topic
      const guidesResponse = await fetch(`/api/admin/study-guides?topic_id=${id}`)
      if (!guidesResponse.ok) {
        throw new Error('Failed to load study guides')
      }
      const guidesData = await guidesResponse.json()
      setStudyGuides(guidesData.study_guides || [])
    } catch (err) {
      console.error('Failed to load content:', err)
      setError(err instanceof Error ? err.message : 'Failed to load content')
    } finally {
      setIsLoading(false)
    }
  }

  const handleViewGuide = (guideId: string) => {
    router.push(`/study-guides/${guideId}`)
  }

  const handleGenerateNew = () => {
    router.push(`/study-generator?topic=${id}${pathId ? `&path=${pathId}` : ''}`)
  }

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center dark:bg-gray-900">
        <div className="text-center">
          <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
          <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">Loading content...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6 dark:bg-gray-900">
      <div className="mx-auto max-w-6xl">
        {/* Header */}
        <div className="mb-6">
          <button
            onClick={() => pathId ? router.push(`/learning-paths/${pathId}`) : router.push('/topics')}
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
            Back to {pathId ? 'Learning Path' : 'Topics'}
          </button>

          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                Generated Content: {topicTitle}
              </h1>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                View and manage all study guides generated for this topic
              </p>
            </div>
            <button
              onClick={handleGenerateNew}
              className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark"
            >
              <svg
                className="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Generate New
            </button>
          </div>
        </div>

        {/* Error Message */}
        {error && (
          <div className="mb-6 rounded-lg bg-red-50 p-4 dark:bg-red-900/20">
            <div className="flex gap-3">
              <svg
                className="h-5 w-5 text-red-600 dark:text-red-400"
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
              <p className="text-sm text-red-800 dark:text-red-300">{error}</p>
            </div>
          </div>
        )}

        {/* Study Guides List */}
        {studyGuides.length === 0 ? (
          <div className="rounded-lg border-2 border-dashed border-gray-300 bg-white p-12 text-center dark:border-gray-700 dark:bg-gray-800">
            <svg
              className="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            <h3 className="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">
              No Content Generated Yet
            </h3>
            <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
              Generate your first study guide for this topic to get started
            </p>
            <button
              onClick={handleGenerateNew}
              className="mt-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark"
            >
              Generate Study Guide
            </button>
          </div>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {studyGuides.map((guide) => (
              <div
                key={guide.id}
                className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm transition-shadow hover:shadow-md dark:border-gray-700 dark:bg-gray-800 dark:shadow-gray-900"
              >
                <div className="p-6">
                  {/* Header */}
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center gap-2">
                        <span className="inline-flex items-center rounded-full bg-purple-100 px-2.5 py-0.5 text-xs font-medium text-purple-800 dark:bg-purple-900/30 dark:text-purple-300">
                          {guide.study_mode || 'standard'}
                        </span>
                        <span className="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">
                          {guide.language || 'en'}
                        </span>
                      </div>
                      <h3 className="mt-2 font-semibold text-gray-900 dark:text-gray-100">
                        {guide.title || topicTitle}
                      </h3>
                    </div>
                  </div>

                  {/* Summary Preview */}
                  {guide.summary && (
                    <p className="mt-3 line-clamp-3 text-sm text-gray-600 dark:text-gray-400">
                      {guide.summary}
                    </p>
                  )}

                  {/* Metadata */}
                  <div className="mt-4 flex items-center gap-4 text-xs text-gray-500 dark:text-gray-400">
                    <div className="flex items-center gap-1">
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
                          d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                        />
                      </svg>
                      {new Date(guide.created_at).toLocaleDateString()}
                    </div>
                    {guide.creator_name && (
                      <div className="flex items-center gap-1">
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
                            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                          />
                        </svg>
                        {guide.creator_name}
                      </div>
                    )}
                  </div>

                  {/* Action Button */}
                  <button
                    onClick={() => handleViewGuide(guide.id)}
                    className="mt-4 w-full rounded-lg bg-gray-100 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
                  >
                    View Details
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Info Card */}
        {studyGuides.length > 0 && (
          <div className="mt-6 rounded-lg border border-blue-200 bg-blue-50 p-4 dark:border-blue-900/30 dark:bg-blue-900/20">
            <div className="flex gap-3">
              <svg
                className="h-5 w-5 text-blue-600 dark:text-blue-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <div className="flex-1">
                <p className="text-sm font-medium text-blue-900 dark:text-blue-300">
                  Content Management
                </p>
                <ul className="mt-2 space-y-1 text-sm text-blue-800 dark:text-blue-400">
                  <li>• Click "View Details" to see the full study guide content</li>
                  <li>• Generate multiple versions in different modes and languages</li>
                  <li>• Each study guide is independently editable and manageable</li>
                </ul>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
