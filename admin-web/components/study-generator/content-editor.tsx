'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { MarkdownEditor } from '@/components/ui/markdown-editor'
import type { StudyGuide, UpdateStudyGuideRequest } from '@/types/admin'

interface ContentEditorProps {
  guide: StudyGuide
  onSave: (guideId: string, updates: UpdateStudyGuideRequest) => Promise<void>
  onCancel: () => void
}

interface RelatedVerse {
  reference: string
  text: string
}

export function ContentEditor({
  guide,
  onSave,
  onCancel,
}: ContentEditorProps) {
  const [isSaving, setIsSaving] = useState(false)
  const [hasChanges, setHasChanges] = useState(false)

  // Form state - Main content fields
  const [passage, setPassage] = useState(guide.passage || guide.content?.passage || '')
  const [summary, setSummary] = useState(guide.summary || guide.content?.summary || '')
  const [context, setContext] = useState(guide.context || guide.content?.context || '')
  const [interpretation, setInterpretation] = useState(
    guide.interpretation || guide.content?.interpretation || ''
  )

  // Array fields
  const [relatedVerses, setRelatedVerses] = useState<RelatedVerse[]>(() => {
    // Handle both formats: array of strings or array of objects
    const verses = guide.related_verses || guide.content?.relatedVerses || guide.content?.related_verses || []

    if (verses.length === 0) return []

    // If it's an array of strings (just references), convert to objects
    if (typeof verses[0] === 'string') {
      return verses.map((ref: string) => ({ reference: ref, text: '' }))
    }

    // If it's already an array of objects, return as is
    return verses
  })
  const [reflectionQuestions, setReflectionQuestions] = useState<string[]>(
    guide.reflection_questions || guide.content?.reflectionQuestions || guide.content?.reflection_questions || []
  )
  const [prayerPoints, setPrayerPoints] = useState<string[]>(
    guide.prayer_points || guide.content?.prayerPoints || guide.content?.prayer_points || []
  )
  const [insights, setInsights] = useState<string[]>(
    guide.interpretation_insights || guide.content?.interpretationInsights || guide.content?.interpretation_insights || []
  )
  const [summaryInsights, setSummaryInsights] = useState<string[]>(
    guide.summary_insights || guide.content?.summaryInsights || guide.content?.summary_insights || []
  )
  const [reflectionAnswers, setReflectionAnswers] = useState<string[]>(
    guide.reflection_answers || guide.content?.reflectionAnswers || guide.content?.reflection_answers || []
  )

  // Question fields
  const [contextQuestion, setContextQuestion] = useState(
    guide.context_question || guide.content?.contextQuestion || guide.content?.context_question || ''
  )
  const [summaryQuestion, setSummaryQuestion] = useState(
    guide.summary_question || guide.content?.summaryQuestion || guide.content?.summary_question || ''
  )
  const [relatedVersesQuestion, setRelatedVersesQuestion] = useState(
    guide.related_verses_question || guide.content?.relatedVersesQuestion || guide.content?.related_verses_question || ''
  )
  const [reflectionQuestion, setReflectionQuestion] = useState(
    guide.reflection_question || guide.content?.reflectionQuestion || guide.content?.reflection_question || ''
  )
  const [prayerQuestion, setPrayerQuestion] = useState(
    guide.prayer_question || guide.content?.prayerQuestion || guide.content?.prayer_question || ''
  )

  useEffect(() => {
    // Convert related verses to string array for comparison
    const currentVersesRefs = relatedVerses.map(v => v.reference).filter(ref => ref.trim() !== '')
    const originalVersesRefs = guide.related_verses || guide.content?.relatedVerses || guide.content?.related_verses || []

    const changed =
      passage !== (guide.passage || guide.content?.passage || '') ||
      summary !== (guide.summary || guide.content?.summary || '') ||
      context !== (guide.context || guide.content?.context || '') ||
      interpretation !== (guide.interpretation || guide.content?.interpretation || '') ||
      contextQuestion !== (guide.context_question || guide.content?.contextQuestion || guide.content?.context_question || '') ||
      summaryQuestion !== (guide.summary_question || guide.content?.summaryQuestion || guide.content?.summary_question || '') ||
      relatedVersesQuestion !== (guide.related_verses_question || guide.content?.relatedVersesQuestion || guide.content?.related_verses_question || '') ||
      reflectionQuestion !== (guide.reflection_question || guide.content?.reflectionQuestion || guide.content?.reflection_question || '') ||
      prayerQuestion !== (guide.prayer_question || guide.content?.prayerQuestion || guide.content?.prayer_question || '') ||
      JSON.stringify(currentVersesRefs) !== JSON.stringify(originalVersesRefs) ||
      JSON.stringify(reflectionQuestions) !==
        JSON.stringify(guide.reflection_questions || guide.content?.reflectionQuestions || guide.content?.reflection_questions || []) ||
      JSON.stringify(prayerPoints) !==
        JSON.stringify(guide.prayer_points || guide.content?.prayerPoints || guide.content?.prayer_points || []) ||
      JSON.stringify(insights) !==
        JSON.stringify(guide.interpretation_insights || guide.content?.interpretationInsights || guide.content?.interpretation_insights || []) ||
      JSON.stringify(summaryInsights) !==
        JSON.stringify(guide.summary_insights || guide.content?.summaryInsights || guide.content?.summary_insights || []) ||
      JSON.stringify(reflectionAnswers) !==
        JSON.stringify(guide.reflection_answers || guide.content?.reflectionAnswers || guide.content?.reflection_answers || [])

    setHasChanges(changed)
  }, [
    passage,
    summary,
    context,
    interpretation,
    contextQuestion,
    summaryQuestion,
    relatedVersesQuestion,
    reflectionQuestion,
    prayerQuestion,
    relatedVerses,
    reflectionQuestions,
    prayerPoints,
    insights,
    summaryInsights,
    reflectionAnswers,
    guide,
  ])

  const handleSave = async () => {
    setIsSaving(true)
    try {
      // Convert related verses back to array of strings (just references) for database
      const relatedVersesForSave = relatedVerses
        .map(v => v.reference)
        .filter(ref => ref.trim() !== '')

      await onSave(guide.id, {
        content: {
          passage,
          summary,
          context,
          interpretation,
          relatedVerses: relatedVersesForSave,
          reflectionQuestions,
          prayerPoints,
          interpretationInsights: insights,
          summaryInsights,
          reflectionAnswers,
          contextQuestion,
          summaryQuestion,
          relatedVersesQuestion,
          reflectionQuestion,
          prayerQuestion,
        }
      })
    } catch (error) {
      console.error('Failed to save changes:', error)
      toast.error('Failed to save changes. Please try again.')
    } finally {
      setIsSaving(false)
    }
  }

  const addVerse = () => {
    setRelatedVerses([...relatedVerses, { reference: '', text: '' }])
  }

  const updateVerse = (index: number, field: 'reference' | 'text', value: string) => {
    const updated = [...relatedVerses]
    updated[index][field] = value
    setRelatedVerses(updated)
  }

  const removeVerse = (index: number) => {
    setRelatedVerses(relatedVerses.filter((_, i) => i !== index))
  }

  const addQuestion = () => {
    setReflectionQuestions([...reflectionQuestions, ''])
  }

  const updateQuestion = (index: number, value: string) => {
    const updated = [...reflectionQuestions]
    updated[index] = value
    setReflectionQuestions(updated)
  }

  const removeQuestion = (index: number) => {
    setReflectionQuestions(reflectionQuestions.filter((_, i) => i !== index))
  }

  const addPrayerPoint = () => {
    setPrayerPoints([...prayerPoints, ''])
  }

  const updatePrayerPoint = (index: number, value: string) => {
    const updated = [...prayerPoints]
    updated[index] = value
    setPrayerPoints(updated)
  }

  const removePrayerPoint = (index: number) => {
    setPrayerPoints(prayerPoints.filter((_, i) => i !== index))
  }

  const addInsight = () => {
    setInsights([...insights, ''])
  }

  const updateInsight = (index: number, value: string) => {
    const updated = [...insights]
    updated[index] = value
    setInsights(updated)
  }

  const removeInsight = (index: number) => {
    setInsights(insights.filter((_, i) => i !== index))
  }

  const addSummaryInsight = () => {
    setSummaryInsights([...summaryInsights, ''])
  }

  const updateSummaryInsight = (index: number, value: string) => {
    const updated = [...summaryInsights]
    updated[index] = value
    setSummaryInsights(updated)
  }

  const removeSummaryInsight = (index: number) => {
    setSummaryInsights(summaryInsights.filter((_, i) => i !== index))
  }

  const addReflectionAnswer = () => {
    setReflectionAnswers([...reflectionAnswers, ''])
  }

  const updateReflectionAnswer = (index: number, value: string) => {
    const updated = [...reflectionAnswers]
    updated[index] = value
    setReflectionAnswers(updated)
  }

  const removeReflectionAnswer = (index: number) => {
    setReflectionAnswers(reflectionAnswers.filter((_, i) => i !== index))
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
              Edit Study Guide
            </h2>
            <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
              {guide.input_value} • {guide.study_mode} mode • {guide.language}
            </p>
          </div>
          {hasChanges && (
            <span className="inline-flex items-center rounded-full bg-yellow-100 px-3 py-1 text-xs font-medium text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300">
              Unsaved changes
            </span>
          )}
        </div>
      </div>

      {/* All Sections - Ordered as per API response */}
      <div className="space-y-8">
        {/* 1. Summary Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
            <span>📝</span>
            <span>Summary</span>
          </h3>
          <MarkdownEditor
            value={summary}
            onChange={setSummary}
            placeholder="Enter a concise summary of the study guide..."
            rows={10}
            showPreview={false}
          />
        </div>

        {/* 2. Context Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
            <span>📖</span>
            <span>Context</span>
          </h3>
          <MarkdownEditor
            value={context}
            onChange={setContext}
            placeholder="Provide historical, cultural, and biblical context..."
            rows={10}
            showPreview={false}
          />
        </div>

        {/* 3. Interpretation Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
            <span>💡</span>
            <span>Interpretation</span>
          </h3>
          <MarkdownEditor
            value={interpretation}
            onChange={setInterpretation}
            placeholder="Explain the theological meaning and application..."
            rows={10}
            showPreview={false}
          />
        </div>

        {/* 4. Related Verses Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>📖</span>
              <span>Related Verses</span>
            </h3>
            <button
              type="button"
              onClick={addVerse}
              className="flex items-center gap-1 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
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
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Add Verse
            </button>
          </div>

          <div className="space-y-3">
            {relatedVerses.map((verse, index) => (
              <div
                key={index}
                className="flex items-center gap-2"
              >
                <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  {index + 1}.
                </span>
                <input
                  type="text"
                  value={verse.reference}
                  onChange={(e) =>
                    updateVerse(index, 'reference', e.target.value)
                  }
                  placeholder="e.g., John 3:16"
                  className="flex-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                />
                <button
                  type="button"
                  onClick={() => removeVerse(index)}
                  className="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
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
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            ))}

            {relatedVerses.length === 0 && (
              <div className="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center dark:border-gray-700">
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  No related verses added yet
                </p>
                <button
                  type="button"
                  onClick={addVerse}
                  className="mt-2 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
                >
                  Add your first verse
                </button>
              </div>
            )}
          </div>
        </div>

        {/* 5. Reflection Questions Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>❓</span>
              <span>Reflection Questions</span>
            </h3>
            <button
              type="button"
              onClick={addQuestion}
              className="flex items-center gap-1 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
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
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Add Question
            </button>
          </div>

          <div className="space-y-2">
            {reflectionQuestions.map((question, index) => (
              <div key={index} className="flex items-start gap-2">
                <span className="mt-2 flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full bg-primary-100 text-xs font-medium text-primary-800 dark:bg-primary-900/30 dark:text-primary-300">
                  {index + 1}
                </span>
                <input
                  type="text"
                  value={question}
                  onChange={(e) => updateQuestion(index, e.target.value)}
                  placeholder="Enter a reflection question..."
                  className="flex-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                />
                <button
                  type="button"
                  onClick={() => removeQuestion(index)}
                  className="mt-2 text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
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
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            ))}

            {reflectionQuestions.length === 0 && (
              <div className="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center dark:border-gray-700">
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  No reflection questions added yet
                </p>
                <button
                  type="button"
                  onClick={addQuestion}
                  className="mt-2 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
                >
                  Add your first question
                </button>
              </div>
            )}
          </div>
        </div>

        {/* 6. Prayer Points Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>🙏</span>
              <span>Prayer Points</span>
            </h3>
            <button
              type="button"
              onClick={addPrayerPoint}
              className="flex items-center gap-1 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
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
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Add Prayer Point
            </button>
          </div>

          <div className="space-y-2">
            {prayerPoints.map((point, index) => (
              <div key={index} className="flex items-start gap-2">
                <span className="mt-2 text-primary dark:text-primary-400">•</span>
                <input
                  type="text"
                  value={point}
                  onChange={(e) => updatePrayerPoint(index, e.target.value)}
                  placeholder="Enter a prayer point..."
                  className="flex-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                />
                <button
                  type="button"
                  onClick={() => removePrayerPoint(index)}
                  className="mt-2 text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
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
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            ))}

            {prayerPoints.length === 0 && (
              <div className="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center dark:border-gray-700">
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  No prayer points added yet
                </p>
                <button
                  type="button"
                  onClick={addPrayerPoint}
                  className="mt-2 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
                >
                  Add your first prayer point
                </button>
              </div>
            )}
          </div>
        </div>

        {/* 7. Passage Section */}
        {passage && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>📜</span>
              <span>Passage</span>
            </h3>
            <MarkdownEditor
              value={passage}
              onChange={setPassage}
              placeholder="Enter the Bible passage text..."
              rows={6}
              showPreview={false}
            />
          </div>
        )}

        {/* 8. Interpretation Insights (Key Insights) Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>⭐</span>
              <span>Key Insights</span>
            </h3>
            <button
              type="button"
              onClick={addInsight}
              className="flex items-center gap-1 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
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
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Add Insight
            </button>
          </div>

          <div className="space-y-2">
            {insights.map((insight, index) => (
              <div key={index} className="flex items-start gap-2">
                <svg
                  className="mt-2 h-4 w-4 flex-shrink-0 text-yellow-500 dark:text-yellow-400"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                <input
                  type="text"
                  value={insight}
                  onChange={(e) => updateInsight(index, e.target.value)}
                  placeholder="Enter a key insight..."
                  className="flex-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                />
                <button
                  type="button"
                  onClick={() => removeInsight(index)}
                  className="mt-2 text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
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
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            ))}

            {insights.length === 0 && (
              <div className="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center dark:border-gray-700">
                <p className="text-sm text-gray-500 dark:text-gray-400">No insights added yet</p>
                <button
                  type="button"
                  onClick={addInsight}
                  className="mt-2 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
                >
                  Add your first insight
                </button>
              </div>
            )}
          </div>
        </div>

        {/* 9. Summary Insights Section */}
        {summaryInsights.length > 0 && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-4 flex items-center justify-between">
              <h3 className="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
                <span>💭</span>
                <span>Summary Insights</span>
              </h3>
              <button
                type="button"
                onClick={addSummaryInsight}
                className="flex items-center gap-1 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
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
                    d="M12 4v16m8-8H4"
                  />
                </svg>
                Add Insight
              </button>
            </div>

            <div className="space-y-2">
              {summaryInsights.map((insight, index) => (
                <div key={index} className="flex items-start gap-2">
                  <span className="mt-2 text-primary dark:text-primary-400">•</span>
                  <input
                    type="text"
                    value={insight}
                    onChange={(e) => updateSummaryInsight(index, e.target.value)}
                    placeholder="Enter a summary insight..."
                    className="flex-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                  />
                  <button
                    type="button"
                    onClick={() => removeSummaryInsight(index)}
                    className="mt-2 text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
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
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* 10. Reflection Answers Section */}
        {reflectionAnswers.length > 0 && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-4 flex items-center justify-between">
              <h3 className="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
                <span>💬</span>
                <span>Reflection Answers</span>
              </h3>
              <button
                type="button"
                onClick={addReflectionAnswer}
                className="flex items-center gap-1 text-sm font-medium text-primary hover:text-primary-600 dark:text-primary-400 dark:hover:text-primary-300"
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
                    d="M12 4v16m8-8H4"
                  />
                </svg>
                Add Answer
              </button>
            </div>

            <div className="space-y-2">
              {reflectionAnswers.map((answer, index) => (
                <div key={index} className="flex items-start gap-2">
                  <span className="mt-2 flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full bg-green-100 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-300">
                    {index + 1}
                  </span>
                  <textarea
                    value={answer}
                    onChange={(e) => updateReflectionAnswer(index, e.target.value)}
                    placeholder="Enter reflection answer..."
                    rows={3}
                    className="flex-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                  />
                  <button
                    type="button"
                    onClick={() => removeReflectionAnswer(index)}
                    className="mt-2 text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
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
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* 11. Summary Question Section */}
        {summaryQuestion && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>❔</span>
              <span>Summary Question</span>
            </h3>
            <input
              type="text"
              value={summaryQuestion}
              onChange={(e) => setSummaryQuestion(e.target.value)}
              placeholder="Enter summary question..."
              className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
            />
          </div>
        )}

        {/* 12. Related Verses Question Section */}
        {relatedVersesQuestion && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>❔</span>
              <span>Related Verses Question</span>
            </h3>
            <input
              type="text"
              value={relatedVersesQuestion}
              onChange={(e) => setRelatedVersesQuestion(e.target.value)}
              placeholder="Enter related verses question..."
              className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
            />
          </div>
        )}

        {/* 13. Reflection Question Section */}
        {reflectionQuestion && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>❔</span>
              <span>Reflection Question</span>
            </h3>
            <input
              type="text"
              value={reflectionQuestion}
              onChange={(e) => setReflectionQuestion(e.target.value)}
              placeholder="Enter reflection question..."
              className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
            />
          </div>
        )}

        {/* 14. Prayer Question Section */}
        {prayerQuestion && (
          <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
            <h3 className="mb-4 flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
              <span>❔</span>
              <span>Prayer Question</span>
            </h3>
            <input
              type="text"
              value={prayerQuestion}
              onChange={(e) => setPrayerQuestion(e.target.value)}
              placeholder="Enter prayer question..."
              className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
            />
          </div>
        )}
      </div>

      {/* Actions */}
      <div className="flex justify-end gap-3">
        <button
          type="button"
          onClick={onCancel}
          disabled={isSaving}
          className="rounded-lg border border-gray-300 px-6 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={handleSave}
          disabled={!hasChanges || isSaving}
          className="rounded-lg bg-primary px-6 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isSaving ? 'Saving...' : 'Save Changes'}
        </button>
      </div>
    </div>
  )
}
