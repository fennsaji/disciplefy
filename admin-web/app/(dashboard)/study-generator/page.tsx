'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { useSearchParams, useRouter } from 'next/navigation'
import { PageHeader } from '@/components/ui/page-header'
import { SourceSelector, type GenerationConfig } from '@/components/study-generator/source-selector'
import { StreamingPreview } from '@/components/study-generator/streaming-preview'
import { ContentEditor } from '@/components/study-generator/content-editor'
import type { StudyGuide, UpdateStudyGuideRequest } from '@/types/admin'
import { loadStudyGuide, updateStudyGuide } from '@/lib/api/admin'

type ViewState = 'configure' | 'generating' | 'editing'

export default function StudyGeneratorPage() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const [viewState, setViewState] = useState<ViewState>('configure')
  const [generationId, setGenerationId] = useState<string | null>(null)
  const [currentGuide, setCurrentGuide] = useState<StudyGuide | null>(null)
  const [error, setError] = useState<string | null>(null)

  // Get initial values from URL parameters
  const initialTopicId = searchParams.get('topic')
  const initialPathId = searchParams.get('path')
  const initialInputType = searchParams.get('input_type') as 'topic' | 'verse' | 'passage' | 'question' | null
  const initialInputValue = searchParams.get('input_value')
  const initialStudyMode = searchParams.get('study_mode') as 'standard' | 'deep' | 'lectio' | 'sermon' | 'recommended' | null
  const initialLanguage = searchParams.get('language') as 'en' | 'hi' | 'ml' | null

  const handleGenerate = async (config: GenerationConfig) => {
    setError(null)
    try {
      // Start generation
      const response = await fetch('/api/admin/study-generator/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(config),
      })

      if (!response.ok) {
        throw new Error('Failed to start generation')
      }

      const data = await response.json()

      // Build the stream URL with parameters
      const streamParams = new URLSearchParams(data.stream_params)
      const streamUrl = `/api/admin/study-generator/generate?${streamParams.toString()}`

      setGenerationId(streamUrl)
      setViewState('generating')
    } catch (err) {
      console.error('Generation failed:', err)
      setError('Failed to start generation. Please try again.')
    }
  }

  const handleGenerationComplete = async (guideId: string) => {
    try {
      // Load the complete study guide
      const response = await loadStudyGuide(guideId)
      setCurrentGuide(response.study_guide)
      setViewState('editing')
    } catch (err) {
      console.error('Failed to load guide:', err)
      setError('Generation complete but failed to load guide. Please try again.')
    }
  }

  const handleGenerationError = (errorMessage: string) => {
    setError(errorMessage)
    setViewState('configure')
  }

  const handleCancelGeneration = () => {
    setViewState('configure')
    setGenerationId(null)
  }

  const handleSaveChanges = async (
    guideId: string,
    updates: UpdateStudyGuideRequest
  ) => {
    try {
      await updateStudyGuide(guideId, updates)
      toast.success('Study guide updated successfully!')
      // Reload the guide to show updated content
      const response = await loadStudyGuide(guideId)
      setCurrentGuide(response.study_guide)
    } catch (err) {
      console.error('Failed to save changes:', err)
      throw err
    }
  }

  const handleCancelEdit = () => {
    if (
      confirm(
        'Are you sure you want to discard your changes and start over?'
      )
    ) {
      setViewState('configure')
      setCurrentGuide(null)
      setGenerationId(null)
    }
  }

  const handleStartNew = () => {
    if (
      confirm(
        'Are you sure you want to start a new study guide? Current work will be preserved but not accessible from this interface.'
      )
    ) {
      setViewState('configure')
      setCurrentGuide(null)
      setGenerationId(null)
      setError(null)
    }
  }

  const handleBack = () => {
    // Navigate to the correct source page based on URL parameters
    if (initialPathId) {
      // Came from a learning path, navigate back to that path
      router.push(`/learning-paths/${initialPathId}`)
    } else if (initialTopicId) {
      // Came from topics page, navigate back to topics
      router.push('/topics')
    } else {
      // No source context, just go back to configure view
      setViewState('configure')
      setCurrentGuide(null)
      setGenerationId(null)
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Study Generator"
        description="Generate and customize study guides for any topic, verse, or question"
        actions={viewState !== 'configure' ? (
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={handleBack}
              className="flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
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
                  d="M15 19l-7-7 7-7"
                />
              </svg>
              Back
            </button>
            <button
              type="button"
              onClick={handleStartNew}
              className="flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
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
              Start New
            </button>
          </div>
        ) : undefined}
      />

      {/* Error Message */}
      {error && (
        <div className="rounded-lg bg-red-50 p-4 dark:bg-red-900/20">
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
            <div className="flex-1">
              <p className="text-sm font-medium text-red-900 dark:text-red-200">Error</p>
              <p className="mt-1 text-sm text-red-800 dark:text-red-300">{error}</p>
            </div>
            <button
              type="button"
              onClick={() => setError(null)}
              className="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
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
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        </div>
      )}

      {/* Configure View */}
      {viewState === 'configure' && (
        <div className="mx-auto max-w-3xl">
          <SourceSelector
            onGenerate={handleGenerate}
            initialTopicId={initialTopicId || undefined}
            initialPathId={initialPathId || undefined}
            initialInputType={initialInputType || undefined}
            initialInputValue={initialInputValue || undefined}
            initialStudyMode={initialStudyMode || undefined}
            initialLanguage={initialLanguage || undefined}
          />

          {/* Info Cards */}
          <div className="mt-6 grid gap-4 md:grid-cols-3">
            <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
              <div className="flex items-center gap-3">
                <div className="rounded-full bg-primary-100 p-2 dark:bg-primary-900/30">
                  <svg
                    className="h-5 w-5 text-primary dark:text-primary-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M13 10V3L4 14h7v7l9-11h-7z"
                    />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Instant Generation
                  </p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    AI-powered in seconds
                  </p>
                </div>
              </div>
            </div>

            <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
              <div className="flex items-center gap-3">
                <div className="rounded-full bg-green-100 p-2 dark:bg-green-900/30">
                  <svg
                    className="h-5 w-5 text-green-600 dark:text-green-400"
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
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Full Editing
                  </p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    Customize every section
                  </p>
                </div>
              </div>
            </div>

            <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
              <div className="flex items-center gap-3">
                <div className="rounded-full bg-blue-100 p-2 dark:bg-blue-900/30">
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
                      d="M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2zm9-13.5V9"
                    />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Multi-Language
                  </p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    English, Hindi, Malayalam
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Generating View */}
      {viewState === 'generating' && generationId && (
        <StreamingPreview
          generationId={generationId}
          onComplete={handleGenerationComplete}
          onError={handleGenerationError}
          onCancel={handleCancelGeneration}
        />
      )}

      {/* Editing View */}
      {viewState === 'editing' && currentGuide && (
        <ContentEditor
          guide={currentGuide}
          onSave={handleSaveChanges}
          onCancel={handleCancelEdit}
        />
      )}

      {/* Usage Tips */}
      {viewState === 'configure' && (
        <div className="mx-auto max-w-3xl">
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-6 dark:border-gray-700 dark:bg-gray-800">
            <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">
              💡 Generation Tips
            </h3>
            <ul className="mt-3 space-y-2 text-sm text-gray-600 dark:text-gray-400">
              <li className="flex items-start gap-2">
                <span className="text-primary dark:text-primary-400">•</span>
                <span>
                  <strong className="text-gray-900 dark:text-gray-100">Existing Topics:</strong> Use pre-configured topics from
                  your library for consistent study guides
                </span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-primary dark:text-primary-400">•</span>
                <span>
                  <strong className="text-gray-900 dark:text-gray-100">Custom Input:</strong> Create one-time guides for
                  specific needs or experimental topics
                </span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-primary dark:text-primary-400">•</span>
                <span>
                  <strong className="text-gray-900 dark:text-gray-100">Study Modes:</strong> Choose the depth level based on
                  your audience (Quick, Standard, Deep, Lectio Divina, Sermon)
                </span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-primary dark:text-primary-400">•</span>
                <span>
                  <strong className="text-gray-900 dark:text-gray-100">Multi-Language:</strong> Generate guides in English,
                  Hindi, or Malayalam for diverse audiences
                </span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-primary dark:text-primary-400">•</span>
                <span>
                  <strong className="text-gray-900 dark:text-gray-100">Full Control:</strong> Edit any section after generation
                  to match your teaching style
                </span>
              </li>
            </ul>
          </div>
        </div>
      )}
    </div>
  )
}
