'use client'

import { useState, useEffect } from 'react'
import { TranslationEditor } from '@/components/ui/translation-editor'
import { IconColorPicker } from '@/components/ui/icon-color-picker'
import { StudyModeSelector } from '@/components/ui/study-mode-selector'
import { PathTopicOrganizer } from './path-topic-organizer'
import type {
  LearningPathWithDetails,
  UpdateLearningPathRequest,
  DifficultyLevel,
  DiscipleLevel,
  StudyMode,
} from '@/types/admin'

interface EditLearningPathDialogProps {
  isOpen: boolean
  path: LearningPathWithDetails | null
  onClose: () => void
  onSubmit: (id: string, data: UpdateLearningPathRequest) => Promise<void>
}

type TabType = 'basic' | 'visual' | 'settings' | 'translations' | 'topics'

export function EditLearningPathDialog({
  isOpen,
  path,
  onClose,
  onSubmit,
}: EditLearningPathDialogProps) {
  const [activeTab, setActiveTab] = useState<TabType>('basic')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

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

  // Load path data when dialog opens
  useEffect(() => {
    if (path) {
      setFormData({
        title: path.title,
        description: path.description,
        icon_name: path.icon_name,
        color: path.color,
        estimated_days: path.estimated_days,
        difficulty_level: path.difficulty_level,
        disciple_level: path.disciple_level,
        recommended_mode: path.recommended_mode,
        is_featured: path.is_featured,
        is_active: path.is_active,
        allow_non_sequential_access: path.allow_non_sequential_access,
        translations: path.translations || {
          en: { title: path.title, description: path.description },
        },
      })
      setActiveTab('basic')
      setErrors({})
    }
  }, [path])

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

    if (!path || !validateForm()) {
      return
    }

    setIsSubmitting(true)
    try {
      await onSubmit(path.id, formData)
      onClose()
    } catch (error) {
      console.error('Failed to update learning path:', error)
      setErrors({ submit: 'Failed to update learning path. Please try again.' })
    } finally {
      setIsSubmitting(false)
    }
  }

  if (!isOpen || !path) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="max-h-[90vh] w-full max-w-4xl overflow-hidden rounded-lg bg-white shadow-xl">
        {/* Header */}
        <div className="border-b border-gray-200 px-6 py-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold text-gray-900">
              Edit Learning Path
            </h2>
            <button
              type="button"
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600"
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
        </div>

        {/* Tabs */}
        <div className="border-b border-gray-200 bg-gray-50 px-6">
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
                className={`border-b-2 px-4 py-3 text-sm font-medium transition-colors whitespace-nowrap ${
                  activeTab === tab.id
                    ? 'border-primary text-primary'
                    : 'border-transparent text-gray-600 hover:text-gray-900'
                }`}
              >
                {tab.label}
                {tab.id === 'topics' && (
                  <span className="ml-2 inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800">
                    {path.topics_count || 0}
                  </span>
                )}
              </button>
            ))}
          </nav>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="max-h-[60vh] overflow-y-auto p-6">
          {/* Basic Info Tab */}
          {activeTab === 'basic' && (
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Slug
                </label>
                <input
                  type="text"
                  value={path?.slug || ''}
                  disabled
                  className="mt-1 w-full rounded-lg border border-gray-300 bg-gray-100 px-4 py-2 text-gray-500 cursor-not-allowed"
                />
                <p className="mt-1 text-xs text-gray-500">
                  Slug cannot be changed after creation
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Title <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) =>
                    setFormData({ ...formData, title: e.target.value })
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                  placeholder="Faith Foundations"
                />
                {errors.title && (
                  <p className="mt-1 text-xs text-red-600">{errors.title}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Description <span className="text-red-500">*</span>
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) =>
                    setFormData({ ...formData, description: e.target.value })
                  }
                  rows={4}
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                  placeholder="Build strong foundations in Christian faith..."
                />
                {errors.description && (
                  <p className="mt-1 text-xs text-red-600">{errors.description}</p>
                )}
              </div>

              {/* Stats */}
              <div className="grid grid-cols-3 gap-4 rounded-lg border border-gray-200 bg-gray-50 p-4">
                <div>
                  <p className="text-xs text-gray-500">Total XP</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {path.total_xp}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-gray-500">Topics</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {path.topics_count || 0}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-gray-500">Enrolled</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {path.enrolled_count || 0}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Visual Tab */}
          {activeTab === 'visual' && (
            <div>
              <IconColorPicker
                selectedIcon={formData.icon_name || 'book'}
                selectedColor={formData.color || '#6A4FB6'}
                onIconChange={(icon) =>
                  setFormData({ ...formData, icon_name: icon })
                }
                onColorChange={(color) => setFormData({ ...formData, color })}
              />
            </div>
          )}

          {/* Settings Tab */}
          {activeTab === 'settings' && (
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700">
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
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                />
                {errors.estimated_days && (
                  <p className="mt-1 text-xs text-red-600">
                    {errors.estimated_days}
                  </p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
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
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  <option value="beginner">Beginner</option>
                  <option value="intermediate">Intermediate</option>
                  <option value="advanced">Advanced</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
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
                  className="mt-1 w-full rounded-lg border border-gray-300 px-4 py-2 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  <option value="seeker">Seeker</option>
                  <option value="follower">Follower</option>
                  <option value="disciple">Disciple</option>
                  <option value="leader">Leader</option>
                </select>
              </div>

              <StudyModeSelector
                selectedMode={formData.recommended_mode || 'standard'}
                onChange={(mode) =>
                  setFormData({ ...formData, recommended_mode: mode })
                }
              />

              <div className="space-y-3">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_featured}
                    onChange={(e) =>
                      setFormData({ ...formData, is_featured: e.target.checked })
                    }
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                  />
                  <span className="text-sm text-gray-700">Featured Path</span>
                </label>

                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={(e) =>
                      setFormData({ ...formData, is_active: e.target.checked })
                    }
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                  />
                  <span className="text-sm text-gray-700">Active</span>
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
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                  />
                  <span className="text-sm text-gray-700">
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
              <PathTopicOrganizer pathId={path.id} />
            </div>
          )}

          {/* Error Message */}
          {errors.submit && (
            <div className="mt-4 rounded-lg bg-red-50 p-4">
              <p className="text-sm text-red-800">{errors.submit}</p>
            </div>
          )}
        </form>

        {/* Footer */}
        {activeTab !== 'topics' && (
          <div className="border-t border-gray-200 bg-gray-50 px-6 py-4">
            <div className="flex justify-end gap-3">
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
                onClick={handleSubmit}
                disabled={isSubmitting}
                className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-50"
              >
                {isSubmitting ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
