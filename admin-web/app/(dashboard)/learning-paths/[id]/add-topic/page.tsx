'use client'

import { useState, use } from 'react'
import { useRouter } from 'next/navigation'
import { TranslationEditor } from '@/components/ui/translation-editor'

interface PageProps {
  params: Promise<{ id: string }>
}

interface Translation {
  title: string
  description: string
}

interface StudyGuideFormData {
  title: string
  description: string
  category: string
  input_type: 'topic' | 'verse' | 'question'
  input_value: string
  xp_value: number
  tags: string[]
  translations: {
    en?: Translation
    hi?: Translation
    ml?: Translation
  }
}

const CATEGORIES = [
  'Faith Foundations',
  'Character Building',
  'Service & Ministry',
  'Apologetics',
  'Family & Relationships',
  'Theology & Philosophy',
  'Spiritual Disciplines',
  'Love & Compassion',
  'Wisdom & Knowledge',
  'Leadership',
]

export default function AddTopicToPathPage({ params }: PageProps) {
  const { id: pathId } = use(params)
  const router = useRouter()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [formData, setFormData] = useState<StudyGuideFormData>({
    title: '',
    description: '',
    category: 'Faith Foundations',
    input_type: 'topic',
    input_value: '',
    xp_value: 10,
    tags: [],
    translations: {
      en: { title: '', description: '' },
      hi: { title: '', description: '' },
      ml: { title: '', description: '' },
    },
  })

  const [tagInput, setTagInput] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)
    setError(null)

    try {
      // Create the topic
      const createResponse = await fetch('/api/admin/topics', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: formData.title,
          description: formData.description,
          category: formData.category,
          input_type: formData.input_type,
          input_value: formData.input_value,
          xp_value: formData.xp_value,
          tags: formData.tags,
          translations: formData.translations,
        }),
      })

      if (!createResponse.ok) {
        const errorData = await createResponse.json()
        throw new Error(errorData.error || 'Failed to create study guide')
      }

      const createData = await createResponse.json()
      const newTopicId = createData.topic.id

      // Add topic to path
      const addResponse = await fetch('/api/admin/path-topics', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          learning_path_id: pathId,
          topic_id: newTopicId,
          position: 999, // Will be reordered by user if needed
        }),
      })

      if (!addResponse.ok) {
        const errorData = await addResponse.json()
        throw new Error(errorData.error || 'Failed to add topic to path')
      }

      // Success! Navigate back
      router.push(`/learning-paths/${pathId}`)
    } catch (err) {
      console.error('Failed to create study guide:', err)
      setError(err instanceof Error ? err.message : 'Failed to create study guide')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleAddTag = () => {
    if (tagInput.trim() && !formData.tags.includes(tagInput.trim())) {
      setFormData({
        ...formData,
        tags: [...formData.tags, tagInput.trim()],
      })
      setTagInput('')
    }
  }

  const handleRemoveTag = (tagToRemove: string) => {
    setFormData({
      ...formData,
      tags: formData.tags.filter((tag) => tag !== tagToRemove),
    })
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6 dark:bg-gray-900">
      <div className="mx-auto max-w-3xl">
        {/* Header */}
        <div className="mb-6">
          <button
            onClick={() => router.push(`/learning-paths/${pathId}`)}
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
            Back to Learning Path
          </button>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
            Add New Study Guide
          </h1>
          <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
            Create a new study guide and add it to this learning path
          </p>
        </div>

        {/* Form */}
        <div className="rounded-lg bg-white shadow dark:bg-gray-800 dark:shadow-gray-900">
          <form onSubmit={handleSubmit} className="p-6">
            {/* Error Message */}
            {error && (
              <div className="mb-6 rounded-lg bg-red-50 p-4 dark:bg-red-900/20">
                <p className="text-sm text-red-800 dark:text-red-300">{error}</p>
              </div>
            )}

            <div className="space-y-6">
              {/* Basic Info */}
              <div className="space-y-4">
                <h3 className="text-sm font-semibold text-gray-900 dark:text-gray-100">
                  Basic Information
                </h3>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Title *
                  </label>
                  <input
                    type="text"
                    value={formData.title}
                    onChange={(e) =>
                      setFormData({ ...formData, title: e.target.value })
                    }
                    required
                    disabled={isSubmitting}
                    placeholder="Enter study guide title"
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400 dark:disabled:bg-gray-800"
                  />
                </div>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Description *
                  </label>
                  <textarea
                    value={formData.description}
                    onChange={(e) =>
                      setFormData({ ...formData, description: e.target.value })
                    }
                    required
                    disabled={isSubmitting}
                    placeholder="Enter description"
                    rows={3}
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400 dark:disabled:bg-gray-800"
                  />
                </div>
              </div>

              {/* Category & Type */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Category *
                  </label>
                  <select
                    value={formData.category}
                    onChange={(e) =>
                      setFormData({ ...formData, category: e.target.value })
                    }
                    required
                    disabled={isSubmitting}
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:disabled:bg-gray-800"
                  >
                    {CATEGORIES.map((cat) => (
                      <option key={cat} value={cat}>
                        {cat}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Input Type *
                  </label>
                  <select
                    value={formData.input_type}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        input_type: e.target.value as 'topic' | 'verse' | 'question',
                      })
                    }
                    required
                    disabled={isSubmitting}
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:disabled:bg-gray-800"
                  >
                    <option value="topic">Topic</option>
                    <option value="verse">Verse</option>
                    <option value="question">Question</option>
                  </select>
                </div>
              </div>

              {/* Input Value */}
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Input Value *
                </label>
                <input
                  type="text"
                  value={formData.input_value}
                  onChange={(e) =>
                    setFormData({ ...formData, input_value: e.target.value })
                  }
                  required
                  disabled={isSubmitting}
                  placeholder={
                    formData.input_type === 'topic'
                      ? 'e.g., The Trinity'
                      : formData.input_type === 'verse'
                        ? 'e.g., John 3:16'
                        : 'e.g., What is salvation?'
                  }
                  className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400 dark:disabled:bg-gray-800"
                />
              </div>

              {/* XP Value */}
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  XP Value *
                </label>
                <input
                  type="number"
                  value={formData.xp_value}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      xp_value: parseInt(e.target.value) || 0,
                    })
                  }
                  required
                  min="0"
                  disabled={isSubmitting}
                  className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:disabled:bg-gray-800"
                />
              </div>

              {/* Tags */}
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Tags
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={tagInput}
                    onChange={(e) => setTagInput(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') {
                        e.preventDefault()
                        handleAddTag()
                      }
                    }}
                    disabled={isSubmitting}
                    placeholder="Add a tag and press Enter"
                    className="flex-1 rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400 dark:disabled:bg-gray-800"
                  />
                  <button
                    type="button"
                    onClick={handleAddTag}
                    disabled={isSubmitting || !tagInput.trim()}
                    className="rounded-lg bg-gray-200 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-300 disabled:cursor-not-allowed disabled:opacity-50 dark:bg-gray-600 dark:text-gray-300 dark:hover:bg-gray-500"
                  >
                    Add
                  </button>
                </div>
                {formData.tags.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-2">
                    {formData.tags.map((tag) => (
                      <span
                        key={tag}
                        className="inline-flex items-center gap-1 rounded-full bg-gray-200 px-3 py-1 text-sm text-gray-700 dark:bg-gray-600 dark:text-gray-300"
                      >
                        {tag}
                        <button
                          type="button"
                          onClick={() => handleRemoveTag(tag)}
                          disabled={isSubmitting}
                          className="text-gray-500 hover:text-gray-700 disabled:cursor-not-allowed dark:text-gray-400 dark:hover:text-gray-200"
                        >
                          ×
                        </button>
                      </span>
                    ))}
                  </div>
                )}
              </div>

              {/* Translations */}
              <div>
                <h3 className="mb-4 text-sm font-semibold text-gray-900 dark:text-gray-100">
                  Translations
                </h3>
                <TranslationEditor
                  translations={formData.translations}
                  onChange={(translations) =>
                    setFormData({ ...formData, translations })
                  }
                  disabled={isSubmitting}
                />
              </div>
            </div>

            {/* Footer */}
            <div className="mt-8 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => router.push(`/learning-paths/${pathId}`)}
                disabled={isSubmitting}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting || !formData.title || !formData.description || !formData.input_value}
                className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {isSubmitting ? 'Creating...' : 'Create Study Guide'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
