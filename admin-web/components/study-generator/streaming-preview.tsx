'use client'

import { useEffect, useState } from 'react'
import ReactMarkdown from 'react-markdown'

interface StreamingPreviewProps {
  generationId: string
  onComplete: (guideId: string) => void
  onError: (error: string) => void
  onCancel: () => void
}

interface SectionProgress {
  summary: boolean
  context: boolean
  interpretation: boolean
  related_verses: boolean
  reflection_questions: boolean
  prayer_points: boolean
  insights: boolean
}

interface GeneratedContent {
  summary?: string
  context?: string
  interpretation?: string
  related_verses?: Array<{ reference: string; text: string }>
  reflection_questions?: string[]
  prayer_points?: string[]
  insights?: string[]
}

export function StreamingPreview({
  generationId,
  onComplete,
  onError,
  onCancel,
}: StreamingPreviewProps) {
  const [progress, setProgress] = useState<SectionProgress>({
    summary: false,
    context: false,
    interpretation: false,
    related_verses: false,
    reflection_questions: false,
    prayer_points: false,
    insights: false,
  })

  const [content, setContent] = useState<GeneratedContent>({})
  const [currentSection, setCurrentSection] = useState<string>('Initializing...')
  const [isCancelled, setIsCancelled] = useState(false)

  useEffect(() => {
    let eventSource: EventSource | null = null

    const connectStream = () => {
      // generationId now contains the full URL with parameters
      eventSource = new EventSource(generationId)
      let isCompleted = false

      // Listen for 'init' events
      eventSource.addEventListener('init', (event: MessageEvent) => {
        try {
          const data = JSON.parse(event.data)
          if (data.status === 'started') {
            setCurrentSection('Starting generation...')
          }
        } catch (err) {
          console.error('Failed to parse init event:', err)
        }
      })

      // Listen for 'section' events
      eventSource.addEventListener('section', (event: MessageEvent) => {
        try {
          const data = JSON.parse(event.data)
          const sectionType = data.type
          setCurrentSection(`Generated ${sectionType}`)

          // Map section types to progress keys
          const progressKey = sectionType.replace(/([A-Z])/g, '_$1').toLowerCase()
          setProgress((prev) => ({ ...prev, [progressKey]: true }))
          setContent((prev) => ({ ...prev, [progressKey]: data.content }))
        } catch (err) {
          console.error('Failed to parse section event:', err)
        }
      })

      // Listen for 'complete' events
      eventSource.addEventListener('complete', (event: MessageEvent) => {
        try {
          const data = JSON.parse(event.data)
          isCompleted = true
          setCurrentSection('Complete!')
          onComplete(data.studyGuideId)
          eventSource?.close()
        } catch (err) {
          console.error('Failed to parse complete event:', err)
        }
      })

      // Listen for 'error' events from SSE (not connection errors)
      eventSource.addEventListener('error', (event: MessageEvent) => {
        try {
          const data = JSON.parse(event.data)
          onError(data.message || data.error || 'Generation failed')
          eventSource?.close()
        } catch (err) {
          // Not a data error, just parse error - ignore
        }
      })

      // Handle connection errors
      eventSource.onerror = (error) => {
        // Only show error if we haven't completed successfully
        if (!isCompleted) {
          console.error('SSE connection error:', error)
          onError('Connection lost. Please try again.')
        }
        eventSource?.close()
      }
    }

    if (!isCancelled) {
      connectStream()
    }

    return () => {
      eventSource?.close()
    }
  }, [generationId, isCancelled, onComplete, onError])

  const handleCancel = () => {
    setIsCancelled(true)
    onCancel()
  }

  const sections = [
    { key: 'summary', label: 'Summary', icon: '📝' },
    { key: 'context', label: 'Context', icon: '📖' },
    { key: 'interpretation', label: 'Interpretation', icon: '💡' },
    { key: 'related_verses', label: 'Related Verses', icon: '📜' },
    { key: 'reflection_questions', label: 'Reflection Questions', icon: '❓' },
    { key: 'prayer_points', label: 'Prayer Points', icon: '🙏' },
    { key: 'insights', label: 'Insights', icon: '✨' },
  ]

  return (
    <div className="space-y-6">
      {/* Progress Header */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
            <div>
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">
                Generating Study Guide
              </h3>
              <p className="text-sm text-gray-600 dark:text-gray-400">{currentSection}</p>
            </div>
          </div>
          <button
            type="button"
            onClick={handleCancel}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
          >
            Cancel
          </button>
        </div>

        {/* Progress Indicators */}
        <div className="mt-6 grid grid-cols-7 gap-2">
          {sections.map((section) => (
            <div
              key={section.key}
              className={`flex flex-col items-center gap-1 rounded-lg p-2 text-center transition-colors ${
                progress[section.key as keyof SectionProgress]
                  ? 'bg-green-100 dark:bg-green-900/30'
                  : 'bg-gray-100 dark:bg-gray-700'
              }`}
            >
              <span className="text-xl">{section.icon}</span>
              <span className="text-xs font-medium text-gray-700 dark:text-gray-300">
                {section.label}
              </span>
              {progress[section.key as keyof SectionProgress] && (
                <svg
                  className="h-4 w-4 text-green-600 dark:text-green-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M5 13l4 4L19 7"
                  />
                </svg>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Generated Content Preview */}
      <div className="space-y-4">
        {/* Summary */}
        {content.summary && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-3 flex items-center gap-2">
              <span className="text-xl">📝</span>
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">Summary</h3>
              <span className="ml-auto inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                Complete
              </span>
            </div>
            <div className="prose prose-sm max-w-none dark:prose-invert">
              <ReactMarkdown>{content.summary}</ReactMarkdown>
            </div>
          </div>
        )}

        {/* Context */}
        {content.context && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-3 flex items-center gap-2">
              <span className="text-xl">📖</span>
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">Context</h3>
              <span className="ml-auto inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                Complete
              </span>
            </div>
            <div className="prose prose-sm max-w-none dark:prose-invert">
              <ReactMarkdown>{content.context}</ReactMarkdown>
            </div>
          </div>
        )}

        {/* Interpretation */}
        {content.interpretation && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-3 flex items-center gap-2">
              <span className="text-xl">💡</span>
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">Interpretation</h3>
              <span className="ml-auto inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                Complete
              </span>
            </div>
            <div className="prose prose-sm max-w-none dark:prose-invert">
              <ReactMarkdown>{content.interpretation}</ReactMarkdown>
            </div>
          </div>
        )}

        {/* Related Verses */}
        {content.related_verses && content.related_verses.length > 0 && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-3 flex items-center gap-2">
              <span className="text-xl">📜</span>
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">Related Verses</h3>
              <span className="ml-auto inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                Complete
              </span>
            </div>
            <div className="space-y-3">
              {content.related_verses.map((verse, index) => (
                <div key={index} className="rounded-lg bg-gray-50 p-3 dark:bg-gray-700">
                  <p className="font-medium text-primary dark:text-primary-400">{verse.reference}</p>
                  <p className="mt-1 text-sm text-gray-700 dark:text-gray-300">{verse.text}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Reflection Questions */}
        {content.reflection_questions &&
          content.reflection_questions.length > 0 && (
            <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
              <div className="mb-3 flex items-center gap-2">
                <span className="text-xl">❓</span>
                <h3 className="font-semibold text-gray-900 dark:text-gray-100">
                  Reflection Questions
                </h3>
                <span className="ml-auto inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                  Complete
                </span>
              </div>
              <ul className="space-y-2">
                {content.reflection_questions.map((question, index) => (
                  <li
                    key={index}
                    className="flex items-start gap-2 text-sm text-gray-700 dark:text-gray-300"
                  >
                    <span className="mt-1 flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full bg-primary-100 text-xs font-medium text-primary-800 dark:bg-primary-900/30 dark:text-primary-400">
                      {index + 1}
                    </span>
                    <span>{question}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

        {/* Prayer Points */}
        {content.prayer_points && content.prayer_points.length > 0 && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-3 flex items-center gap-2">
              <span className="text-xl">🙏</span>
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">Prayer Points</h3>
              <span className="ml-auto inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                Complete
              </span>
            </div>
            <ul className="space-y-2">
              {content.prayer_points.map((point, index) => (
                <li
                  key={index}
                  className="flex items-start gap-2 text-sm text-gray-700 dark:text-gray-300"
                >
                  <span className="text-primary dark:text-primary-400">•</span>
                  <span>{point}</span>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Insights */}
        {content.insights && content.insights.length > 0 && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-3 flex items-center gap-2">
              <span className="text-xl">✨</span>
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">Insights</h3>
              <span className="ml-auto inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                Complete
              </span>
            </div>
            <ul className="space-y-2">
              {content.insights.map((insight, index) => (
                <li
                  key={index}
                  className="flex items-start gap-2 text-sm text-gray-700 dark:text-gray-300"
                >
                  <svg
                    className="mt-1 h-4 w-4 flex-shrink-0 text-yellow-500 dark:text-yellow-400"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                  <span>{insight}</span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </div>
  )
}
