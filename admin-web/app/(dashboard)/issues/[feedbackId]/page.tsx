'use client'

import { useRouter, useParams } from 'next/navigation'
import { toast } from 'sonner'
import { useQuery } from '@tanstack/react-query'

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

export default function FeedbackDetailPage() {
  const router = useRouter()
  const params = useParams()
  const feedbackId = params.feedbackId as string

  const { data: allFeedback, isLoading } = useQuery<Feedback[]>({
    queryKey: ['feedback'],
    queryFn: async () => {
      const response = await fetch('/api/admin/feedback', {
        credentials: 'include',
      })
      if (!response.ok) throw new Error('Failed to fetch feedback')
      return response.json()
    },
  })

  const feedback = allFeedback?.find((f) => f.id === feedbackId)

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

  const getSentimentEmoji = (score: number | null) => {
    if (score === null) return '😐'
    if (score >= 0.5) return '😊'
    if (score >= 0) return '😐'
    if (score >= -0.5) return '😕'
    return '😞'
  }

  const handleReplyViaEmail = () => {
    if (!feedback?.user_email || feedback.user_email === 'Anonymous' || feedback.user_email === 'No email') {
      toast.error('This user does not have an email address on file.')
      return
    }

    const subject = `Re: Your feedback - ${getCategoryLabel(feedback.category)}`
    const body = `Hi ${feedback.user_name || 'there'},\n\nThank you for your feedback regarding ${getCategoryLabel(feedback.category)}.\n\nYour message:\n"${feedback.message || 'No message provided'}"\n\nBest regards,\nDisciplefy Team`

    const mailtoLink = `mailto:${feedback.user_email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
    window.location.href = mailtoLink
  }

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="text-center">
          <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-primary border-r-transparent"></div>
          <p className="mt-4 text-gray-600 dark:text-gray-400">Loading feedback...</p>
        </div>
      </div>
    )
  }

  if (!feedback) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">Feedback Not Found</h1>
          <button
            onClick={() => router.push('/issues')}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
          >
            ← Back to Issues
          </button>
        </div>
        <div className="rounded-lg border border-gray-200 bg-gray-50 p-12 text-center dark:border-gray-700 dark:bg-gray-800">
          <p className="text-gray-500 dark:text-gray-400">The requested feedback could not be found.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push('/issues')}
            className="rounded-lg p-2 text-gray-400 hover:bg-gray-100 hover:text-gray-600 dark:hover:bg-gray-700 dark:hover:text-gray-300"
            aria-label="Back to Issues"
          >
            <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">Feedback Details</h1>
          <span className={`inline-flex rounded-full px-3 py-1 text-sm font-semibold ${getCategoryColor(feedback.category)}`}>
            {getCategoryLabel(feedback.category)}
          </span>
        </div>
        {feedback.user_email && feedback.user_email !== 'Anonymous' && feedback.user_email !== 'No email' && (
          <button
            onClick={handleReplyViaEmail}
            className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
            Reply via Email
          </button>
        )}
      </div>

      {/* Content */}
      <div className="space-y-6">
        {/* User Information */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
            User Information
          </h2>
          <div className="grid gap-4 md:grid-cols-2">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Name</p>
              <p className="mt-1 text-lg font-medium text-gray-900 dark:text-gray-100">
                {feedback.user_name || 'Anonymous'}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Email</p>
              <p className="mt-1 text-lg font-medium text-gray-900 dark:text-gray-100">
                {feedback.user_email || 'No email'}
              </p>
            </div>
          </div>
        </div>

        {/* Feedback Metadata */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
            Feedback Metadata
          </h2>
          <div className="grid gap-4 md:grid-cols-3">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Helpful?</p>
              <span className={`mt-1 inline-flex items-center rounded-full px-3 py-1 text-sm font-semibold ${
                feedback.was_helpful
                  ? 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-300'
                  : 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-300'
              }`}>
                {feedback.was_helpful ? '👍 Yes' : '👎 No'}
              </span>
            </div>
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Sentiment</p>
              <p className="mt-1 text-3xl">
                {getSentimentEmoji(feedback.sentiment_score)}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Submitted</p>
              <p className="mt-1 text-sm font-medium text-gray-900 dark:text-gray-100">
                {new Date(feedback.created_at).toLocaleDateString()}
              </p>
              <p className="text-xs text-gray-500 dark:text-gray-400">
                {new Date(feedback.created_at).toLocaleTimeString()}
              </p>
            </div>
          </div>
        </div>

        {/* Context Information */}
        {feedback.context_type && feedback.context_id && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Context
            </h2>
            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Type</p>
                <p className="mt-1 text-lg font-medium text-gray-900 dark:text-gray-100">
                  {feedback.context_type.replace('_', ' ')}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">ID</p>
                <p className="mt-1 font-mono text-sm text-gray-900 dark:text-gray-100">
                  {feedback.context_id}
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Message */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
            Message
          </h2>
          <div className="rounded-lg bg-gray-50 p-4 dark:bg-gray-900">
            <p className="whitespace-pre-wrap text-gray-900 dark:text-gray-100">
              {feedback.message || <span className="italic text-gray-400">No message provided</span>}
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
