'use client'

import { useState, useEffect, use } from 'react'
import { useRouter } from 'next/navigation'
import { TranslationEditor } from '@/components/ui/translation-editor'
import { IconColorPicker } from '@/components/ui/icon-color-picker'
import { StudyModeSelector } from '@/components/ui/study-mode-selector'
import { PathTopicOrganizer } from '@/components/dialogs/path-topic-organizer'
import type {
  LearningPathWithDetails,
  UpdateLearningPathRequest,
  DifficultyLevel,
  DiscipleLevel,
  StudyMode,
} from '@/types/admin'
import { getLearningPath, updateLearningPath } from '@/lib/api/admin'

interface PageProps {
  params: Promise<{ id: string }>
}

type TabType = 'basic' | 'visual' | 'settings' | 'translations' | 'topics'

// Icon mapping
const ICON_MAP: Record<string, string> = {
  book: '📖',
  school: '🎓',
  cross: '✝️',
  heart: '❤️',
  star: '⭐',
  pray: '🙏',
  dove: '🕊️',
  light: '💡',
  path: '🛤️',
  compass: '🧭',
  crown: '👑',
  mountain: '⛰️',
  // Legacy icon names from database
  auto_stories: '📖',
  trending_up: '📈',
  volunteer_activism: '🤝',
  shield: '🛡️',
  family_restroom: '👨‍👩‍👧‍👦',
  psychology: '🧠',
  spa: '🕊️',
  favorite: '❤️',
  lightbulb: '💡',
}

export default function EditLearningPathPage({ params }: PageProps) {
  const { id } = use(params)
  const router = useRouter()

  const [activeTab, setActiveTab] = useState<TabType>('basic')
  const [isLoading, setIsLoading] = useState(true)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [path, setPath] = useState<LearningPathWithDetails | null>(null)

  // Form state
  const [formData, setFormData] = useState<UpdateLearningPathRequest>({
    title: '',
    description: '',
    icon_name: 'book',
    color: '#6A4FB6',
    estimated_days: 7,
    difficulty_level: 'beginner',
    disciple_level: 'seeker',
    recommended_mode: 'standard',
    is_featured: false,
    is_active: true,
    allow_non_sequential_access: false,
    translations: {
      en: { title: '', description: '' },
    },
  })

  // Load learning path
  useEffect(() => {
    loadPath()
  }, [id])

  const loadPath = async () => {
    setIsLoading(true)
    try {
      const response = await getLearningPath(id)
      const pathData = response.learning_path

      setPath(pathData)
      setFormData({
        title: pathData.title,
        description: pathData.description,
        icon_name: pathData.icon_name,
        color: pathData.color,
        estimated_days: pathData.estimated_days,
        difficulty_level: pathData.difficulty_level,
        disciple_level: pathData.disciple_level,
        recommended_mode: pathData.recommended_mode,
        is_featured: pathData.is_featured,
        is_active: pathData.is_active,
        allow_non_sequential_access: pathData.allow_non_sequential_access,
        translations: pathData.translations || {
          en: { title: pathData.title, description: pathData.description },
        },
      })
    } catch (err) {
      console.error('Failed to load learning path:', err)
      setErrors({ submit: 'Failed to load learning path. Please try again.' })
    } finally {
      setIsLoading(false)
    }
  }

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {}

    if (!formData.title) newErrors.title = 'Title is required'
    if (!formData.description) newErrors.description = 'Description is required'
    if (formData.estimated_days !== undefined && formData.estimated_days < 1)
      newErrors.estimated_days = 'Must be at least 1 day'

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) {
      return
    }

    setIsSubmitting(true)
    try {
      await updateLearningPath(id, formData)
      router.push('/learning-paths')
    } catch (error) {
      console.error('Failed to update learning path:', error)
      setErrors({ submit: 'Failed to update learning path. Please try again.' })
    } finally {
      setIsSubmitting(false)
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

  if (!path) {
    return (
      <div className="flex min-h-screen items-center justify-center dark:bg-gray-900">
        <div className="text-center">
          <p className="text-red-600 dark:text-red-400">Learning path not found</p>
          <button
            onClick={() => router.push('/learning-paths')}
            className="mt-4 text-primary hover:underline"
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
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.push('/learning-paths')}
            className="text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
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
                d="M15 19l-7-7 7-7"
              />
            </svg>
          </button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Edit Learning Path</h1>
            <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">{path.title}</p>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="mx-auto max-w-5xl">
        <div className="overflow-hidden rounded-lg bg-white shadow dark:bg-gray-800 dark:shadow-gray-900">
          {/* Tabs */}
          <div className="border-b border-gray-200 bg-gray-50 px-6 dark:border-gray-700 dark:bg-gray-800">
            <nav className="flex gap-4 overflow-x-auto">
              {[
                { id: 'basic', label: 'Basic Info' },
                { id: 'visual', label: 'Visual' },
                { id: 'settings', label: 'Settings' },
                { id: 'translations', label: 'Translations' },
                { id: 'topics', label: 'Topics' },
              ].map((tab) => (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setActiveTab(tab.id as TabType)}
                  className={`whitespace-nowrap border-b-2 px-4 py-3 text-sm font-medium transition-colors ${
                    activeTab === tab.id
                      ? 'border-primary text-primary'
                      : 'border-transparent text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100'
                  }`}
                >
                  {tab.label}
                  {tab.id === 'topics' && (
                    <span className="ml-2 inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">
                      {path.topics_count || 0}
                    </span>
                  )}
                </button>
              ))}
            </nav>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="p-6">
            {/* Basic Info Tab */}
            {activeTab === 'basic' && (
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Slug
                  </label>
                  <input
                    type="text"
                    value={path?.slug || ''}
                    disabled
                    className="mt-1 w-full cursor-not-allowed rounded-lg border border-gray-300 bg-gray-100 px-4 py-2 text-gray-500 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-400"
                  />
                  <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                    Slug cannot be changed after creation
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Title <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={formData.title}
                    onChange={(e) =>
                      setFormData({ ...formData, title: e.target.value })
                    }
                    className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                  />
                  {errors.title && (
                    <p className="mt-1 text-xs text-red-600 dark:text-red-400">{errors.title}</p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Description <span className="text-red-500">*</span>
                  </label>
                  <textarea
                    value={formData.description}
                    onChange={(e) =>
                      setFormData({ ...formData, description: e.target.value })
                    }
                    rows={4}
                    className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
                  />
                  {errors.description && (
                    <p className="mt-1 text-xs text-red-600 dark:text-red-400">{errors.description}</p>
                  )}
                </div>

                {/* Summary Stats */}
                <div className="grid grid-cols-3 gap-4 rounded-lg border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-700">
                  <div className="text-center">
                    <p className="text-sm text-gray-600 dark:text-gray-400">Total XP</p>
                    <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                      {path.total_xp || 0}
                    </p>
                  </div>
                  <div className="text-center">
                    <p className="text-sm text-gray-600 dark:text-gray-400">Topics</p>
                    <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                      {path.topics_count || 0}
                    </p>
                  </div>
                  <div className="text-center">
                    <p className="text-sm text-gray-600 dark:text-gray-400">Enrolled</p>
                    <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                      {path.enrolled_count || 0}
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Visual Tab */}
            {activeTab === 'visual' && (
              <div className="space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Icon & Color
                  </label>
                  <div className="mt-2">
                    <IconColorPicker
                      selectedIcon={formData.icon_name ?? ''}
                      selectedColor={formData.color ?? ''}
                      onIconChange={(icon) =>
                        setFormData({ ...formData, icon_name: icon })
                      }
                      onColorChange={(color) =>
                        setFormData({ ...formData, color })
                      }
                    />
                  </div>
                </div>

                {/* Preview */}
                <div className="rounded-lg border border-gray-200 bg-gray-50 p-6 dark:border-gray-700 dark:bg-gray-700">
                  <p className="mb-4 text-sm font-medium text-gray-700 dark:text-gray-300">Preview</p>
                  <div
                    className="inline-flex items-center gap-3 rounded-lg p-4"
                    style={{ backgroundColor: `${formData.color}20` }}
                  >
                    <div
                      className="flex h-12 w-12 items-center justify-center rounded-lg text-2xl"
                      style={{ backgroundColor: formData.color }}
                    >
                      {formData.icon_name ? ICON_MAP[formData.icon_name] || '📚' : '📚'}
                    </div>
                    <div>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">{formData.title}</p>
                      <p className="text-sm text-gray-600 dark:text-gray-400">{formData.description}</p>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Settings Tab */}
            {activeTab === 'settings' && (
              <div className="space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Estimated Days
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={formData.estimated_days}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        estimated_days: parseInt(e.target.value) || 1,
                      })
                    }
                    className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                  />
                  {errors.estimated_days && (
                    <p className="mt-1 text-xs text-red-600 dark:text-red-400">{errors.estimated_days}</p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Difficulty Level
                  </label>
                  <select
                    value={formData.difficulty_level}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        difficulty_level: e.target.value as DifficultyLevel,
                      })
                    }
                    className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                  >
                    <option value="beginner">Beginner</option>
                    <option value="intermediate">Intermediate</option>
                    <option value="advanced">Advanced</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Disciple Level
                  </label>
                  <select
                    value={formData.disciple_level}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        disciple_level: e.target.value as DiscipleLevel,
                      })
                    }
                    className="mt-1 w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                  >
                    <option value="seeker">Seeker</option>
                    <option value="new_believer">New Believer</option>
                    <option value="growing">Growing</option>
                    <option value="mature">Mature</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Recommended Study Mode
                  </label>
                  <div className="mt-2">
                    <StudyModeSelector
                      selectedMode={formData.recommended_mode ?? 'standard'}
                      onChange={(mode) =>
                        setFormData({ ...formData, recommended_mode: mode as StudyMode })
                      }
                    />
                  </div>
                </div>

                <div className="space-y-3 rounded-lg border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-700">
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={formData.is_featured}
                      onChange={(e) =>
                        setFormData({ ...formData, is_featured: e.target.checked })
                      }
                      className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary dark:border-gray-600 dark:bg-gray-600"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">Featured Path</span>
                  </label>

                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={formData.is_active}
                      onChange={(e) =>
                        setFormData({ ...formData, is_active: e.target.checked })
                      }
                      className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary dark:border-gray-600 dark:bg-gray-600"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">Active</span>
                  </label>

                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={formData.allow_non_sequential_access}
                      onChange={(e) =>
                        setFormData({
                          ...formData,
                          allow_non_sequential_access: e.target.checked,
                        })
                      }
                      className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary dark:border-gray-600 dark:bg-gray-600"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">
                      Allow Non-Sequential Access
                    </span>
                  </label>
                </div>
              </div>
            )}

            {/* Translations Tab */}
            {activeTab === 'translations' && (
              <div>
                <TranslationEditor
                  translations={formData.translations || {}}
                  onChange={(translations) =>
                    setFormData({ ...formData, translations })
                  }
                />
              </div>
            )}

            {/* Topics Tab */}
            {activeTab === 'topics' && (
              <div>
                <PathTopicOrganizer pathId={id} />
              </div>
            )}

            {/* Error Message */}
            {errors.submit && (
              <div className="mt-4 rounded-lg bg-red-50 p-4 dark:bg-red-900/20">
                <p className="text-sm text-red-800 dark:text-red-300">{errors.submit}</p>
              </div>
            )}

            {/* Footer - Only show on non-topics tabs */}
            {activeTab !== 'topics' && (
              <div className="mt-6 flex justify-end gap-3">
                <button
                  type="button"
                  onClick={() => router.push('/learning-paths')}
                  disabled={isSubmitting}
                  className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {isSubmitting ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            )}
          </form>
        </div>
      </div>
    </div>
  )
}
