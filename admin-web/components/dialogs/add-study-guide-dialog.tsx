'use client'

import { useState } from 'react'
import { TranslationEditor } from '@/components/ui/translation-editor'

interface AddStudyGuideDialogProps {
  isOpen: boolean
  pathId: string
  onClose: () => void
  onSuccess: () => void
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

export function AddStudyGuideDialog({
  isOpen,
  pathId,
  onClose,
  onSuccess,
}: AddStudyGuideDialogProps) {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [formData, setFormData] = useState<StudyGuideFormData>({
    title: '',
    description: '',
    category: 'Faith Foundations',
    input_type: 'topic',
    xp_value: 10,
    tags: [],
    translations: {
      en: { title: '', description: '' },
      hi: { title: '', description: '' },
      ml: { title: '', description: '' },
    },
  })

  const [tagInput, setTagInput] = useState('')

  if (!isOpen) return null

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

      // Success! Reset form and close
      setFormData({
        title: '',
        description: '',
        category: 'Faith Foundations',
        input_type: 'topic',
        xp_value: 10,
        tags: [],
        translations: {
          en: { title: '', description: '' },
          hi: { title: '', description: '' },
          ml: { title: '', description: '' },
        },
      })
      setTagInput('')
      onSuccess()
      onClose()
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
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div
        className="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
        onClick={onClose}
      />

      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="relative w-full max-w-2xl rounded-lg bg-white shadow-xl"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
            <h2 className="text-xl font-semibold text-gray-900">
              Add New Study Guide
            </h2>
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="rounded-lg p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <svg
                className="h-6 w-6"
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

          {/* Form */}
          <form onSubmit={handleSubmit} className="p-6">
            <div className="space-y-6">
              {/* Error Message */}
              {error && (
                <div className="rounded-lg bg-red-50 p-4">
                  <p className="text-sm text-red-800">{error}</p>
                </div>
              )}

              {/* Basic Info */}
              <div className="space-y-4">
                <h3 className="text-sm font-semibold text-gray-900">
                  Basic Information
                </h3>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700">
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
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50"
                  />
                </div>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700">
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
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50"
                  />
                </div>
              </div>

              {/* Category & Type */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700">
                    Category *
                  </label>
                  <select
                    value={formData.category}
                    onChange={(e) =>
                      setFormData({ ...formData, category: e.target.value })
                    }
                    required
                    disabled={isSubmitting}
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50"
                  >
                    {CATEGORIES.map((cat) => (
                      <option key={cat} value={cat}>
                        {cat}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700">
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
                    className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50"
                  >
                    <option value="topic">Topic</option>
                    <option value="verse">Verse</option>
                    <option value="question">Question</option>
                  </select>
                </div>
              </div>

              {/* XP Value */}
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
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
                  className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50"
                />
              </div>

              {/* Tags */}
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
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
                    className="flex-1 rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:bg-gray-50"
                  />
                  <button
                    type="button"
                    onClick={handleAddTag}
                    disabled={isSubmitting || !tagInput.trim()}
                    className="rounded-lg bg-gray-200 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-300 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Add
                  </button>
                </div>
                {formData.tags.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-2">
                    {formData.tags.map((tag) => (
                      <span
                        key={tag}
                        className="inline-flex items-center gap-1 rounded-full bg-gray-200 px-3 py-1 text-sm text-gray-700"
                      >
                        {tag}
                        <button
                          type="button"
                          onClick={() => handleRemoveTag(tag)}
                          disabled={isSubmitting}
                          className="text-gray-500 hover:text-gray-700 disabled:cursor-not-allowed"
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
                <h3 className="mb-4 text-sm font-semibold text-gray-900">
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
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={onClose}
                disabled={isSubmitting}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting || !formData.title || !formData.description}
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
